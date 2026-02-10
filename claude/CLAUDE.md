# Global Instructions

## Default Workflow: OpenSpec + Superpowers

When the user requests any implementation task (new feature, bug fix, refactoring, or code modification), **before starting any work**, ask them:

> Would you like to use the **OpenSpec + Superpowers** workflow for this task?

- If **yes**: Start by invoking `superpowers:brainstorming` to explore requirements and design, then use `opsx:new` (or `openspec-new-change`) to create the change with structured artifacts.
- If **no**: Proceed with the standard approach directly.
- If the task is **trivial** (e.g., fixing a typo, one-line change, simple question): Skip the prompt and proceed directly. Use your judgement.
