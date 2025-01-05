#region Configuration
$script:Config = @{
    GsudoCommand = "gsudo -n"
}
#endregion

#region Elevation
function Assert-Gsudo {
<#
.SYNOPSIS
    Checks if gsudo is installed and installs it if not.
#>
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

function Grant-Elevation {
<#
.SYNOPSIS
    Grant-Elevation - Checks if gsudo is installed and elevates the script if not.
#>    
    [CmdletBinding()]
    param ()
    if (Get-Command "gsudo" -ErrorAction SilentlyContinue) {
        Write-Verbose "Attempting to elevate using gsudo..."
        try {
            Invoke-Expression $script:Config.GsudoCommand
        }
        catch {
            Write-Warning "Grant-Elevation: Failed to elevate using gsudo: $_"
        }
    } else {
        Write-Verbose "gsudo is not installed."
        Assert-Gsudo
    }
}
#endregion

#region Helper Utilities
function Read-Prompt {
<#
.SYNOPSIS
    Read-Prompt - Prompt the user to enter a response.

.DESCRIPTION
    Prompts the user to enter a response, and returns a value based on the response. The prompt is
    constructed from the passed message and possible responses. If the user enters nothing, the default response
    is returned. If the user enters an invalid response, a message is printed and the function continues prompting.

.PARAMETER Message
    The message to display to the user.

.PARAMETER Prompt
    Possible responses for the user. Valid options are "Y", "N", "A", "D", and "S". The default is "YN".
    Responses are case-insensitive and must be entered as a string.

.PARAMETER Default
    The default response to return if the user enters nothing. Valid options are "Y", "N", "A", "D", or "S".
    The response made default will be capitalized in the prompt to indicate its status.

.PARAMETER ResponseMap
    Optional hashtable mapping prompt characters to custom return values.
    Example: @{"Y"="Continue";"N"="Stop"}

.EXAMPLE
    $response = Read-Prompt -Message "Are you sure you want to proceed?"

.EXAMPLE
    $response = Read-Prompt -Message "Are you sure you want to proceed?" -Prompt "YN"

.EXAMPLE
    $response = Read-Prompt -Message "Are you sure you want to proceed?" -Prompt "YNADS" -Default "N"

.EXAMPLE
    # Custom responses
    $map = @{"Y"="Install";"N"="Skip"}
    Read-Prompt "Install package?" -ResponseMap $map
#>
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Message,

        [Parameter(Position=1)]
        [string]$Prompt = "YN",  # Default prompt to "Y" and "N"

        [Parameter(Position=2)]
        [ValidateSet("Y", "N", "A", "D", "S")]
        [string]$Default = "Y",   # Default response to "Y"

        [Parameter(Position=3)]
        [hashtable]$ResponseMap
    )

    # Validate that $Prompt contains only allowed characters: Y, N, A, D, S
    if ($Prompt -notmatch '^[YNADS]+$') {
        throw "Read-Prompt: Invalid Prompt value. It must contain only 'Y', 'N', 'A', 'D', or 'S' characters in any combination."
    }

    # Validate that $Default is one of the characters in $Prompt
    if ($Default -notmatch '^[YNADS]$' -or $Prompt -notmatch $Default) {
        throw "Read-Prompt: Invalid Default value. It must be a single character: 'Y', 'N', 'A', 'D', or 'S', and must be included in Prompt."
    }

    # Define options based on $Prompt with correct capitalization
    $options = [ordered]@{}
    foreach ($char in $Prompt.ToCharArray()) {
        $isDefault = $char -eq $Default
        switch ($char) {
            "Y" { $options[$char] = $isDefault ? "Y(es)" : "y(es)" }
            "N" { $options[$char] = $isDefault ? "N(o)" : "n(o)" }
            "A" { $options[$char] = $isDefault ? "A(ll)" : "a(ll)" }
            "D" { $options[$char] = $isDefault ? "D(eny)" : "d(eny)" }
            "S" { $options[$char] = $isDefault ? "S(uspend)" : "s(uspend)" }
        }
    }

    $promptOptionsString = $options.Values -join "/"
    $prompt = "$Message [$promptOptionsString]"

    if ($ResponseMap) {
        # Validate ResponseMap contains entries for all prompt options
        $invalidKeys = $ResponseMap.Keys | Where-Object { $Prompt -notcontains $_ }
        if ($invalidKeys) {
            throw "ResponseMap contains invalid keys: $($invalidKeys -join ',')"
        }
    }

    while ($true) {
        $response = Read-Host -Prompt $prompt

        if ([string]::IsNullOrWhiteSpace($response)) {
            $response = $Default
        }

        $response = $response.ToUpper()
        if ($response.Length -eq 1 -and $Prompt -match $response) {
            if ($ResponseMap -and $ResponseMap.ContainsKey($response)) {
                return $ResponseMap[$response]
            }
            return $(switch ($response) {
                # boolean responses
                "Y" { $true }
                "N" { $false }
                # string responses
                "A" { "AcceptAll" }
                "D" { "DenyAll" }
                "S" { "Suspend" }
            })
        }

        Write-Host "Invalid response. Please enter one of: $promptOptionsString" -ForegroundColor Yellow
    }
}

function Get-WindowTitle {
<#
.SYNOPSIS
    Get-WindowTitle - Get the title of the console window

.DESCRIPTION
    This function returns the title of the console window.    
    
.OUTPUTS
    System.String - Get-WindowTitle returns the title of the console window  
#>    
    [CmdletBinding()]
    param ()

    $signature = @"
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleTitle(StringBuilder lpConsoleTitle, int nSize);
"@

    $type = Add-Type -MemberDefinition $signature -Name Win32GetConsoleTitle -Namespace Win32Functions -PassThru
    $buffer = New-Object System.Text.StringBuilder 256
    $type::GetConsoleTitle($buffer, $buffer.Capacity) | Out-Null
    return $buffer.ToString()
}

function Set-WindowTitle {
<#
.SYNOPSIS
    Set-WindowTitle - Set the title of the console window

.DESCRIPTION
    This function sets the title of the console window.
    
.PARAMETER title

The title to set for the console window.

.EXAMPLE
    Set-WindowTitle -title "New Title"
#>
    [CmdletBinding()]
    param (
        [string]$title
    )
    
    # Use the Windows API to set the console title
    $signature = @"
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleTitle(string lpConsoleTitle);
"@
    $type = Add-Type -MemberDefinition $signature -Name Win32SetConsoleTitle -Namespace Win32Functions -PassThru
    $type::SetConsoleTitle($title)
}

function Test-Module {
    <#
    .SYNOPSIS
        Test-Module - Checks if a module is installed and installs it if not.
    
    .DESCRIPTION
        Checks if the specified PowerShell module is installed. If it is not, it prompts the user to install it.
    
    .PARAMETER ModuleName
        The name of the PowerShell module to check for.
    
    .EXAMPLE
        Test-Module -ModuleName "YamlDotNet"
    #>
        [CmdletBinding()]
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
#endregion

function Update-PowerShell {
<#
.SYNOPSIS
    Update-PowerShell - Checks if PowerShell is up to date and updates it if necessary.

.DESCRIPTION
    Checks if the current version of PowerShell is up to date. If it is not, it prompts the user to update it.

.LINK
    https://github.com/PowerShell/PowerShell
#>
    [CmdletBinding()]
    param ()

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

#region Logging
function Start-Logging {
    try {
        if (-not (Test-Path -Path "$PSScriptRoot\logs" -PathType Container)) {
            Write-Debug "Start-Logging: No logs directory found. Creating one..."
            New-Item -Path "$PSScriptRoot\logs" -ItemType Directory | Out-Null
        }
        Write-Debug "Start-Logging: Creating transcript and initializing logging..."
        $LogFilePath = Join-Path $PSScriptRoot "logs\$($MyInvocation.MyCommand.Name)_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
        Start-Transcript -Path $LogFilePath | Out-Null
    } catch {
        Write-Error "Start-Logging: Failed to start transcript: $_"
    }
}

function Stop-Logging {
    try {
        Write-Debug "Stop-Logging: Stopping transcript..."
        Stop-Transcript | Out-Null
    } catch {
        Write-Error "Stop-Logging: Failed to stop transcript: $_"
    }
}
#endregion

#region Exports
Export-ModuleMember -Function `
    Grant-Elevation, `
    Update-PowerShell, `
    Assert-Winget, `
    Read-Prompt, `
    Set-WindowTitle, `
    Test-Module

Export-ModuleMember -Function `
    Start-Logging, `
    Stop-Logging
#endregion