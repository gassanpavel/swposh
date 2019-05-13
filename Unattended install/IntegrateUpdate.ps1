### Install-Module -Name LatestUpdate
### https://www.powershellgallery.com/packages/LatestUpdate/

Import-Module LatestUpdate
Import-Module BitsTransfer

$ISO = "D:\Unattend\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US_UPDATED[26042019].ISO"

Function Copy-WithProgress{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        $Source,
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        $Destination
    )

    $Source=$Source.tolower()
    $Filelist = Get-Childitem $Source –Recurse
    $Total=$Filelist.count
    $Position=0

    foreach ($File in $Filelist)
    {
        $Filename=$File.Fullname.tolower().replace($Source,'')
        $DestinationFile=($Destination+$Filename)
        Write-Progress -Activity "Copying data from '$source' to '$Destination'" -Status "Copying File $Filename" -PercentComplete (($Position/$total)*100)
        Copy-Item $File.FullName -Destination $DestinationFile -Force
        $Position++
    }
}

function OpenIsoFile{
    [reflection.assembly]::loadwithpartialname("System.Windows.Forms") | out-null
    $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Title="Please select ISO image with Windows Server"
    }
    $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
    If($openFile.ShowDialog() -eq "OK"){
        Write-Output  "File $($openfile.FileName) selected"
        $ISO = $openFile.FileName
        return $ISO
    }
    else {
        Write-Host  "Iso was not selected... Exitting" -ForegroundColor Yellow
    }
}

function OpenFile{
    [reflection.assembly]::loadwithpartialname("System.Windows.Forms") | out-null
    $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Title="Please select Postinstall script"
    }
    $openFile.Filter = "ps1 files (*.ps1)|*.ps1|All files (*.*)|*.*" 
    If($openFile.ShowDialog() -eq "OK"){
        Write-Output  "File $($openfile.FileName) selected"
        $File = $openFile.FileName
        return $File
    }
    else {
        Write-Host  "Iso was not selected... Exitting" -ForegroundColor Yellow
    }
}

function informmsg{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        $msg
    )
    Write-Host "###`n$msg" -ForegroundColor DarkMagenta
}

if(!(Test-Path -LiteralPath $ISO)){
    OpenIsoFile
}

### mount iso
informmsg "Mounting [$ISO]"
if ((Get-DiskImage -ImagePath $ISO).Attached -like 'False'){
    Mount-DiskImage -ImagePath $ISO
    $MOUNTED_ISO_DRIVE_LETTER = (Get-DiskImage -ImagePath $ISO | Get-Volume).DriveLetter +":\"
    Write-Host "### [$ISO] file already mounted, drive letter is: " -NoNewline
    Write-Host "`t[$MOUNTED_ISO_DRIVE_LETTER]" -ForegroundColor Green
} 
else{
    Write-Host "###[$ISO] file already mounted, drive letter is: " -NoNewline
    $MOUNTED_ISO_DRIVE_LETTER = (Get-DiskImage -ImagePath $ISO | Get-Volume).DriveLetter +":\"
    Write-Host "`t[$MOUNTED_ISO_DRIVE_LETTER]" -ForegroundColor Green
}

### create folder structure
informmsg "Create folders structure"
$ISO_PARENT_DIR = (split-path $ISO)
$EXTRACT_DIR = "$ISO_PARENT_DIR\BUILD\EXTRACT_ISO"
$LCU_DIR = "$ISO_PARENT_DIR\BUILD\LCU"
$OUTPUT_DIR =  "$ISO_PARENT_DIR\BUILD\OUTPUT_ISO"
$WIM_MOUNT_DIR = "$ISO_PARENT_DIR\BUILD\WIM_MOUNT"
$TMP = "$ISO_PARENT_DIR\BUILD\TMP"
$FOLDERS=@("$EXTRACT_DIR", "$LCU_DIR", "$OUTPUT_DIR", "$WIM_MOUNT_DIR", "$TMP")

foreach ($FOLDER in $FOLDERS){
    if (!(Test-Path $FOLDER)){
        New-Item $FOLDER -ItemType Directory | Out-Null
        Write-Host "Folder [$FOLDER] create" -ForegroundColor Yellow
    }
    else{
        Write-Host "Folder [$FOLDER] exist" -ForegroundColor Green
    }
}

if ((Get-ChildItem $EXTRACT_DIR).Length -eq "0"){
    informmsg "Copy files and folders from mounted ISO to [$EXTRACT_DIR] folder"
    Copy-WithProgress -Source $MOUNTED_ISO_DRIVE_LETTER -Destination  "$EXTRACT_DIR\"
    informmsg "Get OS build version from WIM"
    While ($true){
        if (!(Test-Path -LiteralPath "$EXTRACT_DIR\sources\install.wim")){
            Start-Sleep -Seconds 1
        }
        else{
            # Write-Host "Move WIM file from [$EXTRACT_DIR] to [$TMP]" -foregroundcolor Blue -NoNewline
            # Move-Item -Path "$EXTRACT_DIR\sources\install.wim" -Destination "$TMP\" -Force
            # Write-Host "`tOK" -foregroundcolor Green
            #$WIM_PATH = "$TMP\install.wim"
            $WIM_PATH = "$EXTRACT_DIR\sources\install.wim"
            Unblock-File -LiteralPath $WIM_PATH
            Set-ItemProperty -LiteralPath $WIM_PATH -name IsReadOnly -value $false
            $OS_BUILD_VERSION = (Get-WindowsImage -ImagePath $WIM_PATH -index 1).version.Split(".")[-2]
            Write-Host "OS build version [$OS_BUILD_VERSION]" -foregroundcolor green
            try{
                Write-Host "#Unmouning [$ISO] from [$MOUNTED_ISO_DRIVE_LETTER]" -NoNewline
                Dismount-DiskImage -ImagePath $ISO
                Write-Host "`tOK" -ForegroundColor Green
            } catch {
                Write-Host "`t[Error]`n" -ForegroundColor Red
                $_
            }
            break
        }
    }
}
else{
    $WIM_PATH = "$EXTRACT_DIR\sources\install.wim"
    Unblock-File -LiteralPath $WIM_PATH
    Set-ItemProperty -LiteralPath $WIM_PATH -name IsReadOnly -value $false
    $OS_BUILD_VERSION = (Get-WindowsImage -ImagePath $WIM_PATH -index 1).version.Split(".")[-2]
    Write-Host "OS build version [$OS_BUILD_VERSION]" -foregroundcolor green
    try{
        Write-Host "#Unmouning [$ISO] from [$MOUNTED_ISO_DRIVE_LETTER]" -NoNewline
        Dismount-DiskImage -ImagePath $ISO
        Write-Host "`tOK" -ForegroundColor Green
    } catch {
        Write-Host "`t[Error]`n" -ForegroundColor Red
        $_
    }
}

### Download latest Cumulative update 
informmsg "Check latest Cumulative update in [$LCU_DIR]"
$UPDATE_PAKCAGE_NAME = ((Get-LatestUpdate -Build $OS_BUILD_VERSION | Where-Object{$_.Note -like "*Cumulative Update for Windows Server 2016 for x64-based Systems*"}).URL).split("/")[-1]
if(!(Test-Path $LCU_DIR/$UPDATE_PAKCAGE_NAME)){
    Write-Host "[$UPDATE_PAKCAGE_NAME] NOT exist and will be downloaded"
    Start-BitsTransfer -Source (Get-LatestUpdate -Build $OS_BUILD_VERSION  | Where-Object{$_.Note -like "*Cumulative Update for Windows Server 2016 for x64-based Systems*"}).URL -Destination $LCU_DIR
}
else{
    Write-Host "[$UPDATE_PAKCAGE_NAME] exist" -ForegroundColor Green
}

### Intergate updates in WIM file
informmsg "`nIntegrating updates in [$WIM_PATH]"
$IMAGES = Get-WindowsImage -ImagePath $WIM_PATH
$update = Get-ChildItem $LCU_DIR | Select-Object -Property Name
foreach($image in $IMAGES){
    $imgIndex = $image.ImageIndex
    Write-Host ""(Get-Date).ToString("dd/MM/yyyy HH:mm:ss")" Integration of updates into image ["$image.ImageName"] is starting" -foregroundcolor Green
    try {
        Write-Host ""(Get-Date).ToString("dd/MM/yyyy HH:mm:ss")" Mount [$WIM_PATH] image ["$image.ImageName"] with index ["$image.ImageIndex"] to [$WIM_MOUNT_DIR]" -NoNewline
        Mount-WindowsImage -ImagePath $WIM_PATH -Index $imgIndex -Path $WIM_MOUNT_DIR -ScratchDirectory "$TMP\" -LogLevel 2 | Out-Null

        Write-Host "`t[OK]" -Foregroundcolor green
    } catch {
        Write-Host "`t[Error]`n" -ForegroundColor Red
        $_
    }
    foreach($upd in $update.Name){
        try {
            Write-Host ""(Get-Date).ToString("dd/MM/yyyy HH:mm:ss")" Integrating [$upd]" -nonewline
            ###Add-WindowsPackage -Path $WIM_MOUNT_DIR -PackagePath "$LCU_DIR\$upd" -ScratchDirectory "$TMP\" -LogLevel 2
            Write-Host "`t[OK]" -Foregroundcolor green
        } catch {
            Write-Host "`t[Error]`n" -ForegroundColor Red
            $_
        }
    }
    try {
        Write-Host "Integrating POSTINSTALL script" -NoNewline
        Copy-WithProgress -Source OpenFile -Destination "$WIM_MOUNT_DIR\"
        Write-Host "`t[OK]" -Foregroundcolor green
        
        Write-Host ""(Get-Date).ToString("dd/MM/yyyy HH:mm:ss")" Unmounting WIM image ["$image.ImageName"] with index ["$image.ImageIndex"]" -NoNewline
        Dismount-WindowsImage -Path $WIM_MOUNT_DIR -Save -ScratchDirectory "$TMP\" -CheckIntegrity  -LogLevel 2 | Out-Null
        Write-Host "`t[OK]" -Foregroundcolor green
    } catch {
        Write-Host "`t[Error]`n" -ForegroundColor Red
        $_
    }
}

### "Creating .iso file in ""$OUTPUT_DIR\"""
informmsg "Creating .iso file in [$OUTPUT_DIR\]"
$PATHTOOSCDIMG = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
if (!(Test-Path $PATHTOOSCDIMG\oscdimg.exe)){
    Write-Host "Oupps, cannot find Oscdimg.exe. Aborting" -ForegroundColor Red
    Break
}
else{
    $BOOTDATA = '2#p0,e,b"{0}"#pEF,e,b"{1}"' -f "$EXTRACT_DIR\boot\etfsboot.com","$EXTRACT_DIR\efi\Microsoft\boot\efisys_noprompt.bin"
    $Proc = Start-Process -FilePath "$PATHTOOSCDIMG\oscdimg.exe" -ArgumentList @("-bootdata:$BootData",'-u2','-udfver102',"$EXTRACT_DIR","$OUTPUT_DIR\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US_UPDATED.ISO") -PassThru -Wait -NoNewWindow
    if($Proc.ExitCode -ne 0)
    {
        Throw "Failed to generate ISO with exitcode: $($Proc.ExitCode)"
    }
}