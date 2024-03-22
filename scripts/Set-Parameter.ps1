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
