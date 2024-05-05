<#
.SYNOPSIS
    Updates various local profiles by pulling changes from remote GitHub repositories.

.DESCRIPTION
    This script automates the process of updating local profile configurations by fetching and pulling changes from specified GitHub repositories.
    It handles both updating existing local repositories and cloning new repositories if they are not already present locally.

.PARAMETER ConfigurationPath
    The path to the JSON configuration file containing repository information. Defaults to "$PSScriptRoot/config/profiles_github.json" if not specified.

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
    [string]$ConfigurationPath = "$PSScriptRoot/config/profiles_github.json"
)

###############################################
# Imports
###############################################
Import-Module "$PSScriptRoot/lib/ErrorHandling.psm1"
Import-Module "$PSScriptRoot/lib/TextHandling.psm1"
Import-Module "$PSScriptRoot/lib/SysOperation.psm1"

###############################################
# Functions
###############################################

function Get-Configuration {
    param ([string]$ConfigurationPath)
    if (Test-Path -Path $ConfigurationPath) {
        Get-Content $ConfigurationPath -Raw | ConvertFrom-Json
    } else {
        Write-Error "Configuration file not found at $ConfigurationPath."
        exit 1
    }
}

function Commit-LocalChanges {
    param ([string]$Directory)
    Push-Location $Directory
    $changes = git status --porcelain
    if ($changes) {
        git add .
        git commit -m "Auto-commit local changes"
        git push origin
    }
    Pop-Location
}

function Get-RepositoryStatus {
    param (
        [string]$Directory,
        [string]$Branch,
        [string]$RepoName,
        [int]$Index,
        [int]$Total
    )
    Write-Progress -Activity "Checking Repositories" -Status "$RepoName" -PercentComplete (($Index / $Total) * 100)
    if (!(Test-Path -Path $Directory)) {
        return [PSCustomObject]@{
            Name = $RepoName
            Changes = "Error: Directory does not exist"
            Branch = $Branch
        }
    }

    Push-Location $Directory
    git fetch origin
    $local_commit = git log -1 --format="%at"
    $remote_commit = git log -1 --format="%at" "origin/$Branch"
    $status = git status --porcelain

    if ($status) {
        $changes = "Uncommitted changes"
    } elseif ($local_commit -gt $remote_commit) {
        $changes = "↑ UP"
    } elseif ($local_commit -lt $remote_commit) {
        $changes = "↓ DOWN"
    } else {
        $changes = "No changes"
    }

    Pop-Location

    return [PSCustomObject]@{
        Name = $RepoName
        Directory = $Directory
        Changes = $changes
        Branch = $Branch
    }
}

function Sync-Repository {
    param (
        [string]$Directory,
        [string]$Branch,
        [string]$Changes
    )
    Push-Location $Directory
    switch ($Changes) {
        "Uncommitted changes" {
            if ((Read-Host "Local modifications detected. Commit and push? (Y/N)").ToUpper() -eq 'Y') {
                git add .
                git commit -m "Committing local changes"
                git push origin $Branch  # Removed --force flag
                Write-Host "Local changes committed and pushed."
            }
        }
        "Diverged" {
            Write-Host "Local commit diverged from remote."
            if ((Read-Host "Fetch and rebase? (Y/N)").ToUpper() -eq 'Y') {
                git fetch origin
                git rebase "origin/$Branch"
                Write-Host "Rebased to remote."
            }
        }
    }
    Pop-Location
}

function Update-GithubProfiles {
    $repos = Get-Configuration -ConfigurationPath $ConfigurationPath
    $totalRepos = $repos.Count
    $repoIndex = 0
    $changesApplied = @{}

    # Store repository status in an array
    $repoStatuses = @()

    foreach ($repo in $repos) {
        $repoIndex++
        $repoStatus = Get-RepositoryStatus -Directory ([Environment]::ExpandEnvironmentVariables($repo.Dir)) -Branch $repo.Branch -RepoName $repo.Name -Index $repoIndex -Total $totalRepos
        $repoStatuses += $repoStatus
    }

    # Output table header
    $tableHeader = "Name", "Branch", "Changes"
    $repoStatusesFormatted = @()
    foreach ($repoStatus in $repoStatuses) {
        $changesColor = "White"  # Default color
        switch ($repoStatus.Changes) {
            "↑ UP" { $changesColor = "Blue" }
            "↓ DOWN" { $changesColor = "Green" }
        }
        $repoStatusFormatted = [PSCustomObject]@{
            Name = $repoStatus.Name
            Branch = $repoStatus.Branch
            Changes = $repoStatus.Changes
            ChangesColor = $changesColor
        }
        $repoStatusesFormatted += $repoStatusFormatted
    }

    $repoStatusesFormatted | Format-Table -Property $tableHeader -AutoSize | Out-String -Width 200

    # Check if any changes need to be applied
    $changesNeeded = $repoStatuses | Where-Object { $_.Changes -ne "No changes" }

    if ($changesNeeded) {
        # Ask user for action
        $action = Read-Console -Text "Apply changes? (Y/N/A/D)" -Prompt "YAND"

        # Apply changes based on user action
        switch ($action.ToUpper()) {
            "Y" {
                foreach ($repoStatus in $changesNeeded) {
                    if ($repoStatus.Changes -ne "No changes") {
                        Sync-Repository -Directory $repoStatus.Directory -Branch $repoStatus.Branch -Changes $repoStatus.Changes
                        $changesApplied[$repoStatus.Name] = $true
                    }
                }
            }
            "A" {
                foreach ($repoStatus in $changesNeeded) {
                    if ($repoStatus.Changes -ne "No changes") {
                        Sync-Repository -Directory $repoStatus.Directory -Branch $repoStatus.Branch -Changes $repoStatus.Changes
                        $changesApplied[$repoStatus.Name] = $true
                    }
                }
            }
            "D" {
                Write-Host "Changes declined."
            }
        }

        # Output applied changes
        if ($changesApplied.Count -gt 0) {
            Write-Host "Changes applied to the following repositories:"
            foreach ($change in $changesApplied.Keys) {
                Write-Host "- $change"
            }
        }
    } else {
        Write-Host "No updates available."
    }
}

if ($MyInvocation.ScriptName -ne ".") { Update-GithubProfiles }
