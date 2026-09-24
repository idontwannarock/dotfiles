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

// getGitInfo reports how far HEAD is ahead of and behind its upstream.
func TestGetGitInfoAheadBehind(t *testing.T) {
	git := func(dir string, args ...string) {
		t.Helper()
		cmd := exec.Command("git", append([]string{"-c", "user.email=t@t", "-c", "user.name=t"}, args...)...)
		cmd.Dir = dir
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v: %s", args, err, out)
		}
	}

	remote := t.TempDir()
	git(remote, "init", "-q", "--bare", "-b", "main")
	other := t.TempDir()
	git(other, "clone", "-q", remote, ".")
	git(other, "commit", "-q", "--allow-empty", "-m", "base")
	git(other, "push", "-q", "origin", "main")

	local := t.TempDir()
	git(local, "clone", "-q", remote, ".")
	if got := getGitInfo(local); got.Ahead != 0 || got.Behind != 0 || got.Dirty {
		t.Errorf("fresh clone: got %+v, want in sync and clean", got)
	}

	git(other, "commit", "-q", "--allow-empty", "-m", "theirs")
	git(other, "push", "-q", "origin", "main")
	git(local, "fetch", "-q")
	git(local, "commit", "-q", "--allow-empty", "-m", "mine1")
	git(local, "commit", "-q", "--allow-empty", "-m", "mine2")
	if got := getGitInfo(local); got.Ahead != 2 || got.Behind != 1 {
		t.Errorf("diverged: Ahead=%d Behind=%d, want 2 and 1", got.Ahead, got.Behind)
	}

	if err := os.WriteFile(filepath.Join(local, "f"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if !getGitInfo(local).Dirty {
		t.Error("untracked file: Dirty = false, want true")
	}
}
