## Context

{{/* axis: reader — `!`-prefixed backticks are Claude Code's own command injection syntax; Codex has to be told to run the commands itself */ -}}
{{ if eq .n.tool "claude" -}}
- Status: !`git status --short`
- Branch: !`git branch --show-current`
{{- else -}}
First, gather context by running these commands:

- `git status --short` — working tree state
- `git branch --show-current` — current branch
{{- end }}
