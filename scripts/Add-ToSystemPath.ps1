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

param (
    [string[]]$PathsToAdd
)

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
            Write-Output "Added path: $Path"
        } else {
            Write-Output "Path already present: $Path"
        }
    }

    Join-SystemPath -Paths $current_path
}

$params = @{
    PathsToAdd = $PathsToAdd
}

if ($MyInvocation.InvocationName -ne '.') { Add-ToSystemPath @params }
