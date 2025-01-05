[CmdletBinding()]
param()

<#
.SYNOPSIS
    Setup.ps1 - Quick setup script.

.DESCRIPTION
    Quick and dirty setup script for all my stuff.

.NOTES
    Author: Chad
    Creation Date: 2024-01-29 04:30:00 GMT
#>

#############################################################################
# Imports
#############################################################################

Import-Module "$PSScriptRoot/scripts/lib/Helpers.psm1" -Force

#############################################################################
# Functions
#############################################################################

function Install-Office {
    Write-Debug "Install-Office: Starting C2R Office Installer..."
    $response = Read-Prompt -Message "Would you like to install Microsoft Office?" -Default "N"
    if ($response) {
        try {
            Write-Host "Opening download link for 'O365ProPlusRetail'..."
            Start-Process "https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=O365ProPlusRetail&platform=x64&language=en-us&version=O16GA"
        }
        catch {
            Write-Warning "Install-Office: Could not open webpage: $_"
            Write-Host "Visit https://gravesoft.dev/office_c2r_links to manually download Office."
        }
    }
}

function Restore-Activation {
    Write-Debug "Restore-Activation: Checking and restoring Microsoft product activation..."
    $response = Read-Prompt -Message "Would you like to check and restore Microsoft product activation?" -Default "N"
    Write-Host "Checking activation statuses..."
    if ($response) {
        try {
            $activationInfo = Get-CimInstance -ClassName SoftwareLicensingProduct | Where-Object { $_.PartialProductKey -and $_.LicenseStatus }
            $nonLicensedProducts = $activationInfo | Where-Object { $_.LicenseStatus -ne 1 }
    
            if ($nonLicensedProducts) {
                Write-Host "Some Microsoft products are not licensed."
                if (Read-Prompt -Message "Would you like to invoke MAS to restore activation?" -Default "N") {
                    Invoke-MAS
                }
            } else {
                Write-Host "All Microsoft products are licensed."
            }
        } catch {
            Write-Warning "Restore-Activation failed to check Activation Status: $_"
        }
    }
}

function Restore-ClassicContextMenu {
    Write-Debug "Restore-ClassicContextMenu: Starting..."
    Write-Host "Restoring classic right-click context menu..."
    try {
        $keyPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InProcServer32"
        if (-not (Test-Path $keyPath)) {
            New-Item -Path $keyPath -Force | Out-Null
        }
        Set-ItemProperty -Path $keyPath -Name "(Default)" -Value "" -Force
        Write-Host "Classic context menu restored."
    } catch {
        Write-Warning "Restore-ClassicContextMenu: Failed to restore classic context menu: $_"
    }
}

function Enable-DetailedStatusMessages {
<#
.SYNOPSIS
    Enable-DetailedStatusMessages - Enables detailed status messages during boot.

.DESCRIPTION
    This function enables detailed status messages during boot by setting the registry key
    `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\VerboseStatus` to `1`.

.NOTES
    This operation requires elevated privileges. Please run the script as Administrator.
#>
    Write-Host "Enabling detailed status messages..."
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "This operation requires elevated privileges. Please run the script as Administrator."
        return
    }
    
    try {
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }
        Set-ItemProperty -Path $registryPath -Name "VerboseStatus" -Value 1 -Force
        Write-Host "Detailed status messages enabled."
    } catch {
        Write-Warning "Enable-DetailedStatusMessages: Failed to enable detailed status messages: $_"
    }
}

function Add-ScriptsFolderToPath {
<#
.SYNOPSIS
    Add-ScriptsFolderToPath - Adds the scripts folder to the PATH environment variable.

.DESCRIPTION
    This function adds the scripts folder to the PATH environment variable for the current user.

.NOTES
    This operation requires elevated privileges. Please run the script as Administrator.
#>
    Write-Host "Adding scripts folder to PATH..."
    try {
        $scriptsPath = Join-Path $PSScriptRoot "scripts"
        $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if (-not ($currentUserPath.Split(';') -contains $scriptsPath)) {
            $newPath = "$currentUserPath;$scriptsPath"
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            Write-Host "Scripts folder added to PATH."
        } else {
            Write-Host "Scripts folder is already in PATH."
        }
    } catch {
        Write-Warning "Add-ScriptsFolderToPath: Failed to add scripts folder to PATH: $_"
    }
}

function Install-Packages {
    Write-Host "Installing packages via winget..."
    $scriptPath = Join-Path $PSScriptRoot "scripts\Install-Packages.ps1"
    $packagesFile = Join-Path $PSScriptRoot "scripts\config\packages.yaml"
    if (Test-Path $scriptPath) {
        try {
            & $scriptPath -configFile $packagesFile
        } catch {
            Write-Warning "Failed to run Install-Packages.ps1: $_"
        }
    } else {
        Write-Warning "Install-Packages.ps1 not found at $scriptPath"
    }
}

function Install-Extras {
    $package = winget list --id Spotify.Spotify 2>&1

    try {
        if ($package -like "*Spotify.Spotify*") {
            if (Read-Prompt -Message "Spotify.Spotify is installed. Would you like to install Spicetify?" -Default "Y") {
                ./scripts/Update-Spicetify.ps1
            }
        } else {
            Write-Host "Spotify installation was not found."
            Write-Host "Spicetify installation is not possible."
        }
    } catch {
        Write-Warning "Failed to install Spicetify: $_"
    }
}

function Request-RestartExplorer {
    Write-Host "Package installation complete."
    if (Read-Prompt -Message "Do you want to restart Explorer.exe to apply changes now?" -Default "Y") {
        try {
            Write-Host "Restarting Explorer.exe..."
            Stop-Process -Name explorer -Force
            Start-Process explorer.exe
            Write-Host "Explorer.exe restarted."
        } catch {
            Write-Warning "Failed to restart Explorer.exe: $_"
        }
    }

    Write-Host "It is recommended to restart your system to apply all changes."
    if (Read-Prompt -Message "Restart now?" -Default "N") {
        Restart-Computer
    }
}

#############################################################################
# Main Execution
#############################################################################

function Setup {
    [CmdletBinding()]
    param()

    begin {
        Write-Debug "Setup: Starting..."

        Start-Logging
    }

    process {
        Grant-Elevation
        Install-Office
        Restore-Activation

        $updatePerformed = $false

        Write-Host "Checking for updates..."

        if (Update-PowerShell) {
            $updatePerformed = $true
        }

        if (Assert-Winget) {
            $updatePerformed = $true
        }

        if ($updatePerformed) {
            Write-Host "Updates have been installed. Please restart your shell and rerun the script to continue."
            exit
        }

        # Proceed with the rest of the script
        Restore-ClassicContextMenu
        Enable-DetailedStatusMessages
        Add-ScriptsFolderToPath
        Install-Packages
        Install-Extras
        Request-RestartExplorer
    }

    end {
        Write-Debug "Setup: Finished."
        Stop-Logging
    }
}

Setup @PSBoundParameters
