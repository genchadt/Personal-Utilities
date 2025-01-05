#region Assertions
function Assert-Chocolatey {
<#
.SYNOPSIS
    Assert-Chocolatey - Ensures Chocolatey is installed on the system.

.DESCRIPTION
    Checks if Chocolatey is available as a command. If it is not installed, this function installs Chocolatey using an online script.
    Elevates permissions and sets the necessary execution policy.

.LINK
    https://github.com/chocolatey/choco
    https://chocolatey.org
#>
    [CmdletBinding()]
    param ()

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey is not installed. Installing Chocolatey..." -ForegroundColor Yellow
        Write-Debug "Granting elevation permissions."
        Grant-Elevation
        Write-Debug "Setting execution policy to Bypass for the current process."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Debug "Downloading Chocolatey installation script."
        try {
            $installScript = Invoke-WebRequest -Uri 'https://chocolatey.org/install.ps1' -UseBasicParsing -Verbose:$false -Debug:$false
            Write-Debug "Executing Chocolatey installation script."
            Invoke-Expression $installScript.Content
            Write-Host "Chocolatey has been successfully installed." -ForegroundColor Green
            Write-Warning "Please restart your shell and rerun the script to continue."
            return $false
        } catch {
            throw "Failed to install Chocolatey: $_"
        }
    }
    else {
        Write-Host "Chocolatey is already installed." -ForegroundColor Green
        return $true
    }

    Write-Verbose "Completed Assert-Chocolatey function."
}

function Assert-Scoop {
<#
.SYNOPSIS
    Assert-Scoop - Ensures Scoop is installed on the system.

.DESCRIPTION
    Checks if Scoop is available as a command. If it is not installed, this function installs Scoop using an online script.
    Elevates permissions and sets the necessary execution policy.

.LINK
    https://github.com/lukesampson/scoop
    https://scoop.sh
#>
    [CmdletBinding()]
    param ()

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Scoop is not installed. Installing Scoop..." -ForegroundColor Yellow
        Write-Debug "Granting elevation permissions."
        Grant-Elevation
        Write-Debug "Setting execution policy to RemoteSigned for CurrentUser."
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Debug "Downloading Scoop installation script."
        try {
            $installScript = Invoke-WebRequest -Uri 'https://get.scoop.sh' -UseBasicParsing -Verbose:$false -Debug:$false
            Write-Debug "Executing Scoop installation script."
            Invoke-Expression $installScript.Content
            Write-Host "Scoop has been successfully installed." -ForegroundColor Green
            return $true
        } catch {
            throw "Failed to install Scoop: $_"
        }
    }
    else {
        Write-Host "Scoop is already installed." -ForegroundColor Green
        return $true
    }
}

function Assert-Winget {
<#
.SYNOPSIS
    Assert-Winget - Ensures Winget is installed and up to date.

.DESCRIPTION
    Checks if Winget is available as a command. If it is not installed, prompts the user to install it.
    Verifies if the current version of Winget is up to date.
    More or less unneeded now since Winget is now installed by default in Windows 10+

.LINK
    https://github.com/microsoft/winget-cli
    https://apps.microsoft.com/detail/9nblggh4nns1
#>
    [CmdletBinding()]
    param()
    
    Write-Debug "Starting Assert-Winget function"
    
    # Check if winget exists
    try {
        $wingetPath = Get-Command winget -ErrorAction Stop
        Write-Host "Winget is installed at $($wingetPath.Source)."
    } catch {
        Write-Error "Winget not found. Please install App Installer from the Microsoft Store."
        return $false
    }
    
    try {
        # Get current version
        $currentVersion = $null
        $versionOutput = winget --version 2>&1
        if ($versionOutput -match '(\d+\.\d+\.\d+)') {
            $currentVersion = $matches[1]
            Write-Debug "Current winget version: $currentVersion"
        }
        
        # Get latest version
        $latestVersion = $null
        $storeOutput = winget search Microsoft.DesktopAppInstaller --exact
        if ($storeOutput -match 'Windows Package Manager\s+(\d+\.\d+\.\d+)') {
            $latestVersion = $matches[1]
            Write-Debug "Latest winget version: $latestVersion"
        }
        
        # Compare versions
        if ($currentVersion -and $latestVersion) {
            if ([version]$latestVersion -gt [version]$currentVersion) {
                Write-Host "A newer version of Winget is available: $latestVersion"
                $response = Read-Host "Do you want to update Winget? [Y(es)/n(o)]"
                if ($response -match '^y') {
                    winget upgrade Microsoft.DesktopAppInstaller
                }
            }
        } else {
            Write-Warning "Could not determine winget versions for comparison"
        }
        
        return $true
        
    } catch {
        Write-Warning "Error checking winget version: $_"
        return $true # Continue since winget exists
    } finally {
        Write-Debug "Completed Assert-Winget function"
    }
}
#endregion

#region Installers
function Install-ScoopPackages {
<#
.SYNOPSIS
    Install-ScoopPackages - Installs packages via Scoop and adds necessary buckets.

.DESCRIPTION
    Installs specified applications using Scoop and adds any required Scoop buckets.
    Optionally forces an update to any existing Scoop applications.

.PARAMETER ScoopApps
    An array of applications to be installed via Scoop.

.PARAMETER ScoopBuckets
    An array of Scoop buckets required by the applications.

.PARAMETER Force
    If specified, forces an update for each existing Scoop application.

.EXAMPLE
    Install-ScoopPackages -ScoopApps $scoopApps -ScoopBuckets $scoopBuckets -Force -Verbose
    # Installs specified applications with necessary buckets via Scoop, forcing updates, with verbose output.

.LINK
    https://github.com/lukesampson/scoop
    https://scoop.sh
#>
    [CmdletBinding()]
    param (
        [Alias("apps")]
        [Parameter(Mandatory=$true)]
        [array]$ScoopApps,

        [Alias("buckets")]
        [array]$ScoopBuckets,

        [Alias("f")]
        [switch]$Force
    )

    Write-Verbose "Starting Install-ScoopPackages function."

    if ($ScoopBuckets) {
        foreach ($bucket in $ScoopBuckets) {
            Write-Host "Adding Scoop bucket: $bucket" -ForegroundColor Yellow
            try {
                scoop bucket add $bucket
                Write-Host "Successfully added Scoop bucket: $bucket" -ForegroundColor Green
                Write-Verbose "Successfully added Scoop bucket: $bucket."
            } catch {
                throw "Failed to add Scoop bucket: $($bucket): $_"
            }
        }
    }

    foreach ($app in $ScoopApps) {
        $appId = $app.id
        $bucket = $app.managers.scoop.bucket
        $installArgs = $app.'install-args'

        $scoopCommand = if ($bucket) {
            "scoop install $bucket/$appId"
        } else {
            "scoop install $appId"
        }

        if ($installArgs) {
            $scoopCommand += " $installArgs"
        }

        if ($Force) {
            $scoopCommand = "scoop update $appId; $scoopCommand"
        }

        Write-Verbose "Preparing to install Scoop application: $appId"
        Write-Host "Installing (Scoop): $appId" -ForegroundColor Cyan
        Write-Debug "Executing command: $scoopCommand"
        try {
            Invoke-Expression $scoopCommand
            Write-Host "Successfully installed (Scoop): $appId" -ForegroundColor Green
            Write-Verbose "Successfully installed Scoop application: $appId."
        } catch {
            throw "Failed to install (Scoop): $($appId): $_"
        }
    }

    Write-Verbose "Completed Install-ScoopPackages function."
}

function Install-WingetPackages {
<#
.SYNOPSIS
    Install-WingetPackages - Installs packages via Winget.

.DESCRIPTION
    Installs specified applications using Winget, optionally forcing an update to existing applications.

.PARAMETER WingetApps
    An array of applications to be installed via Winget.

.PARAMETER Force
    If specified, forces an update for each existing Winget application.

.EXAMPLE
    Install-WingetPackages -WingetApps $wingetApps -Force -Verbose
    # Installs specified applications via Winget, forcing updates, with verbose output.

.LINK
    https://github.com/microsoft/winget-cli
#>
    [CmdletBinding()]
    param (
        [Alias("apps")]
        [Parameter(Mandatory = $true)]
        [array]$WingetApps,

        [Alias("f")]
        [switch]$Force
    )

    Write-Verbose "Starting Install-WingetPackages function."

    foreach ($app in $WingetApps) {
        $appId = $app.id
        $installArgs = $app.'install-args'
        $wingetCommand = "winget install --id $appId --exact --silent"

        if ($installArgs) {
            $wingetCommand += " $installArgs"
        }

        if ($Force) {
            $wingetCommand += " --force"
        }

        Write-Verbose "Preparing to install Winget application: $appId"
        Write-Host "Installing (Winget): $appId" -ForegroundColor Cyan
        Write-Debug "Executing command: $wingetCommand"
        try {
            Invoke-Expression $wingetCommand
            Write-Host "Successfully installed (Winget): $appId" -ForegroundColor Green
            Write-Verbose "Successfully installed Winget application: $appId."
        } catch {
            throw "Failed to install (Winget): $($appId): $_"
        }
    }

    Write-Verbose "Completed Install-WingetPackages function."
}


function Install-ChocolateyPackages {
<#
.SYNOPSIS
    Install-ChocolateyPackages - Installs packages via Chocolatey.

.DESCRIPTION
    Installs specified applications using Chocolatey, optionally forcing an update to existing applications.

.PARAMETER ChocoApps
    An array of applications to be installed via Chocolatey.

.PARAMETER Force
    If specified, forces an update for each existing Chocolatey application.

.EXAMPLE
    Install-ChocolateyPackages -ChocoApps $chocoApps -Force -Verbose
    # Installs specified applications via Chocolatey, forcing updates, with verbose output.

.LINK
    https://chocolatey.org
#>
    [CmdletBinding()]
    param (
        [Alias("apps")]
        [Parameter(Mandatory = $true)]
        [array]$ChocoApps,

        [Alias("f")]
        [switch]$Force
    )

    Write-Verbose "Starting Install-ChocolateyPackages function."

    foreach ($app in $ChocoApps) {
        $appId = $app.id
        $installArgs = $app.'install-args'
        $chocoCommand = "choco install $appId -y"

        if ($installArgs) {
            $chocoCommand += " $installArgs"
        }

        if ($Force) {
            $chocoCommand += " --force"
        }

        Write-Verbose "Preparing to install Chocolatey application: $appId"
        Write-Host "Installing (Chocolatey): $appId" -ForegroundColor Cyan
        Write-Debug "Executing command: $chocoCommand"
        try {
            Invoke-Expression $chocoCommand
            Write-Host "Successfully installed (Chocolatey): $appId" -ForegroundColor Green
            Write-Verbose "Successfully installed Chocolatey application: $appId."
        } catch {
            Write-Warning "Failed to install (Chocolatey) '$appId': $_"
            Write-Debug "Error details while installing '$appId': $_"
        }
    }

    Write-Verbose "Completed Install-ChocolateyPackages function."
}
#endregion

#region YAML Loader
function Import-YamlPackageConfig {
    <#
    .SYNOPSIS
        Loads YAML package configuration.
    
    .DESCRIPTION
        Parses the YAML configuration file and returns the package configuration.
    
    .PARAMETER ConfigurationFilePath
        The path to the YAML configuration file.
    #>
        [CmdletBinding()]
        param (
            [Parameter(Position = 0)]
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
#endregion

Export-ModuleMember -Function `
    Assert-Chocolatey, `
    Assert-Scoop, `
    Assert-Winget, `
    Install-ScoopPackages, `
    Install-WingetPackages, `
    Install-ChocolateyPackages, `
    Import-YamlPackageConfig
