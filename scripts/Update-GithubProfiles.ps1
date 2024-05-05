<#
.SYNOPSIS
    Update-GithubProfiles.ps1 - Updates various local profiles by pulling changes from remote GitHub repositories.

.DESCRIPTION
    This script automates the process of updating local profile configurations by fetching and pulling changes from specified GitHub repositories.
    It handles both updating existing local repositories and cloning new repositories if they are not already present locally.

.PARAMETER None
    No parameters are needed to run this script directly. All configurations are predefined within the script.

.EXAMPLE
    .\Update-GithubProfiles.ps1
    This command runs the script to update or clone the GitHub repositories specified in the script.

.NOTES
    - This script requires Git to be installed and available in the system's PATH.
    - Repositories are predefined in the script with their respective names, URLs, branches, and local directory paths.
    - Error handling is provided for common issues like Git not being installed, repository not being found, or errors during Git operations.

.LINK
    Git Installation: https://git-scm.com/downloads

.INPUTS
    None

.OUTPUTS
    Console output indicating the status of each repository update or clone operation.
#>

###############################################
# Parameters
###############################################
param (
    [string]$ConfigurationPath = "$PSScriptRoot\config\profiles_github.json"
)

###############################################
# Imports
###############################################
Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"
Import-Module "$PSScriptRoot\lib\SysOperation.psm1"

###############################################
# Functions
###############################################

function Read-Configuration {
    param (
        [string]$ConfigurationPath
    )
    if (Test-Path -Path $ConfigurationPath) {
        $json = Get-Content $ConfigurationPath -Raw | ConvertFrom-Json
        return $json
    } else {
        Write-Console "Configuration file not found at $ConfigurationPath." -MessageType Error
        $errorMessage = "Configuration file not found."
        ErrorHandling -ErrorMessage $errorMessage
        exit 1
    }
}

function Update-GithubProfiles {
    $repos = Read-Configuration -ConfigurationPath $ConfigurationPath

    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Write-Console "Git is not installed. Please install Git and try again."
        exit 1
    }

    foreach ($repo in $repos) {
        $resolved_directory = [Environment]::ExpandEnvironmentVariables($repo.Dir)
        Write-Console "Debug: Resolved directory for $($repo.Name): $resolved_directory"

        if ($resolved_directory -like '*$env:*' -or $resolved_directory -eq $null) {
            Write-Console "Failed to resolve directory for $($repo.Name): $resolved_directory"
            continue
        }

        # Debugging output to check resolved directory
        Write-Console "Resolved directory for $($repo.Name): $resolved_directory"

        try {
            if (!(Test-Path -Path $resolved_directory)) {
                Write-Console "Directory does not exist. Creating directory: $resolved_directory"
                New-Item -Path $resolved_directory -ItemType Directory -Force
            }

            if (Test-Path -Path $resolved_directory) {
                Push-Location $resolved_directory
                git fetch
                $local_commit = git rev-parse HEAD
                $remote_commit = git ls-remote origin -h refs/heads/$($repo.Branch) | Select-Object -First 1 | ForEach-Object { $_.Split()[0] }

                if ($local_commit -ne $remote_commit) {
                    Write-Console "Local repository $($repo.Name) is behind. Updating..."
                    git pull
                    Write-Console "$($repo.Name) updated successfully."
                } else {
                    Write-Console "$($repo.Name) is up-to-date."
                }
                Pop-Location
            } else {
                Write-Console "Cloning repository $($repo.Name) to $resolved_directory..."
                git clone $repo.Url -b $repo.Branch $resolved_directory
                Write-Console "Repository $($repo.Name) cloned successfully."
            }
        } catch {
            Write-Console "Issue encountered while updating $($repo.Name): $($_.Exception.Message)" -MessageType Error
            continue
        }
    }
}

if ($MyInvocation.ScriptName -ne ".") { Update-GithubProfiles }