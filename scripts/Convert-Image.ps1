[CmdletBinding()]
param (
    [Parameter()]
    [String]$Path,

    [Parameter()]
    [switch]$Recurse,

    [Parameter()]
    [string]$InputFormat,

    [Parameter()]
    [string]$OutputFormat,

    [Parameter()]
    [int]$ResolutionMultiplier,

    [Parameter()]
    [int]$Density,

    [Parameter()]
    [string]$Filter,

    [Parameter()]
    [int]$Quality,

    [Parameter()]
    [int]$CompressionLevel,

    [Parameter()]
    [string]$Sharpen
)

Import-Module "$PSScriptRoot/lib/Filesystem.psm1"

function Convert-Image {
<#
.SYNOPSIS
    Converts images from one format to another using ImageMagick.

.DESCRIPTION
    This script converts images from one format to another using ImageMagick.
    It supports various options such as resolution scaling, density, filter,
    quality, compression level, and sharpening.

.PARAMETER Path
    The path to the directory containing the images to convert. Defaults to the current directory.

.PARAMETER Recurse
    If specified, the script will search for images in all subdirectories.

.PARAMETER InputFormat
    The input image format. Defaults to "svg".

.PARAMETER OutputFormat
    The output image format. Defaults to "png".

.PARAMETER ResolutionMultiplier
    The resolution multiplier for resizing the image. Defaults to 1 (100%).

.PARAMETER Density
    The image density in dots per inch (DPI). Defaults to 300.

.PARAMETER Filter
    The filter to use for resizing the image. Defaults to "Lanczos".

.PARAMETER Quality
    The image quality (0-100). Defaults to 100.

.PARAMETER CompressionLevel
    The compression level for PNG images (0-9). Defaults to 9.

.PARAMETER Sharpen
    The sharpening factor for the image. Defaults to "0x0.5".
#>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$Path = $PWD,

        [Parameter()]
        [switch]$Recurse,

        [Parameter()]
        [ValidateSet("svg", "png", "jpg", "jpeg", "tiff", "bmp", "gif")]
        [string]$InputFormat = "svg",

        [Parameter()]
        [ValidateSet("svg", "png", "jpg", "jpeg", "tiff", "bmp", "gif")]
        [string]$OutputFormat = "png",

        [Parameter()]
        [int]$ResolutionMultiplier = 1,

        [Parameter()]
        [int]$Density = 300,

        [Parameter()]
        [string]$Filter = "Lanczos",

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$Quality = 100,

        [Parameter()]
        [ValidateRange(0, 9)]
        [int]$CompressionLevel = 9,

        [Parameter()]
        [string]$Sharpen = "0x0.5"
    )

    # Check if ImageMagick is installed
    if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
        Write-Error "Convert-Image: ImageMagick is not installed. Please install it before running this script."
        return
    }

    $inputFiles = Get-ChildItem -Path $Path -Filter "*.$InputFormat" -Recurse:$Recurse -ErrorAction SilentlyContinue

    if ($inputFiles.Count -eq 0) {
        Write-Host "No .$InputFormat files found in the current directory." -ForegroundColor Yellow
        return
    }

    # Create an array to store all conversion results
    $conversionResults = @()

    foreach ($file in $inputFiles) {
        $outputFileName = "$($file.BaseName).$OutputFormat"
        $resizeOption = "$($ResolutionMultiplier * 100)%"

        # Build arguments array
        $magickArgs = @(
            $file.FullName
            "-density"
            $Density
            "-resize"
            $resizeOption
            "-filter"
            $Filter
            "-quality"
            $Quality
            "-sharpen"
            $Sharpen
            "-background"
            "none"
        )

        if ($OutputFormat -eq "png") {
            $magickArgs += "-define"
            $magickArgs += "png:compression-level=$CompressionLevel"
        }

        $magickArgs += $outputFileName

        try {
            Write-Debug "Convert-Image: Invoking & magick $magickArgs"
            & magick $magickArgs

            # Add conversion result to array
            $properties = [ordered]@{
                'Input' = Get-ShortenedFileName -FileName $file.Name -MaxLength 20
                'Output' = Get-ShortenedFileName -FileName $outputFileName -MaxLength 20
                'Scale (×)' = "×$($ResolutionMultiplier)"
                'Density' = $Density
                'Filter' = $Filter
                'Quality' = $Quality
                'Compression' = $CompressionLevel
                'Sharpen' = $Sharpen
            }
            $conversionResults += New-Object PSObject -Property $properties

        } catch {
            Write-Error "Convert-Image: An error occurred while converting $($file.Name): $_"
            continue
        }
    }

    # Display all results in a single table
    if ($conversionResults.Count -gt 0) {
        $conversionResults | Format-Table -AutoSize
    }
}

Convert-Image @PSBoundParameters
