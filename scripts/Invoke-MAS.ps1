param (
    [string]$MASInstallerPath = "https://get.activated.win"
)

Import-Module "$PSScriptRoot/lib/Helpers.psm1"

function Invoke-MAS {
    Write-Verbose "Invoke-MAS: Launching MAS installer..."
    try {
        Get-Elevation
        Invoke-RestMethod https://get.activated.win | Invoke-Expression
        Write-Verbose "Invoke-MAS: Successfully launched MAS installer."
    } catch {
        Write-Warning "Invoke-MAS: Failed to invoke MAS: $_"
    }
}
Invoke-MAS `
    -MASInstallerPath $MASInstallerPath `
    -Verbose:$Verbose.IsPresent