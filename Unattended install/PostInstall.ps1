Clear-Hosts
### Define variables
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VCppDownloadUri =              'https://aka.ms/vs/16/release/VC_redist.x64.exe'
$VMwareToolsDownloadUri =       'https://packages.vmware.com/tools/esx/latest/windows/x64/index.html'
$OMSADownloadUri =              'https://downloads.dell.com/FOLDER05170353M/1/OM-SrvAdmin-Dell-Web-WINX64-9.2.0-3142_A00.exe'
$StarWindVSANDownloadUri =      'https://www.starwindsoftware.com/tmplink/starwind-v8.exe'
$StarWindHealthDownloadUri =    'https://www.starwindsoftware.com/tmplink/starwindhealthservice.zip'


### Allow install modules from PSGallery
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

### Download and install C++ Redistribution
if (!(Test-Path -Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\16.0\)){
    try{
        Write-Host "Downloading Visual C++ Redistribution" -NoNewline
        Start-BitsTransfer -Source $VCppDownloadUri -Destination "$Global:ScriptDir\VC_redist.x64.exe" `
            -Description "Downloading Visual C++ Redistribution"
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`n$_" -ForegroundColor Red
    }
    try{
        Write-Host "Installing Visual C++ Redistribution" -NoNewline
        Start-Process -FilePath "$Global:ScriptDir\VC_redist.x64.exe" -ArgumentList '/install /quite /norestart' -Wait
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`n$_" -ForegroundColor Red
    }
}

### Check manufacturer info - Baremetal or ESXi
if ((Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer -like 'VMware*'){ ### ESXi part of postinstall
    ### Download latest Vmware tools
    try{
        Write-Host "Downloading latest Vmware tools" -NoNewline
        $VMwareToolsVersion = ((Invoke-WebRequest -Uri $VMWareToolsDownloadUri).links | Where-Object {$_.href -like 'VMware*'}).href
        Start-BitsTransfer -Source ($VMwareDownloadUri.Replace('index.html', $VMwareToolsVersion)) -Destination "$Global:ScriptDir\$VMwareToolsVersion" `
            -Description "Downloading latest Vmware tools"
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`n$_" -ForegroundColor Red
    }
        
    ### Install VMware tools
    try{
        Write-Host "Installing VMware tools" -NoNewline
        Start-Process -FilePath "$Global:ScriptDir\$VMwareToolsVersion"-ArgumentList '/S /v "/qn REBOOT=R ADDLOCAL=ALL"' -Wait
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`n$_" -ForegroundColor Red
    }

    ### Install powerCLI
    try{
        Write-Host "Installing powerCLI" -NoNewline
        Install-Module -Name VMware.PowerCLI –Scope AllUsers -Confirm:$false -Force
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`n$_" -ForegroundColor Red
    }

    
    ### Create rescan_script

}
else{ ### Baremetal part of postinstall
    ### Download Dell OMSA
    try{
        Write-Host "Downloading DELL OMSA" -NoNewline
        Start-BitsTransfer -Source $OMSADownloadUri -Destination "$Global:ScriptDir\OM-SrvAdmin-Dell-Web-WINX64-9.2.0-3142_A00.zip" `
            -Description "Downloading DELL OMSA"
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`n$_" -ForegroundColor Red
    }
    ### Extracting Dell OMSA
    try{
        Write-Host "Extract OMSA" -NoNewline
        Expand-Archive -Path "$Global:ScriptDir\OM-SrvAdmin-Dell-Web-WINX64-9.2.0-3142_A00.zip" -DestinationPath "$Global:ScriptDir\OMSA" -Force
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`n$_" -ForegroundColor Red
    }
    ### Installing Dell OMSA
    try{
        Write-Host "Installing OMSA" -NoNewline
        Start-Process -FilePath "$Global:ScriptDir\OMSA\windows\SystemsManagementx64\SysMgmtx64.msi" -ArgumentList 'ADDLOCAL=ALL /qn' -Wait
        Write-Host "`tOK" -ForegroundColor Green
    }
    catch{
        Write-Host "`n$_" -ForegroundColor Red
    }

    ### Download Mellanox WinOF/WinOF2 drivers
    
}

### Download latest StarWindHealthService
try{
    Write-Host "Downloading latest StarWindHealthService" -NoNewline
    Start-BitsTransfer -Source $StarWindHealthDownloadUri -Destination "$Global:ScriptDir\starwindhealthservice.zip" `
        -Description "Downloading latest StarWindHealthService"
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`n$_" -ForegroundColor Red
}
### Extracting StarWindHealthService
try{
    Write-Host "Extract StarWindHealthService" -NoNewline
    Expand-Archive -Path "$Global:ScriptDir\starwindhealthservice.zip" -DestinationPath "$Global:ScriptDir" -Force
    Expand-Archive -Path "$Global:ScriptDir\starwindhealthservice\starwindhealthservice.zip" -DestinationPath "$Global:ScriptDir\starwindhealthservice" -Force
    ### Yes, I know, this is stupid,
    ### to place the archive into the archive, 
    ### but our web development department, 
    ### which is responsible for the operation of the FTP server, 
    ### cannot change MIME types so that the archived file is downloaded by the archive without changes ... ((((
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`n$_" -ForegroundColor Red
}
### Installing StarWindHealthService
try{
    Write-Host "Installing StarWindHealthService" -NoNewline
    Start-Process -FilePath "$Global:ScriptDir\starwindhealthservice\starwindhealthservice.exe" `
        -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /LOG="D:\sw.log"' -Wait
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

### Installing StarWindVSAN
# try{
#     Write-Host "Installing StarWindVSAN" -NoNewline
#     Start-Process -FilePath $Global:ScriptDir\"starwind.exe" -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /LOG="D:\sw.log"' -Wait
#     Write-Host "`tOK" -ForegroundColor Green
# }
# catch{
#     Write-Host "`n$_" -ForegroundColor Red
# }