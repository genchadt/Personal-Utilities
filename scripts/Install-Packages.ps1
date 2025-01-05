[CmdletBinding()]
param (
    [string]$ConfigurationFilePath,
    [switch]$Force
)

Import-Module "$PSScriptRoot\lib\gui.psm1"
Import-Module "$PSScriptRoot\lib\helpers.psm1"
Import-Module "$PSScriptRoot\lib\packages.psm1"

#region Combine Installations
function Start-PackageInstallation {
<#
.SYNOPSIS
    Installs the selected packages.
#>
    [CmdletBinding()]
    param (
        [array]$Packages,
        [switch]$Force
    )

    $wingetApps = @()
    $scoopApps = @()
    $scoopBuckets = @()
    $chocolateyApps = @()

    foreach ($package in $Packages) {
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
            $chocolateyApps += $package
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
    Install-ChocolateyPackages -chocoApps $chocolateyApps -Force:$Force

    Write-Host "All package installations are complete." -ForegroundColor Green
}
#endregion

#region Main
function Install-Packages {
<#
.SYNOPSIS
    Install-Packages - Launches the package installer GUI and installs selected packages.
#>
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [string]$ConfigurationFilePath = "$PSScriptRoot\config\packages\packages.yaml",

        [Alias("f")]
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
        Write-Debug "Loading package configuration from $ConfigurationFilePath"
        $packageConfig = Import-YamlPackageConfig $ConfigurationFilePath
        Write-Debug "Package configuration loaded: $packageConfig"
        if (-not $packageConfig) {
            Write-Error "Install-Packages: Package configuration is empty or invalid. Exiting."
            return
        }
    } catch {
        Write-Error "Install-Packages: An error occurred while loading the package configuration. $_"
        return
    }

    Write-Verbose "Calling Show-PackageSelectionWindow..."
    Write-Debug "Package configuration packages: $($packageConfig.packages)"
    $selectedPackages = Show-PackageSelectionWindow -packages $packageConfig.packages

    if (-not $selectedPackages) {
        Write-Host "No packages selected. Exiting."
        return
    }

    Write-Verbose "Calling Start-PackageInstallation..."
    Start-PackageInstallation -packages $selectedPackages -Force:$Force
    Write-Host "Package installation complete." -ForegroundColor Green
}
#endregion

Install-Packages @PSBoundParameters