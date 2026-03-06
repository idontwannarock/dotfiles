## ADDED Requirements

### Requirement: Display git insertions and deletions
The statusline SHALL display the number of insertions and deletions from `git diff --shortstat` next to the branch name.

#### Scenario: Uncommitted changes exist
- **WHEN** the working directory has uncommitted changes with insertions and deletions
- **THEN** the display shows `⚡ branch* +N -M` on line 1

#### Scenario: No changes
- **WHEN** `git diff --shortstat` returns empty
- **THEN** only the branch name and dirty mark are shown (no +/- stats)

#### Scenario: Only insertions or only deletions
- **WHEN** changes contain only insertions or only deletions
- **THEN** only the non-zero stat is shown (e.g., `+5` without `-0`)
