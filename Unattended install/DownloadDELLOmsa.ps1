Clear-Host
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$OMSADownloadUri = 'https://downloads.dell.com/FOLDER05170353M/1/OM-SrvAdmin-Dell-Web-WINX64-9.2.0-3142_A00.exe'

### Download Dell OMSA
try{
    Write-Host "Downloading OMSA" -NoNewline
    Start-BitsTransfer -Source "$OMSADownloadUri" `
     -Destination $Global:ScriptDir\"OM-SrvAdmin-Dell-Web-WINX64-9.2.0-3142_A00.zip" `
     -Description "Downloading DELL OMSA"
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`n$_" -ForegroundColor Red
}

### Extracting Dell OMSA
try{
    Write-Host "Extract OMSA" -NoNewline
    Expand-Archive -Path $Global:ScriptDir\"OM-SrvAdmin-Dell-Web-WINX64-9.2.0-3142_A00.zip" -DestinationPath $Global:ScriptDir\"OMSA" -Force
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`n$_" -ForegroundColor Red
}

### Installing Dell OMSA
try{
    Write-Host "Installing OMSA" -NoNewline
    Start-Process -FilePath $Global:ScriptDir\"OMSA\windows\SystemsManagementx64\SysMgmtx64.msi" -ArgumentList 'ADDLOCAL=ALL /qn' -Wait
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`n$_" -ForegroundColor Red
}