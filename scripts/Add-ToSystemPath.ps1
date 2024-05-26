<# 
    .SYNOPSIS
        Add-ToSystemPath.ps1 - Adds paths to the system $PATH variable.

    .DESCRIPTION
        !! This script must be run with Administrator privileges. !!
        Adds paths to the system $PATH variable.

    .PARAMETER PathsToAdd
        The path(s) to add to the system $PATH variable.

    .EXAMPLE
        Add-ToSystemPath.ps1 -PathsToAdd "C:\Program Files\Git\bin"

#>

###############################################
# Parameters
###############################################

param (
    [string[]]$PathsToAdd
)

###############################################
# Imports
###############################################

Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\SysOperation.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"

###############################################
# Functions
###############################################

function Backup-SystemPath {
    param (
        [string]$BackupPath = "$PSScriptRoot\backups\path.reg"
    )

    if ($BackupPath -notlike "*.reg") {
        $BackupPath += ".reg"
    }

    $current_path = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    $current_path | Out-File "$PSScriptRoot\backups\path.reg"
}

function Join-SystemPath {
    param (
        [string]$Paths
    )

    [Environment]::SetEnvironmentVariable("Path", $Paths, [System.EnvironmentVariableTarget]::Machine)
}

function Add-ToSystemPath {
    param (
        [string[]]$PathsToAdd
    )

    $current_path = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)

    foreach ($Path in $PathsToAdd) {
        if ($current_path -notlike "*$Path*") {
            $current_path += ";$Path"
            Write-Console "Added path: $Path"
        } else {
            Write-Console "Path already present: $Path" -MessageType Warning
        }
    }

    Backup-SystemPath
    Join-SystemPath -Paths $current_path
    Write-Console "New path: $current_path"
}

$params = @{
    PathsToAdd = $PathsToAdd
}

if ($MyInvocation.InvocationName -ne '.') { Add-ToSystemPath @params }
