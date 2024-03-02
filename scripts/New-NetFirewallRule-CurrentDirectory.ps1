param(
    [switch]$check,
    [alias("del")]
    [switch]$delete,
    [alias("l")]
    [switch]$list
)

Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"

function ListScriptCreatedFirewallRules {
    Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Block Folder: *" }
}

function CheckFirewallRuleExists {
    param(
        [string]$RuleName
    )
    $existingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    if ($existingRule) {
        Write-Console -Text "A firewall rule for '$RuleName' already exists."
        return $true
    } else {
        Write-Console -Text "No firewall rule exists for '$RuleName'."
        return $false
    }
}

function CheckAndExecuteRule {
    param(
        [string]$RuleName,
        [switch]$Remove
    )
    $existingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    if ($Remove) {
        if ($existingRule) {
            Remove-NetFirewallRule -DisplayName $RuleName
            Write-Console -Text "Firewall rule '$RuleName' has been removed."
        } else {
            Write-Console -Text "No rule named '$RuleName' exists to remove."
        }
    } else {
        if ($existingRule) {
            Write-Console -Text "Firewall rule '$RuleName' already exists. No new rule created."
        } else {
            New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Block -Program (Get-Location).Path -Profile Any
            New-NetFirewallRule -DisplayName $RuleName -Direction Outbound -Action Block -Program (Get-Location).Path -Profile Any
            Write-Console -Text "Firewall rules for blocking folder '$folderName' created successfully."
        }
    }
}

function New-NetFirewallRule-CurrentDirectory {
    try {
        $folderName = (Get-Item (Get-Location)).Name
        $ruleName = "Block Folder: $folderName"
    
        if ($list) {
            $rules = ListScriptCreatedFirewallRules
            if ($rules) {
                Write-Divider -Strong
                Write-Console -Text "Listing all script-created firewall rules:"
                $rules | ForEach-Object { Write-Console -Text "$($_.DisplayName): $($_.Direction) - $($_.Action)" }
                Write-Divider -Strong
            } else {
                Write-Console -Text "No script-created firewall rules found."
            }
        } elseif ($check) {
            CheckFirewallRuleExists -RuleName $ruleName
        } else {
            CheckAndExecuteRule -RuleName $ruleName -Remove:$delete
        }
    } catch {
        ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace
    }
}

New-NetFirewallRule-CurrentDirectory
