#!/bin/bash
#C2_shell is a C2 automated-deployer for red-team/researching operations.
#Some options could be commented. Others are just explainations. Modify the file as needed
#Tools will be added in future from original repositories.

#global vars
me=$(whoami)
procinfo=$(cat /proc/cpuinfo)
meminfo=$(cat /proc/meminfo)
ver=$(uname -a | grep -io "x86_64")
iface=$(netstat -i | awk {'print$1'} | grep eth)
if [ "$iface" = "" ]; then
	iface=$(netstat -i | awk {'print$1'} | grep ens)
fi

function main_config()
{
	#changing user settings
	read -p "Do you want to change root password?[y/n]: " supass
	if [ "$supass" = "y" ]; then
		passwd root
	fi
	read -p "Do you want to create an user?(y/n): " user
	if [ "$user" = "y" ] || [ "$user" = "Y" ]; then
		adduser operator$RANDOM
		usermod -aG sudo operator$RANDOM
		echo "[+] User operator created!$RANDOM"
	else 
		echo "no user created!"
	fi
}

function c2_setup()
{
	printf "[+]C2 setups available.\n1)Red Team C2(standard setup + tools)\n2)Kraken Server(standard setup + hashcat)\n3)Network C2 for passive pourposes(minimum installation for instances)\n4)Full setup(installs everything)\n"
	read -p "Choose C2 setup option(1/2/3/4/5 for exit): " opt
	case $opt in
	1) red_tools
		;;
	2) crack
		;;
	3) echo "skipped..."
		;;
	4) red_tools; crack
		;;
	*) exit 1 
		;;
	esac
}
function chkerr() 
{
	if [ $? -ne 0 ]; then
		printf "An error has ocurred!"
		exit 2
	fi
}

function update ()
{
	apt-get -y update && apt-get -y upgrade
	apt autoremove -y && apt-get autoclean -y
}

function sshd_setup()
{
	read -p "Set SSH port(default 22): " sshport
	if [ "$sshport" = "" ]; then
		sshport=22
	fi
	echo "#ssh access port">>$HOME/cfg_samples/sshd_config
	echo "Port $sshport">>$HOME/cfg_samples/sshd_config
	printf "[+]SSH access listening mode\n"
	read -p "Listen IPv4. Default yes(y/n): " ssh4
	if [ "$ssh4" = "" ] || [ "$ssh4" = "y" ]; then
		echo "ListenAddress 0.0.0.0">>$HOME/cfg_samples/sshd_config
	else
		echo "#ListenAddress 0.0.0.0">>$HOME/cfg_samples/sshd_config
	fi
	read -p "Listen IPv6. Default yes(y/n): " ssh4
	if [ "$ssh6" = "" ] || [ "$ssh6" = "y" ]; then
		echo "ListenAddress ::">>$HOME/cfg_samples/sshd_config
	else
		echo "#ListenAddress ::">>$HOME/cfg_samples/sshd_config
	fi
	cp /etc/ssh/sshd_config /etc/ssh/sshd_config_bak
	printf "[+] Default sshd config file has a backup in ssh directory\n"
	mv cfg_samples/sshd_config /etc/ssh/sshd_config
	printf "[+] Config has been replaces succesfully\n"
	sleep 1
	rm /etc/ssh/ssh_host*
	ssh-keygen -N '' -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key
	ssh-keygen -N '' -t ed25519 -b 256 -f /etc/ssh/ssh_host_ed25519_key
	printf "[+] New directories created at HOME directory. Named .backups/ .backups/sshkeys/ .firewalling/ /opt/tools\n"
	printf "[+] New SSH generated keys are"
	printf "[!] This keys are for ssh access. Recomendation: put a decent password for your private key ffs\n"
	ssh-keygen -t rsa -b 4096 -f $HOME/.backups/sshkeys/mysshkeypar 
	##moving key to gain access with pub auth
	cp $HOME/.backups/sshkeys/mysshkeypar.pub $HOME/.ssh_access_keys/
	printf "[+] Public key ready for authentication\n"
}

function red_tools()
{
	printf "[*] Installing offensive tools in /opt/tools\n"
	git clone https://github.com/trustedsec/unicorn /opt/tools/unicorn
	git clone https://github.com/PowerShellMafia/PowerSploit /opt/powersploit
	git clone https://github.com/EmpireProject/Empire /opt/tools/Empire
	update
	cd /opt/tools/Empire/setup && ./install.sh
	printf "[+] Unicorn, PowerSploit, Empire installed\n"
	sleep 1
	chkerr
	git clone https://github.com/trustedsec/ptf /opt/trustedsecf
	cd /opt/trustedsecf
	chkerr
	git clone https://github.com/sqlmapproject/sqlmap /opt/sqlmap
	printf "[+] sqlmap has been installed\n"
	apt-get -y install nikto
	apt-get -y install dnsutils
	apt-get -y install whois
	add-apt-repository ppa:pi-rho/security
	update
	apt-get -y install whatweb
	apt-get -y install nmap
	apt-get -y install masscan
	apt-get -y install vim
	git clone git://github.com/fwaeytens/dnsenum
}

function crack()
{
	printf "[+] Current server specs and memory available\n"
	echo $procinfo && echo $meminfo
	echo "[+] Hashcat is available"
	read -p "Consider your server resources in order to use hashcat properly. Do you want to add it?(y/n): " hc
	if [ "$hc" = "y" ] || [ "$hc" = "Y" ]; then
		apt-get install p7zip -y &>/dev/null
		wget https://hashcat.net/files/hashcat-4.2.0.7z 
		p7zip -d hashcat-4.2.0.7z
		mkdir /opt/hashcat-4.2.0
		mv hashcat-4.2.0/* /opt/hashcat-4.2.0/
		rmdir hashcat-4.2.0
		if [ "$ver" = "x86_64" ]; then
			cp /opt/hashcat-4.2.0/hashcat64.bin /usr/bin
			ln -s /usr/bin/hashcat64.bin /usr/bin/hashcat
		else
			cp /opt/hashcat-4.2.0/hashcat32.bin /usr/bin
			ln -s /usr/bin/hashcat32.bin /usr/bin/hashcat
		fi
		printf "[+] Hashcat has been installed sucessfully"
		sleep 1
	fi
}

function fw_launcher()
{
	printf "[*][Firewall Option (1):: Every host can reach ssh port]\n[*][Firewall Option (2):: Every host can reach ssh port + webserver. No one can access your database.]\n[*][Firewall Option (3):: Only selected hosts can reach the server]\n"
	read -p "Select firewalling option: " fw
	echo "#!/bin/sh"> /$HOME/.firewalling/firewall.sh
	echo "iptables -F" >> /$HOME/.firewalling/firewall.sh
	echo "iptables -X">>/$HOME/.firewalling/firewall.sh
	echo "iptables -Z">>/$HOME/.firewalling/firewall.sh
	echo "iptables -t nat -F">>/$HOME/.firewalling/firewall.sh
	echo "iptables -P INPUT ACCEPT">>/$HOME/.firewalling/firewall.sh
	echo "iptables -P OUTPUT ACCEPT">>/$HOME/.firewalling/firewall.sh
	echo "iptables -P FORWARD ACCEPT">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp --dport $sshport -j ACCEPT">>/$HOME/.firewalling/firewall.sh
	echo "iptables -N SSHATTACK">>/$HOME/.firewalling/firewall.sh
	echo 'iptables -A SSHATTACK -j LOG --log-prefix "Possible ssh-attack!!" --log-level 7'>>/$HOME/.firewalling/firewall.sh
	echo "iptables -A SSHATTACK -j DROP">>/$HOME/.firewalling/firewall.sh
	if [ $fw -eq 2 ]; then  
		echo "iptables -A INPUT -i $iface -p tcp --dport 80 -j ACCEP"T>>/$HOME/.firewalling/firewall.sh
		echo "iptables -A INPUT -i $iface -p tcp --dport 443 -j ACCEPT">>/$HOME/.firewalling/firewall.sh
	elif [ $fw -eq 3 ]; then
		read -p "Set host" auth_host
		echo "iptables -A INPUT -i $iface -s $auth_host -p tcp --dport $sshport -j ACCEPT">>/$HOME/.firewalling/firewall.sh
		echo "iptables -A INPUT -i $iface -s $auth_host -p udp --dport $sshport -j ACCEPT">>/$HOME/.firewalling/firewall.sh
	elif [ $fw -eq 1 ]; then
		echo "iptables -A INPUT -i $iface -p tcp -m state --dport $sshport --state NEW -m recent --set">>/$HOME/.firewalling/firewall.sh
		echo "iptables -A INPUT -i $iface -p tcp -m state --dport $sshport --state NEW -m recent --update --seconds 600 -hitcount 3 -j SSHATTACK" >>/$HOME/.firewalling/firewall.sh
	fi
	#Anti-scan firewall rules
	echo "iptables -A INPUT -i $iface -p tcp --tcp-flags ACK ACK -m state --state NEW -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp --tcp-flags RST RST -m state --state NEW -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp --tcp-flags PSH PSH -m state --state NEW -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp --tcp-flags FIN FIN -m state --state INVALID -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp --tcp-flags FIN,PSH,URG FIN,PSH,URG -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp --tcp-flags ALL ACK,RST,SYN,FIN -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp --tcp-flags SYN,RST SYN,RST -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp --tcp-flags ALL NONE -j DROP">>/$HOME/.firewalling/firewall.sh
	#Filtering request/DoS
	echo "iptables -A INPUT -i $iface -p tcp --syn -m recent --set ">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp --syn -m recent --update --seconds 5 --hitcount 20 -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i eth0 -p icmp -m icmp --icmp-type 8 -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i eth0 -p icmp --icmp-type echo-request -m hashlimit --hashlimit-name ping --hashlimit-above 1/s --hashlimit-burst 2 --hashlimit-mode srcip -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp -s 0.0.0.0/0 --dport 1:1024 -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p udp -s 0.0.0.0/0 --dport 1:1024 -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp -s 0.0.0.0/0 --dport 1025:13371 -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p udp -s 0.0.0.0/0 --dport 1025:13371 -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p tcp -s 0.0.0.0/0 --dport 13373:65535 -j DROP">>/$HOME/.firewalling/firewall.sh
	echo "iptables -A INPUT -i $iface -p udp -s 0.0.0.0/0 --dport 13373:65535 -j DROP">>/$HOME/.firewalling/firewall.sh
	chmod 755 $HOME/.firewalling/firewall.sh
	iptables-save
	iptables-save>/etc/iptables.rules
	iptables-save>/root/.firewalling/iptables.rules
	echo "[+] Firewall up and running. There's some copies of the rules in /etc/iptables.rules & in /root/.firewall/iptables.rules"
	sleep 1
	apt-get -y install iptables-persistent
	echo "[+] persistent rules activated"
}

function finish() 
{
	printf "Script completed. ~ Happy Hacking ~ \n"
	echo ""
	exit
}

###beginning of the script
reset
if [ "$EUID" -ne 0 ]; then 
	echo "[!] Please run this script with sudo"
  	exit 1
fi
printf "Starting...\n"
printf " [*] C2Shell - C&C automated deployment for Red Team Ops v1.0 by Sapphire [*]\n"
printf "[+] ADVICE: Grab a coffee while the script deploys!\n"
sleep 1
cat banner
printf "[+] Updating the system\n"
apt-get -y update &>/dev/null
chkerr
#update
c2_setup
echo "[+] Stage 1 completed. Update-upgrade done"
##Access Hardening and user configurations
##feel free to replace elements that may fit into your system
if [ ! -d $HOME/.ssh ]; then
	mkdir $HOME/.ssh
fi
##creating useful directories
main_config
mkdir $HOME/.backups $HOME/.backups/sshkeys $HOME/.firewalling /opt/tools $HOME/.ssh_access_keys
##delete old lowgrade keys and creating new ones
sshd_setup
echo "[+] Backup and keys directories done. ssh-keys refreshed and upgraded. C2 --> 30%"
sleep 1
##installing web-server and aplication managers
printf "[+] Installing repos and frameworks..."
apt -y install python-pip
pip install --user requests
apt -y install -U pip
apt-get -y install git
read -p "[+] LAMPP is available. Do you want to install Apache+MySQL+php7?(y/n): " lamp
if [ "$lamp" = "y" ] || [ "$lamp" = "Y" ]; then
	apt-get -y install apache2 libapache2-mod-php php mysql-server php-mysql
fi
chkerr
printf "[+] LAMPP + git + python pip loaded"
chkerr
update
##installing anon-services
echo "[+] Installing anonimization services and more tools. C2 70%"
apt-get -y install proxychains
printf "#tor repositories\n" >> /etc/apt/sources.list
##the tor version may differ since the release of the script, or depending on the server version(Ubuntu/Debian/CentOS/RedHat..)
version=$(cat /etc/lsb-release | grep -i xenial)
if [ "$version" != "" ]; then
	echo "deb https://deb.torproject.org/torproject.org xenial main">> /etc/apt/sources.list
	echo "deb-src https://deb.torproject.org/torproject.org xenial main">> /etc/apt/sources.list
fi
version=$(cat /etc/lsb-release | grep -i bioiface)
if [ "$version" != "" ]; then
	echo "deb https://deb.torproject.org/torproject.org bioiface main">> /etc/apt/sources.list
	echo "deb-src https://deb.torproject.org/torproject.org bioiface main">> /etc/apt/sources.list
fi
version=$(cat /etc/lsb-release | grep -i stretch)
if [ "$version" != "" ]; then
	echo "deb https://deb.torproject.org/torproject.org stretch main">> /etc/apt/sources.list
	echo "deb-src https://deb.torproject.org/torproject.org stretch main">> /etc/apt/sources.list
fi
apt install apt-transport-https -y
apt install gnupg2 -y
gpg2 --recv A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89
gpg2 --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -
apt update
apt -y install tor deb.torproject.org-keyring
printf "[+] Tor has been installed sucessfully. SOCKS listener ready on 9050\n"
chkerr
##Tunneling
read -p "[+] VPN server is available. Do you want to download it?(y/n): " vpn 
if [ "$vpn" = "y" ] || [ "$vpn" = "Y" ]; then
	apt-get -y install easy-rsa
	apt-get -y install openvpn
else
	printf "[-] vpn won't be installed"
fi
update
##firewalling
echo "[+] Shielding C2 Server. C2 --> 85%"
fw_launcher
printf "[!] There are some tools for blue team like rk-hunter and lynis available\n"
read -p 'Do you want to install blue team security tools?(rkhunter + chkrootkit + Lynis)(y/n): ' blueteam
if [ "$blueteam" = "y" ] || [ "$blueteam" = "Y" ]; then
	##installing anti-rootkits. Optional
	apt-get -y install rkhunter
	apt-get -y chkrootkit
	apt-get -y install lynis
	printf "[+] Security tools installed sucessfully\n"
fi
printf "Rememeber to grab your ssh access key. Location -> $HOME/.backups/sshkeys/mysshkeypar\n"
sleep 1
echo "[+] 100% Reached C&C ready to rock ;)"
finish
