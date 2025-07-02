[CmdletBinding()]
param(
    [string]$Query
)

function Get-CheatSh {
    [CmdletBinding()]
    param (
        [string]$Query
    )

    Clear-Host
    Invoke-WebRequest -Uri "https://cheat.sh/$Query" -UseBasicParsing | Select-Object -ExpandProperty Content
}

Get-CheatSh @PSBoundParameters