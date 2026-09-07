package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

// getEffortLevel prefers stdin over CLAUDE_EFFORT over settings.json.
func TestGetEffortLevelPrecedence(t *testing.T) {
	settings := claudeSettings{EffortLevel: "high"}

	tests := []struct {
		name        string
		stdinEffort string
		env         string
		want        string
	}{
		{"stdin wins", "max", "medium", "max"},
		{"env when stdin absent", "", "medium", "medium"},
		{"settings when both absent", "", "", "high"},
		{"blank stdin is absent", "  ", "medium", "medium"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Setenv("CLAUDE_EFFORT", tt.env)
			if got := getEffortLevel(tt.stdinEffort, settings); got != tt.want {
				t.Errorf("getEffortLevel(%q) = %q, want %q", tt.stdinEffort, got, tt.want)
			}
		})
	}
}

func TestFormatTokens(t *testing.T) {
	tests := []struct {
		tokens int
		want   string
	}{
		{0, "0"},
		{999, "999"},
		{15500, "15.5k"},
		{200000, "200k"},
		{1000000, "1M"},
		{1500000, "1.5M"},
	}
	for _, tt := range tests {
		if got := formatTokens(tt.tokens); got != tt.want {
			t.Errorf("formatTokens(%d) = %q, want %q", tt.tokens, got, tt.want)
		}
	}
}

// The 🌿 marker prefixes the branch; the worktree name is never printed beside it.
func TestFormatBranch(t *testing.T) {
	tests := []struct {
		name       string
		inWorktree bool
		branch     string
		want       string
	}{
		{"plain repo", false, "main", " " + cGreen + "main" + cReset},
		{"worktree", true, "feat/x", " " + cGreen + "🌿feat/x" + cReset},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := formatBranch(tt.inWorktree, tt.branch); got != tt.want {
				t.Errorf("formatBranch(%v, %q) = %q, want %q", tt.inWorktree, tt.branch, got, tt.want)
			}
		})
	}
}

// getGitInfo must report the branch from a subdirectory, not just the repo root.
func TestGetGitInfoFromSubdirectory(t *testing.T) {
	root := t.TempDir()
	for _, args := range [][]string{
		{"init", "-q", "-b", "main"},
		{"-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "init"},
	} {
		cmd := exec.Command("git", args...)
		cmd.Dir = root
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v: %s", args, err, out)
		}
	}

	sub := filepath.Join(root, "a", "b")
	if err := os.MkdirAll(sub, 0o755); err != nil {
		t.Fatal(err)
	}

	if got := getGitInfo(sub).Branch; got != "main" {
		t.Errorf("getGitInfo(subdir).Branch = %q, want %q", got, "main")
	}
	if got := getGitInfo(t.TempDir()).Branch; got != "" {
		t.Errorf("getGitInfo(non-repo).Branch = %q, want empty", got)
	}
}
