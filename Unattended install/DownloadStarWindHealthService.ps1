Clear-Host
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$StarWindHealthDownloadUri = 'https://www.starwindsoftware.com/tmplink/starwindhealthservice.zip'

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
    Expand-Archive -Path "$Global:ScriptDir\starwindhealthservice\starwindhealthservice.zip"-DestinationPath "$Global:ScriptDir\starwindhealthservice" -Force
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
## Installing StarWindHealthService
try{
    Write-Host "Installing StarWindHealthService" -NoNewline
    Start-Process -FilePath "$Global:ScriptDir\starwindhealthservice\starwindhealthservice.exe" -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /LOG="D:\sw.log"' -Wait
    Write-Host "`tOK" -ForegroundColor Green
}
catch{
    Write-Host "`n$_" -ForegroundColor Red
}