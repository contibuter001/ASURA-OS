package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"syscall"
	"time"

	"asura/desktop/internal/overlay"
	"asura/desktop/internal/runner"
)

// asuraUpdate runs the complete Void Linux system update lifecycle.
//
// Lifecycle sequence:
//  1. Snapshot ~/.config to git AND create an atomic Btrfs root snapshot
//     (/.snapshots/pre-update-<timestamp>) if / is on Btrfs.
//  2. Run system package updates via xbps-install -Su -y (routing through
//     asura-sysd socket /run/asura/sysd.sock or sudo xbps-install -Su -y).
//  3. Update installed Flatpaks via flatpak update -y (if flatpak is present).
//  4. Re-materialize the /usr/share/asura/ base overlay with ~/.config/asura/user_edits/
//     and trigger a live shell/daemon reload.
func asuraUpdate(args []string) int {
	set := newFlags("update", updateUsage)
	var (
		root       = set.String("root", "", "operate on a tree under this directory")
		dryRun     = set.Bool("dry-run", false, "do the snapshot and preserve steps, fetch nothing")
		noSnapshot = set.Bool("no-snapshot", false, "skip the config snapshot")
		unstable   = set.Bool("unstable", false, "pull the latest code from the dev-unstable branch")
		branch     = set.String("branch", "", "git branch to pull code updates from (default: dev-unstable)")
		channel    = set.String("channel", "", "channel to update from (stable, unstable, dev-unstable)")
		system     = set.Bool("system", false, "force update of all system packages (XBPS)")
		asuraOnly  = set.Bool("asura-only", false, "only update ASURA packages and desktop components")
	)
	if err := set.Parse(args); err != nil {
		return exitUsage
	}

	targetBranch := ""
	if *unstable {
		targetBranch = "dev-unstable"
	} else if *branch != "" {
		targetBranch = *branch
	} else if *channel == "unstable" || *channel == "dev-unstable" {
		targetBranch = "dev-unstable"
	} else {
		if ch, err := xbpsChannel(*root); err == nil {
			if ch == "unstable" || ch == "dev-unstable" {
				targetBranch = "dev-unstable"
			}
		}
	}

	paths, err := overlayPaths(*root)
	if err != nil {
		fmt.Fprintln(os.Stderr, "asura update:", err)
		return exitFail
	}

	isRoot := os.Geteuid() == 0
	updateSystemPkgs := (isRoot || *system) && !*asuraOnly

	var snapshot func(overlay.Paths) error
	if !*noSnapshot {
		snapshot = func(p overlay.Paths) error {
			if err := gitSnapshot(p); err != nil {
				return err
			}
			if !*dryRun && updateSystemPkgs {
				if snap, err := createBtrfsSnapshot(); err != nil {
					fmt.Fprintf(os.Stderr, "asura update: btrfs snapshot: %v\n", err)
				} else if snap != "" {
					fmt.Printf("created system Btrfs snapshot: %s\n", snap)
				}
			}
			return nil
		}
	}

	var asuraErr error
	var fetch func() error
	if !*dryRun {
		fetch = func() error {
			// Step: the ASURA code from its branch (dev-unstable unless the
			// channel or a flag names another), applied to this system.
			b := targetBranch
			if b == "" {
				b = "dev-unstable"
			}
			fmt.Printf("==> Step 1/4: Updating ASURA from the '%s' branch...\n", b)
			if err := pullGitUpdates(b, *root); err != nil {
				asuraErr = err
				fmt.Fprintf(os.Stderr, "asura update: ASURA was not updated: %v\n", err)
			}

			// Full system package update via XBPS (only when root or --system)
			if updateSystemPkgs {
				return voidFetch()
			}
			return nil
		}
	} else {
		fetch = nil
	}

	// Step 1 & 2 & 4: snapshot, package update, and re-materialization
	if err := overlay.Update(paths, snapshot, fetch); err != nil {
		fmt.Fprintln(os.Stderr, "asura update:", err)
		return exitFail
	}

	// Step 3: Flatpak updates (if flatpak is present)
	if !*dryRun {
		updateFlatpaks()
	}

	// Regenerate GRUB so the new Btrfs snapshot gets a boot entry (only on system updates)
	if !*dryRun && updateSystemPkgs && isBtrfsRoot() {
		if _, err := exec.LookPath("grub-mkconfig"); err == nil {
			fmt.Println("==> Regenerating GRUB boot menu (snapshot entries)...")
			cmd := exec.Command("grub-mkconfig", "-o", "/boot/grub/grub.cfg")
			cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
			if err := cmd.Run(); err != nil {
				fmt.Fprintf(os.Stderr, "asura update: grub-mkconfig: %v\n", err)
			}
		}
	}

	status, err := overlay.StatusOf(paths)
	if err != nil {
		fmt.Fprintln(os.Stderr, "asura update:", err)
		return exitFail
	}
	fmt.Printf("updated to revision %s\n", status.Revision)
	fmt.Printf("config materialized; %d user edit(s), %d stale, %d missing\n",
		status.Edits, status.Stale, status.Missing)

	// Step 4b: Reconcile shell config and trigger live reload
	if msg, err := reconcileShellConfig(filepath.Join(paths.Config, "shell.json"), true); err != nil {
		fmt.Fprintln(os.Stderr, "asura update:", err)
	} else if msg != "" {
		fmt.Println(msg)
	}

	if !*dryRun {
		// The running desktop picks up what was just installed: services
		// re-synced, Hyprland reloaded, the shell and daemons restarted. No
		// logout needed.
		fmt.Println("==> Step 4/4: Refreshing the running desktop...")
		if os.Geteuid() == 0 {
			refreshAsSudoUser(os.Stdout, os.Stderr)
		} else {
			refreshMain(os.Stdout, os.Stderr, runner.Exec(20*time.Second))
		}
	}

	if asuraErr != nil {
		fmt.Fprintln(os.Stderr, "\n==> ASURA update FAILED:", asuraErr)
		fmt.Fprintln(os.Stderr, "==> The desktop was refreshed, but runs the code it had before. `asura doctor` checks the system.")
		return exitFail
	}
	if !updateSystemPkgs {
		fmt.Println("\n--------------------------------------------------------------------------------")
		fmt.Println("==> ASURA packages and desktop components are up to date.")
		fmt.Println("==> Recommendation: To update all base system packages (XBPS) and OS, run:")
		fmt.Println("    sudo asura update")
		fmt.Println("--------------------------------------------------------------------------------")
	} else {
		fmt.Println("\n==> Full system and ASURA update complete.")
	}

	return exitOK
}

// voidFetch executes the system package update via Void Linux XBPS.
// It first attempts to route through the privileged asura-sysd socket.
// If the daemon is not active, it falls back to direct xbps-install.
func voidFetch() error {
	fmt.Println("==> Step 2/4: Updating system packages (XBPS)...")

	// Try sysd socket first
	if err := runSysdPkgUpdate(); err == nil {
		fmt.Println("system packages updated via asura-sysd")
		return nil
	}

	// Fallback to local xbps-install command
	return runLocalXbpsUpdate()
}

// runSysdPkgUpdate communicates with asura-sysd over /run/asura/sysd.sock.
func runSysdPkgUpdate() error {
	conn, err := net.DialTimeout("unix", "/run/asura/sysd.sock", 2*time.Second)
	if err != nil {
		return err
	}
	defer conn.Close()

	req := struct {
		Action string `json:"action"`
	}{
		Action: "pkg_update",
	}
	data, err := json.Marshal(req)
	if err != nil {
		return err
	}
	if _, err := conn.Write(append(data, '\n')); err != nil {
		return err
	}

	scanner := bufio.NewScanner(conn)
	if scanner.Scan() {
		var res struct {
			Status  string `json:"status"`
			Message string `json:"message"`
		}
		if err := json.Unmarshal(scanner.Bytes(), &res); err != nil {
			return err
		}
		if res.Status != "ok" {
			return fmt.Errorf("sysd returned error: %s", res.Message)
		}
		return nil
	}
	return fmt.Errorf("no response from asura-sysd")
}

// runLocalXbpsUpdate executes xbps-install -Su -y locally with privilege elevation.
//
// A third-party repository (hyprland-void) can lag behind a library soname
// bump in Void: the update then aborts with exit 8, "broken, unresolvable
// shlib", and nothing at all is updated. In that case the packages XBPS names
// as broken, and the installed library each of them needs, are held for one
// retry so everything else updates; the holds are released afterwards, so the
// next update tries them again once the repository has rebuilt.
func runLocalXbpsUpdate() error {
	elevate := func(prog string, args ...string) *exec.Cmd {
		if os.Geteuid() != 0 {
			return exec.Command("sudo", append([]string{prog}, args...)...)
		}
		return exec.Command(prog, args...)
	}
	run := func() (string, error) {
		var buf strings.Builder
		cmd := elevate("xbps-install", "-Su", "-y")
		cmd.Stdout = io.MultiWriter(os.Stdout, &buf)
		cmd.Stderr = io.MultiWriter(os.Stderr, &buf)
		cmd.Stdin = os.Stdin
		err := cmd.Run()
		return buf.String(), err
	}

	out, err := run()
	if err == nil {
		return nil
	}
	exitErr, ok := err.(*exec.ExitError)
	if !ok || exitErr.ExitCode() != 8 {
		return fmt.Errorf("xbps-install: %w", err)
	}

	broken, shlibs := parseBrokenShlibs(out)
	hold := append([]string(nil), broken...)
	for _, lib := range shlibs {
		if owner := shlibOwner(lib); owner != "" {
			hold = append(hold, owner)
		}
	}
	hold = uniqueStrings(hold)
	if len(hold) == 0 {
		return fmt.Errorf("xbps-install: unresolved shared libraries")
	}
	fmt.Fprintf(os.Stderr, "\n==> A repository has not caught up with a library update; holding back for now: %s\n", strings.Join(hold, " "))
	if err := elevate("xbps-pkgdb", append([]string{"-m", "hold"}, hold...)...).Run(); err != nil {
		return fmt.Errorf("xbps-pkgdb hold: %w", err)
	}
	_, retryErr := run()
	_ = elevate("xbps-pkgdb", append([]string{"-m", "unhold"}, hold...)...).Run()
	if retryErr != nil {
		fmt.Fprintln(os.Stderr, "==> The system packages could not be updated yet; the desktop update continues.")
		return nil
	}
	fmt.Printf("==> System packages updated; held back until their repository rebuilds: %s\n", strings.Join(hold, " "))
	return nil
}

// brokenShlibLine is xbps's "aquamarine-0.8.0_2: broken, unresolvable shlib `libdisplay-info.so.2'".
var brokenShlibLine = regexp.MustCompile("^\\s*(\\S+)-[^-\\s]+_[0-9]+: broken, unresolvable shlib [`'](\\S+?)'")

// parseBrokenShlibs returns the package names XBPS reports broken and the
// shared libraries they cannot resolve.
func parseBrokenShlibs(out string) (pkgs, libs []string) {
	for _, line := range strings.Split(out, "\n") {
		if m := brokenShlibLine.FindStringSubmatch(line); m != nil {
			pkgs = append(pkgs, m[1])
			libs = append(libs, m[2])
		}
	}
	return uniqueStrings(pkgs), uniqueStrings(libs)
}

// shlibOwner names the installed package that provides lib, the one whose
// update would remove it.
func shlibOwner(lib string) string {
	for _, dir := range []string{"/usr/lib", "/usr/lib64"} {
		out, err := exec.Command("xbps-query", "-o", filepath.Join(dir, lib)).Output()
		if err != nil {
			continue
		}
		// "libdisplay-info-0.2.0_1: /usr/lib/libdisplay-info.so.2 (...)"
		if pkgver, _, ok := strings.Cut(strings.TrimSpace(string(out)), ":"); ok {
			if name, err := exec.Command("xbps-uhelper", "getpkgname", pkgver).Output(); err == nil {
				return strings.TrimSpace(string(name))
			}
		}
	}
	return ""
}

func uniqueStrings(in []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, s := range in {
		if !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	return out
}

// updateFlatpaks executes flatpak update -y if Flatpak is installed.
func updateFlatpaks() {
	if _, err := exec.LookPath("flatpak"); err != nil {
		return
	}
	fmt.Println("==> Step 3/4: Updating installed Flatpak applications & runtimes...")
	cmd := exec.Command("flatpak", "update", "-y")
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	_ = cmd.Run()
}

// isBtrfsRoot checks if the root filesystem is Btrfs.
func isBtrfsRoot() bool {
	data, err := os.ReadFile("/proc/mounts")
	if err != nil {
		out, err := exec.Command("stat", "-f", "-c", "%T", "/").Output()
		return err == nil && strings.TrimSpace(string(out)) == "btrfs"
	}
	for _, line := range strings.Split(string(data), "\n") {
		fields := strings.Fields(line)
		if len(fields) >= 3 && fields[1] == "/" && fields[2] == "btrfs" {
			return true
		}
	}
	return false
}

// createBtrfsSnapshot creates an atomic read-only snapshot of root in /.snapshots/.
func createBtrfsSnapshot() (string, error) {
	if !isBtrfsRoot() {
		return "", nil
	}
	if _, err := exec.LookPath("btrfs"); err != nil {
		return "", nil
	}

	snapDir := "/.snapshots"
	timestamp := time.Now().Format("20060102-150405")
	snapName := "pre-update-" + timestamp
	snapPath := filepath.Join(snapDir, snapName)

	sudo := "sudo"
	if os.Geteuid() == 0 {
		sudo = ""
	}

	// Ensure /.snapshots directory exists
	var mkdirCmd *exec.Cmd
	if sudo != "" {
		mkdirCmd = exec.Command(sudo, "mkdir", "-p", snapDir)
	} else {
		mkdirCmd = exec.Command("mkdir", "-p", snapDir)
	}
	_ = mkdirCmd.Run()

	var snapCmd *exec.Cmd
	if sudo != "" {
		snapCmd = exec.Command(sudo, "btrfs", "subvolume", "snapshot", "-r", "/", snapPath)
	} else {
		snapCmd = exec.Command("btrfs", "subvolume", "snapshot", "-r", "/", snapPath)
	}

	out, err := snapCmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("%s (%s)", err, strings.TrimSpace(string(out)))
	}
	return snapPath, nil
}

const defaultGitRepoURL = "https://github.com/mohitjoer/ASURA-OS.git"

// pullGitUpdates fetches the latest changes from the specified branch and updates base files.
func pullGitUpdates(branch string, root string) error {
	repoDir, err := findOrCloneRepo(branch)
	if err != nil {
		return fmt.Errorf("locating Asura repository: %w", err)
	}

	fmt.Printf("==> Pulling latest changes from branch '%s' in %s...\n", branch, repoDir)

	fetchCmd := repoGit(repoDir, "fetch", "origin", branch)
	fetchCmd.Stdout, fetchCmd.Stderr = os.Stdout, os.Stderr
	if err := fetchCmd.Run(); err != nil {
		return fmt.Errorf("git fetch: %w", err)
	}

	checkoutCmd := repoGit(repoDir, "checkout", branch)
	checkoutCmd.Stdout, checkoutCmd.Stderr = os.Stdout, os.Stderr
	_ = checkoutCmd.Run()

	pullCmd := repoGit(repoDir, "pull", "--ff-only", "origin", branch)
	pullCmd.Stdout, pullCmd.Stderr = os.Stdout, os.Stderr
	if err := pullCmd.Run(); err != nil {
		return fmt.Errorf("git pull: %w", err)
	}

	// Apply the pulled checkout to this system: everything the ISO installs
	// from the repository (both desktop shells, Hyprland, the session, runit
	// services, helpers, schemas, system configuration), the Go tools rebuilt
	// from it, and any package new in the manifest. installation/apply-repo.sh
	// is that list, kept equal to the ISO build by its test.
	return applyRepo(repoDir, root)
}

// applyRepoArgs is the command that applies repoDir to root. A package var so
// the update tests can see what would run without running it.
var applyRepoArgs = func(repoDir, root string) []string {
	args := []string{"sh", filepath.Join(repoDir, "installation", "apply-repo.sh"), repoDir}
	if root != "" && root != "/" {
		args = append(args, root)
	}
	if os.Geteuid() != 0 {
		args = append([]string{"sudo"}, args...)
	}
	return args
}

func applyRepo(repoDir, root string) error {
	script := filepath.Join(repoDir, "installation", "apply-repo.sh")
	if _, err := os.Stat(script); err != nil {
		return fmt.Errorf("%s is missing; the checkout is older than this asura", script)
	}
	args := applyRepoArgs(repoDir, root)
	fmt.Println("==> Applying the updated repository to this system...")
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdout, cmd.Stderr, cmd.Stdin = os.Stdout, os.Stderr, os.Stdin
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("apply-repo: %w", err)
	}
	return nil
}

func findOrCloneRepo(branch string) (string, error) {
	// 1. Check ASURA_SRC_DIR environment variable override
	if env := os.Getenv("ASURA_SRC_DIR"); env != "" && isAsuraRepo(env) {
		return env, nil
	}

	// 2. Check current directory or git root
	if out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output(); err == nil {
		top := strings.TrimSpace(string(out))
		if isAsuraRepo(top) {
			return top, nil
		}
	}

	// 3. Check well-known local paths
	home := os.Getenv("HOME")
	candidates := []string{
		filepath.Join(home, "code", "ASURA-OS"),
		filepath.Join(home, "code", "asura", "ASURA-OS"),
		filepath.Join(home, "ASURA-OS"),
		filepath.Join(home, ".cache", "asura", "source"),
		"/usr/src/asura",
		"/usr/share/asura",
		"/var/cache/asura/source",
	}
	if sudoUser := os.Getenv("SUDO_USER"); sudoUser != "" && sudoUser != "root" {
		userHome := filepath.Join("/home", sudoUser)
		candidates = append([]string{
			filepath.Join(userHome, "code", "ASURA-OS"),
			filepath.Join(userHome, "code", "asura", "ASURA-OS"),
			filepath.Join(userHome, "ASURA-OS"),
		}, candidates...)
	}
	// A checkout this user cannot write (a root-owned clone left by an
	// earlier `sudo asura update`) cannot be pulled into: skip it, and clone
	// a copy of the user's own below.
	for _, c := range candidates {
		if isAsuraRepo(c) && canWriteRepo(c) {
			return c, nil
		}
	}

	// 4. Clone to cache directory if not found locally. Under sudo the clone
	// is the invoking user's, in their cache, made as them: a root-owned clone
	// is one the user's own `asura update` can never pull into.
	cacheDir := filepath.Join(home, ".cache", "asura", "source")
	cloneAs := ""
	if os.Geteuid() == 0 {
		cacheDir = "/var/cache/asura/source"
		if u := os.Getenv("SUDO_USER"); u != "" && u != "root" {
			cacheDir = filepath.Join("/home", u, ".cache", "asura", "source")
			cloneAs = u
		}
	}
	if _, err := os.Stat(filepath.Join(cacheDir, ".git")); os.IsNotExist(err) {
		fmt.Printf("==> Cloning Asura OS repository (%s) into %s...\n", branch, cacheDir)
		args := []string{"sh", "-c", `mkdir -p "$(dirname "$1")" && git clone --depth 1 --branch "$2" "$3" "$1"`, "sh", cacheDir, branch, defaultGitRepoURL}
		if cloneAs != "" {
			args = append([]string{"sudo", "-u", cloneAs}, args...)
		}
		cmd := exec.Command(args[0], args[1:]...)
		cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
		if err := cmd.Run(); err != nil {
			return "", fmt.Errorf("git clone failed: %w", err)
		}
		return cacheDir, nil
	}

	return cacheDir, nil
}

// repoGit runs git in repoDir as the checkout's owner. `sudo asura update`
// otherwise writes root-owned objects into the user's own checkout, after which
// the user's `asura update` fails with "Permission denied".
func repoGit(repoDir string, args ...string) *exec.Cmd {
	full := append([]string{"-c", "safe.directory=*", "-C", repoDir}, args...)
	if os.Geteuid() == 0 {
		if info, err := os.Stat(repoDir); err == nil {
			if st, ok := info.Sys().(*syscall.Stat_t); ok && st.Uid != 0 {
				return exec.Command("sudo", append([]string{"-u", fmt.Sprintf("#%d", st.Uid), "git"}, full...)...)
			}
		}
	}
	return exec.Command("git", full...)
}

// canWriteRepo reports whether git can update the checkout at path.
func canWriteRepo(path string) bool {
	return syscall.Access(filepath.Join(path, ".git"), 2 /* W_OK */) == nil
}

func isAsuraRepo(path string) bool {
	if path == "" {
		return false
	}
	if _, err := os.Stat(filepath.Join(path, ".git")); err != nil {
		return false
	}
	if _, err := os.Stat(filepath.Join(path, "shell", "hub")); err == nil {
		return true
	}
	return false
}
