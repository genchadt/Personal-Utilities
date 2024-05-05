<#
.SYNOPSIS
    Update-GithubProfiles.ps1 - A PowerShell script to update my various profiles with changes from remote Github repos.
#>

###############################################
# Imports
###############################################
Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"
Import-Module "$PSScriptRoot\lib\SysOperation.psm1"

###############################################
# Objects
###############################################

$repos = @(
    @{ name = "PowerShell Profile"; Url = "https://github.com/genchadt/powershell-profile.git"; Branch = "main"; Directory = "$env:USERPROFILE\Documents\PowerShell" },
    @{ name = "neovim Profile"; Url = "https://github.com/genchadt/My-Vim.git"; Branch = "main"; Directory = "$env:LOCALAPPDATA\nvim"}
)

repo_list = $repos | ForEach-Object { New-Object PSObject -Property $_ }

###############################################
# Functions
###############################################
function Update-GithubProfiles {
    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Write-Console "Git is not installed. Please install Git and try again."
        Write-Console 
        exit 1
    }

    foreach ($repo in $repo_list) {
        try {
            $git_dir = Join-Path -Path $repo.Directory -ChildPath ".git"
            if (Test-Path -Path $git_dir) {
                Push-Location $repo.Directory
                git fetch
                $status = git status
                if ($status -like "*Your branch is behind*") {
                    Write-Console "Updating $($repo.name)..."
                    git pull
                    Write-Console "$repo.name updated successfully."
                }
                else {
                    Write-Console "$($repo.name) is up-to-date."
                }
                Pop-Location
            }
            else {
                Write-Console "Repository $($repo.name) not found at $($repo.Directory). Cloning now..."
                git clone $repo.Url -b $repo.Branch $repo.Directory
                Write-Console "Repository $($repo.name) cloned successfully."
            }
        } catch {
            Write-Console "Failed to update $($repo.name)."
            ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace -Severity Error
            continue
        }
    }
}

if ($MyInvocation.ScriptName -ne ".") { Update-GithubProfiles }