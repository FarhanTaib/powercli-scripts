#!/usr/bin/powershell

Connect-VIServer <vcenter.hostname> -User '<username>' -Password <password>

$i = 1
$lists = import-csv vmconf.csv
[int]$NumberToDeploy = $lists.NoDeploy
[string]$NamingConvention = $lists.vmname
$PodName = $(Get-Cluster -VMHost $lists.esxi).Name.tolower()
$targetDatastore = Get-Datastore -VMHost $lists.esxi  | Where {($_.FreeSpaceMB -gt "10240")} | Sort-Object -Property FreeSpaceMb -Descending | Select -First 1
$net = @($lists.network.split(',') | % {$_ -replace '"', ""})
$dsk = @($lists.disk.split(','))

while ($i -le $NumberToDeploy) {
    $VMName = $NamingConvention + $i + "." + $PodName
    New-VM -VMHost $lists.esxi -Name $VMName -Datastore $targetDatastore -DiskGB $dsk -MemoryGB $lists.mem -NumCPU $lists.cpu -NetworkName $net -DiskStorageFormat Thin -GuestID $lists.guestid -CD
    New-CDDrive -VM $VMName -ISOPath "[esx1-$PodName] iso\ubuntu-10.04.4-server-amd64.iso"
    $i++
}

Disconnect-VIServer -Server * -Confirm:$false

# csv format
# esxi,vmname,guestid,cpu,mem,disk,network,NoDeploy
# <ip>,<vmname>,ubuntu64Guest,<cpu>,<memory>,"<disk1>,<disk2>,...<diskN>","""<network_name1>"",""<network_name2>"",""<network_name3>"",...,""<network_nameN>""",<Number_of_server_to_deploy>
