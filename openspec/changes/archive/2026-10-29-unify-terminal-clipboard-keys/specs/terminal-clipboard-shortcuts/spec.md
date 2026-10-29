## ADDED Requirements

### Requirement: Separate terminal text shortcuts from program shortcuts

The Windows Terminal configuration SHALL bind Ctrl+Shift+C to terminal selection copy and Ctrl+Shift+V to clipboard text paste. It SHALL explicitly disable terminal copy/paste handling for Ctrl+C and Ctrl+V so those keys reach the inner program rather than falling back to built-in copy/paste defaults.

#### Scenario: Copy terminal selection
- **WHEN** the user selects text in Windows Terminal and presses Ctrl+Shift+C
- **THEN** the selected text is copied to the system clipboard

#### Scenario: Paste text into either CLI
- **WHEN** the clipboard contains a URL or multiline text and the user presses Ctrl+Shift+V in Claude Code or Codex CLI inside Windows Terminal through Herdr
- **THEN** the text is inserted into the active CLI input without invoking image paste or submitting the prompt

#### Scenario: Forward interruption independently of selection
- **WHEN** a disposable foreground command that supports interruption runs in PowerShell inside Windows Terminal and the user presses Ctrl+C
- **THEN** the command receives the interruption input whether or not Windows Terminal has selected text
- **AND** Windows Terminal does not consume that key as a copy action

#### Scenario: Forward image shortcut through Herdr
- **WHEN** the user presses Ctrl+V in either CLI inside Windows Terminal through Herdr
- **THEN** the key reaches the CLI's existing image-paste handler instead of Windows Terminal's text-paste action

### Requirement: Preserve working clipboard integrations

The change SHALL preserve Ghostex's existing text and image clipboard integration and the inspected native CLI image bindings. It SHALL NOT modify Herdr or CLI keymaps without an observed conflict and additional user approval.

#### Scenario: Ghostex text paste
- **WHEN** the clipboard contains text and the user presses Ctrl+Shift+V with either CLI terminal focused in Ghostex
- **THEN** Ghostex inserts the clipboard text into that terminal without invoking the CLI's image-paste handler

#### Scenario: Ghostex image paste
- **WHEN** the clipboard contains an image and the user presses Ctrl+V with either CLI terminal focused in Ghostex
- **THEN** Ghostex retains its existing image-link integration
- **AND** the change does not force the image through native CLI clipboard access

#### Scenario: Preserve existing CLI alternatives
- **WHEN** the Windows Terminal configuration change is applied
- **THEN** Claude Code's existing Ctrl+V and Alt+V image bindings on WSL remain unchanged
- **AND** Codex CLI's existing Ctrl+V and Ctrl+Alt+V image bindings remain unchanged

#### Scenario: Herdr conflict discovered
- **WHEN** verification shows that Herdr consumes a required key instead of forwarding it
- **THEN** the failed path is recorded
- **AND** the implementer requests approval before changing Herdr configuration

### Requirement: Preserve unrelated settings during deployment

The Windows Terminal settings update SHALL preserve unrelated machine-local shortcuts, action definitions, profiles, and other settings while retaining the script's existing managed settings. It SHALL remove conflicting definitions for the four targeted chords without removing unrelated chords from shared legacy entries. Repeated application SHALL produce structurally identical settings.

#### Scenario: Existing custom configuration
- **WHEN** the update runs against settings containing unrelated shortcuts, custom action definitions, and machine-local profiles
- **THEN** those entries retain their values
- **AND** the four targeted chords have the required effective bindings

#### Scenario: Legacy and current binding conflict
- **WHEN** the settings contain old or duplicate definitions of a targeted chord in actions or keybindings
- **THEN** the update leaves no competing definition for that chord
- **AND** unrelated bindings and action definitions survive

#### Scenario: Repeated application
- **WHEN** the update runs twice with no intervening user changes
- **THEN** the second output is structurally identical to the first
- **AND** no duplicate binding or action is added

#### Scenario: Non-Windows rendering
- **WHEN** the Windows Terminal script template is rendered for Linux or macOS
- **THEN** it produces no executable configuration changes

### Requirement: Verify live behavior before syncing deployment source

The implementer SHALL back up the live settings before modification and verify the candidate behavior before syncing it to the chezmoi source. Verification SHALL cover Windows Terminal through Herdr and Ghostex with both CLIs. It SHALL record runtime platform, application versions, and passed, failed, or not-tested outcomes. Configuration inspection alone SHALL NOT count as end-to-end success.

#### Scenario: Image access verified in every path
- **WHEN** image paste is tested in each of the four entry-point and CLI combinations
- **THEN** the user pastes a non-sensitive image with a distinctive marker using Ctrl+V
- **AND** the CLI correctly describes that marker without receiving it in the text prompt
- **AND** receipt of an attachment badge or path alone is not recorded as a pass

#### Scenario: Text and interruption regression checks
- **WHEN** each entry-point and CLI combination is tested
- **THEN** terminal selection copy, URL paste, multiline paste, and interruption are checked separately
- **AND** the record identifies whether the selection belongs to the outer terminal or Herdr
- **AND** interruption testing does not cancel unrelated work

#### Scenario: Incomplete or failed verification
- **WHEN** a required GUI test cannot be performed or a clipboard operation fails
- **THEN** the result remains not tested or failed with its evidence
- **AND** the change is not reported as end-to-end complete
- **AND** a correct key binding is not reported as proof of working image access

#### Scenario: Source regression checks
- **WHEN** live verification succeeds and the source script is updated
- **THEN** a focused regression test has first demonstrated failure against the previous source
- **AND** the updated source passes binding, preservation, idempotence, rendering, and PowerShell parsing checks

### Requirement: Document operation and rollback

The documentation SHALL explain text and image shortcuts, the intentional Ctrl+C behavior change, the distinct image paths, and how to restore the previous live bindings. Rollback SHALL preserve changes made by the user after the backup.

#### Scenario: User needs the previous behavior
- **WHEN** the user chooses to roll back
- **THEN** the instructions restore the backup only if no intervening changes occurred
- **AND** otherwise restore only the changed bindings
- **AND** the instructions cover reverting shipped source changes to prevent reapplication
