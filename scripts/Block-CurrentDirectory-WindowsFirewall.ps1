<#
.SYNOPSIS
    Block-CurrentDirectory-WindowsFirewall.ps1 - This PowerShell script is designed to manage Windows Firewall rules for the current directory. It allows creating, deleting, and listing custom firewall rules that block all inbound and outbound connections for the specified directory.

.DESCRIPTION
    !! This script must be run with Administrator privileges. !!
    This script creates a firewall rule named "Block [FolderName] Folder" for the current directory, blocking all inbound and outbound connections. The script can also delete the rule if it exists.

.PARAMETERS
    -allow
        When used, the script will attempt to delete the "Block [FolderName] Folder" rule for the current directory. If no such rule exists, it notifies the user.

    -listRules
        Lists all the firewall rules created by this script. It filters rules based on the naming convention used ("Block [FolderName] Folder") and displays them with their direction and action.

.EXAMPLE
    .\Block-CurrentDirectory-WindowsFirewall.ps1
    By default, the script creates a firewall rule named "Block [FolderName] Folder" for the current directory, blocking all inbound and outbound connections.

.EXAMPLE
    .\Block-CurrentDirectory-WindowsFirewall.ps1 -allow
    Delete a rule named "Block [FolderName] Folder" if it exists.

.EXAMPLE
    .\Block-CurrentDirectory-WindowsFirewall.ps1 -listRules
    List all the firewall rules created by this script.

.INPUTS
    None

.OUTPUTS
    String
    Outputs to console the rule creation or deletion status.

.NOTES
    Administrative privileges are required to run this script.

    Script Version: 1.0
    Author: Chad
    Creation Date: 2023-12-07 03:30:00 GMT
#>

param(
    [switch]$allow,
    [switch]$listRules
)

$ErrorActionPreference = "Stop"

function Write-VerboseLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    Write-Host $Message
}

try {
    # Function to list all firewall rules created by the script
    function ListScriptCreatedFirewallRules {
        Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Block * Folder" }
    }

    if ($listRules) {
        # List all rules created by the script
        $rules = List-ScriptCreatedFirewallRules
        if ($rules) {
            Write-VerboseLog "Listing all script-created firewall rules:"
            $rules | ForEach-Object { Write-VerboseLog "$($_.DisplayName): $($_.Direction) - $($_.Action)" }
        } else {
            Write-VerboseLog "No script-created firewall rules found."
        }
    } else {
        $currentDirectory = Get-Location
        $folderName = (Get-Item $currentDirectory).Name
        $ruleName = "Block $folderName Folder"

        if ($allow) {
            # Remove rule
            $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
            if ($existingRule) {
                Remove-NetFirewallRule -DisplayName $ruleName
                Write-VerboseLog "Info: Firewall rule '$ruleName' has been removed."
            } else {
                Write-VerboseLog "Info: No rule named '$ruleName' exists to remove."
            }
        } else {
            # Create rule
            $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
            if ($existingRule) {
                Write-VerboseLog "Warning: Firewall rule '$ruleName' already exists. No new rule created."
            } else {
                New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Block -Program $currentDirectory.Path -Profile Any
                New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Action Block -Program $currentDirectory.Path -Profile Any
                Write-VerboseLog "Success: Firewall rules for blocking '$folderName' folder created successfully."
            }
        }
    }
} catch {
    Write-VerboseLog "Error: $_"
} finally {
    $ErrorActionPreference = "Continue"
}
