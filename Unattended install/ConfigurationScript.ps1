Clear-Host

write-host "(C) StarWind Support Team 2017
Welcome to the HCA configuration script.
It will guide you through the process of configuring StarWind HCA
with the Best Practice parameters and settings.
Please follow the on-screen instructions." -ForegroundColor Green
write-host "============================"
write-host "To configure the nodes properly, please provide the following information:"
$userLong = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.split("\")
$user = $userLong[1]
$manufacturer = (Get-ComputerInfo | Select CSmanufacturer).CSmanufacturer #Get-Disk -Number 0 | Select-Object Manufacturer

#--------------------------
do
{
	$selectionnode = Read-Host "
Enter the index of the current node" # used for configuring the network interfaces
	if ($selectionnode -eq "1" -or $selectionnode -eq "2" -or $selectionnode -eq "3")
	{
		$ok_selectionnode = $true
	}
	else
	{
		$ok_selectionnode = $false
	}
}
until ($ok_selectionnode)
#--------------------------
do
{
	$targetnode = Read-Host "
Enter the index of the target node" # used for configuring the network interfaces
	if ($targetnode -eq "1" -or $targetnode -eq "2" -or $targetnode -eq "3")
	{
		$ok_targetnode = $true
	}
	else
	{
		$ok_targetnode = $false
	}
}
until ($ok_targetnode)
#--------------------------
do
{
	$selectioniscsi = Read-Host "
Enter the number of iSCSI interfaces (1 or 2)"
	if ($selectioniscsi -eq "1" -or $selectioniscsi -eq "2")
	{
		$ok_selectioniscsi = $true
	}
	else
	{
		$ok_selectioniscsi = $false
	}
}
until ($ok_selectioniscsi)
#--------------------------
do
{
	$selectionsync = Read-Host "
Enter the number of sync interfaces (1 or 2)"
	if ($selectionsync -eq "1" -or $selectionsync -eq "2")
	{
		$ok_selectionsync = $true
	}
	else
	{
		$ok_selectionsync = $false
	}
}
until ($ok_selectionsync)
#--------------------------
if ($manufacturer -like "VMware*")
{
	$vmware = 1
}
else
{
	$vmware = 0
}
#----------------------------------------------
write-host "Partitioning"
write-host "---------------------------"
$countRAW = Get-Disk | Where-Object PartitionStyle –Eq "RAW" | Where-Object BusType -ne "ISCSI" | Where-Object BusType -ne "USB" | Measure-Object Number
if ($countRAW.count -ge 1)
{
	do
	{
		$selection = Read-Host "The system has an unallocated disk,would you like to allocated it?: [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		$drive = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'S:'"
		if ($drive.DriveType -eq 3)
		{
			write-host "The system already has a local disk that is assigned Drive Letter S"
		}
		else
		{
			if ($drive.DriveType -eq 5 -or $drive.DriveType -eq 2)
			{
				$selection1 = Read-Host "Drive Letter S is already assigned to Compact Disk or Removable Disk, would you like to change Drive Letter?: [y/n]"
				if ($selection1 -eq "y")
				{
					#$Eject =  New-Object -comObject Shell.Application
					#$Eject.NameSpace(17).ParseName($drive.driveletter).InvokeVerb("Eject")
					Set-WmiInstance -input $drive -Arguments @{ DriveLetter = "F:" } | Out-Null
				}
				elseif ($selection1 -eq "n")
				{
					# do nothing
				}
			}
			$DiskNumber = Get-Disk | Where-Object PartitionStyle –Eq "RAW" | Where-Object BusType -ne "ISCSI" | Where-Object BusType -ne "USB" | Select-Object Number -First 1
			Initialize-Disk -Number $DiskNumber.Number -PartitionStyle GPT
			New-Partition -DiskNumber $DiskNumber.Number -DriveLetter S -UseMaximumSize | Out-Null
			Format-Volume -DriveLetter S -FileSystem NTFS -NewFileSystemLabel Storage -Confirm:$false | Out-Null
		}
	}
}
$DiskReserved = Get-Partition | Where-Object –FilterScript { $_.isBoot -Eq "True" } | Select-Object disknumber
$DiskNumber = $DiskReserved.disknumber
$DiskReserved = Get-Partition -DiskNumber $DiskNumber | Measure-Object -Property Size -Sum
$DiskSize = Get-Disk -Number $DiskNumber | Select-Object size
$spase = $DiskSize.size - $DiskReserved.sum
if ($spase -ge 42949672960)
{
	do
	{
		$selection = Read-Host "The system disk has some unallocated space,would you like to allocate it?: [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		$drive = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'd:'"
		if ($drive.DriveType -eq 3)
		{
			New-Partition -DiskNumber $DiskNumber -DriveLetter S -UseMaximumSize | Out-Null
			Format-Volume -DriveLetter S -FileSystem NTFS -NewFileSystemLabel SSD -Confirm:$false | Out-Null
		}
		elseif ($drive.DriveType -eq 5 -or $drive.DriveType -eq 2)
		{
			$selection1 = Read-Host "Drive Letter D is already assigned to either Compact disk or Removable disk,would you like to change Drive Letter?: [y/n]"
			if ($selection1 -eq "y")
			{
				#$Eject =  New-Object -comObject Shell.Application
				#$Eject.NameSpace(17).ParseName($drive.driveletter).InvokeVerb("Eject")
				Set-WmiInstance -input $drive -Arguments @{ DriveLetter = "F:" } | Out-Null
				New-Partition -DiskNumber $DiskNumber -DriveLetter D -UseMaximumSize | Out-Null
				Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel Storage -Confirm:$false | Out-Null
			}
			elseif ($selection1 -eq "n")
			{
				# do nothing
			}
		}
		else
		{
			New-Partition -DiskNumber $DiskNumber -DriveLetter D -UseMaximumSize | Out-Null
			Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel Storage -Confirm:$false | Out-Null
		}
	}
}
#----------------------------------------------
write-host "Checking the name of the host"
write-host "---------------------------"
$hostname = hostname
if ($hostname -like "SW-HCA-0*" -or $hostname -like "SW-HCA-VM-0*")
{
	write-host "Host name $hostname....ОК" -ForegroundColor Green
}
else
{
	write-host "Host name $hostname....FALSE" -ForegroundColor RED
	do
	{
		$selection = Read-Host "Would you like to change the hostname? [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		#$node=read-host "Enter the node number in the format Х"
		if ($vmware -eq 0)
		{
			Rename-Computer -NewName "SW-HCA-0$selectionnode"
		}
		else
		{
			Rename-Computer -NewName "SW-HCA-VM-0$selectionnode"
		}
	}
}
#----------------------------------------------
write-host "
Checking remote connectivity"
write-host "---------------------------"
$RDP = Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections"
$SMR = Configure-SMRemoting.exe -Get
if ($RDP.fDenyTSConnections -eq 0)
{
	Write-Host "Remote connection via RDP....ОК" -ForegroundColor Green
}
else
{
	Write-Host "Remote connection via RDP....FALSE" -ForegroundColor Red
	do
	{
		$selection = Read-Host "Would you like to allow remote connection via RDP [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" 0
	}
}
if ($SMR -eq "Server Manager Remoting is enabled")
{
	Write-Host "Remote management SMR....OK" -ForegroundColor Green
}
else
{
	Write-Host "Remote management SMR....FALSE" -ForegroundColor Red
	do
	{
		$selection = Read-Host "Would you like to allow remote connection via SMR? [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		Configure-SMRemoting.exe -enable
	}
}
#----------------------------------------------
write-host "
Checking firewall"
write-host "---------------------------"
$Firewall = get-NetFirewallProfile -All | Select-Object -Property Name, Enabled
$countfw = 0
foreach ($Enabled in $Firewall)
{
	if ($Enabled.Enabled -eq "False")
	{
		Write-Host $Enabled.Name"....OK" -ForegroundColor Green
	}
	else
	{
		Write-Host $Enabled.Name"....False" -ForegroundColor Red
		$countfw++
	}
}
if ($countfw -gt 0)
{
	do
	{
		$selection = Read-Host "Firewall is enabled. Would you like to disable the firewall? [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		netsh advfirewall set allprofiles state off
	}
}
#----------------------------------------------
write-host "
Checking the operating system disk, disk label and page file"
write-host "---------------------------"
#C--------------------------------------------------------------------
$SystemPartition = Get-Partition | Where-Object –FilterScript { $_.isBoot -Eq "True" } | Select-Object DriveLetter
$SystemPartition = $SystemPartition.DriveLetter + ":"
$SystemPartition = Get-WmiObject -Class win32_volume -Filter "DriveLetter = '$SystemPartition'" | Select-Object  Caption, Label, Capacity
$countwin = 0
if ($SystemPartition.Caption -eq "C:\")
{
	Write-Host "Windows is installed on the correct disk....OK" -ForegroundColor Green
	$countwin++
}
else
{
	Write-Host "Windows is installed on the correct disk....False.
        Change the letter of the disk or reinstall Windows to the correct disk!" -ForegroundColor Red
}
if ($countwin -gt 0)
{
	if ($SystemPartition.Label -eq "System")
	{
		Write-Host "Label of Windows disk....OK" -ForegroundColor Green
	}
	else
	{
		Write-Host "Label of Windows disk....False" -ForegroundColor Red
		do
		{
			$selection = Read-Host "Would you like to change the label of the C drive?: [y/n]"
			if ($selection -eq "y" -or $selection -eq "n")
			{
				$ok_selection = $true
			}
			else
			{
				$ok_selection = $false
			}
		}
		until ($ok_selection)
		if ($selection -eq "y")
		{
			$drive = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'c:'"
			$drive.Label = "System"
			$drive.Put() | Out-Null
		}
	}
	if ([int]($SystemPartition.Capacity/1GB) -gt 95)
	{
		Write-Host "Windows disk size....OK" -ForegroundColor Green
	}
	else
	{
		Write-Host "Windows disk size....False. Expand the Windows disk to 100GB!" -ForegroundColor Red
	}
}
#D--------------------------------------------------------------------
$drive = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'S:'"
if ($null -eq $drive)
{
	write-host "Letter S: is not assigned to any disk" -ForegroundColor Red
}
else
{
	if ($drive.DriveType -eq 3)
	{
		$StoragePartition = Get-Partition -DriveLetter "S" | Select-Object  DiskNumber
		$StoragePartitionStyle = Get-Disk -Number $StoragePartition.DiskNumber | Select-Object PartitionStyle
		if ($drive.Label -eq "Storage")
		{
			Write-Host "Label of disk S:....OK" -ForegroundColor Green
		}
		else
		{
			Write-Host "Label of disk S:....False" -ForegroundColor Red
			do
			{
				$selection = Read-Host "Would you like to change the label of disk S:? [y/n]"
				if ($selection -eq "y" -or $selection -eq "n")
				{
					$ok_selection = $true
				}
				else
				{
					$ok_selection = $false
				}
			}
			until ($ok_selection)
			if ($selection -eq "y")
			{
				$drive.Label = "Storage"
				$drive.Put() | Out-Null
			}
		}
		if ($StoragePartitionStyle.PartitionStyle -eq "GPT")
		{
			Write-Host "Disk S: partition scheme....OK" -ForegroundColor Green
		}
		else
		{
			Write-Host "Disk S: partition scheme....False. Change to GPT!" -ForegroundColor Red
		}
	}
	else
	{
		write-host "S: drive of this type is not suitable for Storage!" -ForegroundColor Red
	}
}
#pagefile--------------------------------------------------------------------
$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
if ($ComputerSystem.AutomaticManagedPagefile)
{
	Write-Host "Pagefile....False" -ForegroundColor Red
	do
	{
		$selection = Read-Host "The size of the page file is set automatically. Would you like to change the pagefile size? [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		$ComputerSystem.AutomaticManagedPagefile = $false
		$ComputerSystem.Put() | Out-Null
		$PageFile = Get-WmiObject -Class Win32_PageFileSetting -EnableAllPrivileges
		$PageFile.InitialSize = 2048
		$PageFile.MaximumSize = 2048
		$PageFile.Put() | Out-Null
	}
}
else
{
	$PageFile = Get-WmiObject -Class Win32_PageFileSetting
	if ($PageFile.MaximumSize -ne 2048)
	{
		Write-Host "Page file....False" -ForegroundColor Red
		do
		{
			$selection = Read-Host "Would you like to change the page file size? [y/n]"
			if ($selection -eq "y" -or $selection -eq "n")
			{
				$ok_selection = $true
			}
			else
			{
				$ok_selection = $false
			}
		}
		until ($ok_selection)
		if ($selection -eq "y")
		{
			$PageFile.InitialSize = 2048
			$PageFile.MaximumSize = 2048
			$PageFile.Put() | Out-Null
		}
	}
	else
	{
		Write-Host "Page file....OK" -ForegroundColor Green
	}
}
write-host "
Checking and configuring network interfaces"
write-host "---------------------------"
$ManagementNIC = Get-NetAdapter | Where-Object –FilterScript { $_.name -like "management" }
if ($null -eq $ManagementNIC)
{
	Write-Host "Management interfaces....False." -ForegroundColor Red
	do
	{
		$selection = Read-Host "Management interface is not configured. Would you like to configure it? [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		Get-NetAdapter
		#-----------------------------------------
		#----------------------------------------- ТУТ ВЫБОРКУ IFINDEX СДЕЛАТЬ
		#-----------------------------------------
		$ifindex = Get-NetAdapter | Select-Object -ExpandProperty ifIndex
		do
		{
			$selectionindex = Read-Host "
Enter the required interface's ifIndex value"
			if ($ifindex.Contains($selectionindex))
			{
				$managementif = $true
				Get-NetAdapter -ifindex $selectionindex | Rename-NetAdapter -NewName management
			}
			else
			{
				$managementif = $false
				write-host "Selected index is not availbale on this system. Try again"
			}
		}
		until ($managementif)
		
	}
	else
	{
		Write-Host "Management interfaces.........OK" -ForegroundColor Green
	}
	#------------------------------------------------------
	
}
$iscsinic = Get-NetAdapter | Where-Object –FilterScript { $_.name -like "iscsi-1?-?" }
if ($null -eq $iscsinic)
{
	Write-Host "iscsi-1 interface....False." -ForegroundColor Red
	do
	{
		$selection = Read-Host "iscsi-1 interface is not configured. Would you like to configure it? [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		Get-NetAdapter
		#-----------------------------------------
		#----------------------------------------- ТУТ ВЫБОРКУ IFINDEX СДЕЛАТЬ
		#-----------------------------------------
		$ifindex = Get-NetAdapter | Select-Object -ExpandProperty ifIndex
		$selectionindex = Read-Host "
Enter the required interface's ifIndex value"
		do
		{
			if ($ifindex.Contains($selectionindex))
			{
				$iscsi1if = $true
				Get-NetAdapter -ifindex $selectionindex | Rename-NetAdapter -NewName "iscsi-1$selectionnode-$targetnode"
				$nicname = Get-NetAdapter -ifindex $selectionindex | Select-Object Name
				if ((Get-NetAdapter -ifindex $selectionindex | Get-NetIPConfiguration).IPv4Address.IPAddress)
				{
					Get-NetAdapter -ifindex $selectionindex | Remove-NetIPAddress -AddressFamily "IPv4" -Confirm:$false
				}
				if ((Get-NetAdapter -ifindex $selectionindex | Get-NetIPConfiguration).Ipv4DefaultGateway)
				{
					Get-NetAdapter -ifindex $selectionindex | Remove-NetRoute -AddressFamily "IPv4" -Confirm:$false
				}
				Get-NetAdapter -ifindex $selectionindex | Set-DnsClientServerAddress -ResetServerAddresses
				Get-NetAdapter -ifindex $selectionindex | New-NetIPAddress -AddressFamily "IPv4" -IPAddress "172.16.10.$selectionnode" -PrefixLength "24" | Out-Null
				Get-NetAdapterAdvancedProperty -Name $nicname.Name -RegistryKeyword "*jumbopacket" | Set-NetAdapterAdvancedProperty -RegistryValue 9014
			}
			else
			{
				$iscsi1if = $false
			}
		}
		until ($iscsi1if)
	}
}
else
{
	Write-Host "Labeling iscsi-1 interface....OK" -ForegroundColor Green
	#=================
	#=================
	#=================
	$iscsi_1_ip = Get-NetIPAddress -InterfaceAlias iscsi-1$selectionnode-$targetnode | Select -ExpandProperty IPV4Address
	#write-host "$iscsi1index"
	if ($iscsi_1_ip -eq "172.16.10.$selectionnode")
	{
		write-host "IP for iscsi-11-2.............OK" -ForegroundColor Green
	}
	else
	{
		write-host "Configure IP for iscsi-11-2 manually" -ForegroundColor Red
	}
	$jumbo = Get-NetAdapterAdvancedProperty -Name "iscsi-1?-?" -RegistryKeyword "*jumbopacket" | Select-Object RegistryValue
	if ($jumbo.RegistryValue -ne 9014)
	{
		write-host "Jumbo packets on iscsi-1....FALSE" -ForegroundColor RED
		do
		{
			$selection = Read-Host "Would you like to enable jumbo packets? [y/n]"
			if ($selection -eq "y" -or $selection -eq "n")
			{
				$ok_selection = $true
			}
			else
			{
				$ok_selection = $false
			}
		}
		until ($ok_selection)
		if ($selection -eq "y")
		{
			Get-NetAdapterAdvancedProperty -Name "iscsi-1?-?" -RegistryKeyword "*jumbopacket" | Set-NetAdapterAdvancedProperty -RegistryValue 9014
		}
	}
	else
	{
		Write-Host "Jumbo packets on iscsi-1......OK" -ForegroundColor Green
	}
}
#---------------------------------------------------------------------------
#second iscsi interface
if ($selectioniscsi -eq 2)
{
	$iscsinic = Get-NetAdapter | Where-Object –FilterScript { $_.name -like "iscsi-2?-?" }
	if ($null -eq $iscsinic)
	{
		Write-Host "iscsi-2 interface....False." -ForegroundColor Red
		do
		{
			$selection = Read-Host "iscsi-2 interface is not configured. Would you like to configure it? [y/n]"
			if ($selection -eq "y" -or $selection -eq "n")
			{
				$ok_selection = $true
			}
			else
			{
				$ok_selection = $false
			}
		}
		until ($ok_selection)
		if ($selection -eq "y")
		{
			Get-NetAdapter
			#-----------------------------------------
			#----------------------------------------- ТУТ ВЫБОРКУ IFINDEX СДЕЛАТЬ
			#-----------------------------------------
			$selectionindex = Read-Host "`nEnter the required interface's ifIndex value"
			$ifindex = Get-NetAdapter | Select-Object -ExpandProperty ifIndex
			do
			{
				if ($ifindex.Contains($selectionindex))
				{
					$iscsi2if = $true
					Get-NetAdapter -ifindex $selectionindex | Rename-NetAdapter -NewName "iscsi-2$selectionnode-$targetnode"
					$nicname = Get-NetAdapter -ifindex $selectionindex | Select-Object Name
					if ((Get-NetAdapter -ifindex $selectionindex | Get-NetIPConfiguration).IPv4Address.IPAddress)
					{
						Get-NetAdapter -ifindex $selectionindex | Remove-NetIPAddress -AddressFamily "IPv4" -Confirm:$false
					}
					if ((Get-NetAdapter -ifindex $selectionindex | Get-NetIPConfiguration).Ipv4DefaultGateway)
					{
						Get-NetAdapter -ifindex $selectionindex | Remove-NetRoute -AddressFamily "IPv4" -Confirm:$false
					}
					Get-NetAdapter -ifindex $selectionindex | Set-DnsClientServerAddress -ResetServerAddresses
					Get-NetAdapter -ifindex $selectionindex | New-NetIPAddress -AddressFamily "IPv4" -IPAddress "172.16.11.$selectionnode" -PrefixLength "24" | Out-Null
					Get-NetAdapterAdvancedProperty -Name $nicname.Name -RegistryKeyword "*jumbopacket" | Set-NetAdapterAdvancedProperty -RegistryValue 9014
				}
				else
				{
					$iscsi2if = $false
				}
			}
			until ($iscsi2if)
		}
		else
		{
			Write-Host "Labeling iscsi-2 interface....OK" -ForegroundColor Green
			
			$iscsi_2_ip = Get-NetIPAddress -InterfaceAlias iscsi-2$selectionnode-$targetnode | Select -ExpandProperty IPV4Address
			#write-host "$iscsi1index"
			if ($iscsi_2_ip -eq "172.16.11.$selectionnode")
			{
				write-host "IP for iscsi-2$selectionnode-$targetnode.............OK" -ForegroundColor Green
			}
			else
			{
				write-host "Configure IP for iscsi-2$selectionnode-$targetnode manually" -ForegroundColor Red
			}
			$jumbo = Get-NetAdapterAdvancedProperty -Name "iscsi-2?-?" -RegistryKeyword "*jumbopacket" | Select-Object RegistryValue
			if ($jumbo.RegistryValue -ne 9014)
			{
				write-host "Jumbo packets on iscsi-2....FALSE" -ForegroundColor RED
				do
				{
					$selection = Read-Host "Would you like to enable Jumbo packets? [y/n]"
					if ($selection -eq "y" -or $selection -eq "n")
					{
						$ok_selection = $true
					}
					else
					{
						$ok_selection = $false
					}
				}
				until ($ok_selection)
				if ($selection -eq "y")
				{
					Get-NetAdapterAdvancedProperty -Name "iscsi-2?-?" -RegistryKeyword "*jumbopacket" | Set-NetAdapterAdvancedProperty -RegistryValue 9014
				}
			}
			else
			{
				Write-Host "Jumbo packets on iscsi-2......OK" -ForegroundColor Green
			}
		}
	}
	#--------------------------------------------------------------------------
}
$syncnic = Get-NetAdapter | Where-Object –FilterScript { $_.name -like "sync-1?-?" }
if ($null -eq $syncnic)
{
	Write-Host "sync-1 interface....False." -ForegroundColor Red
	do
	{
		$selection = Read-Host "sync-1 interface is not configured. Would you like to configure it? [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		Get-NetAdapter
		$selectionindex = Read-Host "`nEnter the required interface's ifIndex value"
		#-----------------------------------------
		#----------------------------------------- ТУТ ВЫБОРКУ IFINDEX СДЕЛАТЬ
		#-----------------------------------------
		$ifindex = Get-NetAdapter | Select-Object -ExpandProperty ifIndex
		do
		{
			if ($ifindex.Contains($selectionindex))
			{
				$sync1if = $true
				Get-NetAdapter -ifindex $selectionindex | Rename-NetAdapter -NewName "sync-1$selectionnode-$targetnode"
				$nicname = Get-NetAdapter -ifindex $selectionindex | Select-Object Name
				if ((Get-NetAdapter -ifindex $selectionindex | Get-NetIPConfiguration).IPv4Address.IPAddress)
				{
					Get-NetAdapter -ifindex $selectionindex | Remove-NetIPAddress -AddressFamily "IPv4" -Confirm:$false
				}
				if ((Get-NetAdapter -ifindex $selectionindex | Get-NetIPConfiguration).Ipv4DefaultGateway)
				{
					Get-NetAdapter -ifindex $selectionindex | Remove-NetRoute -AddressFamily "IPv4" -Confirm:$false
				}
				Get-NetAdapter -ifindex $selectionindex | Set-DnsClientServerAddress -ResetServerAddresses
				Get-NetAdapter -ifindex $selectionindex | New-NetIPAddress -AddressFamily "IPv4" -IPAddress "172.16.20.$selectionnode" -PrefixLength "24" | Out-Null
				Get-NetAdapterAdvancedProperty -Name $nicname.Name -RegistryKeyword "*jumbopacket" | Set-NetAdapterAdvancedProperty -RegistryValue 9014
			}
			else
			{
				$sync1if = $false
			}
		}
		until ($sync1if)
	}
}
else
{
	Write-Host "Labeling sync-1 interface.....OK" -ForegroundColor Green
	$sync_1_ip = Get-NetIPAddress -InterfaceAlias sync-1$selectionnode-$targetnode | Select -ExpandProperty IPV4Address
	if ($sync_1_ip -eq "172.16.20.$selectionnode")
	{
		write-host "IP for sync-1$selectionnode-$targetnode..............OK" -ForegroundColor Green
	}
	else
	{
		write-host "Configure IP for sync-2$selectionnode-$targetnode manually" -ForegroundColor Red
	}
	$jumbo = Get-NetAdapterAdvancedProperty -Name "sync-1?-?" -RegistryKeyword "*jumbopacket" | Select-Object RegistryValue
	if ($jumbo.RegistryValue -ne 9014)
	{
		write-host "Jumbo packets on sync....FALSE" -ForegroundColor RED
		do
		{
			$selection = Read-Host "Would you like to enable Jumbo packets? [y/n]"
			if ($selection -eq "y")
			{
				$ok_jumbo = $true
			}
			else
			{
				$ok_jumbo = $false
			}
		}
		until ($ok_jumbo)
		if ($selection -eq "y")
		{
			Get-NetAdapterAdvancedProperty -Name "sync-1?-?" -RegistryKeyword "*jumbopacket" | Set-NetAdapterAdvancedProperty -RegistryValue 9014
		}
		elseif ($selection -eq "n")
		{
			# do nothing 
		}
		else
		{
			write-host "You have entered an incorrect value"
		}
		
	}
	else
	{
		Write-Host "Jumbo packets on sync-1.......OK" -ForegroundColor Green
	}
}
#---------------------------------------------------------------------------
#second sync interface
if ($selectionsync -eq 2)
{
	$syncnic = Get-NetAdapter | Where-Object –FilterScript { $_.name -like "sync-2?-?" }
	if ($syncnic -eq $null)
	{
		Write-Host "sync-2 interface....False." -ForegroundColor Red
		$selection = Read-Host "sync-2 interface is not configured. Would you like to configure it? [y/n]"
		if ($selection -eq "y")
		{
			Get-NetAdapter
			$selectionindex = Read-Host "`nEnter the required interface's ifIndex value"
			#-----------------------------------------
			#----------------------------------------- ТУТ ВЫБОРКУ IFINDEX СДЕЛАТЬ
			#-----------------------------------------
			$ifindex = Get-NetAdapter | Select-Object -ExpandProperty ifIndex
			do
			{
				if ($ifindex.Contains($selectionindex))
				{
					$sync2if = $true
					Get-NetAdapter -ifindex $selectionindex | Rename-NetAdapter -NewName "sync-2$selectionnode-$targetnode"
					$nicname = Get-NetAdapter -ifindex $selectionindex | Select-Object Name
					if ((Get-NetAdapter -ifindex $selectionindex | Get-NetIPConfiguration).IPv4Address.IPAddress)
					{
						Get-NetAdapter -ifindex $selectionindex | Remove-NetIPAddress -AddressFamily "IPv4" -Confirm:$false
					}
					if ((Get-NetAdapter -ifindex $selectionindex | Get-NetIPConfiguration).Ipv4DefaultGateway)
					{
						Get-NetAdapter -ifindex $selectionindex | Remove-NetRoute -AddressFamily "IPv4" -Confirm:$false
					}
					Get-NetAdapter -ifindex $selectionindex | Set-DnsClientServerAddress -ResetServerAddresses
					#$selectionnodenumber = [int]$selectionnode+2
					Get-NetAdapter -ifindex $selectionindex | New-NetIPAddress -AddressFamily "IPv4" -IPAddress "172.16.21.$selectionnode" -PrefixLength "24" | Out-Null
					Get-NetAdapterAdvancedProperty -Name $nicname.Name -RegistryKeyword "*jumbopacket" | Set-NetAdapterAdvancedProperty -RegistryValue 9014$
				}
				else
				{
					$sync2if = $false
				}
			}
			until ($sync2if)
		}
	}
	else
	{
		Write-Host "Labeling sync-2 interface.....OK" -ForegroundColor Green
		$sync_2_ip = Get-NetIPAddress -InterfaceAlias sync-2$selectionnode-$targetnode | Select -ExpandProperty IPV4Address
		#write-host "$iscsi1index"
		if ($sync_2_ip -eq "172.16.21.$selectionnode")
		{
			write-host "IP for sync-2$selectionnode-$targetnode..............OK" -ForegroundColor Green
		}
		else
		{
			write-host "Configure IP for sync-2$selectionnode-$targetnode manually" -ForegroundColor Red
		}
		$jumbo = Get-NetAdapterAdvancedProperty -Name "sync-2?-?" -RegistryKeyword "*jumbopacket" | Select-Object RegistryValue
		if ($jumbo.RegistryValue -ne 9014)
		{
			write-host "Jumbo packets sync-2....FALSE" -ForegroundColor RED
			do
			{
				$selection = Read-Host "Would you like to enable Jumbo packets? [y/n]"
				if ($selection -eq "y" -or $selection -eq "n")
				{
					$ok_selection = $true
				}
				else
				{
					$ok_selection = $false
				}
			}
			until ($ok_selection)
			if ($selection -eq "y")
			{
				Get-NetAdapterAdvancedProperty -Name "sync-2?-?" -RegistryKeyword "*jumbopacket" | Set-NetAdapterAdvancedProperty -RegistryValue 9014
			}
			elseif ($selection -eq "n")
			{
				# do nothing
			}
		}
		else
		{
			Write-Host "Jumbo packets on sync-2.......OK" -ForegroundColor Green
		}
	}
}
#------------------------------------------------------
write-host "
Check the availability of the partner node and jumbo packet passthrough"
write-host "---------------------------"
do
{
	$selection = Read-Host "Is partner node configured? [y/n]"
	if ($selection -eq "y" -or $selection -eq "n")
	{
		$ok_selection = $true
	}
	else
	{
		$ok_selection = $false
	}
}
until ($ok_selection)
if ($selection -eq "y")
{
	if ($selectionnode -eq 1)
	{
		if (Test-Connection 172.16.10.2 -count 1 -Quiet)
		{
			#iscsi-------------------------------------------------
			Write-Host "Node partner available........................OK" -ForegroundColor Green
			$ping = ping -f -l 8972 172.16.10.2
			$ping = $ping | Out-String
			$bool = $ping.Contains("(0% loss)")
			if ($bool)
			{
				Write-Host "iscsi-1$selectionnode-$targetnode jumbo packets passthrough..........OK" -ForegroundColor Green
			}
			else
			{
				Write-Host "iscsi-1$selectionnode-$targetnode jumbo packets passthrough......FAILED" -ForegroundColor Red
				Write-Host $ping
			}
			if ($selectioniscsi -eq 2)
			{
				$ping = ping -f -l 8972 172.16.11.2
				$ping = $ping | Out-String
				$bool = $ping.Contains("(0% loss)")
				if ($bool)
				{
					Write-Host "iscsi-2$selectionnode-$targetnode jumbo packets passthrough..........OK" -ForegroundColor Green
				}
				else
				{
					Write-Host "iscsi-2$selectionnode-$targetnode jumbo packets passthrough......FAILED" -ForegroundColor Red
					Write-Host $ping
				}
			}
			#sync---------------------------------------------------
			$ping = ping -f -l 8972 172.16.20.2
			$ping = $ping | Out-String
			$bool = $ping.Contains("(0% loss)")
			if ($bool)
			{
				Write-Host "sync-1$selectionnode-$targetnode  jumbo packets passthrough..........OK" -ForegroundColor Green
			}
			else
			{
				Write-Host "sync-1$selectionnode-$targetnode  jumbo packets passthrough......FAILED" -ForegroundColor Red
				Write-Host $ping
			}
			if ($selectioniscsi -eq 2)
			{
				$ping = ping -f -l 8972 172.16.21.2
				$ping = $ping | Out-String
				$bool = $ping.Contains("(0% loss)")
				if ($bool)
				{
					Write-Host "sync-2$selectionnode-$targetnode  jumbo packets passthrough..........OK" -ForegroundColor Green
				}
				else
				{
					Write-Host "sync-2$selectionnode-$targetnode  jumbo packets passthrough......FAILED" -ForegroundColor Red
					Write-Host $ping
				}
			}
		}
		else
		{
			Write-Host "Node partner available................FALSE" -ForegroundColor Red
		}
	}
	elseif ($selectionnode -eq 2)
	{
		if (Test-Connection 172.16.10.1 -count 1 -Quiet)
		{
			#iscsi-------------------------------------------------
			Write-Host "Node partner available....OK." -ForegroundColor Green
			$ping = ping -f -l 8972 172.16.10.1
			$ping = $ping | Out-String
			$bool = $ping.Contains("(0% loss)")
			if ($bool)
			{
				Write-Host "iscsi-1 jumbo packets passthrough was successful" -ForegroundColor Green
			}
			else
			{
				Write-Host "iscsi-1 jumbo packets are not passing through" -ForegroundColor Red
				Write-Host $ping
			}
			if ($selectioniscsi -eq 2)
			{
				$ping = ping -f -l 8972 172.16.11.1
				$ping = $ping | Out-String
				$bool = $ping.Contains("(0% loss)")
				if ($bool)
				{
					Write-Host "iscsi-2 jumbo packets passthrough was successful" -ForegroundColor Green
				}
				else
				{
					Write-Host "iscsi-2 jumbo packets are not passing through" -ForegroundColor Red
					Write-Host $ping
				}
			}
			#sync---------------------------------------------------
			$ping = ping -f -l 8972 172.16.20.1
			$ping = $ping | Out-String
			$bool = $ping.Contains("(0% loss)")
			if ($bool)
			{
				Write-Host "sync-1 jumbo packets passthrough was successful" -ForegroundColor Green
			}
			else
			{
				Write-Host "sync-1 jumbo-packets are not passing through" -ForegroundColor Red
				Write-Host $ping
			}
			if ($selectioniscsi -eq 2)
			{
				$ping = ping -f -l 8972 172.16.21.1
				$ping = $ping | Out-String
				$bool = $ping.Contains("(0% loss)")
				if ($bool)
				{
					Write-Host "sync-2 jumbo packets passthrough was successful" -ForegroundColor Green
				}
				else
				{
					Write-Host "sync-2 jumbo packets are not passing through" -ForegroundColor Red
					Write-Host $ping
				}
			}
		}
		else
		{
			write-host "Node partner available....False." -ForegroundColor Red
		}
	}
	else
	{
		write-host "You have entered an incorrect value"
	}
}
#------------------------------------------------------
write-host "
Checking Windows Update"
write-host "---------------------------"
$update = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name "AUOptions" -ErrorAction SilentlyContinue
if (($null -ne $update.AUOptions) -and ($update.AUOptions -eq "3"))
{
	write-host "Windows Update....ОК" -ForegroundColor Green
}
else
{
	write-host "Windows Update....FALSE" -ForegroundColor RED
	do
	{
		$selection = Read-Host "Would you like to set up Windows Update? [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name "AUoptions" 3
	}
}
if ($vmware -eq 0)
{
	#------------------------------------------------------
	write-host "
	Checking Roles and Features"
	write-host "---------------------------"
	$hipev = Get-WindowsFeature -Name 'Hyper-V' | Select-Object installed
	if ($hipev.Installed)
	{
		write-host "Hyper-V Role....ОК" -ForegroundColor Green
	}
	else
	{
		write-host "Hyper-V Role....FALSE" -ForegroundColor RED
		$selection = Read-Host "Would you like to install the Hyper-V role? [y/n]"
		if ($selection -eq "y")
		{
			$AutoRunScript = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "AutoRunScript" -ErrorAction SilentlyContinue
			if ($null -eq $AutoRunScript)
			{
				$curDir = $MyInvocation.MyCommand.Definition | split-path -parent
				$name = $MyInvocation.MyCommand.Name
				new-itemproperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run AutoRunScript -propertytype String -value "Powershell $curDir\$name" | Out-Null
			}
			Install-WindowsFeature -Name Hyper-V -IncludeManagementTools | Out-Null #-Restart | Out-Null
		}
	}
	#-----------------------------------------------------
	$cluster = Get-WindowsFeature -Name 'Failover-Clustering' | Select-Object installed
	if ($cluster.Installed)
	{
		write-host "Failover Clustering....ОК" -ForegroundColor Green
	}
	else
	{
		write-host "Failover Clustering....FALSE" -ForegroundColor RED
		$selection = Read-Host "Would you like to install the Failover Cluster role? [y/n]"
		if ($selection -eq "y")
		{
			Install-WindowsFeature -Name Failover-Clustering –IncludeManagementTools | Out-Null
		}
	}
	#-----------------------------------------------------
	$mpio = Get-WindowsOptionalFeature –Online –FeatureName MultiPathIO | Select-Object state
	if ($mpio.state -ne "Disabled")
	{
		write-host "MultiPathIO....ОК" -ForegroundColor Green
		$iscsi = Get-MSDSMAutomaticClaimSettings mpio
		if ($iscsi.iscsi)
		{
			write-host "MultiPathIO support for iscsi....ОК" -ForegroundColor Green
		}
		else
		{
			write-host "MultiPathIO support for iscsi....FALSE" -ForegroundColor RED
			do
			{
				$selection = Read-Host "You want to install MultiPathIO support for iscsi? [y/n]"
				if ($selection -eq "y" -or $selection -eq "n")
				{
					$ok_selection = $true
				}
				else
				{
					$ok_selection = $false
				}
			}
			until ($ok_selection)
			if ($selection -eq "y")
			{
				Enable-MSDSMAutomaticClaim -BusType iSCSI | out-null
			}
		}
	}
	else
	{
		write-host "MultiPathIO....FALSE" -ForegroundColor RED
		do
		{
			$selection = Read-Host "Would you like to install MultiPathIO [y/n]"
			if ($selection -eq "y" -or $selection -eq "n")
			{
				$ok_selection = $true
			}
			else
			{
				$ok_selection = $false
			}
		}
		until ($ok_selection)
		if ($selection -eq "y")
		{
			Enable-WindowsOptionalFeature –Online –FeatureName MultiPathIO | Out-Null
			Enable-MSDSMAutomaticClaim -BusType iSCSI | out-null
		}
	}
}
if ($vmware -eq 1)
{
	$framework = Get-WindowsFeature NET-Framework-45-Core | Select-Object installed
	if ($framework.installed -ne "True")
	{
		Write-Host "Starting installation of .NET 4.5 Framework"
		Add-WindowsFeature NET-Framework-45-Core | Out-Null
	}
	$osversion = (Get-WmiObject -class Win32_OperatingSystem).Caption
	if ($osversion -like "*2012 R2*"){
		if ($PSVersionTable.PSVersion.Major -lt 5) {
			wget http://download.windowsupdate.com/d/msdownload/update/software/updt/2017/03/windowsblue-kb3191564-x64_91d95a0ca035587d4c1babe491f51e06a1529843.msu -OutFile C:\wmf-5-1.msu
			start-process 'c:\windows\system32\wusa.exe' -argumentlist 'C:\wmf-5-1.msu' -wait
			#Start-Process wusa.exe C:\wmf-5-1.msu /norestart
			Remove-Item C:\wmf-5-1.msu -Confirm:$false
			write-host "This VM will reboot in 10 seconds to apply PowerShell 5.1 installation" -ForegroundColor yellow
			Start-Sleep -Seconds 10
			Restart-Computer -Force
		}
	}

	#{
	#	Write-Host "Starting installation of Windows Management Framework 5.1 for Windows Server 2012R2"
	#	wget http://download.windowsupdate.com/d/msdownload/update/software/updt/2017/03/windowsblue-kb3191564-x64_91d95a0ca035587d4c1babe491f51e06a1529843.msu -OutFile C:\wmf-5-1.msu
	#	wusa C:\wmf-5-1.msu /quiet /norestart
	#	Remove-Item C:\wmf-5-1.msu -Confirm:$false
	#}
	#$osversion = (Get-WmiObject -class Win32_OperatingSystem).Caption
	#$wmf = Get-HotFix | Where { $_.HotFixID -eq "KB3191564" }
	#if ($osversion -like "*2012 R2*")
	#{
	#	if (!$wmf)
	#	{
	#		wget https://go.microsoft.com/fwlink/?linkid=839516 -OutFile C:\wmf-5-1.msu
	#		wusa C:\wmf-5-1.msu /quiet /norestart
	#		Remove-Item C:\wmf-5-1.msu -force
	#		write-host "Reboot is required after to enable Windows Management Framework 5.1. Server will reboot in 5 seconds..."
	#		Start-Sleep 5000
	#		Restart-Computer -Force
	#	}
	#}
	
	if (Get-Module -ListAvailable -Name VMware.PowerCLI) {
		Write-Host "PowerCLI module is installed"
	} else {
		Write-Host "Module does not exist"
		Write-Host "Starting installation of vSphere PowerCLI"
		Install-Module -Name VMware.PowerCLI -Force -AllowClobber
		Import-Module VMware.PowerCLI
	}
	# install rescan_script
	#------------------------------------------------------------------------
	$isfile = Test-Path "C:\rescan_script.ps1"
	if ($isfile)
	{
		write-host "rescan_script...ok" -ForegroundColor Green
	}
	else
	{
		write-host "rescan_script...false" -ForegroundColor Red
		do
		{
			$selection = Read-Host "Would you like to install rescan_script? [y/n]"
			if ($selection -eq "y" -or $selection -eq "n")
			{
				$ok_selection = $true
			}
			else
			{
				$ok_selection = $false
			}
		}
		until ($ok_selection)
		if ($selection -eq "y")
		{
			do
			{
				try
				{
					[ipaddress]$esxiIP = read-host "Type IP address of the local ESXi server"
				}
				catch
				{
					write-host "IP address entered is not valid. Try again"
				}
			}
			while (!$esxiIP)
			@"
Import-Module VMware.PowerCLI
`$counter = 0
if (`$counter -eq 0){
`t	Set-PowerCLIConfiguration -InvalidCertificateAction ignore -Confirm:`$false|
Out-Null
}
`$ESXiHost = "$esxiIP"
`$ESXiUser = "root"
`$ESXiPassword = "StarWind2015"
Connect-VIServer `$ESXiHost -User `$ESXiUser -Password `$ESXiPassword | Out-Null
Get-VMHostStorage `$ESXiHost -RescanAllHba | Out-Null
Get-ScsiLun -VMHost `$ESXiHost -LunType disk | Where-Object Vendor -EQ "STARWIND"| Where-Object ConsoleDeviceName -NE " " | Set-ScsiLun -MultipathPolicy RoundRobin -CommandsToSwitchPath 1 | Out-Null
Disconnect-VIServer `$ESXiHost -Confirm:`$false
`$file = Get-Content "`$PSScriptRoot\rescan_script.ps1"
if (`$file[1] -ne "`$counter = 1") {
`t	`$file[1] = "`$counter = 1"
`t	`$file > "`$PSScriptRoot\rescan_script.ps1"
}
"@ > C:\rescan_script.ps1
			
		}
		elseif ($selection -eq "n")
		{
			# do nothing
		}
		else
		{
			write-host "You have entered an incorrect value"
		}
	}
	# -------------------------------------------
	$task = Get-ScheduledTask | Where{ $_.TaskName -eq "Rescan ESXi" }
	$time = (Get-Date -Format o).Substring(0, (Get-Date -Format o).length - 6)
	
	if ($task)
	{
		write-host "Rescan task...ok" -ForegroundColor Green
	}
	else
	{
		write-host "Rescan task...false" -ForegroundColor Red
		do
		{
			$selection = Read-Host "Would you like to configure Rescan ESX task? [y/n]"
			if ($selection -eq "y" -or $selection -eq "n")
			{
				$ok_selection = $true
				$taskbody = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>$time</Date>
    <Author>SW-HCA-VM-0$selectionnode\Administrator</Author>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Application"&gt;&lt;Select Path="Application"&gt;*[System[Provider[@Name='StarWindService'] and EventID=788]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Application"&gt;&lt;Select Path="Application"&gt;*[System[Provider[@Name='StarWindService'] and EventID=782]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Application"&gt;&lt;Select Path="Application"&gt;*[System[Provider[@Name='StarWindService'] and EventID=257]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Application"&gt;&lt;Select Path="Application"&gt;*[System[Provider[@Name='StarWindService'] and EventID=773]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Application"&gt;&lt;Select Path="Application"&gt;*[System[Provider[@Name='StarWindService'] and EventID=817]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>SW-HCA-VM-0$selectionnode\Administrator</UserId>
      <LogonType>Password</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>P3D</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -NoLogo -NonInteractive -NoProfile -WindowStyle Hidden -File C:\rescan_script.ps1</Arguments>
    </Exec>
  </Actions>
</Task>
"@
				$taskbody > C:\RescanESX.xml
				schtasks.exe /create /RU administrator /RP StarWind2015 /tn "Rescan ESXi" /XML "C:\RescanESX.xml"
				Remove-Item –path C:\RescanESX.xml -Force -ErrorAction SilentlyContinue
			}
			else
			{
				$ok_selection = $false
			}
		}
		until ($ok_selection)
	}
	
	# configure Windows Task Scheduler to fire HBA rescanning for ESXi upon certain events
	#------------------------------------------------------------------------
}

#------------------------------------------------------
write-host "
Run the script after restart"
write-host "---------------------------"

$AutoRunScript = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "AutoRunScript" -ErrorAction SilentlyContinue
if ($null -eq $AutoRunScript)
{
	do
	{
		$selection = Read-Host "Do you want the script to run after a restart? [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		$curDir = $MyInvocation.MyCommand.Definition | split-path -parent
		$name = $MyInvocation.MyCommand.Name
		new-itemproperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run AutoRunScript -propertytype String -value "Powershell $curDir\$name" | Out-Null
	}
}
else
{
	do
	{
		$selection = Read-Host "Do you want the script to run after a restart? [y/n]"
		if ($selection -eq "y" -or $selection -eq "n")
		{
			$ok_selection = $true
		}
		else
		{
			$ok_selection = $false
		}
	}
	until ($ok_selection)
	if ($selection -eq "y")
	{
		# do nothing
	}
	elseif ($selection -eq "n")
	{
		Remove-Itemproperty -Name 'AutoRunScript' -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\
	}
}

# $isStarwind = Test-Path "c:\Users\$user\Desktop\starwind.exe"
# if ($isStarwind -eq "True")
# {
# 	do
# 	{
# 		$selection = Read-Host "Would you like to delete StarWind installation file? [y/n]"
# 		if ($selection -eq "y" -or $selection -eq "n")
# 		{
# 			$ok_selection = $true
# 		}
# 		else
# 		{
# 			$ok_selection = $false
# 		}
# 	}
# 	until ($ok_selection)
# 	if ($selection -eq "y")
# 	{
# 		Remove-Item "c:\Users\$user\Desktop\starwind.exe"
# 	}
# }

$hcafolder = Test-Path "c:\HCA"
if (!$hcafolder)
{
	New-Item -ItemType directory -Path C:\HCA
}
$networkscript = Test-Path "C:\HCA\StarWind HCA network test.ps1"
if (!$networkscript){
	$net = @"
cls
write-host "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@" -ForegroundColor Yellow
write-host "@@@@               StarWind HCA network connection checker                 @@@@" -ForegroundColor Yellow
write-host "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@" -ForegroundColor Yellow
write-host ""
write-host ""

`$hostname = hostname

`$iscsi11 = "172.16.10.1" # IP address of the 1st iSCSI connection on HCA node 1
`$iscsi12 = "172.16.11.1" # IP address of the 2nd iSCSI connection on HCA node 1 (if present in your system)
`$iscsi21 = "172.16.10.2" # IP address of the 1st iSCSI connection on HCA node 2
`$iscsi22 = "172.16.11.2" # IP address of the 2nd iSCSI connection on HCA node 2 (if present in your system)

`$sync11 = "172.16.20.1" # IP address of the 1st Sync connection on HCA node 1
`$sync12 = "172.16.21.1" # IP address of the 2nd Sync connection on HCA node 1 (if present in your system)
`$sync21 = "172.16.20.2" # IP address of the 1st Sync connection on HCA node 2
`$sync22 = "172.16.21.2" # IP address of the 2nd Sync connection on HCA node 2 (if present in your system)

`$iscsiinterfaces = Get-WmiObject Win32_NetworkAdapter | Select-Object -ExpandProperty NetConnectionID
`$iscsiinterfaces = `$iscsiinterfaces -like "iscsi*"
`$iscsinumber = `$iscsiinterfaces.Count
write-host "`$iscsinumber iSCSI interfaces discovered"

`$syncinterfaces = Get-WmiObject Win32_NetworkAdapter | Select-Object -ExpandProperty NetConnectionID
`$syncinterfaces = `$syncinterfaces -like "sync*"
`$syncnumber = `$syncinterfaces.Count
write-host "`$syncnumber Sync interfaces discovered"

if (`$hostname -eq "SW-HCA-01" -or `$hostname -eq "SW-HCA-VM-01" -or `$hostname -eq "SW1") {
	# checking iSCSI ------------------------------
	`$ping = ping `$iscsi21
	`$ping = `$ping | Out-String
	`$bool = `$ping.Contains("(0% loss)")
	if (`$bool){
		Write-Host "iscsi-11-2 interface connectivity..........OK" -ForegroundColor Green
	} else {
		Write-Host "iscsi-11-2 interface connectivity..........FAILED" -ForegroundColor Red
		Write-host "Check whether cable connections are made according to instruction" -ForegroundColor Yellow
		Write-Host `$ping
	}
	if (`$iscsinumber -eq 2) {
		`$ping2 = ping `$iscsi22
		`$ping2 = `$ping2 | Out-String
		`$bool2 = `$ping2.Contains("(0% loss)")
		if (`$bool2){
			Write-Host "iscsi-21-2 interface connectivity..........OK" -ForegroundColor Green
		} else {
			Write-Host "iscsi-21-2 interface connectivity..........FAILED" -ForegroundColor Red
			Write-host "Check whether cable connections are made according to instruction" -ForegroundColor Yellow
			Write-Host `$ping2
		}
	}
	# checking Sync-------------------------------
	`$ping3 = ping `$sync21
	`$ping3 = `$ping3 | Out-String
	`$bool3 = `$ping3.Contains("(0% loss)")
	if (`$bool3){
		Write-Host "sync-11-2 interface connectivity...........OK" -ForegroundColor Green
	} else {
		Write-Host "sync-11-2 interface connectivity...........FAILED" -ForegroundColor Red
		Write-host "Check whether cable connections are made according to instruction" -ForegroundColor Yellow
		Write-Host `$ping3
	}
	if (`$syncnumber -eq 2) {
		`$ping4 = ping `$sync22
		`$ping4 = `$ping4 | Out-String
		`$bool4 = `$ping4.Contains("(0% loss)")
		if (`$bool4){
			Write-Host "sync-21-2 interface connectivity...........OK" -ForegroundColor Green
		} else {
			Write-Host "sync-21-2 interface connectivity...........FAILED" -ForegroundColor Red
			Write-host "Check whether cable connections are made according to instruction" -ForegroundColor Yellow
			Write-Host `$ping4
		}
	}
} elseif (`$hostname -eq "SW-HCA-02" -or `$hostname -eq "SW-HCA-VM-02" -or `$hostname -eq "SW2"){
	# checking iSCSI ------------------------------
	`$ping = ping `$iscsi11
	`$ping = `$ping | Out-String
	`$bool = `$ping.Contains("(0% loss)")
	if (`$bool){
		Write-Host "iscsi-12-1 interface connectivity..........OK" -ForegroundColor Green
	} else {
		Write-Host "iscsi-12-1 interface connectivity..........FAILED" -ForegroundColor Red
		Write-Host `$ping
	}
	if (`$iscsinumber -eq 2) {
		`$ping2 = ping `$iscsi12
		`$ping2 = `$ping2 | Out-String
		`$bool2 = `$ping2.Contains("(0% loss)")
		if (`$bool2){
			Write-Host "iscsi-22-1 interface connectivity..........OK" -ForegroundColor Green
		} else {
			Write-Host "iscsi-22-1 interface connectivity..........FAILED" -ForegroundColor Red
			Write-Host `$ping2
		}
	}
	# checking Sync-------------------------------
	`$ping3 = ping `$sync11
	`$ping3 = `$ping3 | Out-String
	`$bool3 = `$ping3.Contains("(0% loss)")
	if (`$bool3){
		Write-Host "sync-11-2 interface connectivity...........OK" -ForegroundColor Green
	} else {
		Write-Host "sync-11-2 interface connectivity...........FAILED" -ForegroundColor Red
		Write-Host `$ping3
	}
	if (`$syncnumber -eq 2) {
		`$ping4 = ping `$sync12
		`$ping4 = `$ping4 | Out-String
		`$bool4 = `$ping4.Contains("(0% loss)")
		if (`$bool4){
			Write-Host "sync-21-2 interface connectivity...........OK" -ForegroundColor Green
		} else {
			Write-Host "sync-21-2 interface connectivity...........FAILED" -ForegroundColor Red
			Write-Host `$ping4
		}
	}
} else {
	write-host "Your StarWind HCA nodes have custom settings. Please check network connections manually or edit the IP address settings in the top part of this PowerShell script according to your current settings."
}
write-host "
Press any key to exit"
`$HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
`$HOST.UI.RawUI.Flushinputbuffer()
"@ > "C:\HCA\StarWind HCA network test.ps1"
}

do
{
	$rebootRequied = read-host "Would you like to reboot the server? [y/n]"
	if ($rebootRequied -eq "y" -or $rebootRequied -eq "n")
	{
		$ok_rebootRequired = $true
	}
	else
	{
		$ok_rebootRequired = $false
	}
}
until ($ok_rebootRequired)
if ($rebootRequied -eq "y")
{
	Restart-Computer -Force
}
elseif ($rebootRequied -eq "n")
{
	write-host "Checking done"
	$host.ui.RawUI.ReadKey(6) | out-null
}