Clear-Host
Import-Module BitsTransfer

### Define variables
$Manufacturer                   = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$ScriptDir                      = (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$OSVersion                      = ((Get-CimInstance Win32_OperatingSystem).Caption).split(" ")[3]
$VCppDownloadUri                = 'https://aka.ms/vs/16/release/VC_redist.x64.exe'
$VMwareToolsDownloadUri         = 'https://packages.vmware.com/tools/esx/latest/windows/x64/index.html'
$VMwareToolsVersion             = ((Invoke-WebRequest -Uri $VMWareToolsDownloadUri).links | Where-Object {$_.href -like 'VMware*'}).href
$OMSADownloadUri                = 'https://downloads.dell.com/FOLDER05170353M/1/OM-SrvAdmin-Dell-Web-WINX64-9.2.0-3142_A00.exe'
$StarWindVSANDownloadUri        = 'https://www.starwindsoftware.com/tmplink/starwind-v8.exe'
$StarWindHealthDownloadUri      = 'https://www.starwindsoftware.com/tmplink/starwindhealthservice.zip'
$MellanoxWinOFDownloadUri       = 'http://www.mellanox.com/downloads/WinOF/MLNX_VPI_WinOF-5_50_52000_All_win' + "$OSVersion" + '_x64.exe'
$MellanoxWinOF2DownloadUri      = 'http://www.mellanox.com/downloads/WinOF/MLNX_WinOF2-2_20_50000_All_x64.exe'
$StarWindHealthUser             = 'Health'
$StarWindHealthPassword         = 'StarWind2015!'


try{
    ### Installing NuGet package provider
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

### Download and install C++ Redistribution
if (!(Test-Path -Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\16.0\)){
    try{
        ### Download C++ Redistribution
        Write-Host "Downloading Visual C++ Redistribution" -NoNewline
        Start-BitsTransfer -Source $VCppDownloadUri -Destination $Global:ScriptDir"\HCA\VC_redist.x64.exe" `
            -Description "Downloading Visual C++ Redistribution"
        Write-Host "`tOK" -ForegroundColor Green
        
        ### Install C++ Redistribution
        Write-Host "Installing Visual C++ Redistribution" -NoNewline
        Start-Process -FilePath $Global:ScriptDir"\HCA\VC_redist.x64.exe" -ArgumentList "/install /q /norestart" -Wait
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }
}

### Download latest StarWindHealthService
if (!(Test-Path -Path $Global:ScriptDir"\HCA\starwindhealthservice.zip")){
    try{
        Write-Host "Downloading latest StarWindHealthService" -NoNewline
        Start-BitsTransfer -Source $StarWindHealthDownloadUri -Destination $Global:ScriptDir"\HCA\starwindhealthservice.zip" `
            -Description "Downloading latest StarWindHealthService"
        Write-Host "`tOK" -ForegroundColor Green

    ### Extracting StarWindHealthService

        Write-Host "Extract StarWindHealthService" -NoNewline
        Expand-Archive -Path $Global:ScriptDir"\HCA\starwindhealthservice.zip" -DestinationPath $Global:ScriptDir"\HCA\" -Force
        Expand-Archive -Path $Global:ScriptDir"\HCA\starwindhealthservice\starwindhealthservice.zip" `
            -DestinationPath $Global:ScriptDir"\HCA\starwindhealthservice" -Force
        ### Yes, I know, this is stupid,
        ### to place the archive into the archive, 
        ### but our web development department, 
        ### which is responsible for the operation of the FTP server, 
        ### cannot change MIME types so that the archived file is downloaded by the archive without changes ... ((((
        Write-Host "`tOK" -ForegroundColor Green

    ### Installing StarWindHealthService

        Write-Host "Installing StarWindHealthService" -NoNewline
        Start-Process -FilePath $Global:ScriptDir"\HCA\starwindhealthservice\starwindhealthservice.exe" `
            -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS' -Wait
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }
}
### Download latest StarWindVSAN build
if (!(Test-Path -Path $Global:ScriptDir"\HCA\starwind.exe")){
    try{
        Write-Host "Download latest StarWindVSAN build" -NoNewline
        Start-BitsTransfer -Source $StarWindVSANDownloadUri -Destination $Global:ScriptDir"\HCA\starwind.exe" `
            -Description "Download latest StarWindVSAN build"
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
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

### Check manufacturer info - Baremetal or ESXi

if ($Manufacturer -like "VMware*") {
    Write-Host "###This is ESXi HOST!###" -ForegroundColor Green
    if (!(Test-Path -Path $Global:ScriptDir"\HCA\$VMwareToolsVersion")){

        ### Download latest Vmware tools

        try{
            Write-Host "Downloading latest Vmware tools" -NoNewline
            Start-BitsTransfer -Source ($VMwareToolsDownloadUri.Replace('index.html', $VMwareToolsVersion)) `
                -Destination $Global:ScriptDir"\HCA\$VMwareToolsVersion" `
                -Description "Downloading latest Vmware tools"
            Write-Host "`tOK" -ForegroundColor Green

        ### Install VMware tools

            Write-Host "Installing VMware tools" -NoNewline
            Start-Process -FilePath $Global:ScriptDir"\HCA\$VMwareToolsVersion" -ArgumentList '/S /v "/qn REBOOT=R ADDLOCAL=ALL"' -Wait
            Write-Host "`tOK" -ForegroundColor Green

        ### Install powerCLI
            # Write-Host "Installing NuGet package provider" -NoNewline
            # Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Confirm:$false -Force | Out-Null
            # Write-Host "`tOK" -ForegroundColor Green

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

    try{
        [ipaddress]$ESXiIp = read-host "Type IP address of the local ESXi server"
    }
    catch{
        write-host "IP address entered is not valid. Try again"
    }

    try{
        $SecureStringESXiPassword = Read-Host -AsSecureString "Please enter your password"
        $ESXiPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureStringESXiPassword))
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }

    try{
        ### Connect to ESXi host

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
    ### TODO:
    ### Create scheduler task using https://docs.microsoft.com/en-us/windows/desktop/taskschd/schtasks
    try{
        Write-Host "Creating scheduler task for Rescan_script.ps1" -NoNewline
        Start-Process -FilePath schtasks.exe -ArgumentList "/Create /RU administrator /RP StarWind2015 /TN ""Rescan ESXi"" /XML ""$Global:ScriptDir""\HCA\rescan_esx.xml"" " -Wait
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }
}

else{ ### Baremetal part of postinstall
    Write-Host "###This is BAREMETAL HOST!###" -ForegroundColor Green

    ### Download Dell OMSA
    if(!(Test-Path -Path $Global:ScriptDir"\HCA\OMSA.zip")){    
        try{
            Write-Host "Downloading DELL OMSA" -NoNewline
            Start-BitsTransfer -Source $OMSADownloadUri -Destination $Global:ScriptDir"\HCA\OMSA.zip" `
                -Description "Downloading DELL OMSA"
            Write-Host "`tOK" -ForegroundColor Green
        
        ### Extracting Dell OMSA
        
            Write-Host "Extract OMSA" -NoNewline
            Expand-Archive -Path $Global:ScriptDir"\HCA\OMSA.zip" -DestinationPath $Global:ScriptDir"\HCA\OMSA" -Force
            Write-Host "`tOK" -ForegroundColor Green
        
        ### Installing Dell OMSA
        
            Write-Host "Installing OMSA" -NoNewline
            Start-Process -FilePath $Global:ScriptDir"\HCA\OMSA\windows\SystemsManagementx64\SysMgmtx64.msi" -ArgumentList 'ADDLOCAL=ALL /qn' -Wait
            Write-Host "`tOK" -ForegroundColor Green
        }
        catch{
            Write-Host "`tError`n" -ForegroundColor Red
            $_
        }
    }
    ### Download Mellanox WinOF drivers

    if ((Get-NetAdapter).InterfaceDescription -like 'Mellanox ConnectX-3*'){
        if(!(Test-Path -Path $Global:ScriptDir"\HCA\MLNX_VPI_WinOF.exe")){    
            try{
                    Write-Host "Downloading WinOF driver" -NoNewline
                    Start-BitsTransfer -Source $MellanoxWinOFDownloadUri -Destination $Global:ScriptDir"\HCA\MLNX_VPI_WinOF.exe" `
                    -Description "Downloading WinOF driver"
                    Write-Host "`tOK" -ForegroundColor Green

                    ### Installing Mellanox WinOF Driver

                    Write-Host "Installing WinOF driver" -NoNewline
                    Start-Process -FilePath $Global:ScriptDir"\HCA\MLNX_VPI_WinOF.exe" -ArgumentList ' /S /v/qn' -Wait
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
        if(!(Test-Path -Path $Global:ScriptDir"\HCA\MLNX_WinOF2.exe")){  
            try{
                Write-Host "Downloading WinOF driver" -NoNewline
                Start-BitsTransfer -Source $MellanoxWinOF2DownloadUri -Destination $Global:ScriptDir"\HCA\MLNX_WinOF2.exe" `
                -Description "Downloading WinOF driver"
                Write-Host "`tOK" -ForegroundColor Green

                ### Installing Mellanox WinOF Driver

                Write-Host "Installing WinOF driver" -NoNewline
                Start-Process -FilePath $Global:ScriptDir"\HCA\MLNX_WinOF2.exe" -ArgumentList ' /S /v/qn' -Wait
                Write-Host "`tOK" -ForegroundColor Green
            }
            catch{
                Write-Host "`tError`n" -ForegroundColor Red
                $_
            }
        }
    }

    ### Install Roles and Features
    
    try{
        ### Install MPIO Role

        Write-Host "Enable autostart iscsi service" -NoNewline 
        Get-Service -Name MSiSCSI | Start-Service | Set-Service -Name MSiSCSI -StartupType Automatic
        Write-Host "`tOK" -ForegroundColor Green

        ### Install MPIO Role

        Write-Host "Install MPIO Role" -NoNewline 
        Install-WindowsFeature -name Multipath-IO
        Write-Host "`tOK" -ForegroundColor Green

        ### Enable iSCSI support for MPIO

        Write-Host "Enable iSCSI support for MPIO" -NoNewline 
        New-MSDSMSupportedHW -VendorId MSFT2005 -ProductId iSCSIBusType_0x9
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }

    try{
        ### Install Hyper-V Role

        Write-Host "Install Hyper-V Role" -NoNewline 
        Install-WindowsFeature -Name Hyper-V -ComputerName $env:COMPUTERNAME -IncludeManagementTools
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }

    try{
        ### Install Failover-Clustering Role

        Write-Host "Install Failover-Clustering Role" -NoNewline 
        Install-WindowsFeature -Name Failover-Clustering -ComputerName $env:COMPUTERNAME -IncludeManagementTools
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`tError`n" -ForegroundColor Red
        $_
    }
}

### Install StarWindVSAN

try{
    Write-Host "Install StarWindVSAN" -NoNewline
    Start-Process -FilePath $Global:ScriptDir"\HCA\starwind.exe" -Wait
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`tError`n" -ForegroundColor Red
    $_
}

### Install StarWind SLA

try{
    Write-Host "Install SLA LicenseAgreement" -NoNewline
    Start-Process -FilePath $Global:ScriptDir"\HCA\SLA_LicenseAgreement.exe" -Wait
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`tError`n" -ForegroundColor Red
    $_
}