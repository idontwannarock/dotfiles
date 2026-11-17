# switch-pwsh-to-msi.Tests.ps1 -- Pester 5 tests for the release-selection logic in
# home/dot_local/bin/switch-pwsh-to-msi.ps1
#
# The helper needs elevation and the network, so it cannot run whole in a test.
# The tests pull Select-MsiRelease out of the script with the PowerShell parser and
# run only that function against fixture release objects. No network, no admin.

BeforeAll {
    $script:ScriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'home\dot_local\bin\switch-pwsh-to-msi.ps1'

    $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
    $fn  = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Select-MsiRelease' }, $true)
    if (-not $fn) { throw "Select-MsiRelease is not defined in $ScriptPath" }
    . ([scriptblock]::Create($fn.Extent.Text))

    # A release as the GitHub API returns it, reduced to the fields the helper reads.
    function New-Release([string]$Tag, [switch]$Msi, [switch]$Prerelease, [switch]$Draft) {
        $ver = $Tag.TrimStart('v')
        $assets = @([pscustomobject]@{ name = "PowerShell-$ver-win-x64.zip" })
        if ($Msi) { $assets += [pscustomobject]@{ name = "PowerShell-$ver-win-x64.msi" } }
        [pscustomobject]@{ tag_name = $Tag; prerelease = [bool]$Prerelease; draft = [bool]$Draft; assets = $assets }
    }
}

Describe 'Select-MsiRelease' {
    It 'skips a newer release that has no MSI and picks the newest one that has' {
        $releases = @(
            (New-Release 'v7.7.0')
            (New-Release 'v7.6.10' -Msi)
            (New-Release 'v7.6.9'  -Msi)
        )
        (Select-MsiRelease $releases).tag_name | Should -Be 'v7.6.10'
    }

    It 'compares versions as numbers, whatever the order of the list' {
        $releases = @(
            (New-Release 'v7.6.9'  -Msi)
            (New-Release 'v7.4.22' -Msi)
            (New-Release 'v7.6.10' -Msi)
        )
        (Select-MsiRelease $releases).tag_name | Should -Be 'v7.6.10'
    }

    It 'ignores prerelease and draft releases even when they have an MSI' {
        $releases = @(
            (New-Release 'v7.8.0-preview.1' -Msi -Prerelease)
            (New-Release 'v7.7.1' -Msi -Draft)
            (New-Release 'v7.6.10' -Msi)
        )
        (Select-MsiRelease $releases).tag_name | Should -Be 'v7.6.10'
    }

    It 'returns nothing when no stable release has an MSI' {
        $releases = @(
            (New-Release 'v7.7.0')
            (New-Release 'v7.8.0-preview.1' -Msi -Prerelease)
        )
        Select-MsiRelease $releases | Should -BeNullOrEmpty
    }
}
