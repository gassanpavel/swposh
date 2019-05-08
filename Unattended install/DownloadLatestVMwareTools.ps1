$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
###Download latest VMware tools x64
$VMwareDownloadUri = 'https://packages.vmware.com/tools/esx/latest/windows/x64/index.html'
$VMwareToolsVersion = ((Invoke-WebRequest -Uri $VMWareDownloadUri).links | Where-Object {$_.href -like 'VMware*'}).href
Start-BitsTransfer -Source ($VMwareDownloadUri.Replace("index.html","$VMwareToolsVersion")) -Destination $ScriptDir\"$VMwareToolsVersion"
###Install VMware tools
Start-Process -FilePath $ScriptDir\"$VMwareToolsVersion" -ArgumentList '/S /v "/qn REBOOT=R ADDLOCAL=ALL"' -Wait