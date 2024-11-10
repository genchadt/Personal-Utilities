param (
    [switch]$Simple
)

function Get-QuickFirewallRules {
<#
.SYNOPSIS
    Get-QuickFirewallRules - Lists all firewall rules made with New-QuickFirewallRule.

.DESCRIPTION
    Lists all firewall rules made with New-QuickFirewallRule.
    Criteria: rule begins with "Block Folder: <FolderName>"
    If rule's name is edited elsewhere, they may not be detected.

.PARAMETER Simple
    Lists only the name, direction, and action of the firewall rules.
#>
    [CmdletBinding()]
    param (
        [Alias("s")]
        [Parameter(Position = 0)]
        [switch]$Simple = $false
    )

    function Format-FirewallRule {
        param ($Rule)
        if (-not $Simple) { # Detailed output by default
            [PSCustomObject]@{
                Name      = $Rule.DisplayName
                Direction = $Rule.Direction
                Action    = $Rule.Action
                Enabled   = $Rule.Enabled
                Program   = $Rule.Program
            }
        } else { # Simplified output with -Simple
            Write-Output "$($Rule.DisplayName): $($Rule.Direction) - $($Rule.Action)"
        }
    }

    try {
        $rules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Block Folder: *" }
        if ($rules) {
            Write-Debug "Found $($rules.Count) Quick Firewall Rules."
            foreach ($rule in $rules) {
                Format-FirewallRule $rule 
            }
        } else {
            Write-Warning "No Quick Firewall Rules found."
            return
        }
    } catch {
        Write-Error "An error occurred while retrieving firewall rules: $_"
        return
    }
}

Get-QuickFirewallRules @PSBoundParameters