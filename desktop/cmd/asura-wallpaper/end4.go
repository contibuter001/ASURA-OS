package main

import (
	"os"
	"os/exec"
	"strings"
)

// The end-4 desktop (org.asura.shell desktop-shell = end4) draws its own
// background, wallpaper and palette, over this daemon's layer. A wallpaper
// chosen here would land underneath it and nothing would seem to change, so
// Super+W and Super+Shift+W (`wallpaper ui`, `wallpaper random`) open end-4's
// own wallpaper selector instead. The keys stay the same.

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
