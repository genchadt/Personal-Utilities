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
# Parameters
#############################################################################

param (
    [ValidateSet("Start", "AfterShellRestart", "AfterExplorerRestart")]
    [string]$State = "Start"
)

#############################################################################
# Functions
#############################################################################

function Grant-Elevation {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "This script needs to be run as Administrator."
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -ArgumentList `"-State $State`"" -Verb RunAs
        exit
    }
}

function Update-PowerShell {
    Write-Host "Checking for PowerShell updates..."
    $currentVersion = $PSVersionTable.PSVersion
    $updateRequired = $false
    try {
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestVersion = [Version]($latestRelease.tag_name.TrimStart('v'))
        if ($currentVersion -lt $latestVersion) {
            Write-Host "Updating PowerShell to version $latestVersion..."
            $installer = $latestRelease.assets | Where-Object { $_.name -like "*win-x64.msi" } | Select-Object -First 1
            $installerPath = "$env:TEMP\$($installer.name)"
            Invoke-WebRequest -Uri $installer.browser_download_url -OutFile $installerPath
            Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /qn" -Wait
            Write-Host "PowerShell updated to version $latestVersion."
            $updateRequired = $true
        } else {
            Write-Host "PowerShell is up to date."
        }
    } catch {
        Write-Warning "Failed to check or update PowerShell: $_"
    }
    return $updateRequired
}

function Update-Winget {
    Write-Host "Checking for winget updates..."
    $updateRequired = $false
    try {
        $wingetPath = (Get-Command winget.exe -ErrorAction SilentlyContinue).Source
        if (-not $wingetPath) {
            Write-Host "winget not found. Installing winget..."
            # Install winget via App Installer from Microsoft Store
            winget install --id Microsoft.DesktopAppInstaller -e --source msstore
            $updateRequired = $true
        } else {
            winget upgrade --id Microsoft.DesktopAppInstaller -e --source msstore
            Write-Host "winget is up to date."
        }
    } catch {
        Write-Warning "Failed to check or update winget: $_"
    }
    return $updateRequired
}

function Request-ShellRestart {
    Write-Host "Some updates (PowerShell or winget) may require a shell restart."
    $response = Read-Host "Do you want to restart the shell (PowerShell/Command Prompt) now? (Y/N)"
    if ($response -match '^[Yy]$') {
        try {
            Write-Host "Restarting shell..."
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -ArgumentList `"-State AfterShellRestart`"" -Verb RunAs
            exit
        } catch {
            Write-Warning "Failed to restart the shell: $_"
        }
    } else {
        Set-Variable -Name State -Value "AfterShellRestart" -Scope Global
    }
}

function Restore-ClassicContextMenu {
    Write-Host "Restoring classic right-click context menu..."
    try {
        New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InProcServer32" -Force | Out-Null
        Set-ItemProperty -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InProcServer32" -Name "" -Value "" -Force
        Write-Host "Classic context menu restored."
    } catch {
        Write-Warning "Failed to restore classic context menu: $_"
    }
}

function Enable-DetailedStatusMessages {
    Write-Host "Enabling detailed status messages..."
    try {
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        New-Item -Path $registryPath -Force | Out-Null
        Set-ItemProperty -Path $registryPath -Name "VerboseStatus" -Value 1 -Force
        Write-Host "Detailed status messages enabled."
    } catch {
        Write-Warning "Failed to enable detailed status messages: $_"
    }
}

function Add-ScriptsFolderToPath {
    Write-Host "Adding scripts folder to PATH..."
    try {
        $scriptsPath = Join-Path $PSScriptRoot "scripts"
        $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if (-not $currentUserPath.Split(';') -contains $scriptsPath) {
            $newPath = "$currentUserPath;$scriptsPath"
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            Write-Host "Scripts folder added to PATH."
        } else {
            Write-Host "Scripts folder is already in PATH."
        }
    } catch {
        Write-Warning "Failed to add scripts folder to PATH: $_"
    }
}

function Invoke-InstallPackagesWinget {
    Write-Host "Installing packages via winget..."
    $scriptPath = Join-Path $PSScriptRoot "scripts\Install-Packages-Winget.ps1"
    $packagesFile = Join-Path $PSScriptRoot "scripts\config\packages_winget.txt"
    if (Test-Path $scriptPath) {
        try {
            & $scriptPath -packagesFile $packagesFile
        } catch {
            Write-Warning "Failed to run Install-Packages-Winget.ps1: $_"
        }
    } else {
        Write-Warning "Install-Packages-Winget.ps1 not found at $scriptPath"
    }
}

function Request-RestartExplorer {
    Write-Host "Package installation complete."
    $response = Read-Host "Do you want to restart Explorer.exe to apply changes now? (Y/N)"
    if ($response -match '^[Yy]$') {
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
}

#############################################################################
# Main Execution
#############################################################################

function Setup {
    Grant-Elevation

    switch ($State) {
        "Start" {
            $powerShellUpdated = Update-PowerShell
            $wingetUpdated = Update-Winget

            if ($powerShellUpdated -or $wingetUpdated) {
                Request-ShellRestart
                return
            } else {
                Set-Variable -Name State -Value "AfterShellRestart" -Scope Global
            }
        }

        "AfterShellRestart" {
            Restore-ClassicContextMenu
            Enable-DetailedStatusMessages
            Add-ScriptsFolderToPath
            Invoke-InstallPackagesWinget
            Request-RestartExplorer
        }

        default {
            Write-Warning "Invalid state: $State"
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Setup
}
