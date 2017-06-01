#!/usr/bin/powershell

Function Setup {
    $csvContents = @()
    $csvContents | Export-Csv ESX_settings.csv
    $csvContents | Export-Csv ESX_list.csv
}

Function Populate_ESX{
    Connect-VIServer <vcenter_hostname> -User '<username>' -Password <password> | Out-null
    Get-Cluster | Get-VMHost | Select @{n="DataPod";e={$_.Parent}},@{n="ESXHost";e={$_.Name}} | Export-Csv ESX_list.csv -NoTypeInformation -Force -Append
    Disconnect-VIServer -Server * -Confirm:$false | Out-null
}

Function Body{
    $lists = import-csv ESX_list.csv
    $n = 50
    $pool = @{}
    $count = 0 
    $($lists) |% {$pool[$count % $n] += @($_);$count++}

    0..($n-1) |% {
        ForEach ($line in $pool[$_]){
            Start-Job -InitializationScript $init -ScriptBlock $ScriptBlock -ArgumentList $($line.ESXHost), $($line.DataPod)
        }
        # Wait for all to complete
        While (Get-Job -State "Running") { Start-Sleep 2 }
        # Display output from all jobs
        # Get-Job | Receive-Job
        # Getting the information back from the jobs
        foreach($job in Get-Job){
            Receive-Job -Job $job | select -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName | Export-Csv ESX_settings.csv -NoTypeInformation -Force -Append | Out-null
            Start-Sleep -s 2
            Remove-Job -Job $job -Force
        }
        # Cleanup
        # Remove-Job *
    }
    Remove-Job *
}

$init = 
[scriptblock]::Create(@"
Get-module -ListAvailable PowerCLI* | Import-module
"@)

$ScriptBlock = {
    param($_esx, $_dpod)
    Connect-VIServer vcenter.noc.bluecoatcloud.com -User 'administrator' -Password blu3f0g! | Out-null
    $network = Get-VMHostNetwork -VMHost $_esx
    $ntp = Get-VMHostNTPServer -VMHost $_esx
    $ntpService = Get-VmHostService -VMHost $_esx |Where-Object {$_.key-eq "ntpd"}
    ""|select @{n="DataPod";e={$_dpod}}, `
    @{n="IPaddr";e={$_esx}}, `
    @{n="ESXHostname";e={$network.HostName}}, `
    @{n="PODname";e={$_dpod}}, `
    @{n="DomainName";e={$network.DomainName}}, `
    @{n="SearchDomain";e={[string]::join(',', $($network.SearchDomain))}}, `
    @{n="DNServer";e={[string]::join(',', $($network.DnsAddress))}}, `
    @{n="NTPServer";e={$ntp}}, `
    @{n="ntpPolicy";e={$ntpService.Policy}}, `
    @{n="ntpServiceRunning";e={$ntpService.Running}}
    Disconnect-VIServer -Server * -Confirm:$false | Out-null
}

# Write-Host "Reset CSV files"
# Setup
# Write-Host "Populating ESX list..."
# Populate_ESX
Write-Host "Retriving data..."
Body
Write-Host "Script execution completed!"
