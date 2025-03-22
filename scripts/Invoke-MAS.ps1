[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [Alias("path")]
    [string]$MASInstallerPath
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
        [Parameter(Position = 0)]
        [Alias("path")]
        [string]$MASInstallerPath = "https://get.activated.win"
    )
    Write-Verbose "Invoke-MAS: Launching MAS installer..."
    try {
        Grant-Elevation
        Invoke-RestMethod $MASInstallerPath | Invoke-Expression
        Write-Verbose "Invoke-MAS: Successfully launched MAS installer."
    } catch [System.Net.WebException] {
        Write-Error "Invoke-MAS: Failed due to network error: $_"
    } catch {
        Write-Error "Invoke-MAS: Failed to launch MAS installer: $_"
    }
}
Invoke-MAS @PSBoundParameters
