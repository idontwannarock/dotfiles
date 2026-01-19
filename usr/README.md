These are all custom scripts for personal use.

If it is in Windows, the scripts in `local/bin` should go to `~/.local/bin` folder, `/usr/local/bin` in Linux or MacOS.

# Windows

```powershell
Copy-Item -Path ".local/bin" -Destination "~/.local/bin" -Recurse -Force
Copy-Item -Path Microsoft.PowerShell_profile.ps1 -Destination $PROFILE
```
