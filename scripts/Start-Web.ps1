[CmdletBinding()]
param (
    [Parameter(Position = 0, ValueFromPipeline)]
    [string]$ConfigPath
)

function Import-Config {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param (
        [Parameter()]
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath -PathType Leaf)) {
        Write-Error "Import-Config: Config file not found: $ConfigPath"
        return
    }

    try {
        $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

        Write-Debug "Import-Config: Successfully loaded config from $ConfigPath"
        return $Config
    }
    catch {
        Write-Error "Import-Config: Failed to import config: $_"
        return
    }
}

function Invoke-Entry {
    [CmdletBinding()]
    param(
        [PSObject]$Entry
    )

    switch ($Entry.Type) {
        "Executable" {
            if (Test-Path (Join-Path $Entry.Directory $Entry.Executable)) {
                Write-Debug "Attempting to start: $($Entry.Executable) in $($Entry.Directory)"
                try {
                    $process = Start-Process `
                            -FilePath $Entry.Executable `
                            -WorkingDirectory $Entry.Directory
                            
                    Write-Debug "Process started with ID: $($process.Id)"
                }
                catch {
                    Write-Error "Start-Web: Failed to start executable: $($Entry.Executable): $_"
                }
            }
            else {
                Write-Error "Executable not found: $fullPath" -ErrorAction Inquire
            }
        }
        "Command" {
            try {
                Write-Debug "Invoking commands for $($entry.Name) in directory: $($entry.Directory)"
                Push-Location $entry.Directory
                foreach ($command in $entry.Commands) {
                    Write-Debug "Executing command: $command"
                    Invoke-Expression $command
                }
                Pop-Location
            }
            catch {
                Write-Error "Start-Web: Failed to execute commands for $($entry.Name): $_"
            }
        }
        default {
            Write-Error "Invoke-Entry: Unknown entry type: $($entry.Type)"
        }
    }
}

function Start-Web {
<#
.SYNOPSIS
    Start-Web - Starts web applications and server daemons.

.DESCRIPTION
    Start-Web starts web applications and server daemons based on the configuration file.

.PARAMETER ConfigPath
    The path to the configuration file. If not provided, the default configuration file will be used.

.EXAMPLE
    Start-Web -ConfigPath "C:/utils/scripts/config/Start-Web.json"
#>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$ConfigPath = "$PSScriptRoot\config\Start-Web.json"
    )

    begin {
        $LogFilePath = Join-Path $PSScriptRoot "logs\$($MyInvocation.MyCommand.Name)_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
        
        try {
            New-Item -ItemType File -Path $LogFilePath | Out-Null
        }
        catch {
            Write-Error "Start-Web: Failed to create log file: $_"
        }
        Start-Transcript -Path $LogFilePath

        Write-Debug "Loading configuration from: $ConfigPath"
        $Config = Import-Config -ConfigPath $ConfigPath

        if (-not $Config) {
            Write-Error "Failed to load configuration."
            return
        }
    }

    process {
        foreach ($entry in $Config) {
            Write-Host "Launching: $($entry.Name)" -ForegroundColor Green
            Invoke-Entry -entry $entry
        }
    }

    end {}

    clean {
        Stop-Transcript
    }
}
Start-Web @PSBoundParameters
