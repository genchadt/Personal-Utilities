[CmdletBinding()]
param (
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
        [string]$InputFormat = "svg",

        [Parameter()]
        [string]$OutputFormat = "png",

        [Parameter()]
        [int]$ResolutionMultiplier = 1,

        [Parameter()]
        [int]$Density = 300,

        [Parameter()]
        [string]$Filter = "Lanczos",

        [Parameter()]
        [int]$Quality = 100,

        [Parameter()]
        [int]$CompressionLevel = 9,

        [Parameter()]
        [string]$Sharpen = "0x0.5"
    )

    # Check if ImageMagick is installed
    if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
        Write-Error "Convert-Image: ImageMagick is not installed. Please install it before running this script."
        return
    }

    $inputFiles = Get-ChildItem -Path . -Filter "*.$InputFormat"

    if ($inputFiles.Count -eq 0) {
        Write-Host "No .$InputFormat files found in the current directory." -ForegroundColor Yellow
        return
    }

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

        & magick $magickArgs

        Write-Host "Converted $($file.Name) to $outputFileName with resolution multiplier $ResolutionMultiplier." -ForegroundColor Green
        Write-Host "Density: $Density, Filter: $Filter, Quality: $Quality, Compression Level: $CompressionLevel, Sharpen: $Sharpen" -ForegroundColor Green
    }
}

Convert-Image @PSBoundParameters
