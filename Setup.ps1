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
# !     Define required programs and their friendly names below     !
# Example: @{ Name = "binary.exe"; FriendlyName = "Binary Name" }
############################################################################

$programs = @(
    @{ Name = "pwsh.exe"; FriendlyName = "PowerShell" }
)

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
)

#############################################################################
# !     DO NOT EDIT BELOW THIS LINE     !
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

function Test-ProgramInstalled {
    param (
        [string]$programName,
        [string]$friendlyName
    )
    $path = (Get-Command $programName -ErrorAction SilentlyContinue)
    if (-not $path) {
        Write-Host "$friendlyName is not installed or not in the PATH. Please install $friendlyName and ensure it's added to the PATH.`n
        Package Name: $programName"
        exit 1
    }
}

function Setup {
    Request-Elevation -scriptPath $MyInvocation.MyCommand.Path

    # Check for required programs
    foreach ($program in $programs) {
        Test-ProgramInstalled -programName $program.Name -friendlyName $program.FriendlyName
    }

    foreach ($script in $scripts) {
        Invoke-Script -ScriptName $script.Name -Argument $script.Argument
    }
}

if ($MyInvocation.InvocationName -ne ".") { Setup }