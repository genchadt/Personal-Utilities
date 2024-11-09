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

<#
.SYNOPSIS
    Read-Prompt - Prompt the user to enter a response.

.DESCRIPTION
    Prompts the user to enter a response, and returns a boolean value based on the response. The prompt is
    constructed from the passed message and possible responses. If the user enters nothing, the default response
    is returned. If the user enters an invalid response, a message is printed and the function continues prompting.

.EXAMPLE
    $response = Read-Prompt -Message "Are you sure you want to proceed?"

.EXAMPLE
    $response = Read-Prompt -Message "Are you sure you want to proceed?" -Prompt "YN"

.EXAMPLE
    $response = Read-Prompt -Message "Are you sure you want to proceed?" -Prompt "YNAD" -Default "N"
#>
function Read-Prompt {
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Message,

        [Parameter(Position=1)]
        [string]$Prompt = "YN",  # Default prompt to "Y" and "N"

        [Parameter(Position=2)]
        [ValidateSet("Y", "N", "A", "D")]
        [string]$Default = "Y"   # Default response to "Y"
    )

    # Validate that $Prompt contains only allowed characters: Y, N, A, D
    if ($Prompt -notmatch '^[YNAD]+$') {
        throw "Read-Prompt: Invalid Prompt value. It must contain only 'Y', 'N', 'A', or 'D' characters in any combination."
    }

    # Validate that $Default is one of the characters in $Prompt
    if ($Default -notmatch '^[YNAD]$' -or $Prompt -notmatch $Default) {
        throw "Read-Prompt: Invalid Default value. It must be a single character: 'Y', 'N', 'A', or 'D', and must be included in Prompt."
    }

    # Define options based on $Prompt with correct capitalization
    $options = [ordered]@{}
    foreach ($char in $Prompt.ToCharArray()) {
        $isDefault = $char -eq $Default
        switch ($char) {
            "Y" { $options[$char] = $isDefault ? "(Y)es" : "(y)es" }
            "N" { $options[$char] = $isDefault ? "(N)o" : "(n)o" }
            "A" { $options[$char] = $isDefault ? "(A)ll" : "(a)ll" }
            "D" { $options[$char] = $isDefault ? "(D)eny" : "(d)eny" }
        }
    }

    # Join the prompt options
    $promptOptionsString = $options.Values -join "/"
    $prompt = "$Message [$promptOptionsString]"

    while ($true) {
        # Get user input
        $response = Read-Host -Prompt $prompt

        # Use default response if input is blank
        if ([string]::IsNullOrWhiteSpace($response)) {
            $response = $Default
        }

        # Convert single-letter responses to full response
        $response = $response.ToUpper()
        if ($response.Length -eq 1) {
            # Check if the single letter response is valid
            if ($Prompt -match $response) {
                return $(switch ($response) {
                    "Y" { $true }
                    "N" { $false }
                    "A" { "AcceptAll" }
                    "D" { "DenyAll" }
                })
            }
        }

        Write-Host "Invalid response. Please enter one of: $promptOptionsString" -ForegroundColor Yellow
    }
}

# Example usage:
# $userResponse = Read-Prompt -Message "Are you sure you want to overwrite these files?" -Prompt "YN" -Default "N"

<#
.SYNOPSIS
    Test-Module - Checks if a module is installed and installs it if not.

.DESCRIPTION
    Checks if the specified PowerShell module is installed. If it is not, it prompts the user to install it.
#>

function Set-WindowTitle {
    param (
        [string]$title
    )
    
    $signature = @"
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleTitle(string lpConsoleTitle);
"@
    $type = Add-Type -MemberDefinition $signature -Name Win32SetConsoleTitle -Namespace Win32Functions -PassThru
    $type::SetConsoleTitle($title)
}

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
                throw "Test-Module: Failed to install $ModuleName module: $_"
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
        throw "Failed to check or update PowerShell: $_"
    }
    return $false
}

Export-ModuleMember -Function `
    Grant-Elevation, `
    Update-PowerShell, `
    Assert-Winget, `
    Read-Prompt, `
    Test-Module
