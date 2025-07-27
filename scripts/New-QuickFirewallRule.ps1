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
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::`
        GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($Remove) {
        if (Test-FirewallRuleExists -RuleName $RuleName) {
            try {
                if (-not $isAdmin) {
                    throw "This script requires administrator privileges"
                }

                Remove-NetFirewallRule -DisplayName $RuleName -ErrorAction Stop
                Write-Host "Firewall rule '$RuleName' removed successfully." -ForegroundColor Green
            } catch {
                Write-Error "Failed to remove firewall rule '$RuleName': $_"
            }
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
        try {
            if (-not $isAdmin) {
                throw "This script requires administrator privileges"
            }

            New-NetFirewallRule -DisplayName $RuleName -Direction $direction -Action Block -Program $ProgramPath -Profile Any
        } catch {
            Write-Error "Failed to create firewall rule '$RuleName' for $direction direction: $_"
            return
        }
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