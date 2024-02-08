function Read-Console() {
    param (
        [string]$Text,
        [string]$Prompt
    )

    if ($Prompt) {
        $response = Read-Host -Prompt "$Text $Prompt"
    } 
    else {
        $response = Read-Host -Prompt "$Text (Y)es / (A)ccept All / (N)o / (D)ecline All"
    }

    return $response
}

function Write-Console() {
    param (
        [string]$Text,
        [switch]$NoLog
    )

    Write-Host ">> $Text"
    if (!$NoLog) { Write-Log -Message $Text }
}

function Write-Divider {
    param (
        [switch]$Strong,
        [string]$Char = '-'
    )

    if (!$SilentMode) { 
        if($Strong) { $Char = '=' }
        Write-Host ($Char * 15)
    }
}

function Write-Log() {
    param (
        [string]$Message
    )

    $logFileName = "{0}.log" -f ($MyInvocation.MyCommand.Name -replace '\.ps1$', '')
    $logPath = Join-Path -Path $PSScriptRoot -ChildPath "logs\$logFileName"

    if (-not (Test-Path $logPath)) {
        New-Item -ItemType File -Path $logPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"

    Add-Content -Path $logPath -Value $logEntry
}
