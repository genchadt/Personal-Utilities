###############################################
# Install-Fonts
#
# Installs fonts recursively from the current directory using Windows' built-in tool.
# Arguments:
#   -Path: Specifies the directory to search for font files.
#   -Filter: Specifies the file types to include.
#   -Force: Forces the installation of fonts, overwriting existing files.
###############################################

###############################################
# Parameters
###############################################
param(
    [string]$Path = ".",
    [string]$Filter = "*.ttf,*.otf,*.woff,*.woff2,*.eot,*.fon,*.pfm,*.pfb,*.ttc",
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

    $flag = $Force.IsPresent ? 0x14 : 0x10  # 0x10 for silent, 0x14 to also force replace existing files
    $fontFiles = Get-ChildItem -Path $Path -Filter $Filter -Recurse

    $jobs = $fontFiles | ForEach-Object {
        Start-Job -ScriptBlock {
            param($filePath, $copyFlag)
            $shellApp = New-Object -ComObject Shell.Application
            $fontsFolder = $shellApp.Namespace(0x14)
            if ($null -eq $fontsFolder) {
                throw 'Failed to access the Fonts folder. Ensure you have the necessary permissions.'
            }
            $fontsFolder.CopyHere($filePath, $copyFlag)
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

$params = @{
    Path = $Path
    Filter = $Filter
    Force = $Force
}

if ($MyInvocation.InvocationName -ne '.') { Install-Fonts $params }
