[CmdletBinding()]
param (
    [string]$Path,
    [switch]$Delete
)

function Test-FirewallRuleExists {
    [CmdletBinding()]
    param([string]$RuleName)
    
    return $null -ne (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)
}

function Update-FirewallRules {
    [CmdletBinding()]
    param(
        [string]$RuleName,
        [string]$ProgramPath,
        [switch]$Remove
    )

    if ($Remove) {
        if (Test-FirewallRuleExists -RuleName $RuleName) {
            Remove-NetFirewallRule -DisplayName $RuleName
            Write-Host "Firewall rule '$RuleName' has been removed." -ForegroundColor Green
        } else {
            Write-Host "No rule named '$RuleName' exists to remove." -ForegroundColor Yellow
        }
        return
    }

    if (Test-FirewallRuleExists -RuleName $RuleName) {
        Write-Host "Firewall rule '$RuleName' already exists." -ForegroundColor Yellow
        return
    }

    foreach ($direction in @('Inbound', 'Outbound')) {
        New-NetFirewallRule -DisplayName $RuleName -Direction $direction -Action Block -Program $ProgramPath -Profile Any
    }
    Write-Host "Firewall rules for blocking folder '$RuleName' created successfully." -ForegroundColor Green
}

function New-QuickFirewallRule {
    [CmdletBinding()]
    param(
        [Alias("p")]
        [Parameter(Position = 0)]
        [string]$Path = (Get-Location).Path,

        [Alias("del")]
        [switch]$Delete
    )

    try {
        $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop
        $folderName = (Get-Item $resolvedPath).Name
        $ruleName = "Block Folder: $folderName"

        Update-FirewallRules -RuleName $ruleName -ProgramPath $resolvedPath -Remove:$Delete
    } catch {
        Write-Error "Error: $_"
    }
}

New-QuickFirewallRule @PSBoundParameters