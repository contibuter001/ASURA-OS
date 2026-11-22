package main

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// The agent skills (shell/agent/skills) tell an assistant which commands to run
// on an ASURA machine. A command they name that does not exist sends the
// assistant down a dead end, so every `asura <sub>` and `asura-<tool>` written
// in a skill's code must be a real command.

var (
	codeSpan   = regexp.MustCompile("(?s)```.*?```|`[^`\n]+`")
	asuraSub   = regexp.MustCompile("(?:^|[\\s(|;&`])asura ([a-z][a-z-]*)")
	asuraTool  = regexp.MustCompile(`\b(asura-[a-z]+(?:-[a-z]+)*)`)
	notCommand = map[string]bool{
		"asura-plugins":    true, // the folder new plugins are created in
		"asura-shell.sock": true,
	}
)

func TestSkillsNameRealCommands(t *testing.T) {
	repo, err := filepath.Abs("../../..")
	if err != nil {
		t.Fatal(err)
	}
	skills := filepath.Join(repo, "shell", "agent", "skills")
	files, _ := filepath.Glob(filepath.Join(skills, "*", "*.md"))
	if len(files) == 0 {
		t.Fatalf("no skills under %s", skills)
	}
	toolExists := func(name string) bool {
		for _, dir := range []string{"desktop/cmd", "shell/scripts", "session"} {
			if _, err := os.Stat(filepath.Join(repo, dir, name)); err == nil {
				return true
			}
		}
		return false
	}
	for _, file := range files {
		b, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		rel, _ := filepath.Rel(repo, file)
		for _, code := range codeSpan.FindAllString(string(b), -1) {
			for _, m := range asuraSub.FindAllStringSubmatch(code, -1) {
				_, builtIn := commands[m[1]]
				_, registered := extraCommands[m[1]]
				if !builtIn && !registered {
					t.Errorf("%s: `asura %s` is not an asura command", rel, m[1])
				}
			}
			for _, m := range asuraTool.FindAllStringSubmatch(code, -1) {
				name := strings.TrimSuffix(m[1], "-")
				if notCommand[name] || strings.Contains(code, name+".") || strings.Contains(code, name+"/") {
					continue // a file or folder name, not a command
				}
				if !toolExists(name) {
					t.Errorf("%s: `%s` is not a command ASURA ships", rel, name)
				}
			}
		}
	}
}
