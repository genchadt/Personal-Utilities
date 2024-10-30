function Update-TerminalSettings {
    param (
        [Alias("Path")]
        [string]$SettingsSourcePath = "$PSScriptRoot\config\terminal\settings.json",
        [string]$TargetPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    )
    if (Test-Path $SettingsSourcePath) {
        try {
            Copy-Item -Path $SettingsSourcePath -Destination $TargetPath -Force
            Write-Host "Terminal settings updated successfully."
        }
        catch {
            Write-Host "Update-TerminalSettings: Failed to update terminal settings: $_"
        }
    }
}