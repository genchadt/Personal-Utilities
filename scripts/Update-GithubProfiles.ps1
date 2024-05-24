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
    git fetch origin > $null 2>&1
    $local_commit = git log -1 --format="%at"
    $remote_commit = git log -1 --format="%at" "origin/$Branch"
    $status = git status --porcelain

    if ($status) {
        $changes = "Uncommitted changes"
    } elseif ($local_commit -gt $remote_commit) {
        $changes = "Local changes ahead of remote"
    } elseif ($local_commit -lt $remote_commit) {
        $changes = "Remote changes ahead of local"
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
                git add . > $null 2>&1
                git commit -m "Committing local changes" > $null 2>&1
                git push origin $Branch > $null 2>&1
                Write-Host "Local changes committed and pushed."
            }
        }
        "Local changes ahead of remote" {
            Write-Host "Local commits ahead of remote."
            if ((Read-Host "Push local changes to remote? (Y/N)").ToUpper() -eq 'Y') {
                git push origin $Branch > $null 2>&1
                Write-Host "Local changes pushed to remote."
            }
        }
        "Remote changes ahead of local" {
            Write-Host "Remote commits ahead of local."
            if ((Read-Host "Pull remote changes? (Y/N)").ToUpper() -eq 'Y') {
                git pull origin $Branch > $null 2>&1
                Write-Host "Remote changes pulled to local."
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

    $repoStatuses = @()

    foreach ($repo in $repos) {
        $repoIndex++
        $repoStatus = Get-RepositoryStatus -Directory ([Environment]::ExpandEnvironmentVariables($repo.Dir)) -Branch $repo.Branch -RepoName $repo.Name -Index $repoIndex -Total $totalRepos
        $repoStatuses += $repoStatus
    }

    $repoStatuses | ForEach-Object {
        $color = switch ($_.Changes) {
            "No changes" { "`e[32m" }  # Green
            "Uncommitted changes" { "`e[34m" }  # Blue
            "Local changes ahead of remote" { "`e[33m" }  # Yellow
            "Remote changes ahead of local" { "`e[33m" }  # Yellow
            "Error: Directory does not exist" { "`e[31m" }  # Red
            default { "`e[0m" }  # Reset
        }
        $_ | Add-Member -MemberType NoteProperty -Name 'ChangesColor' -Value $color
    }

    # Format the table with colorized output
    $repoStatuses | Format-Table -Property Name, Branch, @{Name="Changes";Expression={"$($_.ChangesColor)$($_.Changes)`e[0m"}} -AutoSize

    # Check if any changes need to be applied
    $changesNeeded = $repoStatuses | Where-Object { $_.Changes -ne "No changes" }

    if ($changesNeeded) {
        foreach ($repoStatus in $changesNeeded) {
            Write-Host "Repository: $($repoStatus.Name), Changes: $($repoStatus.Changes)"
            $action = Read-Host "Apply changes? (Y)es (N)o (A)ccept All (D)ecline All"
                
            switch ($action.ToUpper()) {
                "Y" {
                    Sync-Repository -Directory $repoStatus.Directory -Branch $repoStatus.Branch -Changes $repoStatus.Changes
                    $changesApplied[$repoStatus.Name] = $true
                }
                "N" {
                    Write-Host "Skipping changes for repository: $($repoStatus.Name)"
                }
                "A" {
                    Write-Host "Applying changes to all repositories."
                    foreach ($repoStatus in $changesNeeded) {
                        Sync-Repository -Directory $repoStatus.Directory -Branch $repoStatus.Branch -Changes $repoStatus.Changes
                        $changesApplied[$repoStatus.Name] = $true
                    }
                    break
                }
                "D" {
                    Write-Host "Declined all changes."
                    break
                }
            }
        }

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
