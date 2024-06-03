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

###############################################
# Parameters
###############################################
param(
    [string]$Path,
    [string]$Filter,
    [switch]$Force
)

###############################################
# Imports
###############################################
Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"
Import-Module "$PSScriptRoot\lib\SysOperation.psm1"

###############################################
# Functions
###############################################
Write-Console "Starting font installations..."

function Install-Fonts {
    param(
        [string]$Path,
        [string]$Filter,
        [switch]$Force
    )

    # If no path is specified, use the current working directory
    if (-not $Path) { $Path = $PWD }
    if (-not $Filter) { $Filter = "*.ttf,*.otf,*.woff,*.woff2,*.eot,*.fon,*.pfm,*.pfb,*.ttc" }

    $flag = $Force.IsPresent ? 0x14 : 0x10  # 0x10 for silent, 0x14 to also force replace existing files

    # Convert the filter into an array
    $filters = $Filter -split ","

    # Get all font files matching the filter
    $font_files = Get-ChildItem -Path $Path -Recurse -Include $filters -File

    if ($font_files.Count -eq 0) {
        Write-Console "No font files found in the specified directory."
        return
    }

    $jobs = $font_files | ForEach-Object {
        Start-Job -ScriptBlock {
            param($filePath, $copyFlag)
            $shell = New-Object -ComObject Shell.Application
            $fonts_directory = $shell.Namespace(0x14)
            if ($null -eq $fonts_directory) {
                throw 'Failed to access the Fonts folder. Ensure you have the necessary permissions.'
            }
            $fonts_directory.CopyHere($filePath, $copyFlag)
        } -ArgumentList $_.FullName, $flag
    }

    $jobs | Wait-Job

    $jobs | ForEach-Object {
        $result = Receive-Job -Job $_
        Remove-Job -Job $_
        $result
    }

    Write-Console "All fonts installations completed."
}

if ($MyInvocation.InvocationName -ne '.') { Install-Fonts -Path $Path -Filter $Filter -Force $Force }
