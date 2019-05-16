Clear-Host
### Install-Module -Name LatestUpdate
### https://www.powershellgallery.com/packages/LatestUpdate/

### https://www.powershellgallery.com/packages/PS.B2/1.0.1
### Install-Module -Name PS.B2

Import-Module -Name PS.B2
Import-Module -Name LatestUpdate
Import-Module -Name BitsTransfer

$ISO                = "D:\Unattend\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US_UPDATED[16052019].ISO"
$PostInstallScript  = "D:\DEV\swposh\Unattended install\PostInstall.ps1"
$UnattendXML        = "D:\DEV\swposh\Unattended install\Autounattend.xml"
$SLAPath            = "D:\DEV\swposh\Unattended install\SLA_LicenseAgreement.exe"
$ISO_PARENT_DIR     = (split-path -Parent $ISO)
$EXTRACT_DIR        = "$ISO_PARENT_DIR\BUILD\EXTRACT_ISO"
$LCU_DIR            = "$ISO_PARENT_DIR\BUILD\LCU"
$OUTPUT_DIR         =  "$ISO_PARENT_DIR\BUILD\OUTPUT_ISO"
$WIM_MOUNT_DIR      = "$ISO_PARENT_DIR\BUILD\WIM_MOUNT"
$TMP                = "$ISO_PARENT_DIR\BUILD\TMP"
$WIM_PATH           = "$EXTRACT_DIR\sources\install.wim"
$UpdDate            = (Get-Date).ToString("ddMMyyy")

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
    $Filelist = Get-Childitem $Source -Recurse
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
        if (!(Test-Path -Path $WIM_PATH)){
            Start-Sleep -Seconds 1
        }
        else{
            Unblock-File -Path $WIM_PATH
            Set-ItemProperty -Path $WIM_PATH -Name IsReadOnly -Value $false
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
    Unblock-File -LiteralPath $WIM_PATH
    Set-ItemProperty -LiteralPath $WIM_PATH -Name IsReadOnly -Value $false
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
    Write-Host ""(Get-Date).ToString("dd/MM/yyyy HH:mm:ss")" Integration of updates into image ["$image.ImageName"] is starting" -Foregroundcolor Green
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
            Write-Host ""(Get-Date).ToString("dd/MM/yyyy HH:mm:ss")" Integrating [$upd]" -NoNewline
            Add-WindowsPackage -Path $WIM_MOUNT_DIR -PackagePath "$LCU_DIR\$upd" -ScratchDirectory "$TMP\" -LogLevel 2
            Write-Host "`t[OK]" -Foregroundcolor Green
        } catch {
            Write-Host "`t[Error]`n" -ForegroundColor Red
            $_
        }
    }
    try {
        Write-Host "Integrating POSTINSTALL script" -NoNewline
        New-Item -ItemType Directory -Path $WIM_MOUNT_DIR -Name "HCA" -Force | Out-Null
        Copy-WithProgress -Source $PostInstallScript -Destination "$WIM_MOUNT_DIR\HCA\"
        Write-Host "`t[OK]" -Foregroundcolor Green

        Write-Host "Integrating SLA script" -NoNewline
        Copy-WithProgress -Source $SLAPath -Destination "$WIM_MOUNT_DIR\HCA\"
        Write-Host "`t[OK]" -Foregroundcolor Green

        Write-Host ""(Get-Date).ToString("dd/MM/yyyy HH:mm:ss")" Unmounting WIM image ["$image.ImageName"] with index ["$image.ImageIndex"]" -NoNewline
        Dismount-WindowsImage -Path $WIM_MOUNT_DIR -Save -ScratchDirectory "$TMP" -CheckIntegrity  -LogLevel 2 | Out-Null
        Write-Host "`t[OK]" -Foregroundcolor Green
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
    #Copy-Item -Path $UnattendXML -Destination "$EXTRACT_DIR\" -Force
    $BOOTDATA = '2#p0,e,b"{0}"#pEF,e,b"{1}"' -f "$EXTRACT_DIR\boot\etfsboot.com","$EXTRACT_DIR\efi\Microsoft\boot\efisys_noprompt.bin"
    $Proc = Start-Process -FilePath "$PATHTOOSCDIMG\oscdimg.exe" -ArgumentList @("-bootdata:$BootData",'-u2','-udfver102',"$EXTRACT_DIR","$OUTPUT_DIR\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US_UPDATED_$UpdDate.ISO") -PassThru -Wait -NoNewWindow
    if($Proc.ExitCode -ne 0)
    {
        Throw "Failed to generate ISO with exitcode: $($Proc.ExitCode)"
    }
}
