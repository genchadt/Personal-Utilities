[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string]$Path = ".",

    [Parameter()]
    [Alias("TC")]
    [switch]$TitleCase,

    [Parameter()]
    [Alias("IP")]
    [switch]$IgnorePunctuation
)

function Convert-VideoFileName {
<#
.SYNOPSIS
    Converts video filenames to a standardized format.

.PARAMETER Path
    Path to a file or directory containing video files. Defaults to current directory.

.PARAMETER TitleCase
    Capitalizes the first letter of each word in the show name.

.PARAMETER IgnorePunctuation
    Removes punctuation from the show name.

.PARAMETER WhatIf
    Shows what would happen if the script runs without actually making changes.

.EXAMPLE
    Convert-VideoFileName -Path "C:\Videos" -TitleCase
    Processes all video files in C:\Videos and capitalizes first letter of each word.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Path = ".",

        [Parameter()]
        [Alias("TC")]
        [switch]$TitleCase,

        [Parameter()]
        [Alias("IP")]
        [switch]$IgnorePunctuation
    )

    begin {
        # Configuration
        $Config = @{
            SeasonEpisodePatterns = @(
                '[sS](\d{1,2})[eE](\d{1,2})'
                '[sS](\d{1,2})\s*[eE][pP]\s*(\d{1,2})'
                '(?i)season\s*(\d{1,2})\s*episode\s*(\d{1,2})'
                '(?i)(\d{1,2})x(\d{1,2})'
            )
            ValidExtensions = @('.mp4', '.mkv', '.avi', '.srt', '.sub')
            LanguageCodes  = @('en', 'eng', 'fr', 'fra', 'es', 'spa', 'de', 'deu')
        }

        # Logging
        try {
            if (-not (Test-Path -Path "$PSScriptRoot\logs" -PathType Container)) {
                New-Item -Path "$PSScriptRoot\logs" -ItemType Directory | Out-Null
            }
            $LogFilePath = Join-Path $PSScriptRoot "logs\$($MyInvocation.MyCommand.Name)_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
            Start-Transcript -Path $LogFilePath | Out-Null
        } catch {
            Write-Error "Failed to start transcript: $_"
        }
    }

    process {
        # Get video files
        $files = if (Test-Path -Path $Path -PathType Container) {
            Get-ChildItem -Path $Path -File | Where-Object { $_.Extension -in $Config.ValidExtensions }
        }
        else {
            Get-Item -Path $Path
        }

        if (-not $files) {
            Write-Warning "No valid files found in path: $Path. Supported extensions: $($Config.ValidExtensions -join ', ')"
            return
        }

        Write-Verbose "Found $($files.Count) files to process"

        foreach ($file in $files) {
            $originalFileName = $file.Name
            Write-Verbose "Processing: $originalFileName"
            
            $extension = $file.Extension.ToLower()
            $matched = $false

            # Find matching pattern and extract info
            foreach ($pattern in $Config.SeasonEpisodePatterns) {
                if ($originalFileName -match $pattern) {
                    $season = $matches[1].PadLeft(2, '0')
                    $episode = $matches[2].PadLeft(2, '0')
                    $showName = ($originalFileName -split $pattern)[0]
                    $matched = $true
                    break
                }
            }

            if (-not $matched) {
                Write-Warning "Could not parse season/episode information from $originalFileName."
                continue
            }

            # Ignore punctuation if requested
            if (-not $IgnorePunctuation) {
                $showName = $showName -replace '[\.\-_]', ' '
                $showName = $showName -replace '\s+', ' '
                $showName = $showName.Trim()
            }

            # Apply title case if requested
            if ($TitleCase) {
                $textInfo = (Get-Culture).TextInfo
                $showName = $textInfo.ToTitleCase($showName)
            }

            $newFileName = if ($extension -eq '.srt') {
                $langCode = if ($originalFileName -match "\.($($Config.LanguageCodes -join '|'))[\.|$]") {
                    $matches[1]
                }
                else { 'en' }
                "$showName S${season}E${episode}.${langCode}${extension}"
            }
            else {
                "$showName S${season}E${episode}${extension}"
            }

            # Validate new filename
            if (-not ($newFileName -match '^[\w\s\-\.\(\)]+$')) {
                Write-Warning "Invalid characters in new filename: $newFileName"
                continue
            }

            $newPath = Join-Path $file.DirectoryName $newFileName

            if (Test-Path $newPath) {
                Write-Warning "Cannot rename '$originalFileName' - '$newFileName' already exists"
                continue
            }

            if ($PSCmdlet.ShouldProcess($originalFileName, "Rename to $newFileName")) {
                try {
                    Rename-Item -Path $file.FullName -NewName $newFileName
                    Write-Information "Renamed '$originalFileName' to '$newFileName'" -InformationAction Continue
                } catch {
                    Write-Error "Failed to rename '$originalFileName' to '$newFileName': $_ (Full path: $($file.FullName))"
                }
            }
            else {
                Write-Verbose "WhatIf: Would rename '$originalFileName' to '$newFileName'"
            }
        }
    }

    end {
        Stop-Transcript
    }
}

Convert-VideoFileName @PSBoundParameters