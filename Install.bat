:: Install script
:: Checks if PowerShell is installed. If not, install it.
:: Probably obsolete since PowerShell Core is now installed by default in Windows 10+

@echo off

where pwsh >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo PowerShell Core is already installed.
) else (
    echo PowerShell Core is not installed.
    echo Installing PowerShell Core...
    winget install --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements
)

echo Running Setup.ps1...
pwsh -File "%~dp0Setup.ps1"