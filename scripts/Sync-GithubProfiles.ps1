param (
    [string]$ConfigurationPath = "$PSScriptRoot/config/github/profiles_github.json",
    [string]$ProfilesPath = "$PSScriptRoot/profiles"
)

Import-Module "$PSScriptRoot/lib/Helpers.psm1"

function Sync-GithubProfiles {
    [CmdletBinding()]
    param (
        [string]$ConfigurationPath,
        [string]$ProfilesPath
    )

    # Validate ConfigurationPath exists as a file
    if (-not (Test-Path -Path $ConfigurationPath -PathType Leaf)) {
        throw "Configuration file '$ConfigurationPath' does not exist or is not a file."
    }

    # Validate ProfilesPath exists as a directory
    if (-not (Test-Path -Path $ProfilesPath -PathType Container)) {
        Write-Warning "Profiles path '$ProfilesPath' does not exist or is not a directory."
        Write-Warning "Would you like to create it?"
        $confirmation = Read-Prompt -Message "Would you like to create it?" -Default "N"
        if ($confirmation) {
            Write-Verbose "Creating profiles path '$ProfilesPath'"
            New-Item -Path $ProfilesPath -ItemType Directory | Out-Null
        } else {
            throw "Profiles path creation declined by the user."
        }
    }

    # Load configuration with verbose output
    Write-Verbose "Loading configuration from '$ConfigurationPath'"
    try {
        $repos = Get-Content -Path $ConfigurationPath | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to load configuration from ${ConfigurationPath}: $_"
    }

    $overwriteFiles = @()  # Collect files that may be overwritten

    # Track colors for alternating profiles
    $profileColors = @("Cyan", "Magenta")
    $colorIndex = 0

    # Check each profile for potential overwrites
    foreach ($repo in $repos) {
        $sourcePath = Join-Path -Path $ProfilesPath -ChildPath $repo.RepoName
        $targetPath = [Environment]::ExpandEnvironmentVariables($repo.Dir)

        if (-not (Test-Path -Path $sourcePath)) {
            Write-Warning "Source path '$sourcePath' for profile '$($repo.Name)' does not exist. Skipping."
            continue
        }

        # Identify files in the source that will overwrite existing files in the target
        $conflicts = Test-FileConflicts -SourcePath $sourcePath -TargetPath $targetPath
        if ($conflicts) {
            # Add conflicts to the list and alternate the display color for each profile
            $profileColor = $profileColors[$colorIndex % $profileColors.Length]
            $colorIndex++

            $overwriteFiles += [PSCustomObject]@{
                ProfileName = $repo.Name
                SourcePath  = $sourcePath
                TargetPath  = $targetPath
                Files       = $conflicts
                Color       = $profileColor
            }
        }
    }

    # Display potential overwrites with full profile color block
    if ($overwriteFiles.Count -gt 0) {
        Write-Host "The following files may be overwritten:" -ForegroundColor Yellow
        foreach ($profile in $overwriteFiles) {
            Write-Host "Profile: $($profile.ProfileName)" -ForegroundColor $profile.Color
            foreach ($file in $profile.Files) {
                Write-Host " - $file" -ForegroundColor $profile.Color
            }
        }

        # Prompt user to accept or decline overwrites
        $userResponse = Read-Prompt -Message "Are you sure you want to overwrite these files?" -Prompt "YN" -Default "N"

        if ($userResponse -eq $true) {  # Adjusted condition
            foreach ($profile in $overwriteFiles) {
                try {
                    Copy-Profile -SourcePath $profile.SourcePath -TargetPath $profile.TargetPath -Verbose:$VerbosePreference
                    Write-Host "Profile '$($profile.ProfileName)' synchronized successfully to '$($profile.TargetPath)'." -ForegroundColor Green
                } catch {
                    Write-Error "Failed to sync profile '$($profile.ProfileName)': $_"
                }
            }
        } else {
            Write-Host "Operation cancelled by the user. No files were overwritten." -ForegroundColor Cyan
        }
    } else {
        Write-Host "No files require overwriting. All profiles are up to date." -ForegroundColor Green
    }
}

function Test-FileConflicts {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$SourcePath,

        [Parameter(Position = 1)]
        [string]$TargetPath
    )

    $conflictFiles = @()
    if (-not (Test-Path -Path $TargetPath)) {
        return $conflictFiles  # No conflicts if target doesn't exist
    }

    # Check each file in the source directory
    Get-ChildItem -Path $SourcePath -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($SourcePath.Length).TrimStart("\\")
        $targetFile = Join-Path -Path $TargetPath -ChildPath $relativePath

        # Check if the file exists in the target and would be overwritten
        if (Test-Path -Path $targetFile) {
            $conflictFiles += $relativePath
        }
    }

    return $conflictFiles
}

function Copy-Profile {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetPath
    )

    # Ensure the target directory exists, with verbose message
    if (-not (Test-Path -Path $TargetPath)) {
        Write-Verbose "Creating target directory '$TargetPath'"
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    }

    # Copy all items excluding specified patterns with verbose message
    Write-Verbose "Copying items from '$SourcePath' to '$TargetPath'"
    try {
        Copy-Item -Path (Join-Path $SourcePath '*') -Destination $TargetPath -Recurse -Force -Exclude '.git', '.gitignore', '.gitattributes'
    } catch {
        Write-Error "Error copying from '$SourcePath' to '$TargetPath': $_"
        throw
    }
}

$params = @{
    ConfigurationPath = $ConfigurationPath
    ProfilesPath      = $ProfilesPath
}
Sync-GithubProfiles @params