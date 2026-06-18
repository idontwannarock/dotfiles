@echo off
rem jdtls.cmd -- Windows-native launcher for jdtls (Wave 11, off-scoop).
rem Counterpart to the bash wrapper (~/.local/bin/jdtls) for callers that resolve
rem commands via PATHEXT (Node / cmd.exe / PowerShell) and cannot execute the
rem extensionless bash script -- e.g. the Claude Code jdtls-lsp plugin's
rem "command": "jdtls". Replaces the scoop jdtls.exe shim removed in Wave 11.
rem
rem bin/jdtls is a python3 script; resolve a real interpreter via uv (the system
rem python is a WindowsApps alias stub). jdtls.py reads %JAVA_HOME% itself, which
rem 22-use-java.ps1 persists to ~/.local/opt/jdk-21.
set "JDTLS_PY="
for /f "delims=" %%i in ('"%USERPROFILE%\.local\bin\uv.exe" python find') do set "JDTLS_PY=%%i"
if not defined JDTLS_PY (
    echo ERROR: no python found for jdtls launcher ^(uv python find failed^). Run: uv python install 1>&2
    exit /b 1
)
"%JDTLS_PY%" "%USERPROFILE%\.local\opt\jdtls\bin\jdtls" %*
