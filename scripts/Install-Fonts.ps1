<#
    .SYNOPSIS
        Install-Fonts.ps1 - Installs fonts recursively from the current directory using Windows' built-in tool.

    .DESCRIPTION
        !! This script must be run with Administrator privileges. !!
        This script recursively installs fonts from the current directory using Windows' built-in tool.

    .PARAMETER Path
        The path to search for fonts. Defaults to the current directory.

    .PARAMETER Filter
        The file types to include. Defaults to *.ttf,*.otf,*.woff,*.woff2,*.eot,*.fon,*.pfm,*.pfb,*.ttc.

    .PARAMETER Force
        Forces the installation of fonts, overwriting existing files.

    .EXAMPLE
        .\Install-Fonts.ps1

    .EXAMPLE
        .\Install-Fonts.ps1 -Path "C:\Windows\Fonts" -Filter "*.ttf,*.otf,*.woff,*.woff2,*.eot,*.fon,*.pfm,*.pfb,*.ttc"
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = (Get-Location).Path,

    [Parameter(Position = 1)]
    [string]$Filter = "*.ttf,*.otf,*.woff,*.woff2,*.eot,*.fon,*.pfm,*.pfb,*.ttc",

    [Parameter(Position = 2)]
    [switch]$Force
)

Import-Module "$PSScriptRoot\lib\helpers.psm1"

function Install-Fonts {
    param(
        [string]$Path,
        [string]$Filter,
        [switch]$Force
    )

    if (-not (Test-Path -Path $Path)) {
        Write-Host "The specified path does not exist: $Path" -ForegroundColor Red
        return
    }

    $flag = if ($Force) { 0x14 } else { 0x10 }  # 0x10 for silent, 0x14 to force replace

    # Convert the filter into an array so we can locate font files matching the rules within the specified path
    $filters = $Filter -split "," | ForEach-Object { $_.Trim() }
    $font_files = Get-ChildItem -Path $Path -Recurse -Include $filters -File

    if ($font_files.Count -eq 0) {
        Write-Host "No font files found in the specified directory." -ForegroundColor Yellow
        return
    }

    # Install fonts using shell COM object
    Grant-Elevation
    $jobs = $font_files | ForEach-Object {
        Start-Job -ScriptBlock {
            param($filePath, $copyFlag)
            $fileName = [System.IO.Path]::GetFileName($filePath)
            $shell = New-Object -ComObject Shell.Application
            $fonts_directory = $shell.Namespace(0x14)  # 0x14 = Fonts folder
            if ($null -eq $fonts_directory) {
                throw 'Failed to access the Fonts folder. Ensure you have the necessary permissions.'
            }

            Write-Verbose "Installing font: $filePath to $fonts_directory"
            try {
                $fonts_directory.CopyHere($fileName, $copyFlag)
            }
            catch {
                Write-Warning "Install-Fonts: Failed to install font ${fileName}: $_"
            }
        } -ArgumentList $_.FullName, $flag
    }

    # Wait for jobs to complete
    $jobs | Wait-Job

    # Check results and clean up jobs
    $jobs | ForEach-Object {
        Receive-Job -Job $_
        Remove-Job -Job $_
    }

    Write-Host "All font installations completed." -ForegroundColor Green
}

$params = @{
    Path = $Path
    Filter = $Filter
    Force = $Force
}
Install-Fonts @params