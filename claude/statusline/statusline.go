package main

import (
	"crypto/md5"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Claude Code JSON 結構
type ClaudeData struct {
	Model struct {
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

type MCPCache struct {
	Servers []MCPServer `json:"servers"`
	Time    time.Time   `json:"time"`
}

type MCPServer struct {
	Name      string `json:"name"`
	Connected bool   `json:"connected"`
}

// Session 追蹤
type SessionData struct {
	Date          string `json:"date"`           // YYYY-MM-DD
	TotalSeconds  int64  `json:"total_seconds"`  // 累計秒數
	LastHeartbeat int64  `json:"last_heartbeat"` // Unix timestamp
}

var cacheDir string
var sessionsDir string

func init() {
	home, _ := os.UserHomeDir()
	cacheDir = filepath.Join(home, ".claude", "statusline-cache")
	sessionsDir = filepath.Join(home, ".claude", "statusline-sessions")
	os.MkdirAll(cacheDir, 0755)
	os.MkdirAll(sessionsDir, 0755)
}

func loadCache[T any](name string, maxAge time.Duration) (*T, bool) {
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

func getCcusageCosts() *CostCache {
	cache, ok := loadCache[CostCache]("ccusage-costs", 60*time.Second)
	if ok && time.Since(cache.Time) < 60*time.Second {
		return cache
	}

	result := &CostCache{Time: time.Now()}
	today := time.Now().Format("20060102")

	if out := runCommand("bunx", "ccusage", "daily", "--since", today, "--json"); out != "" {
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

func getBlockInfo() *BlockCache {
	cache, ok := loadCache[BlockCache]("ccusage-block", 30*time.Second)
	if ok && time.Since(cache.Time) < 30*time.Second {
		return cache
	}

	if out := runCommand("bunx", "ccusage", "blocks", "--active", "--json"); out != "" {
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

func getMCPInfo() *MCPCache {
	cache, ok := loadCache[MCPCache]("mcp-status", 120*time.Second)
	if ok && time.Since(cache.Time) < 120*time.Second {
		return cache
	}

	result := &MCPCache{Time: time.Now(), Servers: []MCPServer{}}

	if out := runCommand("claude", "mcp", "list"); out != "" {
		lines := strings.Split(out, "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			// 格式: "name: cmd ... - ✓ Connected" 或 "name: cmd ... - ✗ Failed"
			if strings.Contains(line, ": ") && (strings.Contains(line, "Connected") || strings.Contains(line, "Failed") || strings.Contains(line, "Error")) {
				// 取得名稱（冒號前的部分）
				colonIdx := strings.Index(line, ":")
				if colonIdx > 0 {
					name := strings.TrimSpace(line[:colonIdx])
					connected := strings.Contains(line, "✓ Connected")
					result.Servers = append(result.Servers, MCPServer{Name: name, Connected: connected})
				}
			}
		}
	}

	saveCache("mcp-status", result)
	return result
}

// 取得當前 session ID（基於 PID 或環境）
func getSessionID() string {
	// 使用 PPID（父進程）作為 session 識別
	ppid := os.Getppid()
	hash := md5.Sum([]byte(fmt.Sprintf("%d", ppid)))
	return fmt.Sprintf("%x", hash[:8])
}

// 更新 session 並計算今日總時數
func updateSessionAndGetStats() (totalHours int, totalMins int, activeSessions int) {
	now := time.Now()
	today := now.Format("2006-01-02")
	currentTime := now.Unix()
	sessionID := getSessionID()

	// 更新當前 session
	sessionFile := filepath.Join(sessionsDir, sessionID+".json")
	var session SessionData

	data, err := os.ReadFile(sessionFile)
	if err == nil {
		json.Unmarshal(data, &session)
	}

	// 如果是新的一天或新 session，重置
	if session.Date != today {
		session = SessionData{Date: today, TotalSeconds: 0}
	}

	// 計算自上次心跳以來的時間（最多 60 秒，避免長時間閒置被計入）
	if session.LastHeartbeat > 0 {
		elapsed := currentTime - session.LastHeartbeat
		if elapsed > 0 && elapsed <= 60 {
			session.TotalSeconds += elapsed
		}
	}
	session.LastHeartbeat = currentTime

	// 儲存 session
	data, _ = json.Marshal(session)
	os.WriteFile(sessionFile, data, 0644)

	// 統計今日所有 session
	var totalSeconds int64 = 0
	activeSessions = 0

	files, _ := filepath.Glob(filepath.Join(sessionsDir, "*.json"))
	for _, f := range files {
		var s SessionData
		if data, err := os.ReadFile(f); err == nil {
			if json.Unmarshal(data, &s) == nil && s.Date == today {
				totalSeconds += s.TotalSeconds
				// 活躍 session：10 分鐘內有心跳
				if currentTime-s.LastHeartbeat < 600 {
					activeSessions++
				}
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

	// 基本資訊
	model := data.Model.DisplayName
	emoji := modelEmoji(model)
	dir := filepath.Base(data.Workspace.CurrentDir)

	// Git 資訊
	branch, dirty := getGitInfo(data.Workspace.CurrentDir)
	gitPart := ""
	if branch != "" {
		dirtyMark := ""
		if dirty {
			dirtyMark = "*"
		}
		gitPart = fmt.Sprintf(" ⚡ %s%s", branch, dirtyMark)
	}

	// Context 計算
	ctxPercent := 0.0
	totalTokens := 0
	if data.ContextWindow.ContextWindowSize > 0 {
		usage := data.ContextWindow.CurrentUsage
		totalTokens = usage.InputTokens + usage.CacheCreationInputTokens + usage.CacheReadInputTokens
		ctxPercent = float64(totalTokens) / float64(data.ContextWindow.ContextWindowSize) * 100
	}

	// Session 時間統計
	totalHours, totalMins, activeSessions := updateSessionAndGetStats()

	// 取得外部資料
	ccusageCost := getCcusageCosts()
	blockInfo := getBlockInfo()
	mcpInfo := getMCPInfo()

	// === 第一行：模型 | 專案 | Git | Context 進度條 | 時數 ===
	bar := progressBar(ctxPercent, 10)
	sessionInfo := fmt.Sprintf("%dh%dm", totalHours, totalMins)
	if activeSessions > 1 {
		sessionInfo += fmt.Sprintf(" [%d sessions]", activeSessions)
	}
	line1 := fmt.Sprintf("[%s %s] 📂 %s%s | %s %.1f%% %s | %s",
		emoji, model, dir, gitPart, bar, ctxPercent, formatTokens(totalTokens), sessionInfo)

	// === 第二行：Burn Rate | Today Cost | Reset Time ===
	var line2Parts []string
	if blockInfo != nil && blockInfo.CostPerHour > 0 {
		line2Parts = append(line2Parts, fmt.Sprintf("🔥 $%.2f/hr", blockInfo.CostPerHour))
	}
	if ccusageCost != nil {
		line2Parts = append(line2Parts, fmt.Sprintf("💰 Today: $%.2f", ccusageCost.Today))
	}
	if blockInfo != nil && blockInfo.RemainingMinutes > 0 {
		mins := int(blockInfo.RemainingMinutes)
		hrs := mins / 60
		m := mins % 60
		line2Parts = append(line2Parts, fmt.Sprintf("⏱ Reset: %dh %dm", hrs, m))
	}
	line2 := strings.Join(line2Parts, " │ ")

	// === 第三行：MCP 狀態 ===
	line3 := "MCP: "
	if mcpInfo != nil && len(mcpInfo.Servers) > 0 {
		var connected []string
		var failed []string
		for _, s := range mcpInfo.Servers {
			if s.Connected {
				connected = append(connected, s.Name)
			} else {
				failed = append(failed, s.Name)
			}
		}
		var parts []string
		if len(connected) > 0 {
			parts = append(parts, fmt.Sprintf("✓ %s", strings.Join(connected, ", ")))
		}
		if len(failed) > 0 {
			parts = append(parts, fmt.Sprintf("✗ %s", strings.Join(failed, ", ")))
		}
		line3 += strings.Join(parts, " │ ")
	} else {
		line3 += "─ No servers"
	}

	// 輸出（分行）
	fmt.Println(line1)
	if line2 != "" {
		fmt.Println(line2)
	}
	fmt.Println(line3)
}
