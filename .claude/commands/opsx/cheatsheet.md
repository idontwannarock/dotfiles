---
name: "OPSX: Cheat Sheet"
description: "Display the OpenSpec workflow cheat sheet - quick reference for commands and workflow"
category: Reference
tags: [workflow, reference, help]
---

Display the following cheat sheet directly to the user. Do NOT do anything else — just print it.

---

## OpenSpec Cheat Sheet

### Daily Workflow (3 commands)

```
/opsx:ff           describe your task → all artifacts generated at once
  review & adjust   tweak proposal/specs/design/tasks if needed
/opsx:apply         implement tasks one by one
/opsx:archive       archive when done
```

### Step-by-Step Workflow (when you want more control)

```
/opsx:new           create a change container
/opsx:continue      create next artifact (proposal → specs → design → tasks)
  repeat continue until all artifacts are ready...
/opsx:apply         implement tasks
/opsx:verify        verify implementation matches artifacts
/opsx:archive       archive when done
```

### Utility Commands

| Command | What it does |
|---------|--------------|
| `/opsx:explore` | Think through problems — no code changes, just investigation |
| `/opsx:ff` | Fast-forward: create all artifacts at once |
| `/opsx:new` | Start a new change, step by step |
| `/opsx:continue` | Create the next artifact in sequence |
| `/opsx:apply` | Implement tasks from a change |
| `/opsx:verify` | Verify implementation matches artifacts |
| `/opsx:archive` | Archive a completed change |
| `/opsx:bulk-archive` | Archive multiple completed changes |
| `/opsx:sync` | Sync delta specs to main specs |
| `/opsx:onboard` | Guided onboarding tutorial |
| `/opsx:cheatsheet` | This cheat sheet |

### Artifact Flow

```
proposal  →  specs  →  design  →  tasks  →  apply  →  archive
  WHY        WHAT       HOW      STEPS     CODE     RECORD
```

### How to Start a Task

| Situation | What you do | What happens |
|-----------|-------------|--------------|
| Clear scope, just do it | Describe task → `/opsx:ff` | All artifacts generated at once |
| Need to think first | Describe task → say "yes" to brainstorming | Claude asks questions to clarify requirements, then auto-triggers `/opsx:new` |
| Explore only, no code | `/opsx:explore` | Investigation mode, no changes made |

**Brainstorming flow** (you just talk, Claude drives everything):
```
You: "I want to improve the retry mechanism"
Claude: "Use OpenSpec + Superpowers workflow?"
You: "Yes"
  → brainstorming starts (normal conversation, no plan mode)
  → Claude asks clarifying questions
  → requirements clear
  → Claude auto-triggers /opsx:new (you don't type it)
  → artifacts created
  → /opsx:apply to implement
```

### Tips

- **Small change, clear scope?** → `/opsx:ff` (fastest)
- **Complex or ambiguous?** → Just describe it, say yes to brainstorming, Claude handles the rest
- **No spec changes (dead code, refactor)?** → Skip specs, "no deltas" warning is OK
- **No plan mode needed** — brainstorming is normal conversation, not plan mode
