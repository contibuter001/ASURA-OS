package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// The end-4 desktop (org.asura.shell desktop-shell = end4) draws its own
// background, wallpaper and palette, over this daemon's layer. When a wallpaper
// is applied, applyEnd4Wallpaper forwards the image to end-4's switchwall.sh
// so the background and Material 3 color palette stay synchronized.

// end4ShellDir is where the end-4 desktop is installed.
const end4ShellDir = "/usr/share/asura/shell-end4"

// desktopShell reads the configured desktop: ASURA_DESKTOP_SHELL, then the
// GSettings key, then end-4, the schema's default.
var desktopShell = func() string {
	if v := strings.TrimSpace(os.Getenv("ASURA_DESKTOP_SHELL")); v != "" {
		return v
	}
	out, err := exec.Command("gsettings", "get", "org.asura.shell", "desktop-shell").Output()
	if err != nil {
		return "end4"
	}
	return strings.Trim(strings.TrimSpace(string(out)), "'")
}

func end4Desktop() bool {
	if desktopShell() != "end4" {
		return false
	}
	_, err := os.Stat(end4ShellDir)
	return err == nil
}

// callEnd4 calls one of the end-4 desktop's IPC functions.
var callEnd4 = func(target, fn string) string {
	cmd := exec.Command("quickshell", "ipc", "--path", end4ShellDir, "--any-display", "call", target, fn)
	if out, err := cmd.CombinedOutput(); err != nil {
		return "err wallpaper: the end-4 desktop did not answer: " + strings.TrimSpace(string(out))
	}
	return "ok"
}

// applyEnd4Wallpaper runs end-4's switchwall.sh script asynchronously so the
// end-4 background and matugen color palette update to match the applied wallpaper.
var applyEnd4Wallpaper = func(path string) {
	if !end4Desktop() || path == "" {
		return
	}
	script := filepath.Join(end4ShellDir, "scripts", "colors", "switchwall.sh")
	if _, err := os.Stat(script); err != nil {
		return
	}
	cmd := exec.Command(script, "--image", path)
	_ = cmd.Start()
}
