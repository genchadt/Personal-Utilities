###############################################
# Parameters
###############################################

param (
    [Alias("p")][String[]]$Path = $PWD,
    [Alias("a")][String[]]$Add,    # Attributes to add
    [Alias("r")][String[]]$Remove, # Attributes to remove
    [Switch]$Recurse,
    [Switch]$Force,
    [Switch]$NoLog
)

###############################################
# Imports
###############################################

# Assuming necessary modules are located in the same directory as this script.
# Adjust paths as necessary.
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

    foreach ($attr in $AddAttributes) {
        $attribute = [System.IO.FileAttributes]::"$attr"
        $Item.Attributes = $Item.Attributes -bor $attribute
        Log-AttributeChange "Added '$attr' attribute to $($Item.FullName)."
    }

    foreach ($attr in $RemoveAttributes) {
        $attribute = [System.IO.FileAttributes]::"$attr"
        $Item.Attributes = $Item.Attributes -band (-bnot $attribute)
        Log-AttributeChange "Removed '$attr' attribute from $($Item.FullName)."
    }
}

function Log-AttributeChange {
    param (
        [Parameter(Mandatory=$true)][string]$Message
    )
    if (-not $Global:NoLog) { Write-Host $Message } # Consider using a more sophisticated logging mechanism.
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
