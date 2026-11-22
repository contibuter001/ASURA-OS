package main

import (
	"bytes"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// TestNoLegacyNames ensures that retired internal names
// do not reappear anywhere in the repository outside of shell-end4 and the migration script.
func TestNoLegacyNames(t *testing.T) {
	root, err := filepath.Abs(filepath.Join("..", "..", ".."))
	if err != nil {
		t.Fatalf("resolving repository root: %v", err)
	}

	pat := "(^|[^a-zA-Z])[" + "R" + "r]" + "y" + "o[a-zA-Z]*|" + "R" + "Y" + "O"
	cmd := exec.Command("git", "grep", "-n", "-I", "-E", pat, "--", ":!shell-end4", ":!migrations/user/1795364225.sh")
	cmd.Dir = root
	out, err := cmd.CombinedOutput()
	if err != nil {
		// git grep exits 1 when no matches are found
		if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() == 1 {
			return
		}
		t.Fatalf("running git grep: %v\noutput: %s", err, string(out))
	}

	var unexpected []string
	for _, line := range strings.Split(string(bytes.TrimSpace(out)), "\n") {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}
		if strings.Contains(strings.ToLower(trimmed), "everyone") {
			continue
		}
		unexpected = append(unexpected, trimmed)
	}

	if len(unexpected) > 0 {
		t.Fatalf("legacy names found in repository:\n%s", strings.Join(unexpected, "\n"))
	}
}
