<#
.SYNOPSIS
    Set-Parameter.PS1 - Modifies file and folder attributes in the specified directory or the current working directory.

.DESCRIPTION
    This script allows for the modification of file and folder attributes within the specified paths or the current working directory by default. It can add or remove attributes such as Hidden, ReadOnly, etc., to files and folders, with optional recursion into subdirectories.

.PARAMETER Path
    Specifies the path(s) where the file and folder attributes will be modified. Defaults to the current working directory (PWD) if not specified.

.PARAMETER Add
    Specifies the attributes to add to the files or folders. Accepts multiple values separated by commas.

.PARAMETER Remove
    Specifies the attributes to remove from the files or folders. Accepts multiple values separated by commas.

.PARAMETER Recurse
    If specified, the script will recursively modify attributes in all subdirectories of the path.

.PARAMETER Force
    If specified, the script will overwrite existing attributes without prompting for confirmation.

.PARAMETER NoLog
    Suppresses logging of attribute changes. By default, changes are logged.

.EXAMPLE
    .\Set-Parameter.ps1 -Add Hidden,ReadOnly
    Adds the Hidden and ReadOnly attributes to files and folders in the current working directory.

.EXAMPLE
    .\Set-Parameter.ps1 -Remove Hidden -Path C:\MyFolder -Recurse
    Removes the Hidden attribute from all files and folders within 'C:\MyFolder' and its subdirectories.

.EXAMPLE
    .\Set-Parameter.ps1 -Add System -Path .\config.sys -NoLog
    Adds the System attribute to 'config.sys' in the current directory without logging the change.

.INPUTS
    None. You cannot pipe objects to Set-Parameter.ps1.

.OUTPUTS
    String. Outputs logs of attribute changes unless NoLog is specified.

.LINK
    About_Attributes: [Microsoft Documentation on FileAttributes](https://docs.microsoft.com/en-us/dotnet/api/system.io.fileattributes)

.NOTES
    Use this script with caution, especially when modifying system or hidden attributes, as it can affect file and folder visibility and behavior.

    Script Version: 1.0.0
    Author: Chad
    Creation Date: 2024-03-22 03:30:00 GMT
    Last Updated: 2024-03-22 03:30:00 GMT
#>

###############################################
# Parameters
###############################################

param (
    [Alias("p")][String[]]$Path = $PWD,
    [Alias("a")][String[]]$Add = @(),
    [Alias("r")][String[]]$Remove = @(),
    [Switch]$Recurse,
    [Switch]$Force,
    [Switch]$NoLog
)

###############################################
# Imports
###############################################

Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"
Import-Module "$PSScriptRoot\lib\SysOperation.psm1"

###############################################
# Helper Functions
###############################################

function Add-RemoveFileAttribute {
    param (
        [Parameter(Mandatory=$true)][System.IO.FileSystemInfo]$Item,
        [String[]]$AddAttributes,
        [String[]]$RemoveAttributes
    )

    $AddAttributes = @($AddAttributes)
    $RemoveAttributes = @($RemoveAttributes)

    $validAttributes = [Enum]::GetNames([System.IO.FileAttributes])
    $AddAttributes = $AddAttributes | ForEach-Object { $_.TrimStart('-') } | Where-Object { $validAttributes -contains $_ }
    $RemoveAttributes = $RemoveAttributes | ForEach-Object { $_.TrimStart('-') } | Where-Object { $validAttributes -contains $_ }

    foreach ($attr in $AddAttributes) {
        try {
            $attribute = [System.IO.FileAttributes]::"$attr"
            $Item.Attributes = $Item.Attributes -bor $attribute
            LogAttributeChange "Successfully added '$attr' attribute to $($Item.FullName)."
        }
        catch {
            LogAttributeChange "Failed to add '$attr' attribute to $($Item.FullName): $_"
        }
    }

    foreach ($attr in $RemoveAttributes) {
        try {
            $attribute = [System.IO.FileAttributes]::"$attr"
            $Item.Attributes = $Item.Attributes -band (-bnot $attribute)
            LogAttributeChange "Successfully removed '$attr' attribute from $($Item.FullName)."
        }
        catch {
            LogAttributeChange "Failed to remove '$attr' attribute from $($Item.FullName): $_"
        }
    }
}

function LogAttributeChange {
    param (
        [Parameter(Mandatory=$true)][string]$Message
    )
    if (-not $Global:NoLog) { Write-Log $Message }
}

###############################################
# Execution
###############################################

try {
    $Global:NoLog = $NoLog
    $processPaths = $Force ? @($PWD) : $Path
    foreach ($itemPath in $processPaths) {
        if (-not (Test-Path -LiteralPath $itemPath)) {
            throw "Path '$itemPath' does not exist."
        }

        $items = @()
        if ($Recurse) {
            $items += Get-ChildItem -Path $itemPath -Recurse:$Recurse -Force
        } else {
            $items += Get-Item -LiteralPath $itemPath -Force
        }

        foreach ($item in $items) {
            Add-RemoveFileAttribute -Item $item -AddAttributes $Add -RemoveAttributes $Remove
        }
    }
} catch {
    ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace
}
