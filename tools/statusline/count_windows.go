//go:build windows

package main

import (
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
)

const processImageBufLen = 1024

// Browser executables that host Claude Code as a Chrome Native Messaging
// helper. When claude.exe is spawned by one of these, it's not a user session.
var browserParents = map[string]bool{
	"chrome.exe":  true,
	"msedge.exe":  true,
	"firefox.exe": true,
	"brave.exe":   true,
}

// countClaudeProcesses enumerates processes via the Windows Toolhelp API and
// counts Claude Code CLI sessions under ~/.local/bin/claude.exe. Claude Desktop
// (installed under %LOCALAPPDATA%\AnthropicClaude\) is excluded by full-path
// check; chrome-native-host helpers are excluded by parent-process name.
func countClaudeProcesses() int {
	snap, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return 1
	}
	defer windows.CloseHandle(snap)

	type candidate struct{ pid, ppid uint32 }
	var candidates []candidate
	pidName := make(map[uint32]string, 256)

	var entry windows.ProcessEntry32
	entry.Size = uint32(unsafe.Sizeof(entry))
	for err := windows.Process32First(snap, &entry); err == nil; err = windows.Process32Next(snap, &entry) {
		name := windows.UTF16ToString(entry.ExeFile[:])
		pidName[entry.ProcessID] = name
		if strings.EqualFold(name, "claude.exe") {
			candidates = append(candidates, candidate{pid: entry.ProcessID, ppid: entry.ParentProcessID})
		}
	}

	count := 0
	for _, c := range candidates {
		if browserParents[strings.ToLower(pidName[c.ppid])] {
			continue
		}
		path, ok := processImagePath(c.pid)
		if !ok {
			continue
		}
		norm := strings.ToLower(strings.ReplaceAll(path, "/", `\`))
		if !strings.Contains(norm, `\.local\bin\claude.exe`) {
			continue
		}
		count++
	}
	if count == 0 {
		return 1
	}
	return count
}

func processImagePath(pid uint32) (string, bool) {
	h, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, pid)
	if err != nil {
		return "", false
	}
	defer windows.CloseHandle(h)
	var buf [processImageBufLen]uint16
	size := uint32(len(buf))
	if err := windows.QueryFullProcessImageName(h, 0, &buf[0], &size); err != nil {
		return "", false
	}
	return windows.UTF16ToString(buf[:size]), true
}
