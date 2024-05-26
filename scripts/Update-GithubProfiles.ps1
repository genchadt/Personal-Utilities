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
Import-Module "$PSScriptRoot/lib/GithubHelpers.psm1"
Import-Module "$PSScriptRoot/lib/SysOperation.psm1"
Import-Module "$PSScriptRoot/lib/TextHandling.psm1"

###############################################
# Functions
###############################################

function Update-GithubProfiles {
    Write-Console "Test"
    $repos = Get-Configuration -FilePath $ConfigurationPath
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
                        Sync-Repository -Directory $repoStatus.Directory -Branch $repoStatus.Branch -Changes $repoStatus.Changes -ApplyAll
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
