clear

$global:WarningPreference = "SilentlyContinue"
$global:ErrorActionPreference = "silentlyContinue"
$Path = $PSScriptRoot
Set-Location $Path

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Form = New-Object System.Windows.Forms.Form 
$Form.Text = "StarWind Storage Test"
$Form.Size = New-Object System.Drawing.Size(580,310) 
$Form.StartPosition = "CenterScreen"
$Form.SizeGripStyle = "Hide"
$Form.FormBorderStyle = "Fixed3D"
$Form.MaximizeBox = $False
$Form.WindowState = "Normal"
$Form.Icon = New-Object System.Drawing.Icon ("$PSScriptRoot\images\starwind.ico")
$Form.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Regular)
$Form.ForeColor = "#444444"

$DiskFirstLabel = New-Object System.Windows.Forms.Label
$DiskFirstLabel.Location = New-Object System.Drawing.Point(10,5) 
$DiskFirstLabel.Size = New-Object System.Drawing.Size(100,15)
$DiskFirstLabel.Text = "First disk:"
$Form.Controls.Add($DiskFirstLabel) 

$DiskFirstList = New-Object System.Windows.Forms.ComboBox 
$DiskFirstList.Location = New-Object System.Drawing.Point(10,25) 
$DiskFirstList.Size = New-Object System.Drawing.Size(250,100)
$DiskFirstList.Sorted = $True
$DiskFirstList.Text = "(none)"
$Form.Controls.Add($DiskFirstList) 

$DiskSecondLabel = New-Object System.Windows.Forms.Label
$DiskSecondLabel.Location = New-Object System.Drawing.Point(300,5) 
$DiskSecondLabel.Size = New-Object System.Drawing.Size(100,15)
$DiskSecondLabel.Text = "Second disk:"
$Form.Controls.Add($DiskSecondLabel) 

$DiskSecondList = New-Object System.Windows.Forms.ComboBox 
$DiskSecondList.Location = New-Object System.Drawing.Point(300,25) 
$DiskSecondList.Size = New-Object System.Drawing.Size(250,100)
$DiskSecondList.Sorted = $True
$DiskSecondList.Text = "(none)"
$Form.Controls.Add($DiskSecondList) 

Get-Partition | ? {$_.DriveLetter -ne "`0"} | ForEach-Object {[void] $DiskFirstList.Items.Add($_.DriveLetter+": ("+[math]::truncate($_.Size/1GB)+"GB)"); [void] $DiskSecondList.Items.Add($_.DriveLetter+": ("+[math]::truncate($_.Size/1GB)+"GB)")}
Get-ClusterSharedVolume | ? {$_.State -eq "Online"} | ForEach-Object {[void] $DiskFirstList.Items.Add($_.SharedVolumeInfo.FriendlyVolumeName+" ("+[math]::truncate($_.SharedVolumeInfo.Partition.Size/1GB)+"GB)"); [void] $DiskSecondList.Items.Add($_.SharedVolumeInfo.FriendlyVolumeName+" ("+[math]::truncate($_.SharedVolumeInfo.Partition.Size/1GB)+"GB)")}

$DurationLabel= New-Object System.Windows.Forms.Label
$DurationLabel.Location = New-Object System.Drawing.Point(10,57) 
$DurationLabel.Size = New-Object System.Drawing.Size(120,15)
$DurationLabel.Text = "Test run duration (s)"
$Form.Controls.Add($DurationLabel) 

$DurationText= New-Object System.Windows.Forms.TextBox
$DurationText.Location = New-Object System.Drawing.Point(130,55) 
$DurationText.Size = New-Object System.Drawing.Size(40,15)
$DurationText.Text = "60"
$Form.Controls.Add($DurationText) 

$WarmUpLabel= New-Object System.Windows.Forms.Label
$WarmUpLabel.Location = New-Object System.Drawing.Point(10,87) 
$WarmUpLabel.Size = New-Object System.Drawing.Size(120,15)
$WarmUpLabel.Text = "Warm up time (s)"
$Form.Controls.Add($WarmUpLabel) 

$WarmUpText= New-Object System.Windows.Forms.TextBox
$WarmUpText.Location = New-Object System.Drawing.Point(130,85) 
$WarmUpText.Size = New-Object System.Drawing.Size(40,15)
$WarmUpText.Text = "5"
$Form.Controls.Add($WarmUpText) 

$SizeLabel= New-Object System.Windows.Forms.Label
$SizeLabel.Location = New-Object System.Drawing.Point(10,117) 
$SizeLabel.Size = New-Object System.Drawing.Size(120,15)
$SizeLabel.Text = "Test file size (GB)"
$Form.Controls.Add($SizeLabel) 

$SizeText= New-Object System.Windows.Forms.TextBox
$SizeText.Location = New-Object System.Drawing.Point(130,115) 
$SizeText.Size = New-Object System.Drawing.Size(40,15)
$SizeText.Text = "500"
$Form.Controls.Add($SizeText) 

$ThreadsLabel= New-Object System.Windows.Forms.Label
$ThreadsLabel.Location = New-Object System.Drawing.Point(10,147) 
$ThreadsLabel.Size = New-Object System.Drawing.Size(120,15)
$ThreadsLabel.Text = "Number of threads"
$Form.Controls.Add($ThreadsLabel) 

$ThreadsText= New-Object System.Windows.Forms.TextBox
$ThreadsText.Location = New-Object System.Drawing.Point(130,145) 
$ThreadsText.Size = New-Object System.Drawing.Size(40,15)
$ThreadsText.Text = (Get-WmiObject win32_processor | measure-object NumberOfCores -sum).Sum/2
$Form.Controls.Add($ThreadsText) 

$IOsLabel= New-Object System.Windows.Forms.Label
$IOsLabel.Location = New-Object System.Drawing.Point(10,177) 
$IOsLabel.Size = New-Object System.Drawing.Size(120,15)
$IOsLabel.Text = "Number of I/Os"
$Form.Controls.Add($IOsLabel) 

$IOsText= New-Object System.Windows.Forms.TextBox
$IOsText.Location = New-Object System.Drawing.Point(130,175) 
$IOsText.Size = New-Object System.Drawing.Size(40,15)
$IOsText.Text = (Get-WmiObject win32_processor | measure-object NumberOfLogicalProcessors -sum).Sum/2
$Form.Controls.Add($IOsText) 

$PatternsLabel = New-Object System.Windows.Forms.Label
$PatternsLabel.Location = New-Object System.Drawing.Point(195,52) 
$PatternsLabel.Size = New-Object System.Drawing.Size(65,30)
$PatternsLabel.Text = " Patterns (use CTRL)"
$Form.Controls.Add($PatternsLabel) 

$PatternsList = New-Object System.Windows.Forms.ListBox
$PatternsList.Location = New-Object System.Drawing.Point(195,89) 
$PatternsList.Size = New-Object System.Drawing.Size(65,110)
$PatternsList.SelectionMode = "MultiExtended"
[void] $PatternsList.Items.Add("4K")
[void] $PatternsList.Items.Add("8K")
[void] $PatternsList.Items.Add("32K")
[void] $PatternsList.Items.Add("64K")
[void] $PatternsList.Items.Add("128K")
[void] $PatternsList.Items.Add("256K")
[void] $PatternsList.Items.Add("512K")
[void] $PatternsList.SelectedItems.Add("4K")
[void] $PatternsList.SelectedItems.Add("64K")
$Form.Controls.Add($PatternsList) 

$RandomLabel= New-Object System.Windows.Forms.Label
$RandomLabel.Location = New-Object System.Drawing.Point(300,57) 
$RandomLabel.AutoSize = $True
$RandomLabel.Text = "Random workload"
$Form.Controls.Add($RandomLabel) 

$RandomText= New-Object System.Windows.Forms.CheckBox
$RandomText.Location = New-Object System.Drawing.Point(535,57) 
$RandomText.Size = New-Object System.Drawing.Size(20,20)
$RandomText.Checked = $True;
$Form.Controls.Add($RandomText) 

$SequentialLabel= New-Object System.Windows.Forms.Label
$SequentialLabel.Location = New-Object System.Drawing.Point(300,87) 
$SequentialLabel.AutoSize = $True
$SequentialLabel.Text = "Sequential workload"
$Form.Controls.Add($SequentialLabel) 

$SequentialText= New-Object System.Windows.Forms.CheckBox
$SequentialText.Location = New-Object System.Drawing.Point(535,87) 
$SequentialText.Size = New-Object System.Drawing.Size(20,20)
$SequentialText.Checked = $True;
$Form.Controls.Add($SequentialText) 

$MixedLabel= New-Object System.Windows.Forms.Label
$MixedLabel.Location = New-Object System.Drawing.Point(300,117) 
$MixedLabel.AutoSize = $True
$MixedLabel.Text = "Include mixed 1/3 writes"
$Form.Controls.Add($MixedLabel) 

$MixedText= New-Object System.Windows.Forms.CheckBox
$MixedText.Location = New-Object System.Drawing.Point(535,117) 
$MixedText.Size = New-Object System.Drawing.Size(20,20)
$Form.Controls.Add($MixedText) 

$ExistingLabel= New-Object System.Windows.Forms.Label
$ExistingLabel.Location = New-Object System.Drawing.Point(300,147) 
$ExistingLabel.AutoSize = $True
$ExistingLabel.Text = "Use existing test file:"
$Form.Controls.Add($ExistingLabel) 

$ExistingText = New-Object System.Windows.Forms.CheckBox
$ExistingText.Location = New-Object System.Drawing.Point(535,147) 
$Form.Controls.Add($ExistingText) 

$AffinityLabel= New-Object System.Windows.Forms.Label
$AffinityLabel.Location = New-Object System.Drawing.Point(10,207) 
$AffinityLabel.AutoSize = $True
$AffinityLabel.Text = "Affinity string"
$Form.Controls.Add($AffinityLabel) 

$AffinityText= New-Object System.Windows.Forms.TextBox
$AffinityText.Location = New-Object System.Drawing.Point(130,205) 
$AffinityText.Size = New-Object System.Drawing.Size(130,20)
$AffinityText.Text = "-a"
for ($i = 0; $i -lt $ThreadsText.Text; $i++)
{
    $AffinityText.Text = $AffinityText.Text+$i+","
}
$AffinityText.Text = $AffinityText.Text.Substring(0,$AffinityText.Text.length-1)
$Form.Controls.Add($AffinityText) 

$StartButton = New-Object System.Windows.Forms.Button
$StartButton.Location = New-Object System.Drawing.Point(300,235)
$StartButton.Size = New-Object System.Drawing.Size(75,23)
$StartButton.Text = "Start"
$Form.Controls.Add($StartButton)

$StopButton = New-Object System.Windows.Forms.Button
$StopButton.Location = New-Object System.Drawing.Point(388,235)
$StopButton.Size = New-Object System.Drawing.Size(75,23)
$StopButton.Text = "Stop"
$StopButton.Enabled = $False
$Form.Controls.Add($StopButton)

$ExitButton = New-Object System.Windows.Forms.Button
$ExitButton.Location = New-Object System.Drawing.Point(475,235)
$ExitButton.Size = New-Object System.Drawing.Size(75,23)
$ExitButton.Text = "Exit"
$ExitButton.DialogResult = [System.Windows.Forms.DialogResult]::Abort
$Form.Controls.Add($ExitButton)

$VersionLabel= New-Object System.Windows.Forms.Label
$VersionLabel.Location = New-Object System.Drawing.Point(10,238) 
$VersionLabel.Size = New-Object System.Drawing.Size(182,20)
$VersionLabel.Text = "Storage Test v0.8 by Taras Shved"
$VersionLabel.ForeColor = "#888888"
$Form.Controls.Add($VersionLabel) 

$TwitterBox = New-Object Windows.Forms.PictureBox
$TwitterBox.Location = New-Object System.Drawing.Point(192,237) 
$TwitterBox.Height = 20;
$TwitterBox.Width = 20;
$TwitterBox.Image = [System.Drawing.Image]::Fromfile("$PSScriptRoot\images\twitter.png");
$TwitterBox.add_Click({[system.Diagnostics.Process]::start("http://www.twitter.com/tshved")})
$TwitterBox.Cursor = "Hand"
$Form.Controls.Add($TwitterBox)

$LinkedINBox = New-Object Windows.Forms.PictureBox
$LinkedINBox.Location = New-Object System.Drawing.Point(216,237) 
$LinkedINBox.Height = 20;
$LinkedINBox.Width = 20;
$LinkedINBox.Image = [System.Drawing.Image]::Fromfile("$PSScriptRoot\images\linkedin.png");
$LinkedINBox.add_Click({[system.Diagnostics.Process]::start("http://www.linkedin.com/in/taras-shved/")})
$LinkedINBox.Cursor = "Hand"
$Form.Controls.Add($LinkedINBox)

$EMailBox = New-Object Windows.Forms.PictureBox
$EMailBox.Location = New-Object System.Drawing.Point(240,237) 
$EMailBox.Height = 20;
$EMailBox.Width = 20;
$EMailBox.Image = [System.Drawing.Image]::Fromfile("$PSScriptRoot\images\email.png");
$EMailBox.add_Click({[system.Diagnostics.Process]::start("mailto:taras.shved@starwind.com")})
$EMailBox.Cursor = "Hand"
$Form.Controls.Add($EMailBox)

$ProgressLabel = New-Object System.Windows.Forms.Label
$ProgressLabel.Location = new-object System.Drawing.Size(300,175)
$ProgressLabel.size = new-object System.Drawing.Size(260,24)
$ProgressLabel.Text = "Configure required benchmark and press start"
$ProgressLabel.ForeColor = "#3399ff"
$Form.Controls.Add($ProgressLabel)

$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = new-object System.Drawing.Size(300,205)
$ProgressBar.size = new-object System.Drawing.Size(250,24)
$ProgressBar.Value = 0
$ProgressBar.Style = "Continuous"
$Progressbar.ForeColor = "#3399ff"
$Form.Controls.Add($ProgressBar)

$BenchmarkTask = {
    Param (
        $Path,
        $TestTime,
        $AccessParameter,
        $WriteParameter,
        $Threads,
        $IOs,
        $BlockParameter,
        $CacheStatus,
        $LatencyStatus,
        $WarmUpTime,
        $TestSize,
        $Affinity,
        $RandomSeed,
        $DiskName
    )
    Set-Location $Path
    .\diskspd.exe  $TestTime $AccessParameter $WriteParameter $Threads $IOs $BlockParameter $CacheStatus $LatencyStatus $WarmUpTime $TestSize $Affinity $RandomSeed $DiskName\Test.io
}

$StopButton.Add_Click({
    $Script:StopTrigger = $True
})

$StartButton.Add_Click({

    $StartButton.Enabled = $False
    $StopButton.Enabled = $True
    $ExitButton.Enabled = $False
    $Script:StopTrigger = $False

    $DiskFirst = $DiskFirstList.SelectedItem.Substring(0,$DiskFirstList.SelectedItem.IndexOf(" "))
    $DiskSecond = $DiskSecondList.SelectedItem.Substring(0,$DiskSecondList.SelectedItem.IndexOf(" "))
    $TestTime = “-d”+$DurationText.Text
    $WarmUpTime = “-W”+$WarmUpText.Text
    if ($ExistingText.Checked -eq $True) { $TestSize = "" } else { $TestSize = “-c”+$SizeText.Text+"G" } 
    $Threads = "-F"+ $ThreadsText.Text
    $IOs = "-o"+ $IOsText.Text
    $Affinity = $AffinityText.Text
    $CacheStatus = "-Sh"
    $LatencyStatus =  "-L"
    $RandomSeed = "-z"

    $TimeStamp = Get-Date -format "yyyy-MM-dd HH-mm-ss"
    $Results = "$PSScriptRoot\Test ($Threads $IOs $TestSize $TestTime $Affinity) $TimeStamp.html"

    if ($SequentialText.Checked -eq $True -and $RandomText.Checked -eq $True) { $Level1 = ("r","si") }
    elseif ($SequentialText.Checked -eq $True -and $RandomText.Checked -eq $False) { $Level1 = ("si") }
    elseif ($SequentialText.Checked -eq $False -and $RandomText.Checked -eq $True) { $Level1 = ("r") }
    else { break; }
    if ($MixedText.Checked -eq $True) { $Level2 = (0,100,33) } else { $Level2 = (0,100) }
    $Level3 = $PatternsList.SelectedItems

    $Counter = 0
    $DurationOfTests = $Level1.Count * $Level2.Count * $Level3.Count * 2 * (($DurationText.Text -as [int]) + ($WarmUpText.Text -as [int]))

    $DisplayString = "$Threads $IOs $TestSize $TestTime"
    "<style>BODY{font-family:Segoe UI,Tahoma,Verdana,Arial;font-size:14px;}.green{background:#d8e4bc;}.red{background:#fde9d9;}.blue{background:#b8cce4;text-align:center;font-size:10px;font-weight:bold;}.yellow{background:#ffff9b;}.grey{background:#d9d9d9;text-align:center;font-size:10px;font-weight:bold;}.grass{background:#c4d79b;text-align:center;font-size:10px;font-weight:bold;}td{vertical-align:middle;border:1px solid #000000;border-width:0px 1px 1px 0px;text-align:right;padding:5px;font-size:12px;font-family:Tahoma,Verdana,Arial;font-weight:normal;color:#000000;}tr:last-child td{border-width:0px 1px 0px 0px;}tr td:last-child{border-width:0px 0px 1px 0px;}tr:last-child td:last-child{border-width:0px 0px 0px 0px;}table{border-collapse: collapse;border-spacing: 0;margin:0px;padding:0px;border:1px solid #000000;}</style><table>"  >> $Results
    "<tr><td colspan=3 class=grey>$DisplayString</td><td colspan=4 class=grey>First disk</td><td colspan=4 class=blue>Second disk</td><td colspan=4 class=grass>Comparison</td></tr>"  >> $Results
    "<tr><td class=grey colspan=2>Test pattern</td><td class=grey>Block size</td><td class=grey>I/Ops</td><td class=grey>MBps</td><td class=grey>Latency (ms)</td><td class=grey>CPU Load</td><td class=blue>I/Ops</td><td class=blue>MBps</td><td class=blue>Latency (ms)</td><td class=blue>CPU Load</td><td class=grass>I/Ops</td><td class=grass>MBps</td><td class=grass>Latency</td><td class=grass>CPU Load</td></tr>"  >> $Results
    
    :benchmark foreach ($_ in $Level1) {
        if ($_ -eq "r") { $type = "Random"; $AccessParameter = "-"+$_} 
        if ($_ -eq "si") { $type = "Sequential"; $AccessParameter = "-"+$_}
        $Span = $Level2.Count * $Level3.Count
        "<tr><td rowspan=$Span class=grey>$type</td>"  >> $Results 
        foreach ($_ in $Level2) { 
            $IODivider++
            if ($_ -eq 0) { $IO = "Read" } 
            if ($_ -eq 100) { $IO = "Write" }
            if ($_ -eq 33) { $IO = "Mixed" } 
            $WriteParameter = "-w"+$_
            $Span = $Level3.Count
            if ($IODivider -eq 1) { "<td rowspan=$Span class=grey>$IO</td>"  >>	$Results }
            else {"<tr><td rowspan=$Span class=grey>$IO</td>"  >> $Results }
            foreach ($_ in $Level3) {
                $BlockDivider++
                $BlockParameter = ("-b"+$_)
                $Blocks = ("$_")
                $BenchmarkJob = Start-Job -Name FirstJob -ScriptBlock $BenchmarkTask -ArgumentList $Path, $TestTime, $AccessParameter, $WriteParameter, $Threads, $IOs, $BlockParameter, $CacheStatus, $LatencyStatus, $WarmUpTime, $TestSize, $Affinity, $RandomSeed, $DiskFirst
                While (Get-Job -Name FirstJob | Where { $_.State -eq "Running" })
                {  
                    if ($Script:StopTrigger -eq $True) { break benchmark }
                    $Counter++
                    [System.Windows.Forms.Application]::DoEvents()
                    Start-Sleep -Seconds 1
                    $ProgressBar.Value = 100 / $DurationofTests * $Counter
                    $TimeLeft = $DurationOfTests - $Counter
                    $ProgressLabel.Text = "Running $Blocks $type $IO ("+[math]::Max(0,$TimeLeft)+"s)"
                    $Form.Refresh()
                }
                $result = Receive-Job -Job $BenchmarkJob
                Get-Job -Name "FirstJob" | Remove-Job
                foreach ($line in $result) { if ($line -like "total:*") { $total=$line; break } }
                foreach ($line in $result) { if ($line -like "avg.*") { $avg=$line; break } }
                $mbps1 = [math]::Round($total.Split("|")[2].Trim())
                $iops1 = [math]::Round($total.Split("|")[3].Trim())
                $latency1 = "{0:N2}" -f [math]::Round($total.Split("|")[4].Trim(),2)
                $cpu1 = $avg.Split("|")[1].Trim()
                $BenchmarkJob = Start-Job -Name SecondJob -ScriptBlock $BenchmarkTask -ArgumentList $Path, $TestTime, $AccessParameter, $WriteParameter, $Threads, $IOs, $BlockParameter, $CacheStatus, $LatencyStatus, $WarmUpTime, $TestSize, $Affinity, $RandomSeed, $DiskSecond
                While (Get-Job -Name SecondJob | Where { $_.State -eq "Running" })
                {  
                    if ($Script:StopTrigger -eq $True) { break benchmark }
                    $Counter++
                    [System.Windows.Forms.Application]::DoEvents()
                    Start-Sleep -Seconds 1
                    $ProgressBar.Value = 100 / $DurationofTests * $Counter
                    $TimeLeft = $DurationOfTests - $Counter
                    $ProgressLabel.Text = "Running $Blocks $type $IO ("+[math]::Max(0,$TimeLeft)+"s)"
                    $Form.Refresh()
                }
                $result = Receive-Job -Job $BenchmarkJob
                Get-Job -Name "SecondJob" | Remove-Job
                foreach ($line in $result) { if ($line -like "total:*") { $total=$line; break } }
                foreach ($line in $result) { if ($line -like "avg.*") { $avg=$line; break } }
                $mbps2 = [math]::Round($total.Split("|")[2].Trim())
                $iops2 = [math]::Round($total.Split("|")[3].Trim())
                $latency2 = "{0:N2}" -f [math]::Round($total.Split("|")[4].Trim(),2)
                $cpu2 = $avg.Split("|")[1].Trim()            
                $mbps3 = [math]::Round($mbps2/$mbps1*100)
                $iops3 = [math]::Round($iops2/$iops1*100)
                $latency3 = [math]::Round($latency2/$latency1*100)
                $cpu3 = [math]::Round($cpu2.Substring(0,$cpu2.Length-1)/$cpu1.Substring(0,$cpu1.Length-1)*100)
    	        if ($BlockDivider -gt 1) { "<tr>"  >>	$Results }
                "<td class=grey>$Blocks</td><td><b>$iops1</b></td><td>$mbps1</td><td>$latency1</td><td>$cpu1</td><td><b>$iops2</b></td><td>$mbps2</td><td>$latency2</td><td>$cpu2</td>"  >> $Results
                if ($iops3 -ge 100) { "<td class=green><b>$iops3%</b></td>"  >> $Results } elseif ($iops3 -le 75) { "<td class=red><b>$iops3%</b></td>"  >> $Results } else {"<td class=yellow><b>$iops3%</b></td>"  >> $Results }
                if ($mbps3 -ge 100) { "<td class=green>$mbps3%</td>"  >> $Results } elseif ($mbps3 -le 75) { "<td class=red>$mbps3%</td>"  >> $Results } else {"<td class=yellow>$mbps3%</td>"  >> $Results }
                if ($latency3 -ge 300) { "<td class=red>$latency3%</td>"  >> $Results } elseif ($latency3 -le 200) { "<td class=green>$latency3%</td>"  >> $Results } else {"<td class=yellow>$latency3%</td>"  >> $Results }
                if ($cpu3 -ge 300) { "<td class=red>$cpu3%</td>"  >> $Results } elseif ($cpu3 -le 200) { "<td class=green>$cpu3%</td>"  >> $Results } else {"<td class=yellow>$cpu3%</td>"  >> $Results }
                "</tr>"  >> $Results
            }
            $BlockDivider = 0
        }
        $IODivider = 0
    }
    "</table>"  >> $Results
    if ($Script:StopTrigger -eq $True) { $ProgressLabel.Text = "Benchmarking stopped"; $ProgressBar.Value = 0 }
    else { $ProgressLabel.Text = "Benchmarking accomplished"; $ProgressBar.Value = 100 }
    $Script:StopTrigger = $False
    $StartButton.Enabled = $True
    $StopButton.Enabled = $False
    $ExitButton.Enabled = $True
    $Form.Refresh()
})

[void] $Form.Focus()
$Form.Topmost = $True
#$Form.Add_Shown({$Form.Activate()})
$Form.ShowDialog()
