[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Alias("p")]
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$Path,

    [Alias("del")]
    [switch]$Delete
)

begin {
    function Test-FirewallRuleExists {
        [CmdletBinding()]
        param(
            [string[]]$RuleNames
        )
        foreach ($name in $RuleNames) {
            if (Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue) {
                return $true
            }
        }
        return $false
    }

    function Update-FirewallRules {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param(
            [string]$RuleName,
            [string]$ProgramPath,
            [switch]$Remove
        )

        $ruleNames = @("$RuleName (Inbound)", "$RuleName (Outbound)")

        if ($Remove) {
            if (Test-FirewallRuleExists -RuleNames $ruleNames) {
                foreach ($name in $ruleNames) {
                    try {
                        if ($PSCmdlet.ShouldProcess($name, "Remove Firewall Rule")) {
                            Remove-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue
                            Write-Host "Firewall rule '$name' removed successfully." -ForegroundColor Green
                        }
                    } catch {
                        Write-Error "Failed to remove firewall rule '$name': $_"
                    }
                }
            } else {
                Write-Host "No rules starting with '$RuleName' exist to remove." -ForegroundColor Yellow
            }
            return
        }

        if (Test-FirewallRuleExists -RuleNames $ruleNames) {
            Write-Host "One or more firewall rules for '$RuleName' already exist." -ForegroundColor Yellow
            return
        }

        foreach ($direction in @('Inbound', 'Outbound')) {
            $ruleDisplayName = "$RuleName ($direction)"
            try {
                if ($PSCmdlet.ShouldProcess($ruleDisplayName, "Create Firewall Rule")) {
                    New-NetFirewallRule -DisplayName $ruleDisplayName -Direction $direction -Action Block -Program $ProgramPath -Profile Any
                    Write-Host "Firewall rule '$ruleDisplayName' created successfully." -ForegroundColor Green
                }
            } catch {
                Write-Error "Failed to create firewall rule '$ruleDisplayName' for $direction direction: $_"
                # Rollback: Remove any rules created for this name to ensure consistency.
                Write-Host "Attempting to roll back by removing rules for '$RuleName'." -ForegroundColor Yellow
                Update-FirewallRules -RuleName $RuleName -ProgramPath $ProgramPath -Remove:$true
                Throw "Failed to create all firewall rules for '$RuleName'. Any partially created rules have been removed."
            }
        }
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw "Administrator rights are required to manage firewall rules."
    }
} # End of begin block

process {
    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw "The specified path '$Path' is not a valid directory."
    }

    try {
        $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop
        $folderName = (Get-Item $resolvedPath).Name
        $ruleName = "Block Folder: $folderName"

        Update-FirewallRules -RuleName $ruleName -ProgramPath $resolvedPath -Remove:$Delete
    } catch {
        Write-Error "Error: $_"
    }
}