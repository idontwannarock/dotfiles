package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
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
	cWhite   = "\033[38;2;220;220;220m"
	cMagenta = "\033[38;2;180;140;255m"
	cDim     = "\033[2m"
	cReset   = "\033[0m"
)

var sep = " " + cDim + "│" + cReset + " "

// Claude Code JSON 結構
type ClaudeData struct {
	SessionID string `json:"session_id"`
	Model     struct {
		DisplayName string `json:"display_name"`
	} `json:"model"`
	Workspace struct {
		CurrentDir string `json:"current_dir"`
	} `json:"workspace"`
	ContextWindow struct {
		ContextWindowSize int `json:"context_window_size"`
		CurrentUsage      struct {
			InputTokens              int `json:"input_tokens"`
			CacheCreationInputTokens int `json:"cache_creation_input_tokens"`
			CacheReadInputTokens     int `json:"cache_read_input_tokens"`
		} `json:"current_usage"`
	} `json:"context_window"`
	Session struct {
		StartTime string `json:"start_time"`
	} `json:"session"`
	Cost struct {
		TotalCostUSD float64 `json:"total_cost_usd"`
	} `json:"cost"`
}

// 緩存結構
type CostCache struct {
	Today float64   `json:"today"`
	Time  time.Time `json:"time"`
}

type BlockTimerCache struct {
	ElapsedMinutes   float64   `json:"elapsedMinutes"`
	RemainingMinutes float64   `json:"remainingMinutes"`
	Time             time.Time `json:"time"`
}

// Version 由 CI 透過 ldflags 注入，格式為 YYYYMMDD
var Version = "dev"

var cacheDir string
var ccusagePath string // resolved at init, empty = not found
var projectsDir string

// Cache TTL 常數
const (
	costCacheTTL       = 60 * time.Second
	blockTimerCacheTTL = 30 * time.Second
	asyncTimeout       = 2 * time.Second  // 等待 goroutines 的時間上限（決定輸出內容）
	totalTimeBudget    = 5 * time.Second   // 整個 process 的時間上限（含 cache 儲存）
	blockDuration      = 5 * time.Hour     // Anthropic 5-hour block
)

func init() {
	home, _ := os.UserHomeDir()
	cacheDir = filepath.Join(home, ".claude", "statusline-cache")
	projectsDir = filepath.Join(home, ".claude", "projects")
	os.MkdirAll(cacheDir, 0755)
	ccusagePath = resolveCcusagePath(home)
}

func resolveCcusagePath(home string) string {
	if p, err := exec.LookPath("ccusage"); err == nil {
		return p
	}
	ext := ""
	if runtime.GOOS == "windows" {
		ext = ".exe"
	}
	fallback := filepath.Join(home, ".bun", "bin", "ccusage"+ext)
	if _, err := os.Stat(fallback); err == nil {
		return fallback
	}
	return ""
}

// === Cache 系統 ===

func loadCache[T any](name string) (*T, bool) {
	path := filepath.Join(cacheDir, name+".json")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, false
	}
	var cache T
	if err := json.Unmarshal(data, &cache); err != nil {
		return nil, false
	}
	return &cache, true
}

func saveCache[T any](name string, cache *T) {
	path := filepath.Join(cacheDir, name+".json")
	data, _ := json.Marshal(cache)
	os.WriteFile(path, data, 0644)
}

func runCommand(name string, args ...string) string {
	cmd := exec.Command(name, args...)
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// === JSONL 讀取基礎設施 ===

func findSessionJSONL(sessionID string) string {
	if sessionID == "" {
		return ""
	}
	jsonlName := sessionID + ".jsonl"
	entries, err := os.ReadDir(projectsDir)
	if err != nil {
		return ""
	}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		candidate := filepath.Join(projectsDir, e.Name(), jsonlName)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}
	return ""
}

func readJSONLTail(path string, maxLines int) []string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()

	stat, err := f.Stat()
	if err != nil || stat.Size() == 0 {
		return nil
	}

	readSize := int64(256 * 1024)
	if stat.Size() < readSize {
		readSize = stat.Size()
	}
	offset := stat.Size() - readSize
	if offset < 0 {
		offset = 0
	}

	f.Seek(offset, 0)
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)

	var lines []string
	for scanner.Scan() {
		line := scanner.Text()
		if line != "" {
			lines = append(lines, line)
		}
	}

	if offset > 0 && len(lines) > 0 {
		lines = lines[1:]
	}

	if len(lines) > maxLines {
		lines = lines[len(lines)-maxLines:]
	}
	return lines
}

type jsonlEntry struct {
	Type        string `json:"type"`
	Timestamp   string `json:"timestamp"`
	IsSidechain bool   `json:"isSidechain"`
	Message     *struct {
		Role  string `json:"role"`
		Usage *struct {
			OutputTokens int `json:"output_tokens"`
			InputTokens  int `json:"input_tokens"`
		} `json:"usage"`
	} `json:"message"`
}

func parseJSONLEntry(line string) *jsonlEntry {
	var entry jsonlEntry
	if json.Unmarshal([]byte(line), &entry) != nil {
		return nil
	}
	return &entry
}

// === Block Timer（從 JSONL 計算）===

func calculateBlockTimer() *BlockTimerCache {
	now := time.Now()
	entries, err := os.ReadDir(projectsDir)
	if err != nil {
		return nil
	}

	cutoff := now.Add(-10 * time.Hour)
	var timestamps []time.Time

	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		projPath := filepath.Join(projectsDir, e.Name())
		files, err := os.ReadDir(projPath)
		if err != nil {
			continue
		}
		for _, f := range files {
			if !strings.HasSuffix(f.Name(), ".jsonl") {
				continue
			}
			info, err := f.Info()
			if err != nil || info.ModTime().Before(cutoff) {
				continue
			}
			filePath := filepath.Join(projPath, f.Name())
			ts := extractTimestamps(filePath, cutoff)
			timestamps = append(timestamps, ts...)
		}
	}

	if len(timestamps) == 0 {
		return nil
	}

	sortTimestamps(timestamps)

	if now.Sub(timestamps[0]) > blockDuration {
		return nil
	}

	blockStart := timestamps[0]
	for i := 1; i < len(timestamps); i++ {
		gap := timestamps[i-1].Sub(timestamps[i])
		if gap >= blockDuration {
			break
		}
		blockStart = timestamps[i]
	}

	blockStart = blockStart.Truncate(time.Hour)

	elapsed := now.Sub(blockStart)
	remaining := blockDuration - elapsed
	if remaining < 0 {
		remaining = 0
	}

	result := &BlockTimerCache{
		ElapsedMinutes:   elapsed.Minutes(),
		RemainingMinutes: remaining.Minutes(),
		Time:             now,
	}
	saveCache("block-timer", result)
	return result
}

func extractTimestamps(path string, cutoff time.Time) []time.Time {
	lines := readJSONLTail(path, 500)
	var timestamps []time.Time

	for _, line := range lines {
		if !strings.Contains(line, `"output_tokens"`) {
			continue
		}

		entry := parseJSONLEntry(line)
		if entry == nil || entry.IsSidechain {
			continue
		}
		if entry.Message == nil || entry.Message.Usage == nil {
			continue
		}
		if entry.Message.Usage.OutputTokens == 0 && entry.Message.Usage.InputTokens == 0 {
			continue
		}

		ts, err := time.Parse(time.RFC3339Nano, entry.Timestamp)
		if err != nil {
			ts, err = time.Parse("2006-01-02T15:04:05.000Z", entry.Timestamp)
			if err != nil {
				continue
			}
		}

		if ts.Before(cutoff) {
			continue
		}
		timestamps = append(timestamps, ts)
	}
	return timestamps
}

func sortTimestamps(ts []time.Time) {
	for i := 1; i < len(ts); i++ {
		for j := i; j > 0 && ts[j].After(ts[j-1]); j-- {
			ts[j], ts[j-1] = ts[j-1], ts[j]
		}
	}
}

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

	cmd := exec.Command("git", "branch", "--show-current")
	cmd.Dir = dir
	out, err := cmd.Output()
	if err != nil {
		return GitInfo{}
	}
	info.Branch = strings.TrimSpace(string(out))

	cmd = exec.Command("git", "status", "--porcelain")
	cmd.Dir = dir
	out, _ = cmd.Output()
	info.Dirty = len(strings.TrimSpace(string(out))) > 0

	cmd = exec.Command("git", "diff", "--shortstat")
	cmd.Dir = dir
	out, _ = cmd.Output()
	diffStat := strings.TrimSpace(string(out))
	if diffStat != "" {
		info.Insertions, info.Deletions = parseDiffStat(diffStat)
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

// === 計算運行中的 Claude Code 進程數量 ===

func countClaudeProcesses() int {
	if runtime.GOOS == "windows" {
		cmd := exec.Command("powershell", "-NoProfile", "-Command",
			"(Get-Process -Name 'claude' -ErrorAction SilentlyContinue | Measure-Object).Count")
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

	cmd := exec.Command("pgrep", "-c", "claude")
	out, err := cmd.Output()
	if err != nil {
		cmd = exec.Command("sh", "-c", "ps aux | grep -c '[c]laude'")
		out, err = cmd.Output()
		if err != nil {
			return 1
		}
	}
	count, err := strconv.Atoi(strings.TrimSpace(string(out)))
	if err != nil {
		return 1
	}
	return count
}

// === ccusage（today cost only）===

func fetchCcusageCosts() *CostCache {
	if ccusagePath == "" {
		return nil
	}
	today := time.Now().Format("20060102")
	out := runCommand(ccusagePath, "daily", "--since", today, "--json")
	if out == "" {
		return nil
	}
	var data struct {
		Daily []struct {
			TotalCost float64 `json:"totalCost"`
		} `json:"daily"`
	}
	if json.Unmarshal([]byte(out), &data) != nil {
		return nil
	}
	result := &CostCache{Time: time.Now()}
	for _, d := range data.Daily {
		result.Today += d.TotalCost
	}
	saveCache("ccusage-costs", result)
	return result
}

// === 顯示用工具函式 ===

func colorForPct(pct float64) string {
	switch {
	case pct >= 90:
		return cRed
	case pct >= 70:
		return cYellow
	case pct >= 50:
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
	if tokens >= 1000000 {
		return fmt.Sprintf("%.1fM", float64(tokens)/1000000)
	}
	if tokens >= 1000 {
		return fmt.Sprintf("%.1fk", float64(tokens)/1000)
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

func getEffortLevel() string {
	home, _ := os.UserHomeDir()
	path := filepath.Join(home, ".claude", "settings.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	var settings struct {
		EffortLevel string `json:"effortLevel"`
	}
	if json.Unmarshal(data, &settings) != nil || settings.EffortLevel == "" {
		return ""
	}
	return settings.EffortLevel
}

func formatEffort(effort string) string {
	switch effort {
	case "high":
		return cMagenta + "● " + effort + cReset
	case "low":
		return cDim + "◔ " + effort + cReset
	default:
		return cDim + "◑ " + effort + cReset
	}
}

func formatSessionDuration(startTime string) string {
	if startTime == "" {
		return ""
	}
	t, err := time.Parse(time.RFC3339Nano, startTime)
	if err != nil {
		t, err = time.Parse("2006-01-02T15:04:05.000Z", startTime)
		if err != nil {
			return ""
		}
	}
	elapsed := time.Since(t)
	if elapsed < 0 {
		return ""
	}
	if elapsed < time.Minute {
		return fmt.Sprintf("%ds", int(elapsed.Seconds()))
	}
	if elapsed < time.Hour {
		return fmt.Sprintf("%dm", int(elapsed.Minutes()))
	}
	return fmt.Sprintf("%dh%dm", int(elapsed.Hours()), int(elapsed.Minutes())%60)
}

func getSessionDisplayName(sessionID string) string {
	path := findSessionJSONL(sessionID)
	if path == "" {
		return ""
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}

	lines := strings.Split(string(data), "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		line := lines[i]
		if !strings.Contains(line, `"custom-title"`) {
			continue
		}
		var entry struct {
			Type        string `json:"type"`
			CustomTitle string `json:"customTitle"`
		}
		if json.Unmarshal([]byte(line), &entry) == nil && entry.Type == "custom-title" && entry.CustomTitle != "" {
			return entry.CustomTitle
		}
	}
	return ""
}

// === Main ===

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--version" {
		fmt.Println(Version)
		return
	}

	processStart := time.Now()

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
	gitInfo := getGitInfo(data.Workspace.CurrentDir)
	effort := getEffortLevel()
	sessionName := getSessionDisplayName(data.SessionID)
	sessionDuration := formatSessionDuration(data.Session.StartTime)

	ctxPercent := 0.0
	totalTokens := 0
	if data.ContextWindow.ContextWindowSize > 0 {
		usage := data.ContextWindow.CurrentUsage
		totalTokens = usage.InputTokens + usage.CacheCreationInputTokens + usage.CacheReadInputTokens
		ctxPercent = float64(totalTokens) / float64(data.ContextWindow.ContextWindowSize) * 100
	}

	// === 載入 cache ===
	cachedCost, _ := loadCache[CostCache]("ccusage-costs")
	cachedBlock, _ := loadCache[BlockTimerCache]("block-timer")

	// === 平行非同步更新過期 cache ===
	var mu sync.Mutex
	var wg sync.WaitGroup
	done := make(chan struct{})
	activeSessions := 1

	if cachedCost == nil || time.Since(cachedCost.Time) > costCacheTTL {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if r := fetchCcusageCosts(); r != nil {
				mu.Lock()
				cachedCost = r
				mu.Unlock()
			}
		}()
	}

	if cachedBlock == nil || time.Since(cachedBlock.Time) > blockTimerCacheTTL {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if r := calculateBlockTimer(); r != nil {
				mu.Lock()
				cachedBlock = r
				mu.Unlock()
			}
		}()
	}

	wg.Add(1)
	go func() {
		defer wg.Done()
		count := countClaudeProcesses()
		mu.Lock()
		activeSessions = count
		mu.Unlock()
	}()

	go func() {
		wg.Wait()
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(asyncTimeout):
	}

	mu.Lock()
	finalCost := cachedCost
	finalBlock := cachedBlock
	finalSessions := activeSessions
	mu.Unlock()

	// === 第一行：Model │ Context bar % tokens │ Dir ⚡branch* +N -N │ Effort ===
	line1 := fmt.Sprintf("%s %s%s%s", emoji, cBlue, model, cReset)

	pctColor := colorForPct(ctxPercent)
	bar := progressBar(ctxPercent, 10)
	line1 += fmt.Sprintf("%s%s %s%.0f%%%s %s", sep, bar, pctColor, ctxPercent, cReset, formatTokens(totalTokens))

	line1 += fmt.Sprintf("%s%s%s%s", sep, cCyan, dir, cReset)
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

	if effort != "" {
		line1 += sep + formatEffort(effort)
	}

	// === 第二行：Session │ Cost │ Block Timer ===
	var line2Parts []string

	sessionPart := ""
	if sessionName != "" {
		sessionPart = fmt.Sprintf("📛 %s%s%s", cWhite, sessionName, cReset)
	} else if data.SessionID != "" {
		shortID := data.SessionID
		if len(shortID) > 8 {
			shortID = shortID[:8]
		}
		sessionPart = fmt.Sprintf("%s#%s%s", cDim, shortID, cReset)
	}
	if sessionDuration != "" {
		sessionPart += fmt.Sprintf(" ⏱ %s%s%s", cWhite, sessionDuration, cReset)
	}
	if finalSessions > 1 {
		sessionPart += fmt.Sprintf(" %s[%d]%s", cDim, finalSessions, cReset)
	}
	if sessionPart != "" {
		line2Parts = append(line2Parts, sessionPart)
	}

	if finalCost != nil {
		line2Parts = append(line2Parts, fmt.Sprintf("💰 %s$%.2f%s", cWhite, finalCost.Today, cReset))
	}

	if finalBlock != nil && finalBlock.RemainingMinutes > 0 {
		mins := int(finalBlock.RemainingMinutes)
		hrs := mins / 60
		m := mins % 60
		line2Parts = append(line2Parts, fmt.Sprintf("⏳ %s%dh%dm left%s", cWhite, hrs, m, cReset))
	}

	// 輸出
	fmt.Println(line1)
	if len(line2Parts) > 0 {
		fmt.Println(strings.Join(line2Parts, sep))
	}

	// 等待 goroutines 完成以儲存 cache
	remaining := totalTimeBudget - time.Since(processStart)
	if remaining > 0 {
		select {
		case <-done:
		case <-time.After(remaining):
		}
	}
}
