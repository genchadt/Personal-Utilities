###############################################
# Parameters
###############################################

param (
    [Alias("p")][String[]]$Path = $PWD,
    [Alias("h")][Switch]$Hidden,
    [Alias("v")][Switch]$Visible,
    [Alias("r")][Switch]$Recurse,
    [Alias("f")][Switch]$Force,
    [Alias("rm")][Switch]$RemoveSystem,
    [Alias("s")][Switch]$NoLog
)

###############################################
# Imports
###############################################

Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"
Import-Module "$PSScriptRoot\lib\SysOperation.psm1"

###############################################
# Main Loop
###############################################

if (-not $Path -or ($Path.Count -eq 0 -and -not $Force)) {
    Write-Error "Please specify at least one path or use the -Force parameter."
    return
}

if ($Hidden -and $Visible) {
    Write-Error "Cannot specify both -Hidden and -Visible flags."
    return
}

function Set-FileAttribute {
    param (
        [Parameter(Mandatory = $true)][String]$ItemPath,
        [Parameter(Mandatory = $true)][Bool]$Hidden,
        [Parameter(Mandatory = $true)][Bool]$Visible,
        [Parameter(Mandatory = $true)][Bool]$RemoveSystem
    )

    $item = Get-Item -LiteralPath $ItemPath -Force
    if ($null -eq $item) {
        Write-Warning "Item at path '$ItemPath' could not be found."
        return
    }

    $currentAttributes = $item.Attributes
    $isSystem = $currentAttributes -band [System.IO.FileAttributes]::System
    if (-not $NoLog) { Write-Log "Current attributes for $ItemPath" + ": " + "$currentAttributes. Is system: $isSystem" }

    if ($isSystem -and $RemoveSystem) {
        $newAttributes = $currentAttributes -band (-bnot [System.IO.FileAttributes]::System)
        $item.Attributes = $newAttributes
        if (-not $NoLog) { Write-Log "Removed 'System' attribute. New attributes: $newAttributes" }
    }

    if ($Hidden) {
        $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
        if (-not $NoLog) { Write-Log "Set 'Hidden' attribute." }
    } elseif ($Visible) {
        $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)
        if (-not $NoLog) { Write-Log "Removed 'Hidden' attribute." }
    }

    if ($isSystem -and !$RemoveSystem) {
        $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::System
        if (-not $NoLog) { Write-Log "Re-added 'System' attribute." }
    }
}

try {
    $processPaths = $Force ? @($PWD) : $Path
    foreach ($itemPath in $processPaths) {
        if (-not (Test-Path $itemPath)) {
            throw "Path '$itemPath' does not exist."
        }

        $item = Get-Item $itemPath -Force
        if ($item -is [System.IO.DirectoryInfo] -and ($Hidden -or $Visible)) {
            Get-ChildItem -Path $itemPath -Recurse:$Recurse -Force | ForEach-Object {
                Set-FileAttribute -ItemPath $_.FullName -Hidden $Hidden -Visible $Visible -RemoveSystem $RemoveSystem
            }
            Set-FileAttribute -ItemPath $itemPath -Hidden $Hidden -Visible $Visible -RemoveSystem $RemoveSystem
        } elseif ($item -is [System.IO.FileInfo]) {
            Set-FileAttribute -ItemPath $itemPath -Hidden $Hidden -Visible $Visible -RemoveSystem $RemoveSystem
        }
    }
} catch { ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace }
