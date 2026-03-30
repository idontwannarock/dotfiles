# Windows Terminal OSC 9;9 - 報告當前工作目錄，讓 duplicate pane 繼承目錄
# 必須在 Starship 初始化之前定義
function Invoke-Starship-PreCommand {
    $loc = $executionContext.SessionState.Path.CurrentLocation
    $esc = [char]27
    $bel = [char]7
    $dq = [char]34
    $host.ui.Write($esc + ']9;12' + $bel)
    if ($loc.Provider.Name -eq 'FileSystem') {
        $host.ui.Write($esc + ']9;9;' + $dq + $loc.ProviderPath + $dq + $bel)
    }
}

Invoke-Expression (&starship init powershell)
