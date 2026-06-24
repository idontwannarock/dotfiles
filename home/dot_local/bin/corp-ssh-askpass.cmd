@echo off
where /q pwsh
if %ERRORLEVEL% EQU 0 (
    pwsh       -NoProfile -ExecutionPolicy Bypass -File "%~dp0corp-ssh-askpass.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0corp-ssh-askpass.ps1" %*
)
