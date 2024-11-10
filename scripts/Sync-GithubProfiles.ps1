param (
    [string]$ConfigurationPath,
    [string]$ProfilesPath
)

Import-Module "$PSScriptRoot/lib/Helpers.psm1"

function Test-FileConflicts {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$SourcePath,

        [Parameter(Position = 1)]
        [string]$TargetPath
    )

    $conflictSourceNewer = @()
    $conflictTargetNewer = @()
    $identicalFiles = @()

    if (-not (Test-Path -Path $TargetPath)) {
        return @{
            ConflictSourceNewer = $conflictSourceNewer
            ConflictTargetNewer = $conflictTargetNewer
            Identicals = $identicalFiles
        }  # No conflicts if target doesn't exist
    }

    # Only process files, not directories
    Get-ChildItem -Path $SourcePath -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($SourcePath.Length).TrimStart("\")
        $targetFile = Join-Path -Path $TargetPath -ChildPath $relativePath

        if (Test-Path -Path $targetFile) {
            # Calculate hashes for both files
            try {
                $sourceHash = (Get-FileHash -Path $_.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                $targetHash = (Get-FileHash -Path $targetFile -Algorithm SHA256 -ErrorAction Stop).Hash

                # Get LastWriteTime for both files
                $sourceLastWrite = (Get-Item -Path $_.FullName).LastWriteTime
                $targetLastWrite = (Get-Item -Path $targetFile).LastWriteTime

                # Determine which file is newer
                if ($sourceLastWrite -gt $targetLastWrite) {
                    $newerFile = "Source"
                } elseif ($targetLastWrite -gt $sourceLastWrite) {
                    $newerFile = "Target"
                } else {
                    $newerFile = "Same"
                }
            } catch {
                Write-Warning "Failed to compute hash or retrieve timestamps for '$($_.FullName)' or '$targetFile': $_"
                return
            }

            if ($sourceHash -eq $targetHash) {
                # File is identical
                $identicalFiles += [PSCustomObject]@{
                    RelativePath  = $relativePath
                    SourceHash    = $sourceHash
                    TargetHash    = $targetHash
                    NewerFile     = $newerFile
                }
            } else {
                # File exists in target but has different content
                if ($newerFile -eq "Source") {
                    $conflictSourceNewer += [PSCustomObject]@{
                        RelativePath  = $relativePath
                        SourceHash    = $sourceHash
                        TargetHash    = $targetHash
                        NewerFile     = $newerFile
                    }
                } elseif ($newerFile -eq "Target") {
                    $conflictTargetNewer += [PSCustomObject]@{
                        RelativePath  = $relativePath
                        SourceHash    = $sourceHash
                        TargetHash    = $targetHash
                        NewerFile     = $newerFile
                    }
                } else {
                    # Same timestamp but different hashes
                    $conflictSourceNewer += [PSCustomObject]@{
                        RelativePath  = $relativePath
                        SourceHash    = $sourceHash
                        TargetHash    = $targetHash
                        NewerFile     = $newerFile
                    }
                }
            }
        }
    }

    # Return a custom object with conflict and identical files
    return [PSCustomObject]@{
        ConflictSourceNewer = $conflictSourceNewer
        ConflictTargetNewer = $conflictTargetNewer
        Identicals = $identicalFiles
    }
}

# TODO - Handle bizarre file conflict issues
function Copy-Profile {
<#
.SYNOPSIS
    Copy-Profile - Copies a profile from one location to another.

.DESCRIPTION
    Copy-Profile - Copies a profile from one location to another.

.PARAMETER SourcePath
    The path to the source profile directory.

.PARAMETER TargetPath
    The path to the target profile directory.
#>
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
    $maxRetries = 3
    $retryDelay = 2 # seconds

    Get-ChildItem -Path (Join-Path $SourcePath '*') -Recurse -File -Exclude '.git', '.gitignore', '.gitattributes' | ForEach-Object {
        $relativePath = $_.FullName.Substring($SourcePath.Length).TrimStart("\", "/")
        $targetFile = Join-Path -Path $TargetPath -ChildPath $relativePath

        for ($retry = 0; $retry -le $maxRetries; $retry++) {
            try {
                # Copy the file
                Copy-Item -Path $_.FullName -Destination $targetFile -Force -ErrorAction Stop

                # Confirm the copy by checking hash and LastWriteTime
                $sourceHash = (Get-FileHash -Path $_.FullName).Hash
                $targetHash = (Get-FileHash -Path $targetFile).Hash
                $sourceLastWrite = (Get-Item -Path $_.FullName).LastWriteTime
                (Get-Item -Path $targetFile).LastWriteTime = $sourceLastWrite

                # Break the retry loop if the hashes match
                if ($sourceHash -eq $targetHash) {
                    Write-Verbose "File '$relativePath' successfully copied and verified."
                    break
                } else {
                    throw "Verification failed for file '$relativePath'. Hashes do not match after copying."
                }

            } catch {
                # Log and retry on failure
                Write-Warning "Failed to copy '$relativePath' on attempt $($retry + 1) of $($maxRetries + 1): $_"

                if ($retry -eq $maxRetries) {
                    Write-Error "Max retries reached for '$relativePath'. File could not be copied."
                } else {
                    Start-Sleep -Seconds $retryDelay
                }
            }
        }
    }
}

function Sync-GithubProfiles {
<#
.SYNOPSIS
    Sync-GithubProfiles - Synchronizes GitHub profiles based on a configuration file.

.PARAMETER ConfigurationPath
    The path to the configuration file containing repository information.

.PARAMETER ProfilesPath
    The path to the directory containing the GitHub profiles.
#>
    [CmdletBinding()]
    param (
        [string]$ConfigurationPath = "$PSScriptRoot/config/github/profiles_github.json",
        [string]$ProfilesPath = "$PSScriptRoot/profiles"
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

    $overwriteFiles = @()

    # Process each profile
    foreach ($repo in $repos) {
        $sourcePath = Join-Path -Path $ProfilesPath -ChildPath $repo.RepoName
        $targetPath = [Environment]::ExpandEnvironmentVariables($repo.Dir)

        if (-not (Test-Path -Path $sourcePath)) {
            Write-Warning "Source path '$sourcePath' for profile '$($repo.Name)' does not exist. Skipping."
            continue
        }

        # Identify files that may overwrite or are identical
        $results = Test-FileConflicts -SourcePath $sourcePath -TargetPath $targetPath
        if ($results.ConflictSourceNewer.Count -gt 0 -or $results.ConflictTargetNewer.Count -gt 0 -or $results.Identicals.Count -gt 0) {
            $overwriteFiles += [PSCustomObject]@{
                ProfileName = $repo.Name
                SourcePath  = $sourcePath
                TargetPath  = $targetPath
                ConflictSourceNewer = $results.ConflictSourceNewer
                ConflictTargetNewer = $results.ConflictTargetNewer
                Identicals = $results.Identicals
            }
        }
    }

    # Initialize counters for conflicts and identicals
    $totalConflictsSourceNewer = 0
    $totalConflictsTargetNewer = 0
    $totalIdenticals = 0

    # Display conflict and identical files with hash details
    foreach ($profile in $overwriteFiles) {
        Write-Host "Profile: $($profile.ProfileName)" -ForegroundColor Cyan

        # Handle conflicts where Source is newer
        if ($profile.ConflictSourceNewer.Count -gt 0) {
            Write-Host "The following files may be overwritten (Source is newer):" -ForegroundColor Yellow
            foreach ($file in $profile.ConflictSourceNewer) {
                Write-Host " - $($file.RelativePath)" -ForegroundColor Red
                Write-Host "   Source Hash: $($file.SourceHash)" -ForegroundColor DarkRed
                Write-Host "   Target Hash: $($file.TargetHash)" -ForegroundColor DarkRed
                $totalConflictsSourceNewer++
            }
        }

        # Handle conflicts where Target is newer
        if ($profile.ConflictTargetNewer.Count -gt 0) {
            Write-Host "The following files have newer versions in the target:" -ForegroundColor Yellow
            foreach ($file in $profile.ConflictTargetNewer) {
                Write-Host " - $($file.RelativePath)" -ForegroundColor Cyan
                Write-Host "   Source Hash: $($file.SourceHash)" -ForegroundColor Cyan
                Write-Host "   Target Hash: $($file.TargetHash)" -ForegroundColor Cyan
                $totalConflictsTargetNewer++
            }
        }

        # Handle identical files
        if ($profile.Identicals.Count -gt 0) {
            Write-Host "The following files are identical and will not be overwritten:" -ForegroundColor Green
            foreach ($file in $profile.Identicals) {
                Write-Host " - $($file.RelativePath)" -ForegroundColor Green
                Write-Host "   Source Hash: $($file.SourceHash)" -ForegroundColor DarkGreen
                Write-Host "   Target Hash: $($file.TargetHash)" -ForegroundColor DarkGreen
                $totalIdenticals++
            }
        }
    }

    # First Prompt: Overwrite targets with source where source is newer
    if ($totalConflictsSourceNewer -gt 0) {
        $promptMessage1 = "$totalConflictsSourceNewer file(s) where the source is newer and may overwrite the target.`nDo you want to proceed with overwriting these files? [Y/N] :"
        $userResponse1 = Read-Prompt -Message $promptMessage1 -Prompt "YN" -Default "N"

        if ($userResponse1 -eq $true) {
            foreach ($profile in $overwriteFiles) {
                if ($profile.ConflictSourceNewer.Count -gt 0) {
                    try {
                        Copy-Profile -SourcePath $profile.SourcePath -TargetPath $profile.TargetPath -Verbose:$VerbosePreference
                        Write-Host "Profile '$($profile.ProfileName)' synchronized successfully to '$($profile.TargetPath)'." -ForegroundColor Green
                    } catch {
                        Write-Error "Failed to sync profile '$($profile.ProfileName)' (Source Overwrite): $_"
                    }
                }
            }
        } else {
            Write-Host "Overwriting target files with source was declined by the user." -ForegroundColor Cyan
        }
    }

    # Second Prompt: Overwrite source with target where target is newer
    if ($totalConflictsTargetNewer -gt 0) {
        $promptMessage2 = "$totalConflictsTargetNewer file(s) where the target is newer and may overwrite the source.`nDo you want to proceed with overwriting the source files with target files? [Y/N] :"
        $userResponse2 = Read-Prompt -Message $promptMessage2 -Prompt "YN" -Default "N"

        if ($userResponse2 -eq $true) {
            foreach ($profile in $overwriteFiles) {
                if ($profile.ConflictTargetNewer.Count -gt 0) {
                    try {
                        # Overwrite source with target
                        Copy-Profile -SourcePath $profile.TargetPath -TargetPath $profile.SourcePath -Verbose:$VerbosePreference
                        Write-Host "Profile '$($profile.ProfileName)' overwritten successfully from '$($profile.TargetPath)' to '$($profile.SourcePath)'." -ForegroundColor Green
                    } catch {
                        Write-Error "Failed to overwrite source for profile '$($profile.ProfileName)': $_"
                    }
                }
            }
        } else {
            Write-Host "Overwriting source files with target was declined by the user." -ForegroundColor Cyan
        }
    }

    # Inform the user about identical files (no action needed)
    if ($totalIdenticals -gt 0) {
        Write-Host "`nNote: $totalIdenticals file(s) are identical and were not overwritten." -ForegroundColor Green
    }

    # Final Message
    if ($totalConflictsSourceNewer -eq 0 -and $totalConflictsTargetNewer -eq 0 -and $totalIdenticals -eq 0) {
        Write-Host "No files require synchronization." -ForegroundColor Green
    }
}

Sync-GithubProfiles @PSBoundParameters
