Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName Microsoft.VisualBasic

# --- Utility functions ---

function Get-FileHashString($path, $algo) {
    $hash = Get-FileHash -Algorithm $algo -Path $path
    return $hash.Hash
}

function Select-File([string]$title) {
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Title = $title
    $dialog.Filter = "Binary files (*.bin)|*.bin|All files (*.*)|*.*"
    if ($dialog.ShowDialog() -eq $true) { return $dialog.FileName }
    return $null
}

function Save-File([string]$title, [string]$default) {
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Title = $title
    $dialog.Filter = "Binary files (*.bin)|*.bin|All files (*.*)|*.*"
    $dialog.FileName = $default
    if ($dialog.ShowDialog() -eq $true) { return $dialog.FileName }
    return $null
}

function Show-Result($title, $message) {
    $resultWindow = New-Object Windows.Window
    $resultWindow.Title = $title
    $resultWindow.SizeToContent = "WidthAndHeight"
    $resultWindow.ResizeMode = "NoResize"
    $resultWindow.WindowStartupLocation = "CenterScreen"

    $grid = New-Object Windows.Controls.Grid
    $grid.Margin = [Windows.Thickness]::new(10)

    $row1 = New-Object Windows.Controls.RowDefinition
    $row1.Height = New-Object Windows.GridLength(1,"Auto")
    $row2 = New-Object Windows.Controls.RowDefinition
    $row2.Height = New-Object Windows.GridLength(1,"Auto")
    $row3 = New-Object Windows.Controls.RowDefinition
    $row3.Height = New-Object Windows.GridLength(1,"Auto")
    $grid.RowDefinitions.Add($row1)
    $grid.RowDefinitions.Add($row2)
    $grid.RowDefinitions.Add($row3)

    # TextBox for message
    $tb = New-Object Windows.Controls.TextBox
    $tb.Text = $message
    $tb.IsReadOnly = $true
    $tb.TextWrapping = "Wrap"
    $tb.VerticalScrollBarVisibility = "Auto"
    $tb.Height = 220
    [Windows.Controls.Grid]::SetRow($tb,0)
    $grid.Children.Add($tb)

    # Close button
    $btnClose = New-Object Windows.Controls.Button
    $btnClose.Content = "Close"
    $btnClose.Width = 120
    $btnClose.Height = 30
    $btnClose.HorizontalAlignment = "Center"
    $btnClose.Margin = [Windows.Thickness]::new(0,10,0,10)
    $btnClose.Add_Click({ $resultWindow.Close() })
    [Windows.Controls.Grid]::SetRow($btnClose,1)
    $grid.Children.Add($btnClose)

    # Version/credit label
    $lblInfo = New-Object Windows.Controls.Label
    $lblInfo.Content = "Vinnie's MT-32 ROM Tool v1.0"
    $lblInfo.Foreground = [System.Windows.Media.Brushes]::Gray
    $lblInfo.FontStyle = "Italic"
    $lblInfo.HorizontalAlignment = "Center"
    [Windows.Controls.Grid]::SetRow($lblInfo,2)
    $grid.Children.Add($lblInfo)

    $resultWindow.Content = $grid
    $resultWindow.ShowDialog() | Out-Null
}

# --- Core functions ---

function Join {
    $mux0 = Select-File "Select Control ROM 0 (IC26)"; if (-not $mux0) { return }
    $mux1 = Select-File "Select Control ROM 1 (IC27)"; if (-not $mux1) { return }
    $output = Save-File "Save combined ROM as..." "ctrl_full.bin"; if (-not $output) { return }

    [byte[]]$data0 = [IO.File]::ReadAllBytes($mux0)
    [byte[]]$data1 = [IO.File]::ReadAllBytes($mux1)

    if ($data0.Length -ne $data1.Length) {
        [System.Windows.MessageBox]::Show("ROMs must be the same size (32K for MT Control ROMs).","Error","OK","Error")
        return
    }

    $combined = New-Object byte[] ($data0.Length + $data1.Length)
    for ($i=0; $i -lt $data0.Length; $i++) {
        $combined[2*$i] = $data0[$i]
        $combined[2*$i+1] = $data1[$i]
    }
    [IO.File]::WriteAllBytes($output, $combined)

    $sha1 = Get-FileHashString $output "SHA1"
    $md5  = Get-FileHashString $output "MD5"
    $msg = "Joined into: `"$output`"`r`nSize: $($combined.Length) bytes`r`nSHA1: $sha1`r`nMD5: $md5"

    Show-Result "ROMs Interleave Success!" $msg
}

function Split {
    $full = Select-File "Select full Control ROM"; if (-not $full) { return }

    [byte[]]$data = [IO.File]::ReadAllBytes($full)
    $mux0 = New-Object byte[] ($data.Length / 2)
    $mux1 = New-Object byte[] ($data.Length / 2)
    for ($i=0; $i -lt $mux0.Length; $i++) {
        $mux0[$i] = $data[2*$i]
        $mux1[$i] = $data[2*$i+1]
    }

    $out0 = Save-File "Save MUX0 as..." "ctrl_mux0.bin"; if (-not $out0) { return }
    $out1 = Save-File "Save MUX1 as..." "ctrl_mux1.bin"; if (-not $out1) { return }

    [IO.File]::WriteAllBytes($out0, $mux0)
    [IO.File]::WriteAllBytes($out1, $mux1)

    $sha1_0 = Get-FileHashString $out0 "SHA1"
    $md5_0  = Get-FileHashString $out0 "MD5"
    $sha1_1 = Get-FileHashString $out1 "SHA1"
    $md5_1  = Get-FileHashString $out1 "MD5"

    $msg = "Split into:`r`n$out0`r`n  SHA1: $sha1_0`r`n  MD5: $md5_0`r`n$out1`r`n  SHA1: $sha1_1`r`n  MD5: $md5_1"
    Show-Result "ROM Split Success!" $msg
}

function Trim-File {
    $inputFile = Select-File "Select file to trim"; if (-not $inputFile) { return }

    $sizeKB = [Microsoft.VisualBasic.Interaction]::InputBox("Enter size to trim to (in KB):","Trim File","32")
    if (-not $sizeKB -or -not [int]::TryParse($sizeKB,[ref]0)) { return }
    $sizeBytes = [int]$sizeKB * 1024

    [byte[]]$data = [IO.File]::ReadAllBytes($inputFile)
    if ($sizeBytes -gt $data.Length) {
        [System.Windows.MessageBox]::Show("That's bigger than the file already is!","Error","OK","Error")
        return
    }

    $trimmed = $data[0..($sizeBytes-1)]
    $outputFile = Save-File "Save as..." ([IO.Path]::GetFileNameWithoutExtension($inputFile) + "_trimmed.bin")
    if (-not $outputFile) { return }

    [IO.File]::WriteAllBytes($outputFile, $trimmed)

    $sha1 = Get-FileHashString $outputFile "SHA1"
    $md5  = Get-FileHashString $outputFile "MD5"
    $msg = "Trimmed file saved as: `"$outputFile`"`r`nSize: $($trimmed.Length) bytes`r`nSHA1: $sha1`r`nMD5: $md5"

    Show-Result "ROM trim successful!" $msg
}

# --- WPF Main Window ---

$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Vinnie's MT-32 ROM Tool" Height="260" Width="280"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center" Margin="10" >
        <Button Name="btnJoin" Content="Combine ROMS" Width="220" Height="32" Margin="0,5"/>
        <Button Name="btnSplit" Content="Split ROM" Width="220" Height="32" Margin="0,5"/>
        <Button Name="btnTrim" Content="Trim File" Width="220" Height="32" Margin="0,5"/>
        <Label Content="Vinnie's MT-32 ROM Tool v1.0" FontStyle="Italic" Foreground="Gray" HorizontalAlignment="Center" Margin="0,10,0,0"/>
    </StackPanel>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$Xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Attach events
$window.FindName("btnJoin").Add_Click({ Join })
$window.FindName("btnSplit").Add_Click({ Split })
$window.FindName("btnTrim").Add_Click({ Trim-File })
$window.FindName("btnJoin").ToolTip = "Interleave two seperated ROM files. Every other byte comes from every other file."
$window.FindName("btnSplit").ToolTip = "De-interleave a ROM into two parts. The reverse of Join."
$window.FindName("btnTrim").ToolTip = "Trim a ROM. You might need this if your control dumps are 64kb each. (default 32 KB)"

$window.ShowDialog() | Out-Null
