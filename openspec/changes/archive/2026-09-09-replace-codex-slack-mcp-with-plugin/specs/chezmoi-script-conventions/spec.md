## ADDED Requirements

### Requirement: Codex config generators SHALL preserve per-machine plugin registration

The Unix `modify_config.toml` generator and its Windows `run_after_modify-codex-config` counterpart SHALL preserve every existing `[plugins.*]` table while regenerating managed global settings and MCP servers. The generators SHALL treat plugin registration as per-machine state in the same way that they preserve `[projects.*]` tables, and the additional preserved content SHALL NOT break their fixed-point property.

#### Scenario: Existing plugin registration survives regeneration
- **WHEN** an existing Codex config contains one or more `[plugins.*]` tables
- **THEN** either platform-specific generator retains every plugin table and its key-value content in the generated config

#### Scenario: Project and plugin tables are both retained
- **WHEN** an existing Codex config contains interleaved `[projects.*]` and `[plugins.*]` tables
- **THEN** regeneration retains the content of both table families without treating either family as managed global configuration

#### Scenario: Preserved plugin content remains a fixed point
- **WHEN** a generated config containing `[plugins.*]` tables is passed through the same generator again
- **THEN** the second output is byte-for-byte identical to the first output

#### Scenario: Unix and Windows preservation rules remain aligned
- **WHEN** the keep filters in the Unix and Windows generators are compared
- **THEN** both preserve the same `[projects.*]` and `[plugins.*]` table families
