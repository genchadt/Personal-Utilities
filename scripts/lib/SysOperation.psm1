<#
    .SYNOPSIS
        SysOperation.psm1 - System operation functions for PowerShell scripts.

    .DESCRIPTION
        Functions for performing system operations in PowerShell scripts.
#>

###############################################
# Public Functions
###############################################

<#
    .SYNOPSIS
        Request-Elevation - Requests elevation for the current PowerShell session.

    .DESCRIPTION
        Requests elevation for the current PowerShell session.

    .EXAMPLE
        Request-Elevation
#>
function Request-Elevation {
    $current_principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())

    if ($current_principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        return $true
    } else {
        $script_path = $MyInvocation.MyCommand.Path
        $arguments = $MyInvocation.UnboundArguments

        $argument_list = $arguments -join " "

        $process_info = New-Object System.Diagnostics.ProcessStartInfo
        $process_info.FileName = "pwsh"
        $process_info.Arguments = "-File `"$script_path`" $argument_list"
        $process_info.Verb = "runas"

        try {
            [System.Diagnostics.Process]::Start($process_info)
            exit
        } catch {
            Write-Error "Failed to request elevation: $_"
            exit 1
        }
    }
}

<#
    .SYNOPSIS
        Get-Configuration - Gets the configuration from a JSON or text file.

    .DESCRIPTION
        Gets the configuration from a JSON or text file.

    .PARAMETER FilePath
        The path to the configuration file.

    .EXAMPLE
        Get-Configuration -FilePath .\config.json
#>
function Get-Configuration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (-not (Test-Path -Path $FilePath)) {
        Write-Error "Configuration file not found at $FilePath."
        exit 1
    }

    try {
        if ($FilePath -match '\.json$') {
            return Read-JsonConfig -FilePath $FilePath
        } else {
            return Read-TextConfig -FilePath $FilePath
        }
    } catch {
        throw "Failed to process config file '$FilePath': $_"
    }
}

<#
    .SYNOPSIS
        Get-CurrentDirectorySize - Gets the size of the current directory.

    .DESCRIPTION
        Gets the size of the current directory.

    .EXAMPLE
        Get-CurrentDirectorySize
#>
function Get-CurrentDirectorySize {
    $directory_size_bytes = (Get-ChildItem -Path . -Recurse -Force | Measure-Object -Property Length -Sum).Sum

    $directory_size = [PSCustomObject]@{
        Bytes = $directory_size_bytes
        Kilobytes = [math]::Round($directory_size_bytes / 1KB, 2)
        Megabytes = [math]::Round($directory_size_bytes / 1MB, 2)
        Gigabytes = [math]::Round($directory_size_bytes / 1GB, 2)
    }

    return $directory_size
}

function Invoke-Command {
    param (
        [string]$Command
    )

    Write-Console "Executing: $Command`n"

    try {
        $output = Invoke-Expression $Command -ErrorAction Stop
    } catch {
        ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace
    }

    Write-Log $output
    return $output
}

function Remove-ItemSafely {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string]$Path
    )

    process {
        if ($PSCmdlet.ShouldProcess($Path, "Move to Recycle Bin")) {
            try {
                $resolved_path = Resolve-Path -Path $Path -ErrorAction Stop
                $item = Get-Item -LiteralPath $resolved_path.Path -ErrorAction Stop

                $shell = New-Object -ComObject "Shell.Application"
                $folder = $shell.Namespace($item.Directory.FullName)
                $file = $folder.ParseName($item.Name)

                if ($null -ne $file) {
                    $file.InvokeVerb("delete")
                    Write-Output "Moved to Recycle Bin: $resolved_path.Path"
                } else {
                    Write-Error "Failed to locate item for Recycle Bin operation: $resolved_path.Path"
                }
            } catch {
                Write-Error "Error moving item to Recycle Bin: $_.Exception.Message"
            } finally {
                if ($null -ne $shell) {
                    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
                }
            }
        }
    }
}

###############################################
# Private Functions
###############################################

function Read-JsonConfig($FilePath) {
    try {
        return Get-Content $FilePath -Raw | ConvertFrom-Json
    } catch {
        throw "Failed to read JSON config file '$FilePath': $_"
    }
}

function Read-TextConfig {
    $processedLines = @()

    try {
        $lines = Get-Content $FilePath -ErrorAction Stop

        foreach ($line in $lines) {
            # Remove inline comments and trim each line
            $processedLine = $line -split '#' | Select-Object -First 1 | ForEach-Object { $_.Trim() }

            # Skip empty lines or lines that became empty after processing
            if (-not $processedLine) {
                continue
            }

            # Add processed line to the array
            $processedLines += $processedLine
        }

        return $processedLines
    } catch {
        throw "Failed to read text config file '$FilePath': $_"
    }
}

###############################################
# Export Functions
###############################################

Export-ModuleMember -Function Request-Elevation
Export-ModuleMember -Function Get-Configuration
Export-ModuleMember -Function Get-CurrentDirectorySize
Export-ModuleMember -Function Invoke-Command
Export-ModuleMember -Function Remove-ItemSafely