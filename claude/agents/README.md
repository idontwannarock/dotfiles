Personal agents for Claude Code based on below references.

# TL;DR

Move this `agents` folder except this README.md file to `~/.claude`, and then you are good to go.

# Nice to have

- context7 remote mcp setup: `claude mcp add --transport http context7 https://mcp.context7.com/mcp`
- grep mcp setup: `claude mcp add --transport http grep https://mcp.grep.app`
- spec workflow mcp setup: `claude mcp add spec-workflow-mcp -s user -- npx spec-workflow-mcp@latest`

or just add following config in `~/.claude.json` file.

```json
    "mcpServers": {
    "spec-workflow-mcp": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "spec-workflow-mcp@latest"
      ],
      "env": {}
    },
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp"
    },
    "grep": {
      "type": "http",
      "url": "https://mcp.grep.app"
    }
  }
```

# Reference

- [contains-studio/agents](https://github.com/contains-studio/agents)
- [kingkongshot/prompts](https://github.com/kingkongshot/prompts)

