<#
.SYNOPSIS
    Install-Packages-Winget.ps1 - Installs selected packages using winget.

.DESCRIPTION
    Reads a list of packages from a configuration file, allows the user to select which packages to install, and installs them using winget.

.NOTES
    Script Version: 1.0.4
    Author: Chad
    Creation Date: 2024-01-29 04:30:00 GMT
#>

###############################################
# Parameters
###############################################

param (
    [Parameter(Position=0, Mandatory=$false)]
    [string]$packagesFile = ".\config\packages_winget.txt",

    [Parameter(Position=1, Mandatory=$false)]
    [switch]$force
)

###############################################
# Functions
###############################################

function Install-Packages-Winget {
    param (
        [string]$packagesFile,
        [switch]$force
    )

    # Parameter validation
    if (-not (Test-Path $packagesFile)) {
        Write-Host "Error: The specified packages file '$packagesFile' does not exist." -ForegroundColor Red
        return
    }

    try {
        # Load packages from file, remove comments and empty lines
        $packages = Get-Content -Path $packagesFile | ForEach-Object {
            # Remove anything after the first '#' and trim whitespace
            ($_ -split '#')[0].Trim()
        } | Where-Object { $_ -ne '' }

        if (-not $packages) {
            Write-Host "Error: No packages found in the specified file." -ForegroundColor Red
            return
        }

        # Show package list in Out-GridView for user selection
        $selectedPackages = $packages | Out-GridView -Title "Select packages to install" -PassThru

        # If no packages selected, exit
        if (-not $selectedPackages) {
            Write-Host "No packages selected. Exiting."
            return
        }

        # Install selected packages sequentially
        foreach ($package in $selectedPackages) {
            $installCommand = "winget install $package -e -i"
            if ($force) {
                $installCommand += " --force"
            }

            try {
                Write-Host "Installing: $package" -ForegroundColor Cyan
                Invoke-Expression $installCommand
                Write-Host "Successfully installed: $package" -ForegroundColor Green
            } catch {
                Write-Host "Failed to install: $package" -ForegroundColor Red
            }
        }

        Write-Host "Winget packages installation complete." -ForegroundColor Green
    } catch {
        Write-Warning "An unexpected error occurred: $_"
    }    
}

###############################################
# Main Execution
###############################################

Install-Packages-Winget -packagesFile $packagesFile -force:$force
