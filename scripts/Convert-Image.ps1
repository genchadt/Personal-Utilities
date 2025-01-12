function Convert-Image {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$InputFormat = "svg",

        [Parameter()]
        [string]$OutputFormat = "png",

        [Parameter()]
        [int]$ResolutionMultiplier = 1
    )

    $inputFiles = Get-ChildItem -Path . -Filter "*.$InputFormat"

    if ($inputFiles.Count -eq 0) {
        Write-Host "No .$InputFormat files found in the current directory." -ForegroundColor Yellow
        return
    }

    # Loop through each file and convert it
    foreach ($file in $inputFiles) {
        # Define the output file name
        $outputFileName = "$($file.BaseName).$OutputFormat"

        # Use ImageMagick's 'magick' command to convert the file
        # -resize option scales the image while preserving aspect ratio
        $resizeOption = "$($ResolutionMultiplier * 100)%"
        magick $file.FullName -resize $resizeOption $outputFileName

        # Output success message
        Write-Host "Converted $($file.Name) to $outputFileName with resolution multiplier $ResolutionMultiplier." -ForegroundColor Green
    }
}