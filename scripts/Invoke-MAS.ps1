[CmdletBinding()]
param (
    [Alias("path")]
    [Parameter(Position = 0)]
    [string]$MASInstallerPath = "https://get.activated.win"
)

Import-Module "$PSScriptRoot/lib/Helpers.psm1"

function Invoke-MAS {
<#
.SYNOPSIS
    Invoke-MAS - Invokes the Microsoft Activation Script (MAS) installer to solve activation issues.

.DESCRIPTION
    Invoke-MAS is a function that downloads and invokes the Microsoft Activation Script (MAS) installer to solve activation issues.

.PARAMETER MASInstallerPath
    The path to the MAS installer. Defaults to "https://get.activated.win".
#>
    [CmdletBinding()]
    param (
        [string]$MASInstallerPath
    )
    Write-Verbose "Invoke-MAS: Launching MAS installer..."
    try {
        Get-Elevation
        Invoke-RestMethod $MASInstallerPath | Invoke-Expression
        Write-Verbose "Invoke-MAS: Successfully launched MAS installer."
    } catch {
        Write-Warning "Invoke-MAS: Failed to invoke MAS: $_"
    }
}

$params = @{
    MASInstallerPath = $MASInstallerPath
    Debug            = $Debug
    Verbose          = $Verbose
}
Invoke-MAS @params