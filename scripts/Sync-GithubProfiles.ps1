function Sync-GithubProfiles {
    [CmdletBinding()]
    param (
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [string]$ConfigurationPath = "$PSScriptRoot/config/github/profiles_github.json",
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [string]$ProfilesPath = "$PSScriptRoot/profiles"
    )

    try {
        $repos = Get-Content -Path $ConfigurationPath | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to load configuration from ${ConfigurationPath}: $_"
    }

    foreach ($repo in $repos) {
        $sourcePath = Join-Path -Path $ProfilesPath -ChildPath $repo.RepoName
        $targetPath = [Environment]::ExpandEnvironmentVariables($repo.Dir)

        if (Test-Path -Path $sourcePath) {
            try {
                Copy-Profile -SourcePath $sourcePath -TargetPath $targetPath
                Write-Host "Profile '$($repo.Name)' synchronized successfully to '$targetPath'."
            } catch {
                Write-Error "Failed to sync profile '$($repo.Name)': $_"
                continue
            }            
        } else {
            Write-Host "Source path '$sourcePath' for profile '$($repo.Name)' does not exist. Skipping."
        }
    }
}

function Copy-Profile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetPath
    )

    # Ensure the target directory exists
    if (-not (Test-Path -Path $TargetPath)) {
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    }

    # Copy all items excluding specified patterns
    try {
        Copy-Item -Path (Join-Path $SourcePath '*') -Destination $TargetPath -Recurse -Force -Exclude '.git', '.gitignore', '.gitattributes'
    } catch {
        Write-Error "Error copying from '$SourcePath' to '$TargetPath': $_"
        throw
    }
}
