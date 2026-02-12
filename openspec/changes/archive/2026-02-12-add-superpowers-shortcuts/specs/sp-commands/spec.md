## ADDED Requirements

### Requirement: SP command files exist for all superpowers skills
The system SHALL provide a `.claude/commands/sp/<name>.md` file for each superpowers skill listed in the design's naming mapping table (14 total).

#### Scenario: All command files present
- **WHEN** listing files in `.claude/commands/sp/`
- **THEN** there SHALL be exactly 14 `.md` files matching the names in the design mapping

### Requirement: Command files follow standard format
Each command file SHALL contain YAML frontmatter with `name`, `description`, `category`, and `tags` fields, followed by a body that instructs Claude to invoke the corresponding `superpowers:*` skill using the Skill tool.

#### Scenario: Frontmatter structure
- **WHEN** reading any command file in `.claude/commands/sp/`
- **THEN** the file SHALL have YAML frontmatter with `name` (prefixed "SP: "), `description`, `category: Workflow`, and `tags` including `superpowers`

#### Scenario: Skill delegation
- **WHEN** a user invokes `/sp:<name>`
- **THEN** Claude SHALL invoke the corresponding `superpowers:*` skill via the Skill tool, passing through any arguments provided after the command

### Requirement: Command names are short and memorable
Each command name SHALL be a concise abbreviation of the full superpowers skill name, following the mapping defined in the design document.

#### Scenario: Name recognizability
- **WHEN** a user sees a `/sp:*` command name
- **THEN** the name SHALL clearly suggest which superpowers skill it invokes (e.g., `tdd` → test-driven-development, `debug` → systematic-debugging)
