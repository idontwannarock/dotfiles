# PowerShell 7+ CommandNotFound integration.
#
# Prerequisites (silent no-op if missing — `-ErrorAction SilentlyContinue`):
#   1. PowerToys installed with the CommandNotFound module enabled.
#      Provides `Microsoft.WinGet.CommandNotFound` (independent of the
#      `Microsoft.WinGet.Client` module / scoop's winget-ps).
#   2. `winget.exe` reachable on PATH. Win10 1809+ and Win11 ship it OS-bundled
#      at %LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe via the
#      Microsoft.DesktopAppInstaller Store package.
#
#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue
#f45873b3-b655-43a6-b217-97c00aa0db58
