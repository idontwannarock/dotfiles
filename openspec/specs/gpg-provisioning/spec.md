# gpg-provisioning Specification

## Purpose
TBD - created by archiving change gpg-off-scoop. Update Purpose after archive.
## Requirements
### Requirement: GnuPG provisioned from first-party source, not Scoop

On Windows, the GnuPG suite SHALL be installed by a chezmoi-managed script from the official gnupg.org NSIS installer, and SHALL NOT be installed or managed by Scoop.

#### Scenario: chezmoi apply installs GnuPG without Scoop

- **WHEN** `chezmoi apply` runs on a Windows machine
- **THEN** the GnuPG suite (`gpg.exe`, `gpg-agent.exe`, `gpgconf.exe`, `keyboxd.exe`, `scdaemon.exe`, `dirmngr.exe`, pinentry) is present under `~/.local/opt/gnupg/`
- **AND** no `Install-ScoopPackage "gpg"` invocation remains in the install scripts

#### Scenario: Source is pinned and verified

- **WHEN** the installer script downloads the GnuPG installer
- **THEN** the URL targets a pinned version and build date on gnupg.org
- **AND** the download is verified against a pinned SHA-1 before execution

### Requirement: GnuPG resolves homedir to the user keyring, never portable mode

The provisioned GnuPG SHALL resolve its homedir to `%USERPROFILE%\.gnupg` and SHALL NOT enter portable mode (no `gpgconf.ctl` marker beside the binary).

#### Scenario: homedir points at the real keyring

- **WHEN** `gpgconf --list-dirs homedir` is run using the provisioned gpg
- **THEN** it reports `C:\Users\<user>\.gnupg`
- **AND** `gpg --list-secret-keys` shows the corp-ssh secret key

#### Scenario: No portable marker is created

- **WHEN** the install completes
- **THEN** no `gpgconf.ctl` file exists in the GnuPG `bin` directory
- **AND** the `GNUPGHOME` environment variable set by the dotfiles is honored

#### Scenario: corp-ssh decryption succeeds

- **WHEN** `corp-ssh-askpass` invokes `gopass show -o corp/password` after the gpg-agent cache is warmed
- **THEN** gopass exits 0 and returns the decrypted secret

### Requirement: Provisioned GnuPG takes PATH precedence

The provisioned GnuPG `bin` directory SHALL appear on PATH ahead of any Scoop shim so that `gpg` resolves to the owned install.

#### Scenario: gpg resolves to the owned install

- **WHEN** `gpg` is resolved from a fresh shell after `chezmoi apply`
- **THEN** it resolves to `~/.local/opt/gnupg/bin/gpg.exe`, not `~/scoop/shims/gpg.exe`

### Requirement: Install is idempotent and version-driven

The installer SHALL skip work when the pinned GnuPG version is already installed, and SHALL re-run only when the pinned version changes.

#### Scenario: Re-running apply with unchanged version is a no-op

- **WHEN** `chezmoi apply` runs and `~/.local/opt/gnupg/bin/gpg.exe` already reports the pinned version
- **THEN** the script performs no download or reinstall

#### Scenario: Bumping the pinned version triggers reinstall

- **WHEN** the pinned version string in the script changes and `chezmoi apply` runs
- **THEN** the new version is downloaded, verified, and installed into `~/.local/opt/gnupg/`

### Requirement: Provisioning is Windows-only

The GnuPG provisioning script SHALL apply only on Windows; Linux/WSL and macOS keep their existing package-manager gpg.

#### Scenario: Non-Windows platforms skip the script

- **WHEN** `chezmoi apply` runs on Linux/WSL or macOS
- **THEN** the Windows GnuPG installer script is excluded and does not execute

### Requirement: gpg-agent pinentry-w32 由偵測到的 git root 解析（不再硬依賴 scoop）
`run_onchange_install-gnupg.ps1.tmpl` 設定 gpg-agent.conf 的 `pinentry-program` 時，SHALL 由「已知 Git-for-Windows 安裝 root 的有序候選清單」（同 chezmoi-structure 的偵測：`~/.local/opt/git` → `C:\Program Files\Git` → scoop，並含 `HKLM/HKCU\SOFTWARE\GitForWindows\InstallPath` registry probe）解析 `<git root>\usr\bin\pinentry-w32.exe`，而非硬指 `~/scoop/apps/git/current/usr/bin/pinentry-w32.exe`。若偵測不到任何 git（無 pinentry-w32），SHALL 維持既有 fallback 至 GnuPG 自帶的 `pinentry-basic.exe`。

#### Scenario: 有非-scoop git 時用其 pinentry-w32
- **WHEN** 機器上有 `C:\Program Files\Git`（winget）
- **THEN** gpg-agent.conf 的 `pinentry-program` 指向 `C:\Program Files\Git\usr\bin\pinentry-w32.exe`

#### Scenario: 無任何 git 時 fallback
- **WHEN** 偵測不到任何候選 git root 的 `usr\bin\pinentry-w32.exe`
- **THEN** `pinentry-program` fallback 至 `~/.local/opt/gnupg/.../pinentry-basic.exe`（既有行為）

