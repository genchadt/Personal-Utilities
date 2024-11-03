param (
    [string]$SpicetifyInstallerPath = "https://raw.githubusercontent.com/spicetify/cli/main/install.ps1"
)

Import-Module "$PSScriptRoot/lib/Helpers.psm1"

function Update-Spicetify {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpicetifyInstallerPath
    )

    try {
        Get-Elevation
        Write-Verbose "Update-Spicetify: Launching Spicetify installer..."
        Invoke-WebRequest -useb $SpicetifyInstallerPath | Invoke-Expression
        Write-Verbose "Update-Spicetify: Successfully launched Spicetify installer."
    }
    catch {
        Write-Error "Update-Spicetify: Failed to launch Spicetify installer: $_"
    }
}
Update-Spicetify -SpicetifyInstallerPath $SpicetifyInstallerPath -Verbose:$Verbose.IsPresent