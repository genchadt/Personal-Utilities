[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("23H2", "24H2")]
    [string]$TargetVersion
)

<#
.SYNOPSIS
    Set-WinTargetVersion - Locks the target version for Windows 11 updates.

.DESCRIPTION
    This script sets the target version for Windows 11 updates using registry keys.
    It requires administrative privileges to modify the registry.

.PARAMETER TargetVersion
    The target version to set. Valid values are "23H2" or "24H2".

.EXAMPLE
    Set-WinTargetVersion -TargetVersion "23H2"
    This command locks the target version to 23H2.
#>

if ($TargetVersion -eq "23H2") {
    Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ProductVersion /t REG_SZ /d "Windows 11" /f' -Wait -Verb RunAs
    Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersion /t REG_DWORD /d 1 /f' -Wait -Verb RunAs
    Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersionInfo /t REG_SZ /d 23H2 /f' -Wait -Verb RunAs
}
elseif ($TargetVersion -eq "24H2") {
    Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ProductVersion /t REG_SZ /d "Windows 11" /f' -Wait -Verb RunAs
    Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersion /t REG_DWORD /d 1 /f' -Wait -Verb RunAs
    Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersionInfo /t REG_SZ /d 24H2 /f' -Wait -Verb RunAs
}
else {
    Write-Host "Invalid Target Version. Please specify either '23H2' or '24H2'."
}