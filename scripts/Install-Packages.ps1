<#
.SYNOPSIS
    Install-Packages.ps1 - Installs selected packages using winget, scoop, and chocolatey.

.DESCRIPTION
    Reads a list of packages from a YAML configuration file, prompts the user to select the installation type (Limited, Standard, Full, Optional Only), displays a custom GUI for package selection with all relevant items pre-selected, and installs them using winget, scoop, and chocolatey.

.NOTES
    Script Version: 2.2.0
    Author: Chad
    Creation Date: 2024-01-29 04:30:00 GMT
#>

###############################################
# Parameters
###############################################

param (
    [Parameter(Position=0, Mandatory=$false)]
    [string]$configFile = "$PSScriptRoot\config\packages.yaml",

    [Parameter(Position=1, Mandatory=$false)]
    [switch]$force
)

###############################################
# Functions
###############################################

function Install-Packages {
    param (
        [array]$packages,
        [switch]$force
    )

    # Initialize arrays
    $wingetApps = @()
    $scoopApps = @()
    $scoopBuckets = @()
    $chocoApps = @()

    # Parse packages and populate arrays
    foreach ($package in $packages) {
        # Winget apps
        if ($package.managers.winget.available) {
            $wingetApps += $package
        }
        # Scoop apps and buckets
        if ($package.managers.scoop.available) {
            $scoopApps += $package
            if ($package.managers.scoop.bucket -and -not ($scoopBuckets -contains $package.managers.scoop.bucket)) {
                $scoopBuckets += $package.managers.scoop.bucket
            }
        }
        # Chocolatey apps
        if ($package.managers.chocolatey.available) {
            $chocoApps += $package
        }
    }

    # Ensure Scoop is installed
    if ($scoopApps.Count -gt 0 -or $scoopBuckets.Count -gt 0) {
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
            Write-Host "Scoop is not installed. Installing Scoop..." -ForegroundColor Yellow
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
        }
    }

    # Install Scoop buckets
    foreach ($bucket in $scoopBuckets) {
        Write-Host "Adding scoop bucket: $bucket" -ForegroundColor Yellow
        try {
            scoop bucket add $bucket
            Write-Host "Successfully added scoop bucket: $bucket" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to add scoop bucket: $bucket - $_"
        }
    }

    # Install Scoop apps
    foreach ($app in $scoopApps) {
        $appId = $app.id
        $bucket = $app.managers.scoop.bucket
        $installArgs = $app.'install-args'

        if ($bucket) {
            $scoopCommand = "scoop install $bucket/$appId"
        } else {
            $scoopCommand = "scoop install $appId"
        }

        if ($installArgs) {
            $scoopCommand += " $installArgs"
        }

        if ($force) {
            $scoopCommand = "scoop update $appId; $scoopCommand"
        }

        Write-Host "Installing (scoop): $appId" -ForegroundColor Cyan
        try {
            Invoke-Expression $scoopCommand
            Write-Host "Successfully installed (scoop): $appId" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to install (scoop): $appId - $_"
        }
    }

    # Install Winget apps
    foreach ($app in $wingetApps) {
        $appId = $app.id
        $installArgs = $app.'install-args'
        $wingetCommand = "winget install $appId -e -i"
        if ($installArgs) {
            $wingetCommand += " $installArgs"
        }
        if ($force) {
            $wingetCommand += " --force"
        }

        Write-Host "Installing (winget): $appId" -ForegroundColor Cyan
        try {
            Invoke-Expression $wingetCommand
            Write-Host "Successfully installed (winget): $appId" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to install (winget): $appId - $_"
        }
    }

    # Ensure Chocolatey is installed
    if ($chocoApps.Count -gt 0) {
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            Write-Host "Chocolatey is not installed. Installing Chocolatey..." -ForegroundColor Yellow
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        }
    }

    # Install Chocolatey apps
    foreach ($app in $chocoApps) {
        $appId = $app.id
        $installArgs = $app.'install-args'
        $chocoCommand = "choco install $appId -y"
        if ($installArgs) {
            $chocoCommand += " $installArgs"
        }
        if ($force) {
            $chocoCommand += " --force"
        }

        Write-Host "Installing (chocolatey): $appId" -ForegroundColor Cyan
        try {
            Invoke-Expression $chocoCommand
            Write-Host "Successfully installed (chocolatey): $appId" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to install (chocolatey): $appId - $_"
        }
    }

    Write-Host "All packages installation complete." -ForegroundColor Green
}

function Load-PackageConfig {
    param (
        [string]$configFile
    )

    if (-not (Test-Path $configFile)) {
        Write-Host "Error: Configuration file '$configFile' does not exist." -ForegroundColor Red
        return $null
    }

    try {
        $yamlContent = Get-Content -Path $configFile -Raw
        $packageConfig = ConvertFrom-Yaml -Yaml $yamlContent
        return $packageConfig
    } catch {
        Write-Host "Error parsing YAML file: $_" -ForegroundColor Red
        return $null
    }
}

function Show-PackageSelectionWindow {
    param (
        [array]$packages
    )

    # Create WPF Window
    Add-Type -AssemblyName PresentationFramework

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Select Packages to Install" Height="600" Width="500"
        Background="#1e1e1e" Foreground="White" WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <!-- Custom CheckBox Style -->
        <Style x:Key="CustomCheckBox" TargetType="CheckBox">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Background" Value="#2d2d30"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <StackPanel Orientation="Horizontal">
                            <Border Width="16" Height="16" BorderBrush="White" BorderThickness="1" Margin="0,0,5,0">
                                <Grid>
                                    <Rectangle Fill="#2d2d30"/>
                                    <Path x:Name="CheckMark" Data="M0,6 L2,4 5,7 10,2 12,4 5,11z" Fill="White" Visibility="Collapsed"/>
                                </Grid>
                            </Border>
                            <ContentPresenter VerticalAlignment="Center"/>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="CheckMark" Property="Visibility" Value="Visible"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <!-- Installation Type Selection -->
        <GroupBox Header="Select Installation Type" Background="#1e1e1e" Foreground="White" Margin="0,0,0,10">
            <StackPanel Orientation="Horizontal" Margin="10">
                <RadioButton Content="Limited" GroupName="InstallType" IsChecked="True" Margin="0,0,10,0" Name="LimitedRadio" Foreground="White" />
                <RadioButton Content="Standard" GroupName="InstallType" Margin="0,0,10,0" Name="StandardRadio" Foreground="White" />
                <RadioButton Content="Full (Standard + Optional)" GroupName="InstallType" Margin="0,0,10,0" Name="FullRadio" Foreground="White" />
                <RadioButton Content="Optional Only" GroupName="InstallType" Name="OptionalRadio" Foreground="White" />
            </StackPanel>
        </GroupBox>

        <!-- Package List -->
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="PackageList" Background="#2d2d30">
            </StackPanel>
        </ScrollViewer>

        <!-- Action Buttons -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Content="Select All" Width="75" Margin="0,0,10,0" Name="SelectAllButton" Background="#007acc" Foreground="White"/>
            <Button Content="Install" Width="75" Margin="0,0,10,0" Name="InstallButton" Background="#007acc" Foreground="White"/>
            <Button Content="Cancel" Width="75" Name="CancelButton" Background="#d32f2f" Foreground="White"/>
        </StackPanel>
    </Grid>
</Window>
"@

    # Parse the XAML
    $reader = (New-Object System.Xml.XmlTextReader([System.IO.StringReader]$xaml))
    $window = [Windows.Markup.XamlReader]::Load($reader)

    # Find UI Elements
    $packageListPanel = $window.FindName("PackageList")
    $installButton = $window.FindName("InstallButton")
    $cancelButton = $window.FindName("CancelButton")
    $selectAllButton = $window.FindName("SelectAllButton")
    $limitedRadio = $window.FindName("LimitedRadio")
    $standardRadio = $window.FindName("StandardRadio")
    $fullRadio = $window.FindName("FullRadio")
    $optionalRadio = $window.FindName("OptionalRadio")

    # Function to load packages based on selected type
    function Load-Packages {
        param (
            [string]$selectedType,
            [array]$allPackages
        )

        $packageListPanel.Children.Clear()

        switch ($selectedType) {
            "Limited" {
                $filteredPackages = $allPackages | Where-Object { $_.categories -contains "Limited" }
            }
            "Standard" {
                $filteredPackages = $allPackages | Where-Object { $_.categories -contains "Standard" -or $_.categories -contains "Limited" }
            }
            "Full" {
                $filteredPackages = $allPackages | Where-Object { $_.categories -contains "Standard" -or $_.categories -contains "Limited" -or $_.categories -contains "Optional" }
            }
            "Optional" {
                $filteredPackages = $allPackages | Where-Object { $_.categories -contains "Optional" }
            }
        }

        # Sort the filtered packages by name alphabetically
        $filteredPackages = $filteredPackages | Sort-Object -Property name

        # Add packages to StackPanel with CheckBoxes
        foreach ($pkg in $filteredPackages) {
            $pkgManagers = @()
            if ($pkg.managers.winget.available) { $pkgManagers += "winget" }
            if ($pkg.managers.scoop.available) { $pkgManagers += "scoop" }
            if ($pkg.managers.chocolatey.available) { $pkgManagers += "chocolatey" }
            $managersStr = $pkgManagers -join ", "

            # Create CheckBox with custom style
            $item = New-Object System.Windows.Controls.CheckBox
            $item.Style = $window.FindResource("CustomCheckBox")
            $item.Content = "$($pkg.name) [$managersStr]"
            $item.Tag = $pkg  # Store the package object in the Tag property
            $item.IsChecked = $true
            $packageListPanel.Children.Add($item) | Out-Null
        }
    }

    # Initial load with default selection (Limited)
    Load-Packages -selectedType "Limited" -allPackages $packages

    # Radio button checked events
    $limitedRadio.Add_Checked({
        Load-Packages -selectedType "Limited" -allPackages $packages
    })
    $standardRadio.Add_Checked({
        Load-Packages -selectedType "Standard" -allPackages $packages
    })
    $fullRadio.Add_Checked({
        Load-Packages -selectedType "Full" -allPackages $packages
    })
    $optionalRadio.Add_Checked({
        Load-Packages -selectedType "Optional" -allPackages $packages
    })

    # Define "Select All" button click event
    $selectAllButton.Add_Click({
        # Get total number of items
        $totalItems = $packageListPanel.Children.Count
        # Count checked and unchecked items
        $checkedItems = 0
        foreach ($item in $packageListPanel.Children) {
            if ($item.IsChecked) {
                $checkedItems += 1
            }
        }
        $uncheckedItems = $totalItems - $checkedItems

        if ($checkedItems -eq $totalItems) {
            # All items are checked, unselect them all
            foreach ($item in $packageListPanel.Children) {
                $item.IsChecked = $false
            }
        } elseif ($uncheckedItems -eq $totalItems) {
            # All items are unchecked, select them all
            foreach ($item in $packageListPanel.Children) {
                $item.IsChecked = $true
            }
        } elseif ($checkedItems -gt $uncheckedItems) {
            # More items are checked than unchecked, select unselected items
            foreach ($item in $packageListPanel.Children) {
                if (-not $item.IsChecked) {
                    $item.IsChecked = $true
                }
            }
        } else {
            # More items are unchecked than checked, unselect everything
            foreach ($item in $packageListPanel.Children) {
                $item.IsChecked = $false
            }
        }
    })

    # Define Install button click event
    $installButton.Add_Click({
        $selectedPackages = @()
        foreach ($item in $packageListPanel.Children) {
            if ($item.IsChecked) {
                $selectedPackages += $item.Tag
            }
        }
        $window.Close()

        if (-not $selectedPackages) {
            Write-Host "No packages selected. Exiting."
            return
        }

        # Install selected packages
        Install-Packages -packages $selectedPackages -force:$force
    })

    # Define Cancel button click event
    $cancelButton.Add_Click({
        $window.Close()
        Write-Host "Installation canceled by user." -ForegroundColor Yellow
    })

    # Show the window
    $window.ShowDialog() | Out-Null
}

###############################################
# Main Execution
###############################################

# Ensure required modules are installed
function Test-Module {
    param (
        [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "$ModuleName module not found. Installing..." -ForegroundColor Yellow
        try {
            Install-Module -Name $ModuleName -Scope CurrentUser -Force
        }
        catch {
            Write-Error "Test-Module: Failed to install $ModuleName module: $_"
            exit
        }
    }
    Import-Module $ModuleName -Force
}

Test-Module -ModuleName "powershell-yaml"

# Is winget installed?
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget is not installed. Please install it from https://github.com/microsoft/winget-cli/releases" -ForegroundColor Red
    exit
}

# Load package configuration from YAML
$packageConfig = Load-PackageConfig -configFile $configFile

if ($null -eq $packageConfig) {
    Write-Host "Failed to load package configuration. Exiting." -ForegroundColor Red
    exit
}

Show-PackageSelectionWindow -packages $packageConfig.packages
