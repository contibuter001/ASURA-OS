package main

import "testing"

func TestWallpaperKeysOpenEnd4InTheEnd4Desktop(t *testing.T) {
	savedShell, savedCall := desktopShell, callEnd4
	defer func() { desktopShell, callEnd4 = savedShell, savedCall }()

	var calls []string
	callEnd4 = func(target, fn string) string {
		calls = append(calls, target+"."+fn)
		return "ok"
	}

	desktopShell = func() string { return "asura" }
	if end4Desktop() {
		t.Fatal("the asura desktop was taken for end-4")
	}

	desktopShell = func() string { return "end4" }
	// end4Desktop also needs the installed tree, which a test machine lacks.
	if end4Desktop() {
		t.Skip("/usr/share/asura/shell-end4 exists here; skipping the absent-tree case")
	}
	if len(calls) != 0 {
		t.Fatalf("end-4 was called while not installed: %v", calls)
	}
}

func TestApplyEnd4WallpaperCallsSwitchwall(t *testing.T) {
	savedShell, savedApply := desktopShell, applyEnd4Wallpaper
	defer func() { desktopShell, applyEnd4Wallpaper = savedShell, savedApply }()

	var appliedPath string
	applyEnd4Wallpaper = func(path string) {
		appliedPath = path
	}

	desktopShell = func() string { return "end4" }
	applyEnd4Wallpaper("/path/to/test.png")
	if appliedPath != "/path/to/test.png" {
		t.Fatalf("expected /path/to/test.png, got %q", appliedPath)
	}
}
