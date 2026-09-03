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
