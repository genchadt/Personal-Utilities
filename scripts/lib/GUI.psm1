function Show-PackageSelectionWindow {
<#
.SYNOPSIS
    Show-PackageSelectionWindow - Shows the package selection GUI.

.DESCRIPTION
    Shows the package GUI. Contains the UI elements and logic for the package selection GUI.

.PARAMETER packages
    An array of packages to be displayed in the GUI.

.OUTPUTS
    System.Array
#>
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

    function Update-PackageList {
        param (
            [string]$SelectedPackageList,
            [array]$AllPackages
        )

        $packageListPanel.Children.Clear()

        switch ($SelectedPackageList) {
            "Limited" {
                $filteredPackages = $AllPackages | Where-Object { $_.categories -contains "Limited" }
            }
            "Standard" {
                $filteredPackages = $AllPackages | Where-Object { $_.categories -contains "Standard" -or $_.categories -contains "Limited" }
            }
            "Full" {
                $filteredPackages = $AllPackages | Where-Object { $_.categories -contains "Standard" -or $_.categories -contains "Limited" -or $_.categories -contains "Optional" }
            }
            "Optional" {
                $filteredPackages = $AllPackages | Where-Object { $_.categories -contains "Optional" }
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
    Update-PackageList -SelectedPackageList "Limited" -AllPackages $packages

    # Radio button checked events
    $limitedRadio.Add_Checked({
        Update-PackageList -SelectedPackageList "Limited" -AllPackages $packages
    })
    $standardRadio.Add_Checked({
        Update-PackageList -SelectedPackageList "Standard" -AllPackages $packages
    })
    $fullRadio.Add_Checked({
        Update-PackageList -SelectedPackageList "Full" -AllPackages $packages
    })
    $optionalRadio.Add_Checked({
        Update-PackageList -SelectedPackageList "Optional" -AllPackages $packages
    })

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

    $installButton.Add_Click({
        $selectedPackages = @()
        foreach ($item in $packageListPanel.Children) {
            if ($item.IsChecked) {
                $selectedPackages += $item.Tag
            }
        }
        $window.Close()
        if (-not $selectedPackages) {
            return
        }
        $script:SelectedPackages = $selectedPackages
    })

    $cancelButton.Add_Click({
        $window.Close()
    })

    $window.Add_Closed({
    })

    try {
        $window.ShowDialog() | Out-Null
    }
    catch {
        Write-Error "Show-PackageSelectionWindow: Failed to show GUI window: $_"
    }

    return $script:SelectedPackages
}

Export-ModuleMember -Function Show-PackageSelectionWindow