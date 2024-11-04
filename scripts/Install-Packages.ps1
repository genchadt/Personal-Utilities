<#
.SYNOPSIS
    Install-Packages.ps1 - Installs selected packages using winget, scoop, and chocolatey.

.DESCRIPTION
    Reads a list of packages from a YAML configuration file, prompts the user to select the installation type (Limited, Standard, Full, Optional Only), displays a custom GUI for package selection with all relevant items pre-selected, and installs them using winget, scoop, and chocolatey.
#>

[CmdletBinding()]
param (
    [Parameter(Position=0)]
    [string]$ConfigurationFilePath = "$PSScriptRoot\config\packages\packages.yaml",

    [Alias("f")]
    [switch]$Force
)

# Load Helpers Modules
Import-Module "$PSScriptRoot\lib\gui.psm1"
Import-Module "$PSScriptRoot\lib\helpers.psm1"
Import-Module "$PSScriptRoot\lib\packages.psm1"

<#
.SYNOPSIS
    Assert-Winget - Checks if winget is installed and up to date.
#>
function Assert-Winget {
    [CmdletBinding()]
    param ()

    $wingetPath = (Get-Command winget.exe -ErrorAction SilentlyContinue).Path
    if (-not $wingetPath) {
        Write-Warning "winget is not installed."
        Write-Warning "Please install it from https://github.com/microsoft/winget-cli/releases"
        return $false
    }

    Write-Verbose "winget is installed and up to date."
    return $true
}

# Configuration Loading Function

<#
.SYNOPSIS
    Loads YAML package configuration.
#>
function Import-YamlPackageConfig {
    [CmdletBinding()]
    param (
        [string]$ConfigurationFilePath
    )

    if (-not (Test-Path $ConfigurationFilePath)) {
        Write-Error "Install-Packages: Configuration file '$ConfigurationFilePath' does not exist."
        return $null
    }

    try {
        $yamlContent = Get-Content -Path $ConfigurationFilePath -Raw
        $packageConfig = ConvertFrom-Yaml -Yaml $yamlContent
        return $packageConfig
    } catch {
        Write-Error "Install-Packages: Error parsing YAML file: $_"
        return $null
    }
}

# Package Installation Function

<#
.SYNOPSIS
    Installs the selected packages.
#>
function Start-PackageInstallation {
    [CmdletBinding()]
    param (
        [array]$packages,
        [switch]$Force
    )

    $wingetApps = @()
    $scoopApps = @()
    $scoopBuckets = @()
    $chocoApps = @()

    foreach ($package in $packages) {
        # Winget apps
        if ($package.managers.winget.available) {
            $wingetApps += $package
        }
        # Scoop apps and buckets
        if ($package.managers.scoop.available) {
            $scoopApps += $package
            if ($package.managers.scoop.bucket -and -not ($scoopBuckets -contains $package.managers.scoop.bucket)) {
                $scoopBuckets += $package.managers.scoop.bucket
            }
        }
        # Chocolatey apps
        if ($package.managers.chocolatey.available) {
            $chocoApps += $package
        }
    }

    # Ensure Scoop and Chocolatey are available so we can install their packages
    if ($scoopApps.Count -gt 0 -or $scoopBuckets.Count -gt 0) { 
        if (-not (Assert-Scoop)) {
            Write-Error "Start-PackageInstallation: Failed to ensure Scoop is available."
            return
        }
    }
    if ($chocoApps.Count -gt 0) { 
        if (-not (Assert-Chocolatey)) {
            Write-Error "Start-PackageInstallation: Failed to ensure Chocolatey is available."
            return
        }
    }

    Write-Verbose "Calling Install-ScoopPackages..."
    Install-ScoopPackages -scoopApps $scoopApps -scoopBuckets $scoopBuckets -Force:$Force

    Write-Verbose "Calling Install-WingetPackages..."
    Install-WingetPackages -wingetApps $wingetApps -Force:$Force

    Write-Verbose "Calling Install-ChocolateyPackages..."
    Install-ChocolateyPackages -chocoApps $chocoApps -Force:$Force

    Write-Host "All package installations are complete." -ForegroundColor Green
}

<#
.SYNOPSIS
    Install-Packages - Launches the package installer GUI and installs selected packages.
#>
function Install-Packages {
    [CmdletBinding()]
    param (
        [string]$ConfigurationFilePath,
        [switch]$Force
    )
    Write-Debug "Starting Install-Packages..."

    # Ensure winget is installed and up to date
    if (-not (Assert-Winget)) {
        Write-Error "Install-Packages: Failed to locate winget."
        return
    }

    # Attempt to load package configuration from YAML
    try {
        $packageConfig = Import-YamlPackageConfig -ConfigurationFilePath $ConfigurationFilePath
        if (-not $packageConfig) {
            Write-Error "Install-Packages: Package configuration is empty or invalid. Exiting."
            return
        }
    } catch {
        Write-Error "Install-Packages: An error occurred while loading the package configuration. $_"
        return
    }

    Write-Verbose "Calling Show-PackageSelectionWindow..."
    $selectedPackages = Show-PackageSelectionWindow -packages $packageConfig.packages

    if (-not $selectedPackages) {
        Write-Host "No packages selected. Exiting."
        return
    }

    Write-Verbose "Calling Start-PackageInstallation..."
    Start-PackageInstallation -packages $selectedPackages -Force:$Force
    Write-Host "Package installation complete." -ForegroundColor Green
}

$params = @{
    ConfigurationFilePath   = $ConfigurationFilePath
    Force                   = $Force
}
Install-Packages @params