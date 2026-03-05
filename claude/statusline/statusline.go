package main

import (
	"crypto/md5"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
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

type BlockCache struct {
	RemainingMinutes float64   `json:"remainingMinutes"`
	CostPerHour      float64   `json:"costPerHour"`
	Time             time.Time `json:"time"`
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

const (
	asyncTimeout   = 2 * time.Second // 等待 goroutines 的時間上限（決定輸出內容）
	totalTimeBudget = 5 * time.Second // 整個 process 的時間上限（含 cache 儲存）
)

func init() {
	home, _ := os.UserHomeDir()
	cacheDir = filepath.Join(home, ".claude", "statusline-cache")
	sessionsDir = filepath.Join(home, ".claude", "statusline-sessions")
	os.MkdirAll(cacheDir, 0755)
	os.MkdirAll(sessionsDir, 0755)
}

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

// 計算運行中的 Claude Code 進程數量（跨平台）
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

func getGitInfo(dir string) (branch string, dirty bool) {
	gitDir := filepath.Join(dir, ".git")
	if _, err := os.Stat(gitDir); os.IsNotExist(err) {
		return "", false
	}

	cmd := exec.Command("git", "branch", "--show-current")
	cmd.Dir = dir
	out, err := cmd.Output()
	if err != nil {
		return "", false
	}
	branch = strings.TrimSpace(string(out))

	cmd = exec.Command("git", "status", "--porcelain")
	cmd.Dir = dir
	out, _ = cmd.Output()
	dirty = len(strings.TrimSpace(string(out))) > 0

	return branch, dirty
}

// fetchCcusageCosts 從 ccusage CLI 取得今日花費（慢，3-5 秒）
func fetchCcusageCosts() *CostCache {
	result := &CostCache{Time: time.Now()}
	today := time.Now().Format("20060102")

	if out := runCommand("ccusage", "daily", "--since", today, "--json"); out != "" {
		var data struct {
			Daily []struct {
				TotalCost float64 `json:"totalCost"`
			} `json:"daily"`
		}
		if json.Unmarshal([]byte(out), &data) == nil {
			for _, d := range data.Daily {
				result.Today += d.TotalCost
			}
		}
	}

	saveCache("ccusage-costs", result)
	return result
}

// fetchBlockInfo 從 ccusage CLI 取得 block 資訊（慢，3-5 秒）
func fetchBlockInfo() *BlockCache {
	if out := runCommand("ccusage", "blocks", "--active", "--json"); out != "" {
		var data struct {
			Blocks []struct {
				Projection struct {
					RemainingMinutes float64 `json:"remainingMinutes"`
				} `json:"projection"`
				BurnRate struct {
					CostPerHour float64 `json:"costPerHour"`
				} `json:"burnRate"`
			} `json:"blocks"`
		}
		if json.Unmarshal([]byte(out), &data) == nil && len(data.Blocks) > 0 {
			result := &BlockCache{
				RemainingMinutes: data.Blocks[0].Projection.RemainingMinutes,
				CostPerHour:      data.Blocks[0].BurnRate.CostPerHour,
				Time:             time.Now(),
			}
			saveCache("ccusage-block", result)
			return result
		}
	}

	return nil
}

// 取得 session ID（使用 Claude Code 傳入的 session_id）
func getSessionID(sessionID string) string {
	if sessionID != "" {
		hash := md5.Sum([]byte(sessionID))
		return fmt.Sprintf("%x", hash[:8])
	}
	ppid := os.Getppid()
	hash := md5.Sum([]byte(fmt.Sprintf("%d", ppid)))
	return fmt.Sprintf("%x", hash[:8])
}

// getSessionDisplayName 從 JSONL 讀取 session 的 customTitle（使用者命名）
// 若無 customTitle，回傳空字串
func getSessionDisplayName(sessionID string) string {
	if sessionID == "" {
		return ""
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}

	// workspace.current_dir 可能是子目錄，無法直接推導 projects 目錄名稱
	// 改為在所有 projects 目錄中搜尋 sessionID.jsonl
	projectsDir := filepath.Join(home, ".claude", "projects")
	jsonlName := sessionID + ".jsonl"

	var jsonlPath string
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
			jsonlPath = candidate
			break
		}
	}
	if jsonlPath == "" {
		return ""
	}

	data, err := os.ReadFile(jsonlPath)
	if err != nil {
		return ""
	}

	// 從尾部往回找最後一個 custom-title 行
	// 逐行字串匹配，只對命中行解析 JSON，即使數 MB 也很快
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

// updateSessionTime 更新 session 心跳並計算今日總時數（純檔案 I/O，快速）
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

// 生成進度條
func progressBar(percent float64, width int) string {
	filled := int(percent / 100 * float64(width))
	if filled > width {
		filled = width
	}
	if filled < 0 {
		filled = 0
	}

	bar := strings.Repeat("█", filled) + strings.Repeat("░", width-filled)
	return bar
}

// 格式化 token 數量
func formatTokens(tokens int) string {
	if tokens >= 1000000 {
		return fmt.Sprintf("%.1fM", float64(tokens)/1000000)
	}
	if tokens >= 1000 {
		return fmt.Sprintf("%.1fk", float64(tokens)/1000)
	}
	return fmt.Sprintf("%d", tokens)
}

// 模型 emoji
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

	branch, dirty := getGitInfo(data.Workspace.CurrentDir)
	gitPart := ""
	if branch != "" {
		dirtyMark := ""
		if dirty {
			dirtyMark = "*"
		}
		gitPart = fmt.Sprintf(" ⚡ %s%s", branch, dirtyMark)
	}

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

	// === 載入所有 cache（檔案讀取，快速）===
	cachedCost, _ := loadCache[CostCache]("ccusage-costs")
	cachedBlock, _ := loadCache[BlockCache]("ccusage-block")

	// === 平行非同步更新過期 cache ===
	var mu sync.Mutex
	var wg sync.WaitGroup
	done := make(chan struct{})
	activeSessions := 1 // 預設值

	// ccusage costs（60 秒過期）
	if cachedCost == nil || time.Since(cachedCost.Time) > 60*time.Second {
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

	// ccusage block info（30 秒過期）
	if cachedBlock == nil || time.Since(cachedBlock.Time) > 30*time.Second {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if r := fetchBlockInfo(); r != nil {
				mu.Lock()
				cachedBlock = r
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
		// 全部完成
	case <-time.After(asyncTimeout):
		// 超時，用已有的 cache + 已完成的結果
	}

	// === 讀取最終結果（加鎖）===
	mu.Lock()
	finalCost := cachedCost
	finalBlock := cachedBlock
	finalActiveSessions := activeSessions
	mu.Unlock()

	// === 第一行：模型 | 專案 | Git | Context 進度條 | 時數 ===
	bar := progressBar(ctxPercent, 10)
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
	line1 := fmt.Sprintf("[%s %s] 📂 %s%s | %s %.1f%% %s | %s%s",
		emoji, model, dir, gitPart, bar, ctxPercent, formatTokens(totalTokens), sessionLabel, sessionInfo)

	// === 第二行：Burn Rate | Today Cost | Reset Time ===
	var line2Parts []string
	if finalBlock != nil && finalBlock.CostPerHour > 0 {
		line2Parts = append(line2Parts, fmt.Sprintf("🔥 $%.2f/hr", finalBlock.CostPerHour))
	}
	if finalCost != nil {
		line2Parts = append(line2Parts, fmt.Sprintf("💰 Today: $%.2f", finalCost.Today))
	}
	if finalBlock != nil && finalBlock.RemainingMinutes > 0 {
		mins := int(finalBlock.RemainingMinutes)
		hrs := mins / 60
		m := mins % 60
		line2Parts = append(line2Parts, fmt.Sprintf("⏱ Reset: %dh %dm", hrs, m))
	}
	line2 := strings.Join(line2Parts, " │ ")

	// 輸出
	fmt.Println(line1)
	if line2 != "" {
		fmt.Println(line2)
	}

	// 等待 goroutines 完成以儲存 cache（避免 process exit 時 goroutine 被 kill）
	remaining := totalTimeBudget - time.Since(processStart)
	if remaining > 0 {
		select {
		case <-done:
		case <-time.After(remaining):
		}
	}
}
