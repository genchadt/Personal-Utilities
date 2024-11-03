###############################################
# Parameters
###############################################

param (
    [string]$ConfigurationPath = "$PSScriptRoot/config/github/profiles_github.json",
    [string]$ProfilesPath = "$PSScriptRoot/profiles",
    [switch]$Verbose
)

###############################################
# Imports
###############################################

Import-Module "$PSScriptRoot/lib/Helpers.psm1"

###############################################
# Functions
###############################################
function Get-RepoStatus {
    [CmdletBinding()]
    param (
        [string]$Directory,
        [string]$Branch,
        [string]$RepoName,
        [string]$RepoUrl
    )

    Write-Verbose "Checking repository status for '$RepoName' at '$Directory'..."
    $changes = ""
    if (-not (Test-Path -Path $Directory)) {
        $changes = "Error: Directory does not exist"
    } elseif (-not (Test-Path -Path (Join-Path $Directory ".git"))) {
        $changes = "Error: Not a git repository"
    } else {
        Push-Location $Directory
        try {
            # Check for uncommitted changes
            $statusOutput = git status --porcelain 2>$null
            if ($statusOutput) {
                $changes = "Uncommitted changes"
            } else {
                # Fetch the latest changes from the remote repository
                Write-Verbose "Fetching latest changes from origin/$Branch"
                git fetch origin $Branch *>$null

                $localCommit = git rev-parse $Branch 2>$null
                $remoteCommit = git rev-parse origin/$Branch 2>$null

                if ($localCommit -eq $remoteCommit) {
                    $changes = "No changes"
                } else {
                    $aheadBehind = git rev-list --left-right --count $Branch...origin/$Branch 2>$null
                    $aheadBehindCounts = $aheadBehind -split "`t"
                    $ahead = [int]$aheadBehindCounts[0]
                    $behind = [int]$aheadBehindCounts[1]

                    if ($ahead -gt 0 -and $behind -gt 0) {
                        $changes = "Diverged"
                    } elseif ($ahead -gt 0) {
                        $changes = "Local changes ahead of remote"
                    } elseif ($behind -gt 0) {
                        $changes = "Remote changes ahead of local"
                    } else {
                        $changes = "No changes"
                    }
                }
            }
        } catch {
            $changes = "Error: $_"
        }
        Pop-Location
    }

    return [PSCustomObject]@{
        Name      = $RepoName
        Directory = $Directory
        Branch    = $Branch
        Changes   = $changes
        RepoUrl   = $RepoUrl
    }
}

function Sync-Repository {
    [CmdletBinding()]
    param (
        [string]$Directory,
        [string]$Branch,
        [string]$Changes
    )

    Write-Verbose "Synchronizing repository at '$Directory' with branch '$Branch'"
    Push-Location $Directory
    try {
        switch ($Changes) {
            "Uncommitted changes" {
                Write-Verbose "Detected uncommitted changes in '$Directory'"
                if (Read-PromptYesNo -Message "Do you want to stash changes?" -Default "N") {
                    git stash | Out-Null
                    Write-Host "Changes stashed."
                } else {
                    Write-Host "Skipping repository due to uncommitted changes."
                    return
                }
            }
            "Local changes ahead of remote" {
                Write-Verbose "Local changes ahead of remote in '$Directory'"
                if (Read-PromptYesNo -Message "Do you want to push changes to remote?" -Default "N") {
                    git push origin $Branch | Out-Null
                    Write-Host "Changes pushed to remote."
                } else {
                    Write-Host "Skipping pushing changes."
                }
            }
            "Remote changes ahead of local" {
                Write-Verbose "Remote changes ahead of local in '$Directory'"
                if (Read-PromptYesNo -Message "Do you want to pull changes from remote?" -Default "N") {
                    git pull origin $Branch | Out-Null
                    Write-Host "Changes pulled from remote."
                } else {
                    Write-Host "Skipping pulling changes."
                }
            }
            "Diverged" {
                Write-Verbose "Local and remote branches have diverged in '$Directory'"
                if (Read-PromptYesNo -Message "Do you want to merge changes?" -Default "N") {
                    git merge origin/$Branch | Out-Null
                    Write-Host "Repositories merged."
                } else {
                    Write-Host "Skipping merge."
                }
            }
            default {
                Write-Host "No action needed for $Directory."
            }
        }
    } catch {
        Write-Warning "Failed to synchronize repository at ${Directory}: $_"
    }
    Pop-Location
}

function Connect-Repository {
    [CmdletBinding()]
    param (
        [string]$RepoUrl,
        [string]$Directory
    )

    Write-Verbose "Cloning repository from '$RepoUrl' to '$Directory'"
    try {
        git clone $RepoUrl $Directory | Out-Null
        Write-Host "Repository cloned successfully."
    } catch {
        Write-Error "Failed to clone repository from '$RepoUrl' to '$Directory': $_"
    }
}

function Update-GithubProfiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ConfigurationPath = "$PSScriptRoot/config/github/profiles_github.json",
        [string]$ProfilesPath = "$PSScriptRoot/profiles"
    )

    Write-Host "Updating GitHub profiles..."
    try {
        $repos = Get-Content -Path $ConfigurationPath | ConvertFrom-Json
    } catch {
        Write-Error "Failed to load configuration from ${ConfigurationPath}: $_"
        return
    }

    $missingRepos = @()
    $changesApplied = @{ }
    $repoStatuses = @()
    $declineAll = $false  # Flag to skip all remaining items if "Decline All" is chosen

    # Identify missing repositories
    foreach ($repo in $repos) {
        $repoDir = Join-Path -Path $ProfilesPath -ChildPath $repo.RepoName
        if (-not (Test-Path -Path $repoDir)) {
            $missingRepos += [PSCustomObject]@{
                Name      = $repo.Name
                Directory = $repoDir
                RepoUrl   = $repo.Url
            }
        }
    }

    # Display missing repositories and prompt for action
    if ($missingRepos.Count -gt 0) {
        Write-Host "The following repositories are missing:" -ForegroundColor Yellow
        $missingRepos | ForEach-Object { Write-Host "- $($_.Name) (Directory: $($_.Directory))" -ForegroundColor Red }

        $action = Read-Host "Would you like to clone (A)ll, (S)kip all, or (S)tep through each one?"

        switch ($action.ToUpper()) {
            "A" {
                foreach ($missingRepo in $missingRepos) {
                    Connect-Repository -RepoUrl $missingRepo.RepoUrl -Directory $missingRepo.Directory -Verbose:$VerbosePreference
                }
            }
            "S" {
                Write-Host "Skipping cloning for all missing repositories."
            }
            "T" {
                foreach ($missingRepo in $missingRepos) {
                    Write-Host "Repository: $($missingRepo.Name)"
                    $cloneAction = Read-PromptYesNo -Message "Do you want to clone this repository?" -Default "Y"
                    if ($cloneAction) {
                        Connect-Repository -RepoUrl $missingRepo.RepoUrl -Directory $missingRepo.Directory -Verbose:$VerbosePreference
                    } else {
                        Write-Host "Skipping $($missingRepo.Name)"
                    }
                }
            }
            default {
                Write-Host "Invalid option. Skipping all cloning operations."
            }
        }
    }

    # Process repositories for updates
    foreach ($repo in $repos) {
        $repoDir = Join-Path -Path $ProfilesPath -ChildPath $repo.RepoName

        # Check repository status
        $repoStatus = Get-RepoStatus -Directory $repoDir -Branch $repo.Branch -RepoName $repo.Name -RepoUrl $repo.Url -Verbose:$VerbosePreference
        $repoStatuses += $repoStatus
    }

    # Display repository statuses and handle updates
    $repoStatuses | ForEach-Object {
        $color = switch ($_.Changes) {
            "No changes"                  { "Green" }
            "Uncommitted changes"         { "Blue" }
            "Local changes ahead of remote" { "Yellow" }
            "Remote changes ahead of local" { "Yellow" }
            default                       { "Red" }
        }
        Write-Host "[$($_.Name)] Branch: $($_.Branch) - Changes: $($_.Changes)" -ForegroundColor $color
    }

    # Check if any changes need to be applied
    $changesNeeded = $repoStatuses | Where-Object { $_.Changes -and $_.Changes -ne "No changes" -and -not $_.Changes.StartsWith("Error") }

    if ($changesNeeded) {
        foreach ($repoStatus in $changesNeeded) {
            if ($declineAll) {
                Write-Host "Skipping changes for repository: $($repoStatus.Name) due to 'Decline All' selection."
                continue
            }

            Write-Host "Repository: $($repoStatus.Name), Changes: $($repoStatus.Changes)"
            $action = Read-Host "Apply changes? (Y)es (N)o (A)ll (D)ecline All"

            switch ($action.ToUpper()) {
                "Y" {
                    Sync-Repository -Directory $repoStatus.Directory -Branch $repoStatus.Branch -Changes $repoStatus.Changes -Verbose:$VerbosePreference
                    $changesApplied[$repoStatus.Name] = $true
                }
                "N" {
                    Write-Host "Skipping changes for repository: $($repoStatus.Name)"
                }
                "A" {
                    Write-Host "Applying changes to all repositories."
                    foreach ($status in $changesNeeded) {
                        Sync-Repository -Directory $status.Directory -Branch $status.Branch -Changes $status.Changes -Verbose:$VerbosePreference
                        $changesApplied[$status.Name] = $true
                    }
                    break
                }
                "D" {
                    Write-Host "Declined all changes."
                    $declineAll = $true  # Set flag to skip all remaining items
                    continue
                }
                default {
                    Write-Host "Invalid selection. Skipping."
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

$params = @{
    ConfigurationPath = $ConfigurationPath
    ProfilesPath      = $ProfilesPath
    Verbose           = $Verbose
}
Update-GithubProfiles @params