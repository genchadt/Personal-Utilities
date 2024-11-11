param (
    [string]$SpicetifyInstallerPath
)

Import-Module "$PSScriptRoot/lib/Helpers.psm1"

function Update-Spicetify {
    [CmdletBinding()]
    param (
        [Alias("path")]
        [Parameter(Position=0)]
        [string]$SpicetifyInstallerPath = "https://raw.githubusercontent.com/spicetify/cli/main/install.ps1"
    )

    try {
        Write-Verbose "Update-Spicetify: Launching Spicetify installer..."
        Grant-Elevation
        Invoke-WebRequest -useb $SpicetifyInstallerPath | Invoke-Expression
        Write-Verbose "Update-Spicetify: Successfully launched Spicetify installer."
    }
    catch {
        Write-Error "Update-Spicetify: Failed to launch Spicetify installer: $_"
    }
}
Update-Spicetify @PSBoundParameters