package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

// ANSI truecolor
const (
	cBlue    = "\033[38;2;0;153;255m"
	cOrange  = "\033[38;2;255;176;85m"
	cGreen   = "\033[38;2;0;175;80m"
	cCyan    = "\033[38;2;86;182;194m"
	cRed     = "\033[38;2;255;85;85m"
	cYellow  = "\033[38;2;230;200;0m"
	cMagenta = "\033[38;2;180;140;255m"
	cDim     = "\033[2m"
	cBold    = "\033[1m"
	cReset   = "\033[0m"
)

var sep = " " + cDim + "│" + cReset + " "

// Claude Code JSON stdin 結構
type ClaudeData struct {
	SessionID string `json:"session_id"`
	Model     struct {
		DisplayName string `json:"display_name"`
	} `json:"model"`
	Workspace struct {
		CurrentDir string `json:"current_dir"`
		ProjectDir string `json:"project_dir"`
	} `json:"workspace"`
	ContextWindow struct {
		ContextWindowSize int      `json:"context_window_size"`
		UsedPercentage    *float64 `json:"used_percentage"`
		CurrentUsage      *struct {
			InputTokens              int `json:"input_tokens"`
			CacheCreationInputTokens int `json:"cache_creation_input_tokens"`
			CacheReadInputTokens     int `json:"cache_read_input_tokens"`
		} `json:"current_usage"`
	} `json:"context_window"`
	RateLimits *struct {
		FiveHour *struct {
			UsedPercentage float64 `json:"used_percentage"`
			ResetsAt       int64   `json:"resets_at"`
		} `json:"five_hour"`
		SevenDay *struct {
			UsedPercentage float64 `json:"used_percentage"`
			ResetsAt       int64   `json:"resets_at"`
		} `json:"seven_day"`
	} `json:"rate_limits"`
	Worktree *struct {
		Name   string `json:"name"`
		Branch string `json:"branch"`
	} `json:"worktree"`
	Effort *struct {
		Level string `json:"level"`
	} `json:"effort"`
}

// Version 由 CI 透過 ldflags 注入，格式為 YYYYMMDD
var Version = "dev"

const (
	asyncTimeout = 1 * time.Second // 等待 goroutines 的時間上限
)

// === Git 資訊 ===

type GitInfo struct {
	Branch     string
	Dirty      bool
	Insertions int
	Deletions  int
}

func getGitInfo(dir string) GitInfo {
	gitDir := filepath.Join(dir, ".git")
	if _, err := os.Stat(gitDir); os.IsNotExist(err) {
		return GitInfo{}
	}

	var info GitInfo
	var branchErr error
	var wg sync.WaitGroup
	wg.Add(3)

	go func() {
		defer wg.Done()
		cmd := exec.Command("git", "branch", "--show-current")
		cmd.Dir = dir
		out, err := cmd.Output()
		if err != nil {
			branchErr = err
			return
		}
		info.Branch = strings.TrimSpace(string(out))
	}()

	go func() {
		defer wg.Done()
		cmd := exec.Command("git", "status", "--porcelain")
		cmd.Dir = dir
		out, _ := cmd.Output()
		info.Dirty = len(strings.TrimSpace(string(out))) > 0
	}()

	go func() {
		defer wg.Done()
		cmd := exec.Command("git", "diff", "--shortstat")
		cmd.Dir = dir
		out, _ := cmd.Output()
		diffStat := strings.TrimSpace(string(out))
		if diffStat != "" {
			info.Insertions, info.Deletions = parseDiffStat(diffStat)
		}
	}()

	wg.Wait()
	if branchErr != nil {
		return GitInfo{}
	}
	return info
}

var diffStatInsertRe = regexp.MustCompile(`(\d+) insertion`)
var diffStatDeleteRe = regexp.MustCompile(`(\d+) deletion`)

func parseDiffStat(stat string) (insertions, deletions int) {
	if m := diffStatInsertRe.FindStringSubmatch(stat); len(m) > 1 {
		insertions, _ = strconv.Atoi(m[1])
	}
	if m := diffStatDeleteRe.FindStringSubmatch(stat); len(m) > 1 {
		deletions, _ = strconv.Atoi(m[1])
	}
	return
}

// === 顯示用工具函式 ===

func colorForPct(pct float64) string {
	switch {
	case pct >= 90:
		return cRed
	case pct >= 70:
		return cYellow
	case pct >= 40:
		return cOrange
	default:
		return cGreen
	}
}

func progressBar(pct float64, width int) string {
	filled := int(pct / 100 * float64(width))
	if filled > width {
		filled = width
	}
	if filled < 0 {
		filled = 0
	}
	color := colorForPct(pct)
	return color + strings.Repeat("●", filled) + cDim + strings.Repeat("○", width-filled) + cReset
}

func formatTokens(tokens int) string {
	// Trim a trailing ".0" so round figures read as 200k, not 200.0k. The
	// context window limit is almost always round; the used count rarely is.
	trim := func(s, unit string) string {
		return strings.TrimSuffix(s, ".0") + unit
	}
	if tokens >= 1000000 {
		return trim(fmt.Sprintf("%.1f", float64(tokens)/1000000), "M")
	}
	if tokens >= 1000 {
		return trim(fmt.Sprintf("%.1f", float64(tokens)/1000), "k")
	}
	return fmt.Sprintf("%d", tokens)
}

func modelEmoji(model string) string {
	lower := strings.ToLower(model)
	if strings.Contains(lower, "opus") {
		return "💛"
	}
	if strings.Contains(lower, "sonnet") {
		return "💠"
	}
	if strings.Contains(lower, "haiku") {
		return "🌸"
	}
	return "🤖"
}

// claudeSettings holds the subset of ~/.claude/settings.json we care about.
// ultracode is a Claude Code orchestration flag (xhigh effort + auto dynamic
// workflows), not an effort level — it sits alongside effortLevel.
type claudeSettings struct {
	EffortLevel string `json:"effortLevel"`
	Ultracode   bool   `json:"ultracode"`
}

func readClaudeSettings() claudeSettings {
	home, _ := os.UserHomeDir()
	data, err := os.ReadFile(filepath.Join(home, ".claude", "settings.json"))
	if err != nil {
		return claudeSettings{}
	}
	var s claudeSettings
	_ = json.Unmarshal(data, &s)
	return s
}

// getEffortLevel resolves effort from the most authoritative source available.
// Claude Code sends effort.level on stdin for models that support the reasoning
// effort parameter; that value is per-session and tracks runtime /effort
// toggles. CLAUDE_EFFORT is the fallback for older Claude Code builds that omit
// the field, and settings.json is the last resort static default.
func getEffortLevel(stdinEffort string, s claudeSettings) string {
	if v := strings.TrimSpace(stdinEffort); v != "" {
		return v
	}
	if v := strings.TrimSpace(os.Getenv("CLAUDE_EFFORT")); v != "" {
		return v
	}
	return s.EffortLevel
}

func formatEffort(effort string) string {
	// Claude Code effort ladder (low → max). ultracode is NOT a level —
	// it's rendered separately as a badge via formatUltracodeBadge.
	switch effort {
	case "low":
		return cDim + "◔ " + effort + cReset
	case "medium":
		return cDim + "◑ " + effort + cReset
	case "high":
		return cMagenta + "● " + effort + cReset
	case "xhigh":
		return cMagenta + "◉ " + effort + cReset
	case "max":
		return cBold + cMagenta + "✦ " + effort + cReset
	default:
		return cDim + "· " + effort + cReset
	}
}

func formatUltracodeBadge() string {
	return cBold + cYellow + "⚡ultra" + cReset
}

// writeContextWindowCache 將 Claude Code 傳來的 context_window_size 寫成兩份
// cache 檔供 UserPromptSubmit hook 取用：
//   - session-<session_id>.cache — 精確匹配當前 session
//   - latest.cache — 跨 session 的 fallback，永不清理；處理新 session 首個
//     prompt 在 statusline 首次重繪前就進來、session-<id>.cache 尚未存在的情境
//
// 只在 size > 0 時寫；採 tmp+rename 避免部分寫。任何錯誤都靜默 —
// 這是錦上添花的資料，失敗不該影響 statusline 顯示。
func writeContextWindowCache(sessionID string, size int) {
	if sessionID == "" || size <= 0 {
		return
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return
	}
	dir := filepath.Join(home, ".cache", "claude-handoff")
	if err := os.MkdirAll(dir, 0755); err != nil {
		return
	}
	payload := []byte(strconv.Itoa(size))
	for _, name := range []string{"session-" + sessionID + ".cache", "latest.cache"} {
		target := filepath.Join(dir, name)
		tmp := target + ".tmp"
		if err := os.WriteFile(tmp, payload, 0644); err != nil {
			continue
		}
		_ = os.Rename(tmp, target)
	}
}

func formatResetTime(epochSec int64) string {
	remaining := time.Until(time.Unix(epochSec, 0))
	if remaining <= 0 {
		return "now"
	}
	totalMin := int(remaining.Minutes())
	if totalMin < 60 {
		return fmt.Sprintf("%dm", totalMin)
	}
	totalHour := totalMin / 60
	if totalHour >= 24 {
		return fmt.Sprintf("%dd%dh", totalHour/24, totalHour%24)
	}
	return fmt.Sprintf("%dh%dm", totalHour, totalMin%60)
}

func formatRateLimit(label string, pct float64, resetsAt int64) string {
	pctInt := int(pct + 0.5)
	result := fmt.Sprintf("%s: %d%%", label, pctInt)
	if resetsAt > 0 {
		result += " ⟳ " + formatResetTime(resetsAt)
	}
	return result
}

// === Main ===

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--version" {
		fmt.Println(Version)
		return
	}

	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Println("Error reading input")
		return
	}

	var data ClaudeData
	if err := json.Unmarshal(input, &data); err != nil {
		fmt.Println("Error parsing JSON")
		return
	}

	// === 快速本地操作 ===
	model := data.Model.DisplayName
	emoji := modelEmoji(model)
	dir := filepath.Base(data.Workspace.CurrentDir)
	settings := readClaudeSettings()
	stdinEffort := ""
	if data.Effort != nil {
		stdinEffort = data.Effort.Level
	}
	effort := getEffortLevel(stdinEffort, settings)

	ctxPercent := 0.0
	if data.ContextWindow.UsedPercentage != nil {
		ctxPercent = *data.ContextWindow.UsedPercentage
	}

	totalTokens := 0
	if data.ContextWindow.CurrentUsage != nil {
		usage := data.ContextWindow.CurrentUsage
		totalTokens = usage.InputTokens + usage.CacheCreationInputTokens + usage.CacheReadInputTokens
	}

	writeContextWindowCache(data.SessionID, data.ContextWindow.ContextWindowSize)

	// === 平行取得外部資訊 ===
	var wg sync.WaitGroup
	done := make(chan struct{})

	var gitInfo GitInfo

	wg.Add(1)
	go func() {
		defer wg.Done()
		gitInfo = getGitInfo(data.Workspace.CurrentDir)
	}()

	go func() {
		wg.Wait()
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(asyncTimeout):
	}

	// === Model │ Effort │ Context bar % tokens/limit │ Rate limits │ Dir [worktree] ⚡branch* +N -N ===
	line1 := fmt.Sprintf("%s %s%s%s", emoji, cBlue, model, cReset)

	if effort != "" {
		line1 += sep + formatEffort(effort)
		if settings.Ultracode {
			line1 += " " + formatUltracodeBadge()
		}
	}

	pctColor := colorForPct(ctxPercent)
	bar := progressBar(ctxPercent, 10)
	tokenPart := formatTokens(totalTokens)
	// Show the limit the session is measured against; Claude Code caps this at
	// 200K unless a repo overrides CLAUDE_CODE_DISABLE_1M_CONTEXT.
	if size := data.ContextWindow.ContextWindowSize; size > 0 {
		tokenPart += cDim + "/" + formatTokens(size) + cReset
	}
	line1 += fmt.Sprintf("%s%s %s%.0f%%%s %s", sep, bar, pctColor, ctxPercent, cReset, tokenPart)

	if data.RateLimits != nil {
		var rlParts []string
		if data.RateLimits.FiveHour != nil {
			rlParts = append(rlParts, formatRateLimit("5h", data.RateLimits.FiveHour.UsedPercentage, data.RateLimits.FiveHour.ResetsAt))
		}
		if data.RateLimits.SevenDay != nil {
			rlParts = append(rlParts, formatRateLimit("7d", data.RateLimits.SevenDay.UsedPercentage, data.RateLimits.SevenDay.ResetsAt))
		}
		if len(rlParts) > 0 {
			line1 += sep + "⏳ " + strings.Join(rlParts, sep)
		}
	}

	line1 += fmt.Sprintf("%s%s%s%s", sep, cCyan, dir, cReset)
	if data.Worktree != nil && data.Worktree.Name != "" {
		line1 += fmt.Sprintf(" %s🌿%s%s", cGreen, data.Worktree.Name, cReset)
	}
	if gitInfo.Branch != "" {
		line1 += fmt.Sprintf(" %s%s%s", cGreen, gitInfo.Branch, cReset)
		if gitInfo.Dirty {
			line1 += cRed + "*" + cReset
		}
		if gitInfo.Insertions > 0 || gitInfo.Deletions > 0 {
			if gitInfo.Insertions > 0 {
				line1 += fmt.Sprintf(" %s+%d%s", cGreen, gitInfo.Insertions, cReset)
			}
			if gitInfo.Deletions > 0 {
				line1 += fmt.Sprintf(" %s-%d%s", cRed, gitInfo.Deletions, cReset)
			}
		}
	}

	fmt.Println(line1)
}
