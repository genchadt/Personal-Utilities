# lib\helpers.psm1

function Grant-Elevation {
    [CmdletBinding()]
    param ()
    if (Get-Command "gsudo" -ErrorAction SilentlyContinue) {
        & gsudo
    } else {
        Install-Gsudo
    }
}

function Install-Gsudo {
    Update-Winget

    if (Get-Command "gsudo" -ErrorAction SilentlyContinue) {
        return
    } else {
        try {
            Write-Host "Installing gsudo..."
            winget install -e --id=gerardog.gsudo
            Write-Host "gsudo installed."
        } catch {
            Write-Warning "Failed to install gsudo: $_"
        }
    }
}

function Read-PromptYesNo {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [ValidateSet("Y", "N")]
        [string]$Default = "N"
    )

    $prompt = if ($Default -eq "Y") { "$Message (Y/n): " } else { "$Message (y/N): " }
    $defaultResponse = if ($Default -eq "Y") { "Y" } else { "N" }

    $response = Read-Host $prompt

    if ([string]::IsNullOrWhiteSpace($response)) {
        $response = $defaultResponse
    }

    return $response -match '^[Yy]$'
}

function Update-PowerShell {
    Write-Host "Checking for PowerShell updates..."
    $currentVersion = $PSVersionTable.PSVersion
    try {
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestVersion = [Version]($latestRelease.tag_name.TrimStart('v'))

        if ($currentVersion -lt $latestVersion) {
            Write-Host "A newer version of PowerShell is available: $latestVersion"
            if (Read-PromptYesNo -Message "Do you want to update PowerShell?" -Default "N") {
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

function Update-Winget {
    Write-Host "Checking for winget updates..."
    try {
        $wingetPath = (Get-Command winget.exe -ErrorAction SilentlyContinue).Source

        if (-not $wingetPath) {
            Write-Host "winget is not installed."
            Write-Host "Please install it from https://github.com/microsoft/winget-cli/releases"
            return $false
        } else {
            # Get the installed version of winget from file properties
            $installedVersion = (Get-Command winget).Version
            if (-not $installedVersion) {
                Write-Warning "Failed to retrieve installed winget version."
                return 
            } else {
                # Check if an upgrade is available
                $wingetUpgradeOutput = winget upgrade --id Microsoft.DesktopAppInstaller -e --source msstore 2>&1
                if ($wingetUpgradeOutput -notmatch "No applicable update found") {
                    Write-Host "An update for winget is available (Installed: $installedVersion)."
                    if (Read-PromptYesNo -Message "Do you want to update winget?" -Default "N") {
                        winget upgrade --id Microsoft.DesktopAppInstaller -e --source msstore
                        Write-Host "winget upgraded."
                        return $true
                    }
                } else {
                    Write-Host "winget is up to date (Version: $installedVersion)."
                }
            }
        }
    } catch {
        Write-Warning "Failed to check or update winget: $_"
    }
    return $false
}

Export-ModuleMember -Function Grant-Elevation, Update-PowerShell, Update-Winget, Read-PromptYesNo
