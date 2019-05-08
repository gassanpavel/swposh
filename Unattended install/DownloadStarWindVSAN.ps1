Clear-Host
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$StarWindVSANDownloadUri = 'https://www.starwindsoftware.com/tmplink/starwind-v8.exe'

### Download latest StarWindVSAN
try{
    Write-Host "Downloading latest StarWindVSAN" -NoNewline
    Start-BitsTransfer -Source $StarWindVSANDownloadUri -Destination $Global:ScriptDir\starwind.exe `
        -Description "Downloading latest StarWindVSAN from $StarWindVSANDownloadUri"
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