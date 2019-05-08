$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
###Download latest C++ Redistribution x64
$VCppDownloadUri = 'https://aka.ms/vs/16/release/VC_redist.x64.exe'
Start-BitsTransfer -Source $VCppDownloadUri -Destination $ScriptDir\"VC_redist.x64.exe"
###Install C++ Redistribution
Start-Process -FilePath $ScriptDir\"VC_redist.x64.exe" -ArgumentList '/install /quite /norestart' -Wait