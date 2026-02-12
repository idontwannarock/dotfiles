Personal agents for Claude Code based on below references.

# TL;DR

Move this `agents` folder except this README.md file to `~/.claude`, and then you are good to go.

# Agent Catalog

## Engineering (cyan) - 7 agents
| Agent | Description |
|-------|-------------|
| `ai-engineer` | AI/ML features, LLM integration, recommendation systems |
| `backend-architect` | APIs, databases, scalable backend systems |
| `frontend-developer` | React/Vue/Angular, responsive UI, performance |
| `mobile-app-builder` | iOS/Android, React Native, mobile optimization |
| `devops-automator` | CI/CD, cloud infrastructure, monitoring |
| `rapid-prototyper` | MVPs, prototypes, quick experiments |
| `linus-torvalds` | Code review, system design, implementation |
| `test-writer-fixer` | Write tests, run tests, fix failures |

## Testing (yellow) - 5 agents
| Agent | Description |
|-------|-------------|
| `api-tester` | API load testing, contract testing, security testing |
| `performance-benchmarker` | Speed testing, profiling, optimization |
| `test-results-analyzer` | Test analysis, quality metrics, trend reports |
| `workflow-optimizer` | Human-agent workflows, process efficiency |
| `tool-evaluator` | New tools/frameworks evaluation |

## Product (purple) - 3 agents
| Agent | Description |
|-------|-------------|
| `trend-researcher` | Market trends, viral content, opportunities |
| `sprint-prioritizer` | Sprint planning, feature prioritization |
| `feedback-synthesizer` | User feedback analysis, insights |

## Project Management (blue) - 3 agents
| Agent | Description |
|-------|-------------|
| `experiment-tracker` | A/B tests, feature experiments tracking |
| `project-shipper` | Launch coordination, go-to-market |
| `studio-producer` | Cross-team coordination, resource management |

## Studio Operations (orange) - 5 agents
| Agent | Description |
|-------|-------------|
| `analytics-reporter` | Metrics analysis, performance reports |
| `finance-tracker` | Budget management, cost optimization |
| `infrastructure-maintainer` | System health, scaling, reliability |
| `legal-compliance-checker` | Legal review, regulatory compliance |
| `support-responder` | Customer support, documentation |

## Bonus (gold) - 1 agent
| Agent | Description |
|-------|-------------|
| `studio-coach` | Team motivation, performance coaching |

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

# Color Scheme

| Category | Color | Agents |
|----------|-------|--------|
| Engineering | cyan | ai-engineer, backend-architect, frontend-developer, mobile-app-builder, devops-automator, rapid-prototyper, linus-torvalds, test-writer-fixer |
| Testing | yellow | api-tester, performance-benchmarker, test-results-analyzer, workflow-optimizer, tool-evaluator |
| Product | purple | trend-researcher, sprint-prioritizer, feedback-synthesizer |
| Project Management | blue | experiment-tracker, project-shipper, studio-producer |
| Studio Operations | orange | analytics-reporter, finance-tracker, infrastructure-maintainer, legal-compliance-checker, support-responder |
| Bonus | gold | studio-coach |

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

