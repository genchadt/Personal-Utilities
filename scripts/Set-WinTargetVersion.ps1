[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("23H2", "24H2")]
    [string]$TargetVersion
)

function Set-WinTargetVersion {
<#
.SYNOPSIS
    Set-WinTargetVersion - Locks the target version for Windows 11 updates.

.DESCRIPTION
    This script sets the target version for Windows 11 updates using registry keys.
    It requires administrative privileges to modify the registry.

.PARAMETER TargetVersion
    The target version to set. Valid values are "23H2" or "24H2".

.EXAMPLE
    Set-WinTargetVersion -TargetVersion "23H2"
    This command locks the target version to 23H2.
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$TargetVersion
    )

    $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $registrySettings = @{
        'ProductVersion' = @{
            Type = 'String'
            Value = 'Windows 11'
        }
        'TargetReleaseVersion' = @{
            Type = 'DWord'
            Value = 1
        }
        'TargetReleaseVersionInfo' = @{
            Type = 'String'
            Value = $TargetVersion
        }
    }

    try {
        # Test for admin rights
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
        if (-not $isAdmin) {
            throw "This script requires administrator privileges"
        }

        # Create registry path if it doesn't exist
        if (-not (Test-Path $registryPath)) {
            if ($PSCmdlet.ShouldProcess($registryPath, "Create registry key")) {
                New-Item -Path $registryPath -Force | Out-Null
            }
        }

        # Set registry values
        foreach ($setting in $registrySettings.GetEnumerator()) {
            if ($PSCmdlet.ShouldProcess("$registryPath\$($setting.Key)", "Set $($setting.Value.Value)")) {
                Set-ItemProperty -Path $registryPath -Name $setting.Key -Value $setting.Value.Value -Type $setting.Value.Type -Force
            }
        }

        Write-Host "Successfully set Windows 11 target version to $TargetVersion" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to set target version: $_"
        exit 1
    }
}

Set-WinTargetVersion @PSBoundParameters