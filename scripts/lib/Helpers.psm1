<#
.SYNOPSIS
    Checks if gsudo is installed and installs it if not.
#>
function Assert-Gsudo {
    [CmdletBinding()]
    param ()

    Write-Debug "Starting Assert-Gsudo..."
    if (Get-Command "gsudo" -ErrorAction SilentlyContinue) {
        Write-Verbose "gsudo is already installed."
        return $true
    } else {
        try {
            Write-Warning "gsudo is not installed."
            if (Read-Prompt -Message "Do you want to install gsudo?" -Prompt "YN" -Default "Y") {
                winget install -e --id=gerardog.gsudo
                Write-Host "gsudo installed."
                return $true
            } else {
                Write-Warning "gsudo installation was declined by the user."
                return $false
            }
        } catch {
            Write-Warning "Failed to install gsudo: $_"
            return $false
        }
    }
}

<#
.SYNOPSIS
    Grant-Elevation - Checks if gsudo is installed and elevates the script if not.
#>
function Grant-Elevation {
    [CmdletBinding()]
    param ()
    if (Get-Command "gsudo" -ErrorAction SilentlyContinue) {
        Write-Verbose "gsudo is installed."
        Write-Verbose "Attempting to elevate using gsudo..."
        try {
            & gsudo -n
        }
        catch {
            Write-Warning "Grant-Elevation: Failed to elevate using gsudo: $_"
        }
    } else {
        Write-Verbose "gsudo is not installed."
        Assert-Gsudo
    }
}

function Read-Prompt {
    param (
        [Parameter(Position=0)]
        [string]$Message,

        [Parameter(Position=1)]
        [string]$Prompt = "YN",  # Default prompt to "Y" and "N"

        [Parameter(Position=2)]
        [string]$Default = "Y"   # Default response to "Y"
    )

    # Validate that $Prompt contains only allowed characters: Y, N, A, D
    if ($Prompt -notmatch '^[YNAD]+$') {
        throw "Read-Prompt: Invalid Prompt value. It must contain only 'Y', 'N', 'A', or 'D' characters in any combination."
    }

    # Validate that $Default is a single character and one of the options in $Prompt
    if ($Default -notmatch '^[YNAD]$' -or $Prompt -notcontains $Default) {
        throw "Read-Prompt: Invalid Default value. It must be a single character: 'Y', 'N', 'A', or 'D', and must be included in Prompt."
    }

    # Define options based on $Prompt
    $options = @{}
    if ($Prompt -contains "Y") { $options["Y"] = "(y)es" }
    if ($Prompt -contains "N") { $options["N"] = "(n)o" }
    if ($Prompt -contains "A") { $options["A"] = "(a)ccept all" }
    if ($Prompt -contains "D") { $options["D"] = "(d)eny all" }

    # Construct prompt with default option capitalized
    $promptOptions = foreach ($key in $options.Keys) {
        if ($key -eq $Default) {
            $options[$key] = $options[$key].Replace("(", "(" + $key.ToUpper() + ")")
        }
        $options[$key]
    }

    $prompt = "$Message " + ($promptOptions -join "/") + ": "

    # Get user input
    $response = Read-Host $prompt

    # Use default response if input is blank
    if ([string]::IsNullOrWhiteSpace($response)) {
        $response = $Default
    }

    # Determine return values based on response
    switch -regex ($response.ToUpper()) {
        "^[Y]$" { return $true }
        "^[N]$" { return $false }
        "^[A]$" { return "AcceptAll" }
        "^[D]$" { return "DenyAll" }
        default  { 
            Write-Host "Invalid response. Please try again."
            return $null
        }
    }
}

<#
.SYNOPSIS
    Test-Module - Checks if a module is installed and installs it if not.

.DESCRIPTION
    Checks if the specified PowerShell module is installed. If it is not, it prompts the user to install it.
#>
function Test-Module {
    param (
        [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "$ModuleName module not found." -ForegroundColor Yellow
        if (Read-Prompt -Message "Do you want to install $ModuleName module?") {
            try {
                Install-Module -Name $ModuleName -Scope CurrentUser -Force
            }
            catch {
                Write-Error "Test-Module: Failed to install $ModuleName module: $_"
                exit
            }
        }
    }
    Import-Module $ModuleName -Force
}

<#
.SYNOPSIS
    Update-PowerShell - Checks if PowerShell is up to date and updates it if necessary.

.DESCRIPTION
    Checks if the current version of PowerShell is up to date. If it is not, it prompts the user to update it.

.LINK
    https://github.com/PowerShell/PowerShell
#>
function Update-PowerShell {
    Write-Host "Checking for PowerShell updates..."
    $currentVersion = $PSVersionTable.PSVersion
    try {
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestVersion = [Version]($latestRelease.tag_name.TrimStart('v'))

        if ($currentVersion -lt $latestVersion) {
            Write-Host "A newer version of PowerShell is available: $latestVersion"
            if (Read-Prompt -Message "Do you want to update PowerShell?" -Default "N") {
                $installer = $latestRelease.assets | Where-Object { $_.name -like "*win-x64.msi" } | Select-Object -First 1
                $installerPath = "$env:TEMP\$($installer.name)"
                Invoke-WebRequest -Uri $installer.browser_download_url -OutFile $installerPath
                Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /qn" -Wait
                Write-Host "PowerShell updated to version $latestVersion."
                return $true
            }
        } else {
            Write-Host "PowerShell is up to date."
        }
    } catch {
        Write-Warning "Failed to check or update PowerShell: $_"
    }
    return $false
}

Export-ModuleMember -Function `
    Grant-Elevation, `
    Update-PowerShell, `
    Assert-Winget, `
    Read-Prompt, `
    Test-Module
