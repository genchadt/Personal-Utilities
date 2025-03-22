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
            '[sS](\d{1,2})[eE](\d{1,2}(?:-[eE]?\d{1,2})?)'
            # Season ## Episode ## format
            '(?i)season\s*(\d{1,2})\s*episode\s*(\d{1,2})'
            # ##x## format
            '(?i)(\d{1,2})x(\d{1,2}(?:-\d{1,2})?)'
            # S## Part/Pt ## format (for specials)
            '(?i)(?:S(\d{1,2}))?[\.\-_ ]?(?:Part|Pt)[\.\-_ ](\d+)'
            # E## format (implied season 1)
            '(?i)^(?:.*?)[\.\-_ ]?[eE](\d{1,2})[\.\-_ ]'
        ]
        ValidExtensions = @('.mp4', '.mkv', '.avi', '.m4v', '.mov', '.wmv', '.ts', '.m2ts', '.webm', '.srt', '.sub', '.idx', '.ass')
        LanguageCodes = @('en', 'eng', 'fr', 'fra', 'es', 'spa', 'de', 'deu', 'it', 'ita', 'ja', 'jpn', 'ko', 'kor', 'zh', 'zho')
        YearPattern = '(?:^|\D)(\d{4})(?:\D|$)'
        ResolutionPatterns = @(
            '(?i)(?<resolution>4k|2160p|1080p|720p|480p)'
            '(?i)(?<resolution>\d+x\d+)'
        )
        SpecialMarkers = @('special', 'ova', 'pilot', 'extra')
        RemovePatterns = @(
            # Release group tags
            '\[(?:[^\[\]]+)\]'
            # Common quality indicators
            '(?i)(?:HDTV|WEB-DL|BRRip|BluRay|DVDRip)'
            # Technical specs
            '(?i)(?:x264|x265|HEVC|AAC|AC3|DTS)'
            # Other common noise in filenames
            '(?i)(?:REPACK|PROPER|RERIP)'
        )
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
        
        foreach ($p in $Path) {
            # Handle wildcards and file/directory distinction
            if ((Test-Path -Path $p -PathType Container) -or ($p -match '\*')) {
                $searchParams = @{
                    Path = $p
                    File = $true
                    ErrorAction = 'SilentlyContinue'
                }
                
                if ($Recurse) {
                    $searchParams['Recurse'] = $true
                }
                
                $foundFiles = Get-ChildItem @searchParams | 
                    Where-Object { $_.Extension -in $config.ValidExtensions }
                
                $files += $foundFiles
            }
            else {
                # Handle individual file
                try {
                    $file = Get-Item -Path $p -ErrorAction Stop
                    if ($file.Extension -in $config.ValidExtensions) {
                        $files += $file
                    }
                }
                catch {
                    Write-Warning "Could not access path: $p - $_"
                }
            }
        }
        
        return $files
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
        
        # Remove known noise patterns
        foreach ($pattern in $config.RemovePatterns) {
            $result = $result -replace $pattern, ''
        }
        
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
            if ($FileName -match $pattern) {
                return $Matches.resolution
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

    function Rename-WithRetry {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [string]$Path,
            [string]$NewName,
            [int]$MaxRetries = 3,
            [int]$DelaySeconds = 2
        )
        
        $retryCount = 0
        $success = $false
        $lastError = $null

        while (-not $success -and $retryCount -lt $MaxRetries) {
            try {
                if ($PSCmdlet.ShouldProcess($Path, "Rename to $NewName")) {
                    Rename-Item -Path $Path -NewName $NewName -ErrorAction Stop
                    $success = $true
                }
                else {
                    return $true # WhatIf mode, just report success
                }
            }
            catch {
                $lastError = $_
                $retryCount++
                
                if ($retryCount -lt $MaxRetries) {
                    Write-Verbose "Retry $($retryCount/$MaxRetries): Failed to rename '$Path' to '$NewName'. Waiting $DelaySeconds seconds..."
                    Start-Sleep -Seconds $DelaySeconds
                }
            }
        }
        
        if (-not $success) {
            Write-Error "Failed to rename '$Path' to '$NewName' after $MaxRetries attempts: $lastError"
            return $false
        }
        
        return $true
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
    # Get files to process
    $files = Get-VideoFiles -Path $Path -Recurse:$Recurse
    $totalFiles = $files.Count
    
    if ($totalFiles -eq 0) {
        Write-Warning "No valid video files found with extensions: $($config.ValidExtensions -join ', ')"
        return
    }
    
    Write-Host "Found $totalFiles files to process" -ForegroundColor Green
    
    # Track files that need to be processed in a separate pass (for subtitles that match video files)
    $secondPassFiles = @()
    
    # Process each file
    $fileCounter = 0
    foreach ($file in $files) {
        $fileCounter++
        $originalFileName = $file.Name
        $percentComplete = [math]::Round(($fileCounter / $totalFiles) * 100)
        
        Write-Progress -Activity "Processing Files" -Status "$fileCounter of $totalFiles - $originalFileName" `
            -PercentComplete $percentComplete
        
        Write-Verbose "[$fileCounter/$totalFiles] Processing: $originalFileName"
        
        # Skip subtitle files for the first pass (they will be handled with their corresponding video files)
        $isSubtitle = $file.Extension -in @('.srt', '.sub', '.idx', '.ass')
        if ($isSubtitle) {
            # Check if this might be related to a video we'll process
            $possibleVideoName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            # Remove potential language code suffix
            $possibleVideoName = $possibleVideoName -replace "\.([$($config.LanguageCodes -join '|')])\s*$", ""
            
            $matchingVideo = $files | Where-Object { 
                $_.Extension -notin @('.srt', '.sub', '.idx', '.ass') -and 
                [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -eq $possibleVideoName 
            }
            
            if ($matchingVideo) {
                # Will process this with the matching video
                $secondPassFiles += $file
                continue
            }
        }
        
        $stats.Processed++
        $extension = $file.Extension.ToLower()
        $matched = $false
        $season = "01"  # Default to Season 1
        $episode = "01" # Default to Episode 1
        $isSpecial = $false
        $showName = $null
        $year = $null
        $resolution = $null
        
        # Check if file contains "special" markers
        foreach ($marker in $config.SpecialMarkers) {
            if ($originalFileName -match "(?i)$marker") {
                $isSpecial = $true
                break
            }
        }
        
        # Extract additional information
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($originalFileName)
        $year = Extract-Year -FileName $baseName
        
        if ($PreserveResolution) {
            $resolution = Extract-Resolution -FileName $baseName
        }
        
        # Find matching pattern for season/episode info
        foreach ($pattern in $config.SeasonEpisodePatterns) {
            if ($baseName -match $pattern) {
                if ($matches.Count -gt 2) {
                    $season = $matches[1].ToString().PadLeft(2, '0')
                    $episode = $matches[2].ToString().PadLeft(2, '0')
                }
                else {
                    # For patterns where season might be implicit (like E01)
                    $episode = $matches[1].ToString().PadLeft(2, '0')
                }
                
                # Extract show name (everything before the pattern match)
                $showNameRaw = ($baseName -split $pattern)[0]
                $matched = $true
                break
            }
        }
        
        # If marked as special and not matched, set season to 00
        if ($isSpecial -and -not $matched) {
            $season = "00"
            # Try to extract just an episode number
            if ($baseName -match "(?i)(?:ep|episode|#)?(\d{1,2})") {
                $episode = $matches[1].ToString().PadLeft(2, '0')
                $showNameRaw = ($baseName -split "(?i)(?:ep|episode|#)?$episode")[0]
                $matched = $true
            }
            else {
                $showNameRaw = $baseName
                $matched = $true
            }
        }
        
        if (-not $matched) {
            Write-Warning "[$fileCounter/$totalFiles] Could not parse season/episode information from: $originalFileName"
            $stats.Skipped++
            continue
        }
        
        # Process show name
        $showName = Format-ShowName -Name $showNameRaw -TitleCase:$TitleCase -IgnorePunctuation:$IgnorePunctuation
        
        if ([string]::IsNullOrWhiteSpace($showName)) {
            Write-Warning "[$fileCounter/$totalFiles] Show name would be empty after formatting: $originalFileName"
            $stats.Skipped++
            continue
        }
        
        # Build new filename
        $newBaseName = if ($isSpecial) {
            "${showName} - Special S${season}E${episode}"
        }
        else {
            "${showName} S${season}E${episode}"
        }
        
        # Add year if available
        if ($year) {
            $newBaseName += " ($year)"
        }
        
        # Add resolution if available and requested
        if ($resolution -and $PreserveResolution) {
            $newBaseName += " [$resolution]"
        }
        
        # Handle subtitles with language codes
        $newFileName = if ($isSubtitle) {
            $langCode = "en" # Default language
            
            # Extract language code if present
            $langPattern = "\.($($config.LanguageCodes -join '|'))\s*$"
            if ($baseName -match $langPattern) {
                $langCode = $matches[1]
            }
            
            "${newBaseName}.${langCode}${extension}"
        }
        else {
            "${newBaseName}${extension}"
        }
        
        # Ensure filename is valid
        $newFileName = Get-ValidFileName -FileName $newFileName
        
        # Determine target path
        $targetDir = if ($MoveToSeasonFolders) {
            New-SeasonFolder -BasePath $file.DirectoryName -Season $season
        }
        else {
            $file.DirectoryName
        }
        
        $newPath = Join-Path $targetDir $newFileName
        
        # Check if target file already exists
        if ((Test-Path $newPath) -and -not $Force -and ($file.FullName -ne $newPath)) {
            Write-Warning "[$fileCounter/$totalFiles] Cannot rename '$originalFileName' - '$newFileName' already exists"
            $stats.Skipped++
            continue
        }
        
        # Skip if no change needed
        if ($file.Name -eq $newFileName -and $file.DirectoryName -eq $targetDir) {
            Write-Verbose "[$fileCounter/$totalFiles] File '$originalFileName' already has the correct name"
            $stats.Skipped++
            continue
        }
        
        # Perform the rename/move
        try {
            $operationDesc = if ($file.DirectoryName -ne $targetDir) {
                "Move and rename to $newFileName in $targetDir"
            }
            else {
                "Rename to $newFileName"
            }
            
            if ($PSCmdlet.ShouldProcess($originalFileName, $operationDesc)) {
                # For move operations
                if ($file.DirectoryName -ne $targetDir) {
                    if (-not (Test-Path $targetDir)) {
                        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                    }
                    
                    if ($file.Name -eq $newFileName) {
                        # Just move, no rename
                        Move-Item -Path $file.FullName -Destination $targetDir -Force:$Force
                        $stats.Moved++
                    }
                    else {
                        # Move and rename
                        Move-Item -Path $file.FullName -Destination $newPath -Force:$Force
                        $stats.Renamed++
                        $stats.Moved++
                    }
                }
                else {
                    # Just rename
                    $success = Rename-WithRetry -Path $file.FullName -NewName $newFileName -MaxRetries $config.MaxRetries -DelaySeconds $config.RetryDelaySeconds
                    if ($success) {
                        $stats.Renamed++
                    }
                    else {
                        $stats.Errors++
                    }
                }
                
                # Report success
                Write-Host "[$fileCounter/$totalFiles] " -NoNewline
                Write-Host "SUCCESS: " -ForegroundColor Green -NoNewline
                Write-Host "'$originalFileName' → '$newFileName'"
                
                # Process related subtitle files if this is a video file
                if ($extension -notin @('.srt', '.sub', '.idx', '.ass')) {
                    $relatedSubs = $secondPassFiles | Where-Object { 
                        [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -eq [System.IO.Path]::GetFileNameWithoutExtension($originalFileName) -or
                        [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -match "^$([regex]::Escape([System.IO.Path]::GetFileNameWithoutExtension($originalFileName)))\.([$($config.LanguageCodes -join '|')])\s*$"
                    }
                    
                    foreach ($sub in $relatedSubs) {
                        $langCode = "en" # Default
                        $subName = [System.IO.Path]::GetFileNameWithoutExtension($sub.Name)
                        
                        # Extract language code if present
                        if ($subName -match "\.([$($config.LanguageCodes -join '|')])\s*$") {
                            $langCode = $matches[1]
                        }
                        
                        $newSubName = "${newBaseName}.${langCode}$($sub.Extension)"
                        $newSubName = Get-ValidFileName -FileName $newSubName
                        $newSubPath = Join-Path $targetDir $newSubName
                        
                        if ($PSCmdlet.ShouldProcess($sub.Name, "Move and rename to $newSubName")) {
                            try {
                                Move-Item -Path $sub.FullName -Destination $newSubPath -Force:$Force
                                $stats.Renamed++
                                Write-Host "[$fileCounter/$totalFiles] " -NoNewline
                                Write-Host "SUCCESS: " -ForegroundColor Green -NoNewline
                                Write-Host "Subtitle '$($sub.Name)' → '$newSubName'"
                            }
                            catch {
                                Write-Error "Failed to process subtitle '$($sub.Name)': $_"
                                $stats.Errors++
                            }
                        }
                        
                        # Remove from second pass list
                        $secondPassFiles = $secondPassFiles | Where-Object { $_.FullName -ne $sub.FullName }
                    }
                }
            }
        }
        catch {
            Write-Error "[$fileCounter/$totalFiles] Failed to rename '$originalFileName': $_"
            $stats.Errors++
        }
    }
    
    # Handle any remaining subtitle files that weren't processed with their videos
    foreach ($subFile in $secondPassFiles) {
        $stats.Processed++
        Write-Verbose "Processing orphaned subtitle: $($subFile.Name)"
        
        # Use the same logic as for regular files, but ensure we mark it as a subtitle
        # (This is a simplified version - in a real script you might want to consolidate this logic)
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($subFile.Name)
        $matched = $false
        
        # Try to extract show info from subtitle name
        foreach ($pattern in $config.SeasonEpisodePatterns) {
            if ($baseName -match $pattern) {
                $season = if ($matches.Count -gt 2) { $matches[1].ToString().PadLeft(2, '0') } else { "01" }
                $episode = $matches[-1].ToString().PadLeft(2, '0')
                $showNameRaw = ($baseName -split $pattern)[0]
                $matched = $true
                break
            }
        }
        
        if (-not $matched) {
            Write-Warning "Could not parse info from orphaned subtitle: $($subFile.Name)"
            $stats.Skipped++
            continue
        }
        
        # Process and rename subtitle (similar to main file processing)
        $showName = Format-ShowName -Name $showNameRaw -TitleCase:$TitleCase -IgnorePunctuation:$IgnorePunctuation
        $year = Extract-Year -FileName $baseName
        
        $newBaseName = "${showName} S${season}E${episode}"
        if ($year) { $newBaseName += " ($year)" }
        
        $langCode = "en" # Default
        if ($baseName -match "\.([$($config.LanguageCodes -join '|')])\s*$") {
            $langCode = $matches[1]
        }
        
        $newFileName = "${newBaseName}.${langCode}$($subFile.Extension)"
        $newFileName = Get-ValidFileName -FileName $newFileName
        
        $targetDir = if ($MoveToSeasonFolders) {
            New-SeasonFolder -BasePath $subFile.DirectoryName -Season $season
        }
        else {
            $subFile.DirectoryName
        }
        
        $newPath = Join-Path $targetDir $newFileName
        
        if ((Test-Path $newPath) -and -not $Force -and ($subFile.FullName -ne $newPath)) {
            Write-Warning "Cannot rename orphaned subtitle '$($subFile.Name)' - '$newFileName' already exists"
            $stats.Skipped++
            continue
        }
        
        try {
            if ($PSCmdlet.ShouldProcess($subFile.Name, "Rename orphaned subtitle to $newFileName")) {
                if ($subFile.DirectoryName -ne $targetDir) {
                    if (-not (Test-Path $targetDir)) {
                        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                    }
                    Move-Item -Path $subFile.FullName -Destination $newPath -Force:$Force
                    $stats.Moved++
                    $stats.Renamed++
                }
                else {
                    $success = Rename-WithRetry -Path $subFile.FullName -NewName $newFileName -MaxRetries $config.MaxRetries -DelaySeconds $config.RetryDelaySeconds
                    if ($success) {
                        $stats.Renamed++
                    }
                    else {
                        $stats.Errors++
                    }
                }
                
                Write-Host "Renamed orphaned subtitle '$($subFile.Name)' to '$newFileName'" -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Failed to rename orphaned subtitle '$($subFile.Name)': $_"
            $stats.Errors++
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
