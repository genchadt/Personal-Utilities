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

    $scriptDirectory = $PSScriptRoot

    if ($null -eq $scriptDirectory) {
        $scriptDirectory = Get-Location
    }

    $logPath = Join-Path -Path $scriptDirectory -ChildPath "logs\Optimize-PSX.log"

    if (!(Test-Path $logPath)) {
        New-Item -ItemType File -Path $logPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"

    $existingContent = Get-Content -Path $logPath -Raw
    $updatedContent = "$logEntry`r`n$existingContent"

    Set-Content -Path $logPath -Value $updatedContent
}