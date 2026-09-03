package main

import "testing"

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
