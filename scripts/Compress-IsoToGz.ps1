<#
.SYNOPSIS
Compress-IsoToGz is a PowerShell script designed for processing and compressing various disc image files, such as .bin/.cue, into the .iso format and optionally compressing them into .gz files.

.DESCRIPTION
This script provides a versatile solution for converting and compressing disc image files. It can process .bin, .cue, and .iso files, allowing you to convert .bin/.cue pairs to .iso format and, if desired, further compress the resulting .iso files into .gz files. Ensure that 7-zip is installed!

.PARAMETER deleteSource
Deletes source files automatically without prompting.

.PARAMETER OnlyConvert
Performs conversion from .bin/.cue to .iso format without compression to .gz.

.PARAMETER VerboseMode
Displays detailed information about the operations performed by the script.

.PARAMETER Help
Displays this help message.

<filename1> <filename2> ...
Names of the files to be processed, which can include .bin, .cue, or .iso files.

.EXAMPLE
1. Convert and compress a .bin/.cue pair to .iso and .gz:
   .\Compress-IsoToGz.ps1 '.\Game (USA).bin'

.EXAMPLE
2. Convert a .bin/.cue pair to .iso without compression:
   .\Compress-IsoToGz.ps1 '.\Another Game (USA).bin' -OnlyConvert

.EXAMPLE
3. Compress an existing .iso file to .gz:
   .\Compress-IsoToGz.ps1 '.\Yet Another Game.iso'

.NOTES
    Administrative privileges are required to run this script.
    7-zip is required to run this script - see https://www.7-zip.org

    Script Version: 1.0
    Author: Chad
    Creation Date: 2023-12-07 03:30:00 GMT
#>

param (
    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$FileNames,
    [switch]$deleteSource,
    [switch]$OnlyConvert,
    [switch]$VerboseMode,
    [switch]$Help
)

# If -Help is specified, display a help message and exit
if ($Help) {
    Write-Host "Usage: .\Compress-IsoToGz.ps1 [-deleteSource] [-OnlyConvert] [-VerboseMode] [-Help] <filename1> <filename2> ..."
    Write-Host "-deleteSource: Deletes source files automatically without prompting."
    Write-Host "-OnlyConvert: Converts .bin/.cue to .iso without compressing to .gz."
    Write-Host "-VerboseMode: Displays more details about the operations."
    Write-Host "-Help: Displays this help message."
    return
}

function Compress-File {
    param (
        [Parameter(Mandatory = $true)]
        [string]$file
    )

    $7zPath = "7z.exe"
    & $7zPath a -tgzip "$file.gz" $file
}

function ConvertBinCueToISO {
    param (
        [Parameter(Mandatory = $true)]
        [string]$binFile,
        [Parameter(Mandatory = $true)]
        [string]$cueFile
    )

    try {
        $binFilePath = Join-Path -Path (Split-Path -Path $cueFile) -ChildPath $binFile

        if (-Not (Test-Path -Path $binFilePath -Type Leaf)) {
            Write-Host "Could not find the .bin file: $binFilePath"
            return $null
        }

        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($cueFile)
        $null = & bchunk "$binFilePath" "$cueFile" "$baseName"

        $convertedIso = "${baseName}01.iso"
        $expectedIso = "${baseName}.iso"

        if (Test-Path -Path $expectedIso -Type Leaf) {
            $response = Read-Host "The file $expectedIso already exists. Do you want to overwrite? (y/n)"
            if ($response -ne 'y') {
                Write-Host "Skipping conversion for $binFilePath due to existing file."
                return $null
            }
        }

        if (Test-Path -Path $convertedIso -Type Leaf) {
            $existingIso = "${baseName}.iso"
            if (Test-Path -Path $existingIso -Type Leaf) {
                # Generate a unique ISO file name
                $uniqueCounter = 1
                do {
                    $expectedIso = "${baseName}_${uniqueCounter}.iso"
                    $uniqueCounter++
                } while (Test-Path -Path $expectedIso -Type Leaf)
            } else {
                # The expected ISO file name is available, so use it
                $expectedIso = "${baseName}.iso"
            }

            Rename-Item -Path $convertedIso -NewName $expectedIso
            return $expectedIso
        } else {
            Write-Host "Conversion for $binFilePath failed or the resulting ISO is not in the expected location."
            return $null
        }
    } catch {
        Write-Host "An error occurred: $_"
        return $null
    }
}

function DeleteFiles {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$files
    )

    foreach ($file in $files) {
        if (Test-Path $file) {
            Remove-Item $file
        }
    }
}

function FindMatchingCue {
    param (
        [Parameter(Mandatory = $true)]
        [string]$binFile
    )

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($binFile)
    $cueFile = Get-ChildItem -Path ([System.IO.Path]::GetDirectoryName($binFile)) -Filter "$baseName.cue" | Select-Object -First 1

    if ($cueFile) {
        return $cueFile.FullName
    } else {
        return $null
    }
}

foreach ($file in $FileNames) {
    $filesToDelete = @()

    if ($file -match '\.bin$') {
        $cueFile = FindMatchingCue -binFile $file
        if (-not $cueFile) {
            # If the FindMatchingCue function doesn't find the cue file, try deducing its name
            $cueFile = $file -replace '\.bin$', '.cue'
        }
        
        if (Test-Path $cueFile) {
            if ($VerboseMode) { Write-Host "Matching .cue file found for ${file}: ${cueFile}" }
            $isoFile = ConvertBinCueToISO -binFile $file -cueFile $cueFile
            if ($isoFile -and (Test-Path $isoFile)) {
                if (-not $OnlyConvert) {
                    Compress-File -file $isoFile
                    $filesToDelete += $file, $cueFile, $isoFile
                } else {
                    if ($VerboseMode) { Write-Host "$file converted to ISO format successfully." }
                    $filesToDelete += $file, $cueFile
                }
            } else {
                Write-Error "Failed to convert $file to ISO or the path is not valid."
            }
        } else {
            Write-Error "Cue file for $file not found."
        }
    } elseif ($file -match '\.iso$' -and -not $OnlyConvert) {
        Compress-File -file $file
        $filesToDelete += $file
    } else {
        if ($VerboseMode) { Write-Host "File $file does not match expected formats or criteria." }
    }

    if ($filesToDelete.Count -gt 0) {
        if ($deleteSource) {
            DeleteFiles -files $filesToDelete
        } else {
            $response = Read-Host "Do you want to delete the source files? (y/n)"
            if ($response -eq 'y') {
                DeleteFiles -files $filesToDelete
            }
        }
    }
}
