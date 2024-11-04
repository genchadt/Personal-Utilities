[CmdletBinding()]
param(
    [switch]$check,
    [alias("del")]
    [switch]$delete,
    [alias("l")]
    [switch]$list
)

function ListScriptCreatedFirewallRules {
    Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Block Folder: *" }
}

function CheckFirewallRuleExists {
    param(
        [string]$RuleName
    )
    $existingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    if ($existingRule) {
        Write-Host "A firewall rule for '$RuleName' already exists." -ForegroundColor Green
        return $true
    } else {
        Write-Host "No firewall rule exists for '$RuleName'." -ForegroundColor Yellow
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
            Write-Host "Firewall rule '$RuleName' has been removed." -ForegroundColor Green
        } else {
            Write-Host "No rule named '$RuleName' exists to remove." -ForegroundColor Yellow
        }
    } else {
        if ($existingRule) {
            Write-Host "Firewall rule '$RuleName' already exists. No new rule created." -ForegroundColor Yellow
        } else {
            New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Block -Program (Get-Location).Path -Profile Any
            New-NetFirewallRule -DisplayName $RuleName -Direction Outbound -Action Block -Program (Get-Location).Path -Profile Any
            Write-Host "Firewall rules for blocking folder '$RuleName' created successfully." -ForegroundColor Green
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
                Write-Host "Listing all script-created firewall rules:" -ForegroundColor Cyan
                $rules | ForEach-Object { Write-Host "$($_.DisplayName): $($_.Direction) - $($_.Action)" }
            } else {
                Write-Host "No script-created firewall rules found." -ForegroundColor Yellow
            }
        } elseif ($check) {
            CheckFirewallRuleExists -RuleName $ruleName
        } else {
            CheckAndExecuteRule -RuleName $ruleName -Remove:$delete
        }
    } catch {
        Write-Error "An error occurred: $_.Exception.Message"
        Write-Host "Stack Trace: $_.Exception.StackTrace" -ForegroundColor Red
    }
}

$params = @{
    check   = $check
    delete  = $delete
    list    = $list
}
New-NetFirewallRule-CurrentDirectory $params
