Personal agents for Claude Code, deployed by chezmoi from `home/dot_claude/exact_agents/`.

`exact_agents/` is chezmoi-exclusive: deleting a file here removes it from
`~/.claude/agents/` on the next apply. No `.chezmoiremove` entry needed.

# Agent Catalog

Seven agents, all serving the `/code:review-*` commands. Each agent's trigger
conditions live in its frontmatter `description`.

| Agent | Used by |
| --- | --- |
| `code-review/code-reviewer` | comprehensive, uncommitted, spec, security, surgical |
| `engineering/linus-torvalds` | comprehensive, uncommitted, spec, linus |
| `code-review/pr-test-analyzer` | comprehensive, uncommitted, spec |
| `code-review/silent-failure-hunter` | comprehensive, uncommitted, security |
| `code-review/type-design-analyzer` | comprehensive, types |
| `code-review/code-simplifier` | surgical |
| `code-review/comment-analyzer` | comprehensive |

`/code:review-cross-model` uses none of these — it dispatches a different model
through herdr.

# Cost model

An agent's `description` is preloaded into every session's system prompt so the
model can route to it; only the body is lazy. Agents therefore cost tokens even
when never invoked. Keep this directory to agents that something actually calls.

The 24 agents from [contains-studio/agents](https://github.com/contains-studio/agents)
that shipped here originally were retired for that reason — nothing referenced
them, and they cost roughly 14k tokens per session.

# Reference

- [contains-studio/agents](https://github.com/contains-studio/agents)
- [kingkongshot/prompts](https://github.com/kingkongshot/prompts)
