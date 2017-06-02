Powershell Sources: https://github.com/PowerShell/PowerShell
VM PowerCLI Sources: https://labs.vmware.com/flings/powercli-core
Building Curl RPM: http://seccentral.blogspot.my/2017/01/building-curl-7521-rpms-on-centos-6-and.html
Other ref: 1) http://www.opentechshed.com/powercli-core-on-centos-7
           2) http://serverfault.com/questions/77122/rhel5-forbid-installation-of-i386-packages-on-64-bit-systems
           3) http://www.virtuallyghetto.com/2017/01/how-to-install-powercli-core-on-debian-linux.html
           4) http://www.virtuallyghetto.com/2016/09/vmware-powercli-for-mac-os-x-linux-more-yes-please.html
           5) https://github.com/PowerShell/PowerShell/blob/master/docs/installation/linux.md#centos-7
++++++++++++++++++++++
CentOS 7

1) ---Yum Repo Method---
	$ sudo curl https://packages.microsoft.com/config/rhel/7/prod.repo > /etc/yum.repos.d/microsoft.repo
	$ sudo yum install -y powershell

2) ---Manual RPM Method---
	Using CentOS 7, download the RPM package powershell-6.0.0_alpha.15-1.el7.centos.x86_64.rpm from the releases page onto the CentOS machine.

	Then execute the following in the terminal:
	#sudo yum install ./powershell-6.0.0_alpha.15-1.el7.centos.x86_64.rpm

	You can also install the RPM without the intermediate step of downloading it:
	# sudo yum install https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-alpha.15/powershell-6.0.0_alpha.15-1.el7.centos.x86_64.rpm

	This package works on Oracle Linux 7. It should work on Red Hat Enterprise Linux 7 too.

Uninstallation:
sudo yum remove powershell
++++++++++++++++++++++

1. vi /etc/yum.conf
 add
 |-> multilib_policy=best
 '-> exclude=*.i?86
2. yum -y localinstall curl-7.52.1-1.x86_64.rpm curl-debuginfo-7.52.1-1.x86_64.rpm libcurl-7.52.1-1.x86_64.rpm libcurl-devel-7.52.1-1.x86_64.rpm

3. Verify that the curl version is built with OpenSSL
	# /usr/local/bin/curl --version
 	curl 7.52.1 (x86_64-pc-linux-gnu) libcurl/7.52.1 OpenSSL/1.0.1e

4. Create the following directory if it does not exist by running the following command:
	# mkdir -p ~/.local/share/powershell/Modules

5. Download the powershell and unzip
	# unzip PowerCLI_Core.zip -d ~/.local/share/powershell/Modules/
	# cd ~/.local/share/powershell/Modules
	# unzip PowerCLI.ViCore.zip
	# PowerCLI.Vds.zip
==============================
OR

1. vi /etc/yum.conf
 add
 |-> multilib_policy=best
 '-> exclude=*.i?86
2. yum -y localinstall curl-7.52.1-1.x86_64.rpm curl-debuginfo-7.52.1-1.x86_64.rpm libcurl-7.52.1-1.x86_64.rpm libcurl-devel-7.52.1-1.x86_64.rpm

3. cd ~/ && tar -xzvf powershell.tar.gz

4. powershell
==============================
Launch PowerCLI

Step 1 - Open terminal
Step 2 - Start Powershell in the terminal by running the following command:
	powershell
Step 3 - Import the PowerCLI Modules into your PowerShell Session:
	Get-Module -ListAvailable PowerCLI* | Import-Module

Step 3a - (Optional - Please Read) If the SSL certificates of your vCenter are not trusted by your OS, disable SSL certificate validation for PowerCLI by running:
	Set-PowerCLIConfiguration -InvalidCertificateAction Ignore

Step 4 - Connect to your vCenter Server using Connect-VIServer
	PS> Connect-VIServer -Server 192.168.1.51 -User administrator@vSphere.local -Password VMware1! 

xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

List the contents of a tar.gz file
Use the following command:
$ tar -ztvf file.tar.gz


