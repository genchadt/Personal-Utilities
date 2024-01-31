<#
.SYNOPSIS
    AutoAddPath.ps1 - Adds the current directory and all subdirectories to the system $PATH environment variable.

.DESCRIPTION
    This script adds the directory from which it is invoked, along with all its subdirectories, to the system $PATH environment variable. It checks for the existence of each directory in the $PATH to avoid duplication.

.EXAMPLE
    PS> .\AutoAddPath.ps1
    This command runs the script in the current directory, adding it and all subdirectories to the system $PATH.

.INPUTS
    None

.OUTPUTS
    String
    Outputs the updated $PATH variable to the console for verification.

.NOTES
    Administrative privileges are required to run this script.

    Script Version: 2.2
    Author: Chad
    Creation Date: 2024-01-29 03:30:00 GMT
#>

param (
    [switch]$NoPrompt
)

try {
    # Get the current directory and its subdirectories
    $pathsToAdd = @((Get-Location), (Get-ChildItem -LiteralPath $PWD -Directory).FullName)

    # Filter paths that don't exist in the current system $PATH
    $pathsToAdd = $pathsToAdd | Where-Object { [Environment]::GetEnvironmentVariable("PATH", "Machine") -notlike "*$_*" }

    # Display confirmation message
    if ($pathsToAdd.Count -eq 0) {
        Write-Host "No new directories to add. Operation cancelled."
        exit
    }

    Write-Host "The following directories are about to be added to your system `$PATH` variable:"
    $pathsToAdd | ForEach-Object { Write-Host $_ }

    if (-not $NoPrompt -and (Read-Host "Do you want to add these directories to your system `$PATH` variable? Y/N") -ne 'Y') {
        Write-Host "Operation cancelled by user."
        exit
    }

    # Add each path to $PATH
    $currentPath += ";$($pathsToAdd -join ';')"

    # Update the system $PATH
    [Environment]::SetEnvironmentVariable("PATH", $currentPath, "Machine")

    # Output updated $PATH for verification
    Write-Host "Updated PATH: $currentPath"

    # Prompt to restart terminal
    if (-not $NoPrompt -and (Read-Host "You will need to start a new terminal session. Exit now? Y/N") -eq 'Y') {
        Write-Host "Exiting the terminal in 3 seconds..."
        Start-Sleep -Seconds 3
        Stop-Process -Id $PID -Force
    }
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
