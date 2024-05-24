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
        [string]$Changes,
        [switch]$ApplyAll
    )
    Push-Location $Directory
    switch ($Changes) {
        "Uncommitted changes" {
            if ($ApplyAll -or (Read-Host "Local modifications detected. Commit and push? (Y/N)").ToUpper() -eq 'Y') {
                git add . > $null 2>&1
                git commit -m "Committing local changes" > $null 2>&1
                git push origin $Branch > $null 2>&1
                Write-Host "Local changes committed and pushed."
            }
        }
        "Local changes ahead of remote" {
            Write-Host "Local commits ahead of remote."
            if ($ApplyAll -or (Read-Host "Push local changes to remote? (Y/N)").ToUpper() -eq 'Y') {
                git push origin $Branch > $null 2>&1
                Write-Host "Local changes pushed to remote."
            }
        }
        "Remote changes ahead of local" {
            Write-Host "Remote commits ahead of local."
            if ($ApplyAll -or (Read-Host "Pull remote changes? (Y/N)").ToUpper() -eq 'Y') {
                git pull origin $Branch > $null 2>&1
                Write-Host "Remote changes pulled to local."
            }
        }
    }
    Pop-Location
}

Export-ModuleMember -Function Get-RepositoryStatus
Export-ModuleMember -Function Sync-Repository