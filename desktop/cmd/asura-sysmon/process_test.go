package main

import (
	"os"
	"testing"
)

func TestListProcesses(t *testing.T) {
	procs, err := ListProcesses("mem", 10)
	if err != nil {
		t.Fatalf("ListProcesses failed: %v", err)
	}
	if len(procs) == 0 {
		t.Fatalf("expected active processes, got 0")
	}

	myPID := os.Getpid()
	var foundMine bool
	for _, p := range procs {
		if p.PID == myPID {
			foundMine = true
			break
		}
	}

	// Also test without limit to find myPID
	allProcs, err := ListProcesses("pid", 0)
	if err != nil {
		t.Fatalf("ListProcesses all failed: %v", err)
	}
	for _, p := range allProcs {
		if p.PID == myPID {
			foundMine = true
			if p.User == "" {
				t.Errorf("expected non-empty user for PID %d", myPID)
			}
			break
		}
	}
	if !foundMine {
		t.Fatalf("current test process %d not found in /proc", myPID)
	}
}

func TestKillProcessSafety(t *testing.T) {
	if err := KillProcess(1, false); err == nil {
		t.Fatalf("expected error refusing to kill PID 1")
	}
	if err := KillProcess(0, false); err == nil {
		t.Fatalf("expected error refusing to kill PID 0")
	}
}

func TestResolveProcessName(t *testing.T) {
	cases := []struct {
		comm     string
		cmdline  string
		expected string
	}{
		{"quickshell", "quickshell -p /usr/share/asura/shell --no-color", "quickshell (shell)"},
		{"quickshell", "quickshell -p /usr/share/asura/sysmon/sysmon.qml", "quickshell (sysmon)"},
		{"quickshell", "quickshell --path=/usr/share/asura/shell/hub.qml", "quickshell (hub)"},
		{"xdg-desktop-por", "/usr/libexec/xdg-desktop-portal-hyprland", "xdg-desktop-portal-hyprland"},
		{"xdg-desktop-por", "/usr/libexec/xdg-desktop-portal", "xdg-desktop-portal"},
		{"python3", "python3 /usr/bin/asura-doctor", "python3 (asura-doctor)"},
		{"bash", "bash", "bash"},
		{"kthreadd", "", "kthreadd"},
	}

	for _, tc := range cases {
		got := resolveProcessName(tc.comm, tc.cmdline)
		if got != tc.expected {
			t.Errorf("resolveProcessName(%q, %q) = %q; want %q", tc.comm, tc.cmdline, got, tc.expected)
		}
	}
}
