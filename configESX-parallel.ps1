#!/usr/bin/powershell

$dataPods = import-csv DNSnTime3.csv
$n = 10
$_grplst = @{}
$count = 0 
$dataPods |% {$_grplst[$count % $n] += @($_);$count++}

$ScriptBlock = {
    param($pod)
    Connect-VIServer <vcenter_hostname> -User '<username>' -Password <passowrd> | Out-null
    $dataPod = $($pod.DataPod)
    $dnspri, $dnsalt = $($pod.DNSserver.split(','))
    $ntpServer = $($pod.NTPserver)
    $domainname = $dataPod.ToLower() + ".<domain_name.com>"
    $esxHosts = Get-Cluster -Name $dataPod | Get-VMHost
    foreach ($esx in $esxHosts) {
        SetNTP
        SetDNS
    }
    Disconnect-VIServer -Server * -Confirm:$false
}

Function Set_DNS{
    Write-host "[$dataPod] Configuring DNS and Domain Name on $esx" -ForegroundColor Green
    Get-VMHostNetwork -VMHost $esx | Set-VMHostNetwork -DomainName $domainname -DNSAddress $dnspri , $dnsalt -Confirm:$false | Out-Null
}

Function Set_NTP{
    #--- REMOVAL & ADD NTP ---#
    Write-host "[$dataPod] Removing existing NTP Server on $esx" -ForegroundColor Red
    try {
        $_ntp = $esx | Get-VMHostNtpServer
        $esx | Remove-VMHostNtpServer -NtpServer $_ntp -Confirm:$false 
    }
    catch [System.Exception] {
        Write-Warning "Error during removing existing NTP Servers."    
    }
    Write-host "[$dataPod] Configuring NTP Servers on $esx" -ForegroundColor Green
    foreach ($NTP in $ntpServer.split(',')) {
        $esx | Add-VMHostNtpServer -ntpserver $NTP -confirm:$False | Out-Null
    }
    #=========================#

    #--- SET NTP & START SERVICES ---#
    Write-host "[$dataPod] Configure NTP Service on $esx" -ForegroundColor Green
    $NTPService = $esx | Get-VMHostService | Where-Object {$_.key -eq "ntpd"}
    if($NTPService.Running -eq $True){
        Write-host "[$dataPod] Stopping NTP Client on $esx" -ForegroundColor Red
        Stop-VMHostService -HostService $NTPService -Confirm:$false | Out-Null
    }
    if($NTPService.Policy -ne "on"){
        Write-host "[$dataPod] Configuring NTP Client Policy on $esx" -ForegroundColor Green
        Set-VMHostService -HostService $NTPService -Policy "on" -confirm:$False | Out-Null
    }

    Write-host "[$dataPod] Allow NTP queries outbound through the firewall on $esx" -ForegroundColor Green
    Get-VMHostFirewallException -VMHost $esx | where {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled:$true | Out-Null

    Write-host "[$dataPod] Configure Local Time on $esx" -ForegroundColor Green
    $HostTimeSystem = Get-View $esx.ExtensionData.ConfigManager.DateTimeSystem 
    $HostTimeSystem.UpdateDateTime([DateTime]::UtcNow) 
    
    Write-host "[$dataPod] Starting NTP service on $esx" -ForegroundColor Green
    Start-VMHostService -HostService $NTPService -confirm:$False | Out-Null
    #=========================#
}

Function Set_SERIAL{
    Write-host "[$dataPod] Configure remoteSerialPort firewall for $esx" -ForegroundColor Green
    $esxcli = Get-EsxCli -VMHost $esx
    if($esxcli -ne $null){
      if($esxcli.network.firewall.ruleset.list("remoteSerialPort").Enabled -eq "false"){
        Write-host "[$dataPod] Changing the remoteSerialPort firewall configuration for $esx"
        $esxcli.network.firewall.ruleset.set($false, $true, "remoteSerialPort")
        $esxcli.network.firewall.refresh()
      }
      $_status = $esx | foreach {Get-VMHostFirewallException -VMHost $_.name | where {$_.Name -eq "VM serial port connected over network"}} | select Enabled
      Write-host "[$dataPod] remoteSerialPort firewall config status for $esx - $_status" -ForegroundColor Green
    }
}

Function Set_SSH{
    $SSHService = Get-VMHostService -VMHost $esx | where {$_.Key -eq "TSM-SSH"}
    if($SSHService.Running -ne $True){
        Write-host "[$dataPod] Starting ESXi Shell service on $esx"
	    Get-VMHostService -VMHost $esx| where {$_.Key -eq "TSM"} | Restart-VMHostService -Confirm:$false | Out-null

        Write-host "[$dataPod] Starting SSH Server service on $esx"
        Restart-VMHostService -HostService $SSHService -Confirm:$false | Out-null

        Write-host "[$dataPod] SSH Server service Status on $esx"
        Get-VMHostService -VMHost $esx | where {$_.Key -eq "TSM-SSH"} | select VMHost, Label, Running | Format-Table -AutoSize
    }
}

$init = 
[scriptblock]::Create(@"
function SetDNS {$function:Set_DNS}
function SetNTP {$function:Set_NTP}
function SetSERIAL {$function:Set_SERIAL}
function SetSSH {$function:Set_SSH}
Get-module -ListAvailable PowerCLI* | Import-module
"@)

###-Lets Start HERE-###
0..($n-1) |% {
    ForEach ($_line in $_grplst[$_]){
        Start-Job -InitializationScript $init -ScriptBlock $ScriptBlock -ArgumentList $_line
    }
    # Wait for all to complete
    While (Get-Job -State "Running") { Start-Sleep 2 }
    # Display output from all jobs
    Get-Job | Receive-Job
    # Cleanup
    Remove-Job *
}
Write-Host "Script execution completed!"




# CSV Format:
# DataPod,DNSserver,NTPserver
# <VM_Cluster_Name>,"<NTP_IP>,8.8.8.8","0.pool.ntp.org,1.pool.ntp.org,2.pool.ntp.org,3.pool.ntp.org"
