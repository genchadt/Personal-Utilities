<#
.SYNOPSIS
    Standardizes video filenames using consistent patterns and formatting.

.DESCRIPTION
    Convert-VideoFileName processes video files to standardize their filenames
    following TV show naming conventions (ShowName S01E02 format).
    It supports various input formats, handles subtitles, preserves year information,
    and can process entire directories of files recursively.

.PARAMETER Path
    Path to video file(s) or directory containing video files. Defaults to current directory.
    Supports wildcards and pipeline input.

.PARAMETER TitleCase
    Capitalizes the first letter of each word in the show name.

.PARAMETER IgnorePunctuation
    Preserves punctuation in show names instead of converting to spaces.

.PARAMETER Recurse
    Process subdirectories recursively.

.PARAMETER PreserveResolution
    Keep resolution info (e.g., 1080p, 720p) in the filename if detected.

.PARAMETER ConfigPath
    Path to custom configuration JSON file. If not specified, uses default settings.

.PARAMETER LogPath
    Path to save log file. If not specified, logs are created in a 'logs' subfolder.

.PARAMETER MoveToSeasonFolders
    Organize files into season folders (Season 01, Season 02, etc.)

.PARAMETER Force
    Overwrite existing files with the same target name.

.EXAMPLE
    Convert-VideoFileName -Path "C:\Videos" -TitleCase -Recurse
    Processes all video files in C:\Videos and its subdirectories, applying title case to show names.

.EXAMPLE
    Get-ChildItem -Path "D:\TV Shows\*.mkv" | Convert-VideoFileName -PreserveResolution
    Renames all MKV files in the TV Shows folder, preserving resolution information.

.EXAMPLE
    Convert-VideoFileName -Path "C:\Unsorted" -MoveToSeasonFolders
    Renames files and organizes them into season folders.

.NOTES
    Author: AI Assistant
    Version: 2.0
    Last Updated: February 27, 2025
#>

[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Path')]
param (
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Path')]
    [Alias("FullName")]
    [string[]]$Path = ".",

    [Parameter()]
    [Alias("TC")]
    [switch]$TitleCase,

    [Parameter()]
    [Alias("IP")]
    [switch]$IgnorePunctuation,

    [Parameter()]
    [Alias("R")]
    [switch]$Recurse,

    [Parameter()]
    [Alias("PR")]
    [switch]$PreserveResolution,

    [Parameter()]
    [Alias("Config")]
    [string]$ConfigPath,

    [Parameter()]
    [string]$LogPath,

    [Parameter()]
    [Alias("Season", "SF")]
    [switch]$MoveToSeasonFolders,

    [Parameter()]
    [Alias("F")]
    [switch]$Force
)

begin {
    #region Configuration Loading
    # Default configuration
    $defaultConfig = @{
        SeasonEpisodePatterns = @(
            # Standard S##E## format
            '[sS](\d{1,2})[eE](\d{1,2}(?:-[eE]?\d{1,2})?)',
            # Season ## Episode ## format
            '(?i)season\s*(\d{1,2})\s*episode\s*(\d{1,2})',
            # ##x## format
            '(?i)(\d{1,2})x(\d{1,2}(?:-\d{1,2})?)',
            # S## Part/Pt ## format (for specials)
            '(?i)(?:S(\d{1,2}))?[\.\-_ ]?(?:Part|Pt)[\.\-_ ](\d+)',
            # E## format (implied season 1)
            '(?i)[\.\-_ ]?[eE](\d{1,2})[\.\-_ ]?'
        )
        ValidVideoExtensions = @('.mp4', '.mkv', '.avi', '.m4v', '.mov', '.wmv', '.ts', '.m2ts', '.webm')
        ValidSubtitleExtensions = @('.srt', '.sub', '.idx', '.ass')
        LanguageCodes = @('en', 'eng', 'fr', 'fra', 'es', 'spa', 'de', 'deu', 'it', 'ita', 'ja', 'jpn', 'ko', 'kor', 'zh', 'zho')
        YearPattern = '(?:^|\D)(\d{4})(?:\D|$)'
        ResolutionPatterns = @(
            '(?i)(?<resolution>4k|2160p|1080p|720p|480p)',
            '(?i)(?<resolution>\d+x\d+)'
        )
        SpecialMarkers = @('special', 'ova', 'pilot', 'extra')
        # Combined pattern for faster removal
        RemovePattern = '\[(?:[^\[\]]+)\]|(?i)(?:HDTV|WEB-DL|BRRip|BluRay|DVDRip|x264|x265|HEVC|AAC|AC3|DTS|REPACK|PROPER|RERIP)'
        MaxFilenameLength = 240 # To avoid path length issues
        MaxRetries = 3
        RetryDelaySeconds = 2
    }

    # Load custom configuration if provided
    $config = $defaultConfig.Clone()
    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        try {
            $customConfig = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            foreach ($key in $customConfig.Keys) {
                $config[$key] = $customConfig[$key]
            }
            Write-Verbose "Loaded custom configuration from $ConfigPath"
        }
        catch {
            Write-Warning "Failed to load custom configuration: $_"
            Write-Warning "Using default configuration"
        }
    }
    $config.ValidExtensions = $config.ValidVideoExtensions + $config.ValidSubtitleExtensions
    #endregion Configuration Loading

    #region Setup Logging
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    if (-not $LogPath) {
        $logDir = Join-Path $PSScriptRoot "logs"
        if (-not (Test-Path -Path $logDir -PathType Container)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        # Cleanup old logs (keep last 10)
        Get-ChildItem -Path $logDir -Filter "*.log" | Sort-Object LastWriteTime -Descending |
            Select-Object -Skip 10 | Remove-Item -Force

        $LogPath = Join-Path $logDir "VideoFileRename_$timestamp.log"
    }

    try {
        Start-Transcript -Path $LogPath -ErrorAction Stop
        Write-Host "Video File Rename Operation Started at $(Get-Date)" -ForegroundColor Cyan
        Write-Host "---------------------------------------------------" -ForegroundColor Cyan
    }
    catch {
        Write-Error "Failed to start transcript: $_"
    }
    #endregion Setup Logging

    #region Helper Functions
    function Get-VideoFiles {
        [CmdletBinding()]
        param (
            [string[]]$Path,
            [switch]$Recurse
        )

        $files = @()
        $searchParams = @{
            File        = $true
            ErrorAction = 'SilentlyContinue'
        }
        if ($Recurse) {
            $searchParams['Recurse'] = $true
        }

        foreach ($p in $Path) {
            try {
                $providerPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
                if (Test-Path -LiteralPath $providerPath -PathType Container) {
                    $searchParams.Path = $providerPath
                    $files += Get-ChildItem @searchParams
                }
                elseif ($p -match '[\*\?]') {
                    $searchParams.Path = $p
                    $files += Get-ChildItem @searchParams
                }
                else {
                    $files += Get-Item -LiteralPath $providerPath
                }
            }
            catch {
                Write-Warning "Could not access path: $p - $_"
            }
        }

        # Filter for valid extensions
        return $files | Where-Object { $_.Extension -in $config.ValidExtensions }
    }

    function Format-ShowName {
        [CmdletBinding()]
        param (
            [string]$Name,
            [switch]$TitleCase,
            [switch]$IgnorePunctuation
        )

        $result = $Name

        # Clean up show name
        if (-not $IgnorePunctuation) {
            $result = $result -replace '[\.\-_]', ' '
        }

        # Remove known noise patterns using the combined pattern
        $result = $result -replace $config.RemovePattern, ''

        # Clean up whitespace
        $result = $result -replace '\s+', ' '
        $result = $result.Trim()

        # Apply title case if requested
        if ($TitleCase) {
            $textInfo = (Get-Culture).TextInfo
            $result = $textInfo.ToTitleCase($result.ToLower())
        }

        return $result
    }

    function Extract-Year {
        [CmdletBinding()]
        param ([string]$FileName)
        
        $yearMatches = [regex]::Matches($FileName, $config.YearPattern)
        foreach ($match in $yearMatches) {
            $potentialYear = $match.Groups[1].Value
            if ($potentialYear -match '^\d{4}$') {
                $year = [int]$potentialYear
                # Validate the year is reasonable
                if ($year -ge 1900 -and $year -le ([DateTime]::Now.Year + 1)) {
                    return $year
                }
            }
        }
        return $null
    }

    function Extract-Resolution {
        [CmdletBinding()]
        param ([string]$FileName)

        foreach ($pattern in $config.ResolutionPatterns) {
            $match = [regex]::Match($FileName, $pattern)
            if ($match.Success) {
                return $match.Groups['resolution'].Value
            }
        }
        return $null
    }

    function Get-ValidFileName {
        [CmdletBinding()]
        param ([string]$FileName)
        
        # Replace invalid characters
        $invalidChars = [IO.Path]::GetInvalidFileNameChars()
        $result = $FileName
        foreach ($char in $invalidChars) {
            $result = $result.Replace($char, '_')
        }
        
        # Ensure length is valid
        if ($result.Length -gt $config.MaxFilenameLength) {
            $extension = [System.IO.Path]::GetExtension($result)
            $result = $result.Substring(0, $config.MaxFilenameLength - $extension.Length) + $extension
        }
        
        return $result
    }

    function Move-File {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [System.IO.FileInfo]$File,
            [string]$NewName,
            [string]$TargetDir,
            [switch]$Force
        )

        $newPath = Join-Path $TargetDir $NewName
        $originalPath = $File.FullName

        # Skip if no change is needed
        if ($originalPath -eq $newPath) {
            Write-Verbose "File '$($File.Name)' already has the correct name and location."
            return @{ Skipped = $true }
        }

        # Check for existing file at destination
        if ((Test-Path $newPath) -and -not $Force) {
            Write-Warning "Cannot process '$($File.Name)' - target '$NewName' already exists in destination."
            return @{ Skipped = $true }
        }

        $operationDesc = if ($File.DirectoryName -ne $TargetDir) {
            "Move and rename to '$NewName' in '$TargetDir'"
        }
        else {
            "Rename to '$NewName'"
        }

        if (-not $PSCmdlet.ShouldProcess($File.Name, $operationDesc)) {
            return @{ Skipped = $true }
        }

        try {
            # Ensure target directory exists
            if ($File.DirectoryName -ne $TargetDir -and -not (Test-Path $TargetDir)) {
                New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null
            }

            $moveParams = @{
                Path        = $originalPath
                Destination = $newPath
                Force       = $Force
                ErrorAction = 'Stop'
            }
            Move-Item @moveParams

            Write-Host "SUCCESS: '$($File.Name)' -> '$NewName'" -ForegroundColor Green
            $result = @{ Renamed = $true }
            if ($File.DirectoryName -ne $TargetDir) {
                $result.Moved = $true
            }
            return $result
        }
        catch {
            Write-Error "Failed to process '$($File.Name)': $_"
            return @{ Error = $true }
        }
    }

    function Parse-FileInfo {
        [CmdletBinding()]
        param (
            [System.IO.FileInfo]$File
        )

        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
        $info = @{
            OriginalFileName = $File.Name
            BaseName         = $baseName
            Extension        = $File.Extension.ToLower()
            IsSubtitle       = $File.Extension -in $config.ValidSubtitleExtensions
            ShowName         = $null
            Season           = "01"
            Episode          = "01"
            Year             = $null
            Resolution       = $null
            IsSpecial        = $false
            Matched          = $false
        }

        # Check for special markers
        foreach ($marker in $config.SpecialMarkers) {
            if ($info.BaseName -match "(?i)$marker") {
                $info.IsSpecial = $true
                break
            }
        }

        # Extract Year and Resolution
        $info.Year = Extract-Year -FileName $info.BaseName
        if ($PreserveResolution) {
            $info.Resolution = Extract-Resolution -FileName $info.BaseName
        }

        # Find matching pattern for season/episode info
        foreach ($pattern in $config.SeasonEpisodePatterns) {
            if ($info.BaseName -match $pattern) {
                if ($matches.Count -gt 2) {
                    $info.Season = $matches[1].ToString().PadLeft(2, '0')
                    $info.Episode = $matches[2].ToString().PadLeft(2, '0')
                }
                else {
                    $info.Episode = $matches[1].ToString().PadLeft(2, '0')
                }
                $info.ShowName = ($info.BaseName -split $pattern)[0]
                $info.Matched = $true
                break
            }
        }

        # Handle specials that didn't match a standard pattern
        if ($info.IsSpecial -and -not $info.Matched) {
            $info.Season = "00"
            if ($info.BaseName -match "(?i)(?:ep|episode|#)?(\d{1,2})") {
                $info.Episode = $matches[1].ToString().PadLeft(2, '0')
                $info.ShowName = ($info.BaseName -split "(?i)(?:ep|episode|#)?$($info.Episode)")[0]
            }
            else {
                $info.ShowName = $info.BaseName
            }
            $info.Matched = $true
        }

        return $info
    }

    function New-SeasonFolder {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [string]$BasePath,
            [string]$Season
        )
        
        $seasonNumber = [int]$Season
        $seasonFolder = Join-Path $BasePath "Season $($seasonNumber.ToString().PadLeft(2, '0'))"
        
        if (-not (Test-Path $seasonFolder)) {
            if ($PSCmdlet.ShouldProcess($seasonFolder, "Create Season Folder")) {
                New-Item -Path $seasonFolder -ItemType Directory -Force | Out-Null
            }
        }
        
        return $seasonFolder
    }
    #endregion Helper Functions

    # Initialize statistics
    $stats = @{
        Processed = 0
        Renamed = 0
        Skipped = 0
        Errors = 0
        Moved = 0
    }
}

process {
    # Get and categorize files
    $allFiles = Get-VideoFiles -Path $Path -Recurse:$Recurse
    if ($allFiles.Count -eq 0) {
        Write-Warning "No valid files found with extensions: $($config.ValidExtensions -join ', ')"
        return
    }

    Write-Host "Found $($allFiles.Count) files to process." -ForegroundColor Green

    # Create a lookup for video files by their base name (without extension)
    $videoFilesMap = @{}
    $subtitleFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    foreach ($file in $allFiles) {
        if ($file.Extension -in $config.ValidVideoExtensions) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $videoFilesMap[$baseName] = $file
        }
        elseif ($file.Extension -in $config.ValidSubtitleExtensions) {
            $subtitleFiles.Add($file)
        }
    }

    # Process video files first
    $processedItems = @{} # To store new name info for subtitle matching
    $fileCounter = 0
    $totalToProcess = $videoFilesMap.Count + $subtitleFiles.Count

    foreach ($videoFile in $videoFilesMap.Values) {
        $fileCounter++
        Write-Progress -Activity "Processing Files" -Status "$fileCounter of $totalToProcess - $($videoFile.Name)" -PercentComplete (($fileCounter / $totalToProcess) * 100)
        Write-Verbose "[$fileCounter/$totalToProcess] Processing video: $($videoFile.Name)"
        $stats.Processed++

        $fileInfo = Parse-FileInfo -File $videoFile
        if (-not $fileInfo.Matched) {
            Write-Warning "[$fileCounter/$totalToProcess] Could not parse season/episode from: $($videoFile.Name)"
            $stats.Skipped++
            continue
        }

        $showName = Format-ShowName -Name $fileInfo.ShowName -TitleCase:$TitleCase -IgnorePunctuation:$IgnorePunctuation
        if ([string]::IsNullOrWhiteSpace($showName)) {
            Write-Warning "[$fileCounter/$totalToProcess] Show name is empty after formatting: $($videoFile.Name)"
            $stats.Skipped++
            continue
        }

        # Build new filename
        $newBaseName = if ($fileInfo.IsSpecial) {
            "$($showName) - Special S$($fileInfo.Season)E$($fileInfo.Episode)"
        }
        else {
            "$($showName) S$($fileInfo.Season)E$($fileInfo.Episode)"
        }
        if ($fileInfo.Year) { $newBaseName += " ($($fileInfo.Year))" }
        if ($fileInfo.Resolution) { $newBaseName += " [$($fileInfo.Resolution)]" }

        $newFileName = Get-ValidFileName -FileName ($newBaseName + $fileInfo.Extension)
        $processedItems[$fileInfo.BaseName] = $newBaseName # Store for subtitles

        $targetDir = if ($MoveToSeasonFolders) {
            New-SeasonFolder -BasePath $videoFile.DirectoryName -Season $fileInfo.Season
        }
        else {
            $videoFile.DirectoryName
        }

        $result = Move-File -File $videoFile -NewName $newFileName -TargetDir $targetDir -Force:$Force
        if ($result.Renamed) { $stats.Renamed++ }
        if ($result.Moved) { $stats.Moved++ }
        if ($result.Skipped) { $stats.Skipped++ }
        if ($result.Error) { $stats.Errors++ }
    }

    # Process subtitle files
    foreach ($subFile in $subtitleFiles) {
        $fileCounter++
        Write-Progress -Activity "Processing Files" -Status "$fileCounter of $totalToProcess - $($subFile.Name)" -PercentComplete (($fileCounter / $totalToProcess) * 100)
        Write-Verbose "[$fileCounter/$totalToProcess] Processing subtitle: $($subFile.Name)"
        $stats.Processed++

        $subBaseName = [System.IO.Path]::GetFileNameWithoutExtension($subFile.Name)
        $langCode = "en" # Default
        $langPattern = "\.($($config.LanguageCodes -join '|'))\s*$"
        $videoBaseName = $subBaseName
        if ($subBaseName -match $langPattern) {
            $langCode = $matches[1]
            $videoBaseName = $subBaseName -replace $langPattern, ''
        }

        if ($processedItems.ContainsKey($videoBaseName)) {
            # Matched a video that was processed
            $newBaseName = $processedItems[$videoBaseName]
            $newFileName = Get-ValidFileName -FileName ("${newBaseName}.${langCode}$($subFile.Extension)")

            $fileInfo = Parse-FileInfo -File ($videoFilesMap[$videoBaseName])
            $targetDir = if ($MoveToSeasonFolders) {
                New-SeasonFolder -BasePath $subFile.DirectoryName -Season $fileInfo.Season
            }
            else {
                $subFile.DirectoryName
            }

            $result = Move-File -File $subFile -NewName $newFileName -TargetDir $targetDir -Force:$Force
            if ($result.Renamed) { $stats.Renamed++ }
            if ($result.Moved) { $stats.Moved++ }
            if ($result.Skipped) { $stats.Skipped++ }
            if ($result.Error) { $stats.Errors++ }
        }
        else {
            # Orphaned subtitle
            Write-Warning "[$fileCounter/$totalToProcess] Orphaned subtitle (no matching video found): $($subFile.Name)"
            $stats.Skipped++
        }
    }
}

end {
    Write-Progress -Activity "Processing Files" -Completed

    # Print summary
    Write-Host "`n==== Operation Summary ====" -ForegroundColor Cyan
    Write-Host "Files processed: $($stats.Processed)" -ForegroundColor White
    Write-Host "Files renamed:   $($stats.Renamed)" -ForegroundColor Green
    if ($stats.Moved -gt 0) {
        Write-Host "Files moved:     $($stats.Moved)" -ForegroundColor Green
    }
    Write-Host "Files skipped:   $($stats.Skipped)" -ForegroundColor Yellow
    if ($stats.Errors -gt 0) {
        Write-Host "Errors:          $($stats.Errors)" -ForegroundColor Red
    }

    Write-Host "`nLog file: $LogPath" -ForegroundColor Cyan
    Write-Host "---------------------------------------------------" -ForegroundColor Cyan

    try {
        Stop-Transcript
    }
    catch {
        Write-Error "Failed to stop transcript: $_"
    }
}
