Personal agents for Claude Code based on below references.

# TL;DR

Move this `agents` folder except this README.md file to `~/.claude`, and then you are good to go.

# Agent Catalog

> 完整清單與使用情境見 [`~/.claude/reference.md`](../reference.md)。
>
> 6 類 24 個 agents：Engineering (8) · Testing (5) · Product (3) · Project Management (3) · Studio Operations (5) · Bonus (1)

# Agent Collaboration Patterns

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEVELOPMENT WORKFLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  trend-researcher ──► rapid-prototyper ──► test-writer-fixer    │
│        │                    │                     │              │
│        ▼                    ▼                     ▼              │
│  sprint-prioritizer    linus-torvalds      api-tester           │
│        │                    │                     │              │
│        ▼                    ▼                     ▼              │
│  experiment-tracker    devops-automator    project-shipper      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

Common Pipelines:

1. New Feature Pipeline:
   trend-researcher → rapid-prototyper → test-writer-fixer → project-shipper

2. Code Quality Pipeline:
   linus-torvalds → test-writer-fixer → api-tester → performance-benchmarker

3. Production Pipeline:
   devops-automator → infrastructure-maintainer → analytics-reporter

4. Product Planning Pipeline:
   feedback-synthesizer → sprint-prioritizer → experiment-tracker

5. Launch Pipeline:
   project-shipper → studio-producer → support-responder
```

# Nice to have

## MCP Servers

> context7 已透過 plugin 安裝（`/plugin` → context7），不需要手動設定 MCP。
> spec-workflow-mcp 已由 OpenSpec + Superpowers 流程取代，不再需要。

- grep mcp setup: `claude mcp add --transport http grep https://mcp.grep.app`

or just add following config in `~/.claude.json` file.

```json
    "mcpServers": {
    "grep": {
      "type": "http",
      "url": "https://mcp.grep.app"
    }
  }
```

# Reference

- [contains-studio/agents](https://github.com/contains-studio/agents)
- [kingkongshot/prompts](https://github.com/kingkongshot/prompts)

