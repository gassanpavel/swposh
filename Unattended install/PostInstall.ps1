Clear-Host
Import-Module BitsTransfer

### Define variables
$Manufacturer                   = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$OSVersion                      = ((Get-CimInstance Win32_OperatingSystem).Caption).split(" ")[3]
$VCppDownloadUri                = 'https://aka.ms/vs/16/release/VC_redist.x64.exe'
$VMwareToolsDownloadUri         = 'https://packages.vmware.com/tools/esx/latest/windows/x64/index.html'
$VMwareToolsVersion             = ((Invoke-WebRequest -Uri $VMWareToolsDownloadUri -UseBasicParsing).links | Where-Object {$_.href -like 'VMware*'}).href
$OMSADownloadUri                = 'https://downloads.dell.com/FOLDER05170353M/1/OM-SrvAdmin-Dell-Web-WINX64-9.2.0-3142_A00.exe'
$StarWindVSANDownloadUri        = 'https://www.starwindsoftware.com/tmplink/starwind-v8.exe'
$StarWindHealthDownloadUri      = 'https://www.starwindsoftware.com/tmplink/starwindhealthservice.zip'
$MellanoxWinOFDownloadUri       = 'http://www.mellanox.com/downloads/WinOF/MLNX_VPI_WinOF-5_50_52000_All_win' + "$OSVersion" + '_x64.exe'
$MellanoxWinOF2DownloadUri      = 'http://www.mellanox.com/downloads/WinOF/MLNX_WinOF2-2_20_50000_All_x64.exe'
$StarWindHealthUser             = 'Health'
$StarWindHealthPassword         = 'StarWind2015!'
$RegPath                        = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$NetFramework472Uri             = 'https://go.microsoft.com/fwlink/?LinkId=863265'
$NetFramework48Uri              = 'https://go.microsoft.com/fwlink/?linkid=2088631'

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

    ### Install C++ Redistribution
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

    ### Install C++ Redistribution
    Write-Host "Installing .Net 4.8 framework" -NoNewline
    Start-Process -FilePath $PSScriptRoot"\DotNet48.exe" -ArgumentList "/q /norestart" -Wait
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`tError" -ForegroundColor Red
    Write-Host "Cant download .Net 4.8 framework. Please download it from $NetFramework48Uri and install manually`n" -ForegroundColor Yellow
}

### Download and install C++ Redistribution

if (!(Test-Path -Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\16.0\)){
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
}

### Download latest StarWindHealthService

if (!(Test-Path -Path $PSScriptRoot"\starwindhealthservice.zip")){
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

### Download latest StarWindVSAN build

if (!(Test-Path -Path $PSScriptRoot"\starwind.exe")){
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

### Check manufacturer info - Baremetal or ESXi

if ($Manufacturer -like "VMware*") {
    Write-Host "###This is ESXi HOST!###" -ForegroundColor Green
    if (!(Test-Path -Path $PSScriptRoot"\$VMwareToolsVersion")){

        ### Download latest Vmware tools

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
    }
    
    ### Create HEALTH USER on ESXi host

    function ESXiConnect{
        while ($true){
            try{
                [ipaddress]$ESXiIp = read-host "Type IP address of the local ESXi server"
                break
            }
            catch{
                Write-Host "IP address is not valid. Try again"
            }
        }
        $SecureStringESXiPassword = Read-Host -AsSecureString "Please enter your password"
        $ESXiPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureStringESXiPassword)) 
        Write-Host "Connecting to ESXi host" -NoNewline
        Set-PowerCLIConfiguration -InvalidCertificateAction ignore -Confirm:$false | Out-Null
        Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $true -Confirm:$false | Out-Null
        if (!(Connect-VIServer -Server $ESXiIp -User root -Password $ESXiPassword -ErrorAction SilentlyContinue)){
            Write-Host "`nCant connect to ESXi server. Check your IP or credentials and try again`n" -ForegroundColor Red
            ESXiConnect
            break
        }
        else{
            Write-Host "`tOK" -ForegroundColor Green
            break
        }
    }

    try{
        ### Connect to ESXi host
        ESXiConnect
        Write-Host "Connecting to ESXi host" -NoNewline
        Set-PowerCLIConfiguration -InvalidCertificateAction ignore -Confirm:$false | Out-Null
        Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $true -Confirm:$false | Out-Null
        Connect-VIServer -Server $ESXiIp -User root -Password $ESXiPassword
        Write-Host "`tOK" -ForegroundColor Green

        ### Create HEALTH USER

        Write-Host "Create HEALTH USER" -NoNewline
        New-VMHostAccount -Id $StarWindHealthUser -Password $StarWindHealthPassword -Description "Vendor Support" -ErrorAction SilentlyContinue
        New-VIRole -Name StarWind -ErrorAction SilentlyContinue
        Set-VIRole -Role StarWind -AddPrivilege Inventory -ErrorAction SilentlyContinue
        Set-VIRole -Role StarWind -AddPrivilege Configuration -ErrorAction SilentlyContinue
        Set-VIRole -Role StarWind -AddPrivilege 'Local operations' -ErrorAction SilentlyContinue
        Set-VIRole -Role StarWind -AddPrivilege CIM -ErrorAction SilentlyContinue
        Set-VIRole -Role StarWind -AddPrivilege 'vSphere Replication' -ErrorAction SilentlyContinue
        Set-VIRole -Role StarWind -AddPrivilege Settings -ErrorAction SilentlyContinue
        Set-VIRole -Role StarWind -AddPrivilege Diagnostics -ErrorAction SilentlyContinue
        New-VIPermission -Role StarWind -Principal Health -Entity (Get-VMHost) -ErrorAction SilentlyContinue
        Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }
    
    ### Create rescan_script.ps1
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

else{ ### Baremetal part of postinstall
    Write-Host "###This is BAREMETAL HOST!###" -ForegroundColor Green
    
    if ($Manufacturer -like "*Dell*")
    {
        ### Download Dell OMSA
        if(!(Test-Path -Path $PSScriptRoot"\OMSA.zip")){    
            try{
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
    }
    
    ### Download Mellanox WinOF drivers

    if ((Get-NetAdapter).InterfaceDescription -like 'Mellanox ConnectX-3*'){
        if(!(Test-Path -Path $PSScriptRoot"\MLNX_VPI_WinOF.exe")){    
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
    }

    ### Download Mellanox WinOF2 drivers

    if ((Get-NetAdapter).InterfaceDescription -like 'Mellanox ConnectX-4*'){
        if(!(Test-Path -Path $PSScriptRoot"\MLNX_WinOF2.exe")){  
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

### Reboot node to run configuration script
Write-Host "Computer will be rebooted in 15 sec..."
Start-Sleep -Seconds 15
Restart-Computer -Force