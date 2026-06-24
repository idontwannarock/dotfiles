# 22-use-java.ps1 -- switch the default JDK by setting JAVA_HOME.
#
# JDKs are installed off-scoop as real dirs in ~/.local/opt/jdk-N (Wave 10).
# The default `java`/`javac` on PATH are ~/.local/bin/java.cmd and javac.cmd, which
# delegate to %JAVA_HOME%\bin\* (cmd expands %JAVA_HOME% at runtime -- SSH-safe,
# unlike putting %JAVA_HOME%\bin directly on PATH, which Win32-OpenSSH won't expand).
# So switching the default JDK is just a matter of changing JAVA_HOME: this updates
# both the persisted (User) value and the current session. For one-off use of a
# specific version, call the java8/11/17/21/25 .cmd aliases.
#
# Dot-sourced by both PS5 and PS7 profile loaders -- keep ASCII-only, no PS7-only
# syntax (no ternary, no null-coalescing).

function use-java {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string] $Version)

    $optDir  = Join-Path $env:USERPROFILE ".local\opt"
    $jdkHome = Join-Path $optDir "jdk-$Version"
    if (-not (Test-Path (Join-Path $jdkHome "bin\java.exe"))) {
        $avail = (Get-ChildItem $optDir -Directory -Filter "jdk-*" -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Name -replace '^jdk-', '' }) -join ', '
        Write-Error "use-java: jdk-$Version not installed (available: $avail)"
        return
    }

    # Persist for new sessions/programs + apply to the current session. The default
    # java/javac wrappers read %JAVA_HOME% at invocation, so this is all it takes.
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkHome, "User")
    $env:JAVA_HOME = $jdkHome

    Write-Host "JAVA_HOME -> $jdkHome (default java/javac now use this; persisted)" -ForegroundColor Green
}
