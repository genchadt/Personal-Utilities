function Get-QuickFirewallRules {
<#
.SYNOPSIS
    Get-QuickFirewallRules - Lists all firewall rules made with New-QuickFirewallRule.

.DESCRIPTION
    Lists all firewall rules made with New-QuickFirewallRule.
    Criteria: rule begins with "Block Folder: <FolderName>"
    If rule's name is edited elsewhere, they may not be detected.

.NOTES
    Use -Verbose to get more information about each rule.
#>
    [CmdletBinding()]
    param ()

    function Format-FirewallRule {
        param ($Rule)
        if ($Verbose) {
            [PSCustomObject]@{
                Name      = $Rule.DisplayName   # Name of the rule
                Direction = $Rule.Direction     # Direction of the rule
                Action    = $Rule.Action        # Action of the rule
                Enabled   = $Rule.Enabled       # Enabled status of the rule
                Program   = $Rule.Program       # Program associated with the rule
            }
        } else {
            Write-Output "$($Rule.DisplayName): $($Rule.Direction) - $($Rule.Action)"
        }
    }

    try {
        $rules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Block Folder: *" }
        if ($rules) {
            foreach ($rule in $rules) {
                Format-FirewallRule $rule 
            }
        } else {
            Write-Warning "No Quick Firewall Rules found."
        }
    } catch {
        Write-Error "An error occurred while retrieving firewall rules: $_"
    }
}

Get-QuickFirewallRules @PSBoundParameters