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
        Write-Console ($Char * 15) -NoLog 
    }
}

function Write-Log() {
    param (
        [string]$Message
    )

    $logFileName = "{0}.log" -f (Split-Path $MyInvocation.ScriptName -Leaf -Replace '\.ps1$')
    $logPath = Join-Path -Path (Split-Path $MyInvocation.ScriptName -Parent) -ChildPath "logs\$logFileName"

    if (-not (Test-Path $logPath)) {
        New-Item -ItemType File -Path $logPath -Force > $null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"

    $logContent = Get-Content -Path $logPath -Raw
    Set-Content -Path $logPath -Value "$logEntry`r`n$logContent"
}
