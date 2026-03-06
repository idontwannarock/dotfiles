package main

import (
	"bufio"
	"crypto/md5"
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

type TokenSpeedCache struct {
	TokensPerSec float64   `json:"tokensPerSec"`
	Time         time.Time `json:"time"`
}

// Session 追蹤
type SessionData struct {
	Date          string `json:"date"`           // YYYY-MM-DD
	TotalSeconds  int64  `json:"total_seconds"`  // 累計秒數
	LastHeartbeat int64  `json:"last_heartbeat"` // Unix timestamp
}

// Version 由 CI 透過 ldflags 注入，格式為 YYYYMMDD
var Version = "dev"

var cacheDir string
var sessionsDir string
var ccusagePath string // resolved at init, empty = not found
var projectsDir string

// Cache TTL 常數
const (
	costCacheTTL       = 60 * time.Second
	blockTimerCacheTTL = 30 * time.Second
	tokenSpeedCacheTTL = 15 * time.Second
	asyncTimeout       = 2 * time.Second  // 等待 goroutines 的時間上限（決定輸出內容）
	totalTimeBudget    = 5 * time.Second   // 整個 process 的時間上限（含 cache 儲存）
	blockDuration      = 5 * time.Hour     // Anthropic 5-hour block
)

func init() {
	home, _ := os.UserHomeDir()
	cacheDir = filepath.Join(home, ".claude", "statusline-cache")
	sessionsDir = filepath.Join(home, ".claude", "statusline-sessions")
	projectsDir = filepath.Join(home, ".claude", "projects")
	os.MkdirAll(cacheDir, 0755)
	os.MkdirAll(sessionsDir, 0755)
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

// findSessionJSONL 在 projects 目錄中搜尋 sessionID.jsonl
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

// readJSONLTail 從檔案尾部讀取最後 maxLines 行
func readJSONLTail(path string, maxLines int) []string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()

	// 從尾部往回讀取
	stat, err := f.Stat()
	if err != nil || stat.Size() == 0 {
		return nil
	}

	// 讀取最後 256KB（大部分情況下足夠取得 N 行）
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
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024) // 1MB buffer for long lines

	var lines []string
	for scanner.Scan() {
		line := scanner.Text()
		if line != "" {
			lines = append(lines, line)
		}
	}

	// 如果是從中間開始讀，第一行可能不完整，丟棄
	if offset > 0 && len(lines) > 0 {
		lines = lines[1:]
	}

	// 只保留最後 maxLines 行
	if len(lines) > maxLines {
		lines = lines[len(lines)-maxLines:]
	}
	return lines
}

// JSONL 行解析結構
type jsonlEntry struct {
	Type        string    `json:"type"`
	Timestamp   string    `json:"timestamp"`
	IsSidechain bool      `json:"isSidechain"`
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

// === Token Speed ===

func calculateTokenSpeed(sessionID string) float64 {
	path := findSessionJSONL(sessionID)
	if path == "" {
		return 0
	}

	lines := readJSONLTail(path, 100)
	if len(lines) == 0 {
		return 0
	}

	// 收集最近的 user→assistant 配對來計算速度
	type requestPair struct {
		userTime      time.Time
		assistantTime time.Time
		outputTokens  int
	}

	var pairs []requestPair
	var lastUserTime time.Time

	for _, line := range lines {
		entry := parseJSONLEntry(line)
		if entry == nil || entry.IsSidechain {
			continue
		}

		ts, err := time.Parse(time.RFC3339Nano, entry.Timestamp)
		if err != nil {
			ts, err = time.Parse("2006-01-02T15:04:05.000Z", entry.Timestamp)
			if err != nil {
				continue
			}
		}

		if entry.Type == "user" {
			lastUserTime = ts
		} else if entry.Type == "assistant" && entry.Message != nil && entry.Message.Usage != nil {
			if !lastUserTime.IsZero() && entry.Message.Usage.OutputTokens > 0 {
				pairs = append(pairs, requestPair{
					userTime:      lastUserTime,
					assistantTime: ts,
					outputTokens:  entry.Message.Usage.OutputTokens,
				})
			}
		}
	}

	if len(pairs) == 0 {
		return 0
	}

	// 取最近 5 對計算平均速度
	start := 0
	if len(pairs) > 5 {
		start = len(pairs) - 5
	}
	recent := pairs[start:]

	var totalTokens int
	var totalDuration time.Duration
	for _, p := range recent {
		dur := p.assistantTime.Sub(p.userTime)
		if dur > 0 && dur < 5*time.Minute { // 排除異常值
			totalTokens += p.outputTokens
			totalDuration += dur
		}
	}

	if totalDuration == 0 {
		return 0
	}
	return float64(totalTokens) / totalDuration.Seconds()
}

// === Block Timer（從 JSONL 計算）===

func calculateBlockTimer() *BlockTimerCache {
	now := time.Now()
	entries, err := os.ReadDir(projectsDir)
	if err != nil {
		return nil
	}

	// 收集近 10 小時內有修改的 JSONL 的 timestamps
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

	// 排序（最新在前）
	sortTimestamps(timestamps)

	// 檢查最近活動是否在 5hr block 內
	if now.Sub(timestamps[0]) > blockDuration {
		return nil
	}

	// 從最新往回找 5hr gap
	blockStart := timestamps[0]
	for i := 1; i < len(timestamps); i++ {
		gap := timestamps[i-1].Sub(timestamps[i])
		if gap >= blockDuration {
			break
		}
		blockStart = timestamps[i]
	}

	// Floor to hour
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

// extractTimestamps 從 JSONL 檔案中提取有 token usage 的 timestamps
func extractTimestamps(path string, cutoff time.Time) []time.Time {
	lines := readJSONLTail(path, 500)
	var timestamps []time.Time

	for _, line := range lines {
		// 快速篩選：只處理有 output_tokens 的行
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

// sortTimestamps 降序排序（最新在前）
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

	// git diff --shortstat for insertions/deletions
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

// fetchCcusageCosts 從 ccusage CLI 取得今日花費（慢，3-5 秒）
// 失敗時回傳 nil，不覆蓋既有 cache
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

// === Session 管理 ===

func getSessionID(sessionID string) string {
	if sessionID != "" {
		hash := md5.Sum([]byte(sessionID))
		return fmt.Sprintf("%x", hash[:8])
	}
	ppid := os.Getppid()
	hash := md5.Sum([]byte(fmt.Sprintf("%d", ppid)))
	return fmt.Sprintf("%x", hash[:8])
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

func updateSessionTime(claudeSessionID string) (totalHours int, totalMins int) {
	now := time.Now()
	today := now.Format("2006-01-02")
	currentTime := now.Unix()
	sessionID := getSessionID(claudeSessionID)

	sessionFile := filepath.Join(sessionsDir, sessionID+".json")
	var session SessionData

	data, err := os.ReadFile(sessionFile)
	if err == nil {
		json.Unmarshal(data, &session)
	}

	if session.Date != today {
		session = SessionData{Date: today, TotalSeconds: 0}
	}

	if session.LastHeartbeat > 0 {
		elapsed := currentTime - session.LastHeartbeat
		if elapsed > 0 && elapsed <= 60 {
			session.TotalSeconds += elapsed
		}
	}
	session.LastHeartbeat = currentTime

	data, _ = json.Marshal(session)
	os.WriteFile(sessionFile, data, 0644)

	var totalSeconds int64 = 0
	files, _ := filepath.Glob(filepath.Join(sessionsDir, "*.json"))
	for _, f := range files {
		var s SessionData
		if data, err := os.ReadFile(f); err == nil {
			if json.Unmarshal(data, &s) == nil && s.Date == today {
				totalSeconds += s.TotalSeconds
			}
		}
	}

	totalHours = int(totalSeconds / 3600)
	totalMins = int((totalSeconds % 3600) / 60)
	return
}

// === 顯示用工具函式 ===

func progressBar(percent float64, width int) string {
	filled := int(percent / 100 * float64(width))
	if filled > width {
		filled = width
	}
	if filled < 0 {
		filled = 0
	}
	return strings.Repeat("█", filled) + strings.Repeat("░", width-filled)
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

	// === 快速本地操作（無外部命令）===
	model := data.Model.DisplayName
	emoji := modelEmoji(model)
	dir := filepath.Base(data.Workspace.CurrentDir)

	gitInfo := getGitInfo(data.Workspace.CurrentDir)

	ctxPercent := 0.0
	totalTokens := 0
	if data.ContextWindow.ContextWindowSize > 0 {
		usage := data.ContextWindow.CurrentUsage
		totalTokens = usage.InputTokens + usage.CacheCreationInputTokens + usage.CacheReadInputTokens
		ctxPercent = float64(totalTokens) / float64(data.ContextWindow.ContextWindowSize) * 100
	}

	// Session 名稱與時間（純檔案 I/O，快速）
	sessionName := getSessionDisplayName(data.SessionID)
	totalHours, totalMins := updateSessionTime(data.SessionID)

	// === 載入所有 file cache ===
	cachedCost, _ := loadCache[CostCache]("ccusage-costs")
	cachedBlock, _ := loadCache[BlockTimerCache]("block-timer")
	cachedSpeed, _ := loadCache[TokenSpeedCache]("token-speed")

	// === 平行非同步更新過期 cache ===
	var mu sync.Mutex
	var wg sync.WaitGroup
	done := make(chan struct{})
	activeSessions := 1

	// ccusage costs（60s TTL）
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

	// Block timer from JSONL（30s TTL）
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

	// Token speed from JSONL（15s TTL）
	if cachedSpeed == nil || time.Since(cachedSpeed.Time) > tokenSpeedCacheTTL {
		wg.Add(1)
		go func() {
			defer wg.Done()
			speed := calculateTokenSpeed(data.SessionID)
			if speed > 0 {
				r := &TokenSpeedCache{TokensPerSec: speed, Time: time.Now()}
				saveCache("token-speed", r)
				mu.Lock()
				cachedSpeed = r
				mu.Unlock()
			}
		}()
	}

	// 進程數（PowerShell，慢）
	wg.Add(1)
	go func() {
		defer wg.Done()
		count := countClaudeProcesses()
		mu.Lock()
		activeSessions = count
		mu.Unlock()
	}()

	// 等待全部完成或超時
	go func() {
		wg.Wait()
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(asyncTimeout):
	}

	// === 讀取最終結果（加鎖）===
	mu.Lock()
	finalCost := cachedCost
	finalBlock := cachedBlock
	finalSpeed := cachedSpeed
	finalActiveSessions := activeSessions
	mu.Unlock()

	// === 第一行：模型 | 專案 | Git | Context 進度條 | Token Speed | Session ===
	gitPart := ""
	if gitInfo.Branch != "" {
		dirtyMark := ""
		if gitInfo.Dirty {
			dirtyMark = "*"
		}
		diffPart := ""
		if gitInfo.Insertions > 0 || gitInfo.Deletions > 0 {
			var parts []string
			if gitInfo.Insertions > 0 {
				parts = append(parts, fmt.Sprintf("+%d", gitInfo.Insertions))
			}
			if gitInfo.Deletions > 0 {
				parts = append(parts, fmt.Sprintf("-%d", gitInfo.Deletions))
			}
			diffPart = " " + strings.Join(parts, " ")
		}
		gitPart = fmt.Sprintf(" ⚡ %s%s%s", gitInfo.Branch, dirtyMark, diffPart)
	}

	bar := progressBar(ctxPercent, 10)
	speedPart := ""
	if finalSpeed != nil && finalSpeed.TokensPerSec > 0 {
		speedPart = fmt.Sprintf(" | ⚡ %.1f t/s", finalSpeed.TokensPerSec)
	}

	sessionLabel := ""
	if sessionName != "" {
		sessionLabel = fmt.Sprintf("📛 %s │ ", sessionName)
	} else if data.SessionID != "" {
		shortID := data.SessionID
		if len(shortID) > 8 {
			shortID = shortID[:8]
		}
		sessionLabel = fmt.Sprintf("#%s │ ", shortID)
	}
	sessionInfo := fmt.Sprintf("%dh%dm", totalHours, totalMins)
	if finalActiveSessions > 1 {
		sessionInfo += fmt.Sprintf(" [%d sessions]", finalActiveSessions)
	}

	line1 := fmt.Sprintf("[%s %s] 📂 %s%s | %s %.1f%% %s%s | %s%s",
		emoji, model, dir, gitPart, bar, ctxPercent, formatTokens(totalTokens), speedPart, sessionLabel, sessionInfo)

	// === 第二行：Today Cost | Burn Rate | Block Timer ===
	var line2Parts []string

	sessionCost := data.Cost.TotalCostUSD
	if finalCost != nil {
		line2Parts = append(line2Parts, fmt.Sprintf("💰 Today: $%.2f (session: $%.2f)", finalCost.Today, sessionCost))
	} else {
		line2Parts = append(line2Parts, fmt.Sprintf("💰 Session: $%.2f", sessionCost))
	}

	// Burn rate: session_cost / block_elapsed（近似，因為 today_cost 跨多個 block）
	if finalBlock != nil && finalBlock.ElapsedMinutes > 5 && sessionCost > 0 {
		elapsedHours := finalBlock.ElapsedMinutes / 60
		burnRate := sessionCost / elapsedHours
		line2Parts = append(line2Parts, fmt.Sprintf("🔥 $%.2f/hr", burnRate))
	}

	if finalBlock != nil && finalBlock.RemainingMinutes > 0 {
		mins := int(finalBlock.RemainingMinutes)
		hrs := mins / 60
		m := mins % 60
		line2Parts = append(line2Parts, fmt.Sprintf("⏱ Block: %dh%dm left", hrs, m))
	}

	line2 := strings.Join(line2Parts, " │ ")

	// 輸出
	fmt.Println(line1)
	if line2 != "" {
		fmt.Println(line2)
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
