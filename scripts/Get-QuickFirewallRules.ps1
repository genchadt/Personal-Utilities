param (
    [switch]$Detailed
)

function Get-QuickFirewallRules {
<#
.SYNOPSIS
    Get-QuickFirewallRules - Lists all firewall rules made with New-QuickFirewallRule.

.DESCRIPTION
    Lists all firewall rules made with New-QuickFirewallRule.
    Criteria: rule begins with "Block Folder: <FolderName>"
    If rule's name is edited elsewhere, they may not be detected.

.PARAMETER Detailed
    Show the rule's properties.
#>
    [CmdletBinding()]
    param (
        [Alias("detailed")]
        [switch]$Detailed
    )

    begin {
        function Format-FirewallRule {
            param ($Rule)
            if ($Detailed) {
                [PSCustomObject]@{
                    Name = $Rule.DisplayName
                    Direction = $Rule.Direction
                    Action = $Rule.Action
                    Enabled = $Rule.Enabled
                    Program = $Rule.Program
                }
            } else {
                Write-Host "$($Rule.DisplayName): $($Rule.Direction) - $($Rule.Action)"
            }
        }
    }

    process {
        $rules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Block Folder: *" }
        if ($rules) {
            $rules | ForEach-Object { Format-FirewallRule $_ }
        } else {
            Write-Host "No Quick Firewall Rules found." -ForegroundColor Yellow
        }
    }
}

Get-QuickFirewallRules @PSBoundParameters