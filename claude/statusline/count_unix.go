//go:build !windows

package main

import (
	"os/exec"
	"strconv"
	"strings"
)

func countClaudeProcesses() int {
	cmd := exec.Command("sh", "-c", "ps aux | grep '[.]local/bin/claude' | grep -v -- '--chrome-native-host' | wc -l")
	out, err := cmd.Output()
	if err != nil {
		return 1
	}
	count, err := strconv.Atoi(strings.TrimSpace(string(out)))
	if err != nil {
		return 1
	}
	return count
}
