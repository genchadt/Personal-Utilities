function Convert-VideoFileName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Path = ".",
        
        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )

    # Regular expression patterns for matching season and episode
    $seasonEpisodePatterns = @(
        'S(\d{1,2})E(\d{1,2})'
        's(\d{1,2})e(\d{1,2})'
        's(\d{1,2})ep(\d{1,2})'
        's(\d{1,2})\s*ep\s*(\d{1,2})'  # Added space handling
        'season\s*(\d{1,2})\s*episode\s*(\d{1,2})'
        '(\d{1,2})x(\d{1,2})'
    )

    # Supported file extensions
    $validExtensions = @('.mp4', '.mkv', '.avi', '.srt', '.sub')

    # Get all files if Path is a directory
    $files = if (Test-Path -Path $Path -PathType Container) {
        Get-ChildItem -Path $Path -File | Where-Object { $_.Extension -in $validExtensions }
    }
    else {
        Get-Item -Path $Path -ErrorAction SilentlyContinue
    }

    if (-not $files) {
        Write-Warning "No valid files found in path: $Path"
        return
    }

    Write-Host "Found $($files.Count) files to process"

    foreach ($file in $files) {
        $originalName = $file.Name
        Write-Host "Processing: $originalName"
        
        $extension = $file.Extension.ToLower()

        # Initialize variables
        $showName = $null
        $season = $null
        $episode = $null
        $matched = $false

        # Find first matching pattern
        foreach ($pattern in $seasonEpisodePatterns) {
            if ($originalName -match $pattern) {
                $season = $matches[1]
                $episode = $matches[2]
                $showName = ($originalName -split $pattern)[0]
                $matched = $true
                Write-Host "Matched pattern: $pattern"
                Write-Host "Season: $season, Episode: $episode"
                break
            }
        }

        if (-not $matched) {
            Write-Warning "Could not parse season/episode information from $originalName"
            continue
        }

        # Clean up show name
        $showName = $showName -replace '[\.\-_]', ' '
        $showName = $showName -replace '\s+', ' '
        $showName = $showName.Trim()

        # Pad season and episode numbers
        $season = $season.PadLeft(2, '0')
        $episode = $episode.PadLeft(2, '0')

        # Construct new filename
        $newName = if ($extension -eq '.srt') {
            $langCode = if ($originalName -match '\.(en|eng|fr|fra|es|spa|de|deu)[\.|$]') {
                $matches[1]
            }
            else {
                'en'
            }
            "$showName S${season}E${episode}.${langCode}${extension}"
        }
        else {
            "$showName S${season}E${episode}${extension}"
        }

        $newPath = Join-Path $file.DirectoryName $newName

        # Handle file rename
        if ($WhatIf) {
            Write-Host "Would rename '$originalName' to '$newName'"
            continue
        }

        if (Test-Path $newPath) {
            Write-Warning "Cannot rename '$originalName' - '$newName' already exists"
            continue
        }

        try {
            Rename-Item -Path $file.FullName -NewName $newName
            Write-Host "Renamed '$originalName' to '$newName'"
        }
        catch {
            Write-Error "Failed to rename '$originalName': $_"
        }
    }
}
Set-Alias -Name Format-VideoFilename -Value Convert-VideoFileName

Format-VideoFilename @PSBoundParameters