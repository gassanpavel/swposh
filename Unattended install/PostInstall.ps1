Clear-Host
Import-Module BitsTransfer

### Define variables

$Manufacturer                   = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$OSVersion                      = ((Get-CimInstance Win32_OperatingSystem).Caption).split(" ")[3]
$VCppDownloadUri                = 'https://aka.ms/vs/16/release/VC_redist.x64.exe'
$VMwareToolsDownloadUri         = 'https://packages.vmware.com/tools/esx/latest/windows/x64/index.html'
$VMwareToolsVersion             = ((Invoke-WebRequest -Uri $VMWareToolsDownloadUri -UseBasicParsing).links | Where-Object {$_.href -like 'VMware*'}).href
$OMSADownloadUri                = 'https://downloads.dell.com/FOLDER05170353M/1/OM-SrvAdmin-Dell-Web-WINX64-9.2.0-3142_A00.exe'
#$StarWindVSANDownloadUri        = 'https://www.starwindsoftware.com/tmplink/starwind-v8.exe'
$StarWindVSANDownloadUri        = 'https://f002.backblazeb2.com/file/SW-Support/StarWind_8.0_R8_20181121_12658_6517_434_1072-R8-release.exe'
$StarWindHealthDownloadUri      = 'https://www.starwindsoftware.com/tmplink/starwindhealthservice.zip'
$MellanoxWinOFDownloadUri       = 'http://www.mellanox.com/downloads/WinOF/MLNX_VPI_WinOF-5_50_52000_All_win' + "$OSVersion" + '_x64.exe'
$MellanoxWinOF2DownloadUri      = 'http://www.mellanox.com/downloads/WinOF/MLNX_WinOF2-2_20_50000_All_x64.exe'
$StarWindHealthUser             = 'Health'
$StarWindHealthPassword         = 'StarWind2015!'
$RegPath                        = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$NetFramework472Uri             = 'https://go.microsoft.com/fwlink/?LinkId=863265'
$NetFramework48Uri              = 'https://go.microsoft.com/fwlink/?linkid=2088631'

### Configure disks

### Import script to show Menu https://github.com/QuietusPlus/Write-Menu
. $PSScriptRoot\Write-Menu.ps1

### If "CanPool" disks >= 2 - create Storage Space

if ((Get-PhysicalDisk -CanPool $true).count -ge 2) 
{

    ### Create Pool 

    New-StoragePool -StorageSubSystemFriendlyName "Windows Storage*" -FriendlyName "StoragePool" -PhysicalDisks (Get-PhysicalDisk -CanPool $true)
    if ((Get-PhysicalDisk | Where-Object {$_.MediaType -eq "Unspecified"}).count -ge 2)
    {
        ### Set media type
        try{
            $HDD = Get-PhysicalDisk | Where-Object {$_.cannotpoolreason -eq "In a Pool" -and $_.MediaType -eq "Unspecified"} `
                | Select-Object -Property FriendlyName, UniqueId, @{Name = 'Size in Gb'; Expression = {[math]::round($_.Size/1Gb)}}
            if(($HDD | Measure-Object).Count -ge 1)
            {
                $selectHDD = Write-Menu -Title 'Select drives for HDD media type' -Entries @($HDD) -MultiSelect -Sort
                foreach($HDDDrive in $selectHDD){
                    Set-PhysicalDisk -MediaType HDD -UniqueId $HDDDrive.UniqueId -ErrorAction SilentlyContinue
                }
            }

            $SSD = Get-PhysicalDisk | Where-Object {$_.cannotpoolreason -eq "In a Pool" -and $_.MediaType -eq "Unspecified"} `
                | Select-Object -Property FriendlyName, UniqueId, @{Name = 'Size in Gb'; Expression = {[math]::round($_.Size/1Gb)}}
            if(($SSD | Measure-Object).Count -ge 1)
            {
                $selectSSD = Write-Menu -Title 'Select drives for SSD media type' -Entries @($SSD) -MultiSelect -Sort
                foreach($SSDDrive in $selectSSD){
                    Set-PhysicalDisk -MediaType SSD -UniqueId $SSDDrive.UniqueId -ErrorAction SilentlyContinue
                }
            }
        }
        catch
        {
            $_
        }

        ### Create Storage Tier

        New-StorageTier -MediaType SSD -StoragePoolFriendlyName StoragePool -FriendlyName SSDTier -ResiliencySettingName Mirror -NumberOfDataCopies 2 -Interleave 65536 | Out-Null
        New-StorageTier -MediaType HDD -StoragePoolFriendlyName StoragePool -FriendlyName HDDTier -ResiliencySettingName Parity -Interleave 65536 | Out-Null
        $SSDTier = Get-StorageTier -FriendlyName SSDTier
        $HDDTier = Get-StorageTier -FriendlyName HDDTier
        $HDDStorageTierSize = ((((((Get-PhysicalDisk | Where-Object {$_.MediaType -eq "HDD"}).size) | Measure-Object -Sum).Sum)/1Gb) - 10).ToString() + "Gb"
        $SSDStorageTierSize = ((((((Get-PhysicalDisk | Where-Object {$_.MediaType -eq 'SSD'}).size) | Measure-Object -Sum).Sum)/1Gb) - 10).ToString() + "Gb"


        Get-StoragePool "StoragePool" | New-VirtualDisk -FriendlyName "VD" -ResiliencySettingName "Simple" -ProvisioningType "Fixed" `
        -StorageTiers @($SSDTier, $HDDTier) -StorageTierSizes @(($SSDStorageTierSize/1), ($HDDStorageTierSize/1)) -AutoWriteCacheSize | Out-Null

        ### Format Volume

        foreach ($disk in $D = Get-Disk | Where-Object {$_.FriendlyName -like "*VD*" -and $_.PartitionStyle -like "*RAW*"})
        {
            $D | Where-Object {$_.OperationalStatus -eq "Offline"} | Set-Disk -IsOffline $false 
            Get-Disk $disk.number | Initialize-Disk  -PartitionStyle GPT -PassThru | New-Partition -DriveLetter S -UseMaximumSize `
                | Get-Partition | Format-Volume | Set-Volume -NewFileSystemLabel "Storage"
        }
    }   
}

### If RAW disk count eq to 1 - create partition and format it

elseif ((Get-Disk | Where-Object {$_.PartitionStyle -eq "RAW"} | Measure-Object).Count -eq 1){
    foreach ($disk in $D = Get-Disk | Where-Object {$_.PartitionStyle -like "*RAW*"})
    {
        $D | Where-Object {$_.OperationalStatus -eq "Offline"} | Set-Disk -IsOffline $false 
        Get-Disk $disk.number | Initialize-Disk  -PartitionStyle GPT -PassThru | New-Partition -DriveLetter S -UseMaximumSize `
            | Get-Partition | Format-Volume | Set-Volume -NewFileSystemLabel "Storage"
    }
}


### Disable Firewall 

try{
    Write-Host "Disabling firewall" -NoNewline
    Set-NetFirewallProfile -All -Enabled False
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`tError`n" -ForegroundColor Red
    $_
}

### Enable RPD connections

try{
    Write-Host "Enable RDP connections" -NoNewline
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" 0
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`tError`n" -ForegroundColor Red
    $_
}

### Enable WinRM

try{
    Write-Host "Enable WinRM connections" -NoNewline
    Enable-PSRemoting -SkipNetworkProfileCheck -Force | Out-Null
    Get-Service -Name WinRM | Start-Service -Confirm:$false
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`tError`n" -ForegroundColor Red
    $_
}

### Installing NuGet package provider

try{
    Write-Host "Installing NuGet package provider" -NoNewline
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Confirm:$false -Force | Out-Null
    Write-Host "`tOK" -ForegroundColor Green

}
catch{
    Write-Host "`tError`n" -ForegroundColor Red
    $_
}

### Allow to install modules from PSGallery to install powercli module

try{
    Write-Host "Allow to install modules from PSGallery to install powercli module" -NoNewline
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`tError`n" -ForegroundColor Red
    $_
}

try{
    ### Download .Net 4.7.2 framework
    Write-Host "Downloading .Net 4.7.2 framework" -NoNewline
    Start-BitsTransfer -Source $NetFramework472Uri -Destination $PSScriptRoot"\DotNet472.exe" `
        -Description "Downloading .Net 4.7.2 framework"
    Write-Host "`tOK" -ForegroundColor Green

    ### Install .Net 4.7.2 framework
    Write-Host "Installing .Net 4.7.2 framework" -NoNewline
    Start-Process -FilePath $PSScriptRoot"\DotNet472.exe" -ArgumentList "/q /norestart" -Wait
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`tError" -ForegroundColor Red
    Write-Host "Cant download .Net 4.7.2 framework. Please download it from $NetFramework472Uri and install manually`n" -ForegroundColor Yellow
}

try{
    ### Download .Net 4.8 framework
    Write-Host "Downloading .Net 4.8 framework" -NoNewline
    Start-BitsTransfer -Source $NetFramework48Uri -Destination $PSScriptRoot"\DotNet48.exe" `
        -Description "Downloading .Net 4.8 framework"
    Write-Host "`tOK" -ForegroundColor Green

    ### Install .Net 4.8 framework
    Write-Host "Installing .Net 4.8 framework" -NoNewline
    Start-Process -FilePath $PSScriptRoot"\DotNet48.exe" -ArgumentList "/q /norestart" -Wait
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`tError" -ForegroundColor Red
    Write-Host "Cant download .Net 4.8 framework. Please download it from $NetFramework48Uri and install manually`n" -ForegroundColor Yellow
}

### Download and install C++ Redistribution

try{
    ### Download C++ Redistribution
    Write-Host "Downloading Visual C++ Redistribution" -NoNewline
    Start-BitsTransfer -Source $VCppDownloadUri -Destination $PSScriptRoot"\VC_redist.x64.exe" `
        -Description "Downloading Visual C++ Redistribution"
    Write-Host "`tOK" -ForegroundColor Green

    ### Install C++ Redistribution
    Write-Host "Installing Visual C++ Redistribution" -NoNewline
    Start-Process -FilePath $PSScriptRoot"\VC_redist.x64.exe" -ArgumentList "/install /q /norestart" -Wait
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`tError`n" -ForegroundColor Red
    Write-Host "Cant download VC++. Please download it from $VCppDownloadUri and install manually"
}

### Set ConfigurationScript to next boot

try{
    Write-Host "Set Autostart ConfigurationScript.ps1"
    New-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" AutoRunScript -propertytype String -value "Powershell $PSScriptRoot'\ConfigurationScript.ps1'" | Out-Null
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`tError`n"
}

### Set autologin count = 1
try{
    Write-Host "Set AutoLogin count to 1"
    Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String 
    Set-ItemProperty $RegPath "DefaultUsername" -Value "Administrator" -type String 
    Set-ItemProperty $RegPath "DefaultPassword" -Value "StarWind2015" -type String
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`tError`n"
}

function InstallStarWindVSAN{
    try{
        Write-Host "Download latest StarWindVSAN build" -NoNewline
        Start-BitsTransfer -Source $StarWindVSANDownloadUri -Destination $PSScriptRoot"\starwind.exe" `
            -Description "Download latest StarWindVSAN build"
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        Write-Host "Cant download StaWindVSAN. Please download it from $StarWindVSANDownloadUri and install manually"
    }
    
    
    ### Install StarWindVSAN
    
    try{
        Write-Host "Install StarWindVSAN" -NoNewline
        Start-Process -FilePath $PSScriptRoot"\starwind.exe" -Wait
        Write-Host "`tOK" -ForegroundColor Green
    
        ### Install StarWind SLA
        Move-Item -Path $PSScriptRoot"\SLA_LicenseAgreement.exe" -Destination "C:\Program Files\StarWind Software\StarWind\SLA_LicenseAgreement.exe"
        Write-Host "Install SLA LicenseAgreement" -NoNewline
        Start-Process -FilePath "C:\Program Files\StarWind Software\StarWind\SLA_LicenseAgreement.exe" -Wait
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }
}

function InstallStarWindHealthService{
    try{
        Write-Host "Downloading latest StarWindHealthService" -NoNewline
        Start-BitsTransfer -Source $StarWindHealthDownloadUri -Destination $PSScriptRoot"\starwindhealthservice.zip" `
            -Description "Downloading latest StarWindHealthService"
        Write-Host "`tOK" -ForegroundColor Green
    
    ### Extracting StarWindHealthService
    
        Write-Host "Extract StarWindHealthService" -NoNewline
        Expand-Archive -Path $PSScriptRoot"\starwindhealthservice.zip" -DestinationPath $PSScriptRoot"\" -Force
        Expand-Archive -Path $PSScriptRoot"\starwindhealthservice\starwindhealthservice.zip" `
            -DestinationPath $PSScriptRoot"\starwindhealthservice" -Force
        ### Yes, I know, this is stupid,
        ### to place the archive into the archive, 
        ### but our web development department, 
        ### which is responsible for the operation of the FTP server, 
        ### cannot change MIME types so that the archived file is downloaded by the archive without changes ... ((((
        Write-Host "`tOK" -ForegroundColor Green
    
    ### Installing StarWindHealthService
    
        Write-Host "Installing StarWindHealthService" -NoNewline
        Start-Process -FilePath $PSScriptRoot"\starwindhealthservice\starwindhealthservice.exe" `
            -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS' -Wait
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        Write-Host "Cant download StaWindHealth. Please download it from $StarWindHealthDownloadUri and install manually"
    }
}

function InstallVMwareStuff{
    try{
        Write-Host "Downloading latest Vmware tools" -NoNewline
        Start-BitsTransfer -Source ($VMwareToolsDownloadUri.Replace('index.html', $VMwareToolsVersion)) `
            -Destination $PSScriptRoot"\$VMwareToolsVersion" `
            -Description "Downloading latest Vmware tools"
        Write-Host "`tOK" -ForegroundColor Green

    ### Install VMware tools

        Write-Host "Installing VMware tools" -NoNewline
        Start-Process -FilePath $PSScriptRoot"\$VMwareToolsVersion" -ArgumentList '/S /v "/qn REBOOT=R ADDLOCAL=ALL"' -Wait
        Write-Host "`tOK" -ForegroundColor Green

        Write-Host "Installing powerCLI" -NoNewline
        Install-Module -Name VMware.PowerCLI -Scope AllUsers -Confirm:$false -Force | Out-Null
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }

### Create HEALTH USER on ESXi host

function ESXiConnect{
    while ($true){
        try{
            [ipaddress]$ESXiIp = read-host "Type IP address of the local ESXi server"
            break
        }
        catch{
            Clear-Host
            Write-Host "`nIP address is not valid. Try again`n"
        }
    }

    $SecureStringESXiPassword = Read-Host -AsSecureString "Please enter your password"
    $ESXiPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureStringESXiPassword)) 
    Write-Host "Connecting to ESXi host" -NoNewline
    Set-PowerCLIConfiguration -InvalidCertificateAction ignore -Confirm:$false | Out-Null
    Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $true -Confirm:$false | Out-Null
    if (!(Connect-VIServer -Server $ESXiIp -User root -Password $ESXiPassword -ErrorAction SilentlyContinue)){
        Clear-Host
        Write-Host "`nCant connect to ESXi server. Check your IP or credentials and try again`n" -ForegroundColor Red
        ESXiConnect
        break
    }
    
    else{
        Write-Host "`tOK" -ForegroundColor Green
        try{
            ### Connect to ESXi host
            
            Set-PowerCLIConfiguration -InvalidCertificateAction ignore -Confirm:$false | Out-Null
            Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $true -Confirm:$false | Out-Null

            ### Create HEALTH USER
    
            Write-Host "Create HEALTH USER" -NoNewline
            New-VMHostAccount -Id $StarWindHealthUser -Password $StarWindHealthPassword -Description "Vendor Support" | Out-Null
            New-VIRole -Name StarWind | Out-Null
            Set-VIRole -Role StarWind -AddPrivilege Inventory | Out-Null
            Set-VIRole -Role StarWind -AddPrivilege Configuration | Out-Null
            Set-VIRole -Role StarWind -AddPrivilege 'Local operations' | Out-Null
            Set-VIRole -Role StarWind -AddPrivilege CIM | Out-Null
            Set-VIRole -Role StarWind -AddPrivilege 'vSphere Replication' | Out-Null
            Set-VIRole -Role StarWind -AddPrivilege Settings | Out-Null
            Set-VIRole -Role StarWind -AddPrivilege Diagnostics | Out-Null
            New-VIPermission -Role StarWind -Principal Health -Entity (Get-VMHost) | Out-Null
            Disconnect-VIServer -Server * -Confirm:$false | Out-Null
            Write-Host "`tOK" -ForegroundColor Green
        }
        catch{
            Write-Host "`tError`n" -ForegroundColor Red
            $_
        }
        try{
            Write-Host "Creating RescanScript" -NoNewline
            $RescanScript = @"
Import-Module VMware.PowerCLI
`$counter = 0
if (`$counter -eq 0){
`t	Set-PowerCLIConfiguration -InvalidCertificateAction ignore -Confirm:`$false | Out-Null
}
`$ESXiHost = "$ESXiIp"
`$ESXiUser = "$StarWindHealthUser"
`$ESXiPassword = "$StarWindHealthPassword"
Connect-VIServer `$ESXiHost -User `$ESXiUser -Password `$ESXiPassword | Out-Null
Get-VMHostStorage `$ESXiHost -RescanAllHba | Out-Null
Get-ScsiLun -VMHost `$ESXiHost -LunType disk | Where-Object Vendor -EQ "STARWIND"|
Where-Object ConsoleDeviceName -NE " " | Set-ScsiLun -MultipathPolicy RoundRobin -CommandsToSwitchPath 1 |
Out-Null
Disconnect-VIServer `$ESXiHost -Confirm:`$false
`$file = Get-Content "`$PSScriptRoot\rescan_script.ps1"
if (`$file[1] -ne "```$counter = 1") {
`t    `$file[1] = "```$counter = 1"
`t   `$file > "`$PSScriptRoot\rescan_script.ps1"
}
"@
        $RescanScript | Out-File -FilePath C:\rescan_script.ps1 -Encoding utf8
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
            Write-Host "`tError`n" -ForegroundColor Red
            $_
    }
    try{
        Write-Host "Creating scheduler task for Rescan_script.ps1" -NoNewline
        Start-Process -FilePath schtasks.exe -ArgumentList "/Create /RU administrator /RP StarWind2015 /TN ""Rescan ESXi"" /XML ""$PSScriptRoot""\rescan_esx.xml"" " -Wait
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }

    }

ESXiConnect
}
}

function InstallDellOMSA{
    try{
    ### Download Dell OMSA

        Write-Host "Downloading DELL OMSA" -NoNewline
        Start-BitsTransfer -Source $OMSADownloadUri -Destination $PSScriptRoot"\OMSA.zip" `
            -Description "Downloading DELL OMSA"
        Write-Host "`tOK" -ForegroundColor Green
    
    ### Extracting Dell OMSA
    
        Write-Host "Extract OMSA" -NoNewline
        Expand-Archive -Path $PSScriptRoot"\OMSA.zip" -DestinationPath $PSScriptRoot"\OMSA" -Force
        Write-Host "`tOK" -ForegroundColor Green
    
    ### Installing Dell OMSA
    
        Write-Host "Installing OMSA" -NoNewline
        Start-Process -FilePath $PSScriptRoot"\OMSA\windows\SystemsManagementx64\SysMgmtx64.msi" -ArgumentList 'ADDLOCAL=ALL /qn' -Wait
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }
}

function InstallMellanoxDrivers{
    if ((Get-NetAdapter).InterfaceDescription -like 'Mellanox ConnectX-3*'){    
        try{
                Write-Host "Downloading WinOF driver" -NoNewline
                Start-BitsTransfer -Source $MellanoxWinOFDownloadUri -Destination $PSScriptRoot"\MLNX_VPI_WinOF.exe" `
                -Description "Downloading WinOF driver"
                Write-Host "`tOK" -ForegroundColor Green

                ### Installing Mellanox WinOF Driver

                Write-Host "Installing WinOF driver" -NoNewline
                Start-Process -FilePath $PSScriptRoot"\MLNX_VPI_WinOF.exe" -ArgumentList ' /S /v/qn' -Wait
                Write-Host "`tOK" -ForegroundColor Green
            }
            catch{
                Write-Host "`tError`n" -ForegroundColor Red
                $_
            }
    }

    ### Download Mellanox WinOF2 drivers

    if ((Get-NetAdapter).InterfaceDescription -like 'Mellanox ConnectX-4*'){
        try{
            Write-Host "Downloading WinOF driver" -NoNewline
            Start-BitsTransfer -Source $MellanoxWinOF2DownloadUri -Destination $PSScriptRoot"\MLNX_WinOF2.exe" `
            -Description "Downloading WinOF driver"
            Write-Host "`tOK" -ForegroundColor Green

            ### Installing Mellanox WinOF Driver

            Write-Host "Installing WinOF driver" -NoNewline
            Start-Process -FilePath $PSScriptRoot"\MLNX_WinOF2.exe" -ArgumentList ' /S /v/qn' -Wait
            Write-Host "`tOK" -ForegroundColor Green
        }
        catch{
            Write-Host "`tError`n" -ForegroundColor Red
            $_
        }
    }
}

function InstallRolesAndFeatures{
     ### Install Roles and Features
    
    ### Install Hyper-V Role

    try{
        Write-Host "Install Hyper-V Role" -NoNewline 
        Install-WindowsFeature -Name Hyper-V -ComputerName $env:COMPUTERNAME -IncludeManagementTools
        Write-Host "`tOK" -ForegroundColor Green
        }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }

    ### Install Failover-Clustering Role

    try{
        Write-Host "Install Failover-Clustering Role" -NoNewline 
        Install-WindowsFeature -Name Failover-Clustering -ComputerName $env:COMPUTERNAME -IncludeManagementTools
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }

    ### Enable MSiSCSI service

    try{
        Write-Host "Enable autostart iscsi service" -NoNewline 
        Get-Service -Name MSiSCSI | Start-Service | Set-Service -Name MSiSCSI -StartupType Automatic
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }

    ### Install MPIO Role

    try{
        Write-Host "Install MPIO Role" -NoNewline 
        Install-WindowsFeature -Name Multipath-IO
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }
}

function RebootHost{
    Write-Host "Computer will be rebooted in 15 sec..."
    Start-Sleep -Seconds 15
    Restart-Computer -Force
}

Write-Menu -Title 'Select components to install' -Entries @{
    'Install StarWind VSAN'             = 'InstallStarWindVSAN'
    'Install StarWind Health Service'   = 'InstallStarWindHealthService'
    'Install VMware stuff'              = 'InstallVMwareStuff'
    'Install Dell OMSA'                 = 'InstallDellOMSA'
    'Install Melalnox Drivers'          = 'InstallMellanoxDrivers'
    'Install Roles and Features'        = 'InstallRolesAndFeatures'
    'Reboot HOST after install'         = 'RebootHost'
     } -MultiSelect -Sort