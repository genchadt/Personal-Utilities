<#
.SYNOPSIS
    Ensures Chocolatey is installed on the system.

.DESCRIPTION
    Checks if Chocolatey is available as a command. If it is not installed, this function installs Chocolatey using an online script.
    Elevates permissions and sets the necessary execution policy.

.EXAMPLE
    Assert-Chocolatey -Verbose
    # Ensures Chocolatey is installed; installs it if missing, with verbose output.

.LINK
    https://github.com/chocolatey/choco
    https://chocolatey.org
#>
function Assert-Chocolatey {
    [CmdletBinding()]
    param ()

    Write-Verbose "Starting Assert-Chocolatey function."

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Verbose "Chocolatey not found on the system."
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
            Write-Verbose "Chocolatey installation completed successfully."
        } catch {
            Write-Warning "Failed to install Chocolatey: $_"
            Write-Debug "Error details: $_"
        }
    }
    else {
        Write-Host "Chocolatey is already installed." -ForegroundColor Green
        Write-Verbose "Chocolatey is present on the system. No action needed."
    }

    Write-Verbose "Completed Assert-Chocolatey function."
}

<#
.SYNOPSIS
    Ensures Scoop is installed on the system.

.DESCRIPTION
    Checks if Scoop is available as a command. If it is not installed, this function installs Scoop using an online script.
    Elevates permissions and sets the necessary execution policy.

.EXAMPLE
    Assert-Scoop -Verbose
    # Ensures Scoop is installed; installs it if missing, with verbose output.

.LINK
    https://github.com/lukesampson/scoop
    https://scoop.sh
#>
function Assert-Scoop {
    [CmdletBinding()]
    param ()

    Write-Verbose "Starting Assert-Scoop function."

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Verbose "Scoop not found on the system."
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
            Write-Verbose "Scoop installation completed successfully."
        } catch {
            Write-Warning "Failed to install Scoop: $_"
            Write-Debug "Error details: $_"
        }
    }
    else {
        Write-Host "Scoop is already installed." -ForegroundColor Green
        Write-Verbose "Scoop is present on the system. No action needed."
    }

    Write-Verbose "Completed Assert-Scoop function."
}

<#
.SYNOPSIS
    Ensures Winget is installed and up to date.

.DESCRIPTION
    Checks if Winget is available as a command. If it is not installed, prompts the user to install it.
    Verifies if the current version of Winget is up to date.

.EXAMPLE
    Assert-Winget -Verbose
    # Checks for Winget and verifies its installation and version, with verbose output.

.LINK
    https://github.com/microsoft/winget-cli
    https://apps.microsoft.com/detail/9nblggh4nns1
#>
function Assert-Winget {
    [CmdletBinding()]
    param ()

    Write-Verbose "Starting Assert-Winget function."

    $wingetPath = (Get-Command winget.exe -ErrorAction SilentlyContinue).Path
    if (-not $wingetPath) {
        Write-Warning "Winget is not installed."
        Write-Verbose "Winget executable not found in system PATH."
        Write-Warning "Please install it from https://github.com/microsoft/winget-cli/releases"
        Write-Debug "Winget installation link provided to the user."
        return $false
    }
    else {
        Write-Host "Winget is installed at $wingetPath." -ForegroundColor Green
        Write-Verbose "Winget executable found at $wingetPath."
        # Optionally, add logic to check for updates
        return $true
    }

    Write-Verbose "Completed Assert-Winget function."
}

<#
.SYNOPSIS
    Installs packages via Scoop and adds necessary buckets.

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
function Install-ScoopPackages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$ScoopApps,

        [Parameter(Mandatory = $false)]
        [array]$ScoopBuckets,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    Write-Verbose "Starting Install-ScoopPackages function."

    if ($ScoopBuckets) {
        foreach ($bucket in $ScoopBuckets) {
            Write-Verbose "Adding Scoop bucket: $bucket"
            Write-Host "Adding Scoop bucket: $bucket" -ForegroundColor Yellow
            try {
                Write-Debug "Executing 'scoop bucket add $bucket'."
                scoop bucket add $bucket
                Write-Host "Successfully added Scoop bucket: $bucket" -ForegroundColor Green
                Write-Verbose "Successfully added Scoop bucket: $bucket."
            } catch {
                Write-Warning "Failed to add Scoop bucket '$bucket': $_"
                Write-Debug "Error details while adding bucket '$bucket': $_"
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
            Write-Warning "Failed to install (Scoop) '$appId': $_"
            Write-Debug "Error details while installing '$appId': $_"
        }
    }

    Write-Verbose "Completed Install-ScoopPackages function."
}

<#
.SYNOPSIS
    Installs packages via Winget.

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
function Install-WingetPackages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$WingetApps,

        [Parameter(Mandatory = $false)]
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
            Write-Warning "Failed to install (Winget) '$appId': $_"
            Write-Debug "Error details while installing '$appId': $_"
        }
    }

    Write-Verbose "Completed Install-WingetPackages function."
}

<#
.SYNOPSIS
    Installs packages via Chocolatey.

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
function Install-ChocolateyPackages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$ChocoApps,

        [Parameter(Mandatory = $false)]
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

Export-ModuleMember -Function `
    Assert-Chocolatey, `
    Assert-Scoop, `
    Assert-Winget, `
    Install-ScoopPackages, `
    Install-WingetPackages, `
    Install-ChocolateyPackages
