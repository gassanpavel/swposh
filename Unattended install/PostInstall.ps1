Clear-Host
### Define variables
$Manufacturer =                 (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$ScriptDir =                    Split-Path -Parent $MyInvocation.MyCommand.Definition
$OSVersion =                    ((Get-CimInstance Win32_OperatingSystem).Caption).split(" ")[3]
$VCppDownloadUri =              'https://aka.ms/vs/16/release/VC_redist.x64.exe'
$VMwareToolsDownloadUri =       'https://packages.vmware.com/tools/esx/latest/windows/x64/index.html'
$VMwareToolsVersion =           ((Invoke-WebRequest -Uri $VMWareToolsDownloadUri).links | Where-Object {$_.href -like 'VMware*'}).href
$OMSADownloadUri =              'https://downloads.dell.com/FOLDER05170353M/1/OM-SrvAdmin-Dell-Web-WINX64-9.2.0-3142_A00.exe'
$StarWindVSANDownloadUri =      'https://www.starwindsoftware.com/tmplink/starwind-v8.exe'
$StarWindHealthDownloadUri =    'https://www.starwindsoftware.com/tmplink/starwindhealthservice.zip'
$MellanoxWinOFDownloadUri =     'http://www.mellanox.com/downloads/WinOF/MLNX_VPI_WinOF-5_50_52000_All_win' + "$OSVersion" + '_x64.exe'
$MellanoxWinOF2DownloadUri =    'http://www.mellanox.com/downloads/WinOF/MLNX_WinOF2-2_20_50000_All_x64.exe'

### Allow to install modules from PSGallery to install powercli module
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

### Get installed programms
### Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName | Where-Object {$_ -like '*StarWind*'}

### Download and install C++ Redistribution
if (!(Test-Path -Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\16.0\)){
    try{
        ### Download C++ Redistribution
        Write-Host "Downloading Visual C++ Redistribution" -NoNewline
        Start-BitsTransfer -Source $VCppDownloadUri -Destination "$Global:ScriptDir\VC_redist.x64.exe" `
            -Description "Downloading Visual C++ Redistribution"
        Write-Host "`tOK" -ForegroundColor Green
        
        ### Install C++ Redistribution
        Write-Host "Installing Visual C++ Redistribution" -NoNewline
        Start-Process -FilePath "$Global:ScriptDir\VC_redist.x64.exe" -ArgumentList '/install /quite /norestart' -Wait
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`n$_" -ForegroundColor Red
    }
}

### Download latest StarWindHealthService

try{
    Write-Host "Downloading latest StarWindHealthService" -NoNewline
    Start-BitsTransfer -Source $StarWindHealthDownloadUri -Destination "$Global:ScriptDir\starwindhealthservice.zip" `
        -Description "Downloading latest StarWindHealthService"
    Write-Host "`tOK" -ForegroundColor Green

### Extracting StarWindHealthService

    Write-Host "Extract StarWindHealthService" -NoNewline
    Expand-Archive -Path "$Global:ScriptDir\starwindhealthservice.zip" -DestinationPath "$Global:ScriptDir" -Force
    Expand-Archive -Path "$Global:ScriptDir\starwindhealthservice\starwindhealthservice.zip" `
        -DestinationPath "$Global:ScriptDir\starwindhealthservice" -Force
    ### Yes, I know, this is stupid,
    ### to place the archive into the archive, 
    ### but our web development department, 
    ### which is responsible for the operation of the FTP server, 
    ### cannot change MIME types so that the archived file is downloaded by the archive without changes ... ((((
    Write-Host "`tOK" -ForegroundColor Green

### Installing StarWindHealthService

    Write-Host "Installing StarWindHealthService" -NoNewline
    Start-Process -FilePath "$Global:ScriptDir\starwindhealthservice\starwindhealthservice.exe" `
        -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS' -Wait
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`n$_" -ForegroundColor Red
}

### Download latest StarWindVSAN build

try{
    Write-Host "Download latest StarWindVSAN build" -NoNewline
    Start-BitsTransfer -Source $StarWindVSANDownloadUri -Destination "$Global:ScriptDir\starwind.exe" `
        -Description "Download latest StarWindVSAN build"
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`n$_" -ForegroundColor Red
}

### Check manufacturer info - Baremetal or ESXi

if ($Manufacturer -like "VMware*") {
    if (!Test-Path -FilePath "$Global:ScriptDir\$VMwareToolsVersion"){

        ### Download latest Vmware tools

        try{
            Write-Host "###This is ESXi HOST!###" -ForegroundColor Green
            Write-Host "Downloading latest Vmware tools" -NoNewline
            Start-BitsTransfer -Source ($VMwareDownloadUri.Replace('index.html', $VMwareToolsVersion)) `
                -Destination "$Global:ScriptDir\$VMwareToolsVersion" `
                -Description "Downloading latest Vmware tools"
            Write-Host "`tOK" -ForegroundColor Green

        ### Install VMware tools

            Write-Host "Installing VMware tools" -NoNewline
            Start-Process -FilePath "$Global:ScriptDir\$VMwareToolsVersion"-ArgumentList '/S /v "/qn REBOOT=R ADDLOCAL=ALL"' -Wait
            Write-Host "`tOK" -ForegroundColor Green

        ### Install powerCLI

            Write-Host "Installing powerCLI" -NoNewline
            Install-Module -Name VMware.PowerCLI -Scope AllUsers -Confirm:$false -Force
            Write-Host "`tOK" -ForegroundColor Green
        }
        catch{
            Write-Host "`n$_" -ForegroundColor Red
        }
    }
    

    ###TODO:
    ### Create rescan_script
    ########################
    ########################


}
else{ ### Baremetal part of postinstall
    Write-Host "###This is BAREMETAL HOST!###" -ForegroundColor Green

    ### Download Dell OMSA

    try{
        Write-Host "Downloading DELL OMSA" -NoNewline
        Start-BitsTransfer -Source $OMSADownloadUri -Destination "$Global:ScriptDir\OMSA.zip" `
            -Description "Downloading DELL OMSA"
        Write-Host "`tOK" -ForegroundColor Green
    
    ### Extracting Dell OMSA
    
        Write-Host "Extract OMSA" -NoNewline
        Expand-Archive -Path "$Global:ScriptDir\OMSA.zip" -DestinationPath "$Global:ScriptDir\OMSA" -Force
        Write-Host "`tOK" -ForegroundColor Green
    
    ### Installing Dell OMSA
    
        Write-Host "Installing OMSA" -NoNewline
        Start-Process -FilePath "$Global:ScriptDir\OMSA\windows\SystemsManagementx64\SysMgmtx64.msi" -ArgumentList 'ADDLOCAL=ALL /qn' -Wait
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`n$_" -ForegroundColor Red
    }

    ### Download Mellanox WinOF drivers

    if ((Get-NetAdapter).InterfaceDescription -like 'Mellanox ConnectX-3*'){
        try{
            Write-Host "Downloading WinOF driver" -NoNewline
            Start-BitsTransfer -Source $MellanoxWinOFDownloadUri -Destination "$Global:ScriptDir\MLNX_VPI_WinOF.exe" `
            -Description "Downloading WinOF driver"
            Write-Host "`tOK" -ForegroundColor Green

            ### Installing Mellanox WinOF Driver

            Write-Host "Installing WinOF driver" -NoNewline
            Start-Process -FilePath "$Global:ScriptDir\MLNX_VPI_WinOF.exe" -ArgumentList ' /S /v/qn' -Wait
            Write-Host "`tOK" -ForegroundColor Green
        }
        catch{
            Write-Host "`n$_" -ForegroundColor Red
        }
    }

    ### Download Mellanox WinOF2 drivers

    if ((Get-NetAdapter).InterfaceDescription -like 'Mellanox ConnectX-4*'){
        try{
            Write-Host "Downloading WinOF driver" -NoNewline
            Start-BitsTransfer -Source $MellanoxWinOF2DownloadUri -Destination "$Global:ScriptDir\MLNX_WinOF2.exe" `
            -Description "Downloading WinOF driver"
            Write-Host "`tOK" -ForegroundColor Green

            ### Installing Mellanox WinOF Driver

            Write-Host "Installing WinOF driver" -NoNewline
            Start-Process -FilePath "$Global:ScriptDir\MLNX_WinOF2.exe" -ArgumentList ' /S /v/qn' -Wait
            Write-Host "`tOK" -ForegroundColor Green
        }
        catch{
            Write-Host "`n$_" -ForegroundColor Red
        }
    }

    ###TODO:
    ### Install Roles and Features

    ###TODO:
    ### Configure Roles and Features
    ### MPIO add support iSCSI
    ### MPIO set multipathig policy
}