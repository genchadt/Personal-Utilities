<#
.SYNOPSIS
    Setup.ps1 - Quick setup script.

.DESCRIPTION
    Quick and dirty setup script for all my stuff.

.NOTES
    Script Version: 1.0.1
    Author: Chad
    Creation Date: 2024-01-29 04:30:00 GMT
#>

############################################################################
# !     Define scripts and their arguments below    !
# Example: @{ Name = "Install-Packages-Winget.ps1"; Argument = ".\scripts\config\packages_winget.txt" }
############################################################################

$scripts = @(
    @{ Name = ".\scripts\Add-Paths.ps1" }
    @{ Name = ".\scripts\Install-Chocolatey-PacMan.ps1" }
    @{ Name = ".\scripts\Install-Packages-Winget.ps1"; Argument = ".\scripts\config\packages_winget.txt" }
    @{ Name = ".\scripts\Install-Packages-Chocolatey.ps1"; Argument = ".\scripts\config\packages_choco.txt" }
    @{ Name = "Install-Module 7Zip4PowerShell" }
    @{ Name = "Install-Script winfetch" }
)

#############################################################################
# Imports
#############################################################################

Import-Module "$PSScriptRoot\scripts\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\scripts\lib\TextHandling.psm1"
Import-Module "$PSScriptRoot\scripts\lib\SysOperation.psm1"
. "$PSScriptRoot\scripts\Add-Paths.ps1"

#############################################################################
# Functions
#############################################################################

function Invoke-Script {
    param (
        [string]$scriptName,
        [string]$arguments
    )

    try {
        if ($Argument) {
            .\$scriptName $arguments
        } else {
            .\$scriptName
        }
        Write-Host "$scriptName executed successfully."
    } catch {
        Write-Host "An error occurred: $_"
        Add-Content -Path "errorLog.txt" -Value ("[" + (Get-Date) + "] Error: $_")
        exit 1
    }
}

function Request-Elevation {
    param (
        [string]$scriptPath
    )

    # Check if running with administrative privileges
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Requesting elevation..."
        
        # Prompt user for elevation using Start-Process with -Verb RunAs
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File $scriptPath" -Verb RunAs
        exit
    }
}

#############################################################################
# Main
#############################################################################

function Setup {
    # Check for elevation
    Request-Elevation -scriptPath $MyInvocation.MyCommand.Path

    # Add all relevant paths to system PATH variable
    Add-Paths

    # Install Package Manager (Chocolatey)
    Invoke-Command ".\scripts\Install-Chocolatey-PacMan.ps1"

    # Install Packages (Chocolatey and Winget)
    Invoke-Command ".\scripts\Install-Packages-Chocolatey.ps1"
    Invoke-Command ".\scripts\Install-Packages-Winget.ps1"

    if ($scripts) {
        foreach ($script in $scripts) {
            Invoke-Script -ScriptName $script.Name -Argument $script.Argument
        }
    } else {
        Write-Console "No scripts to execute."
    }
}

if ($MyInvocation.InvocationName -ne ".") { Setup }