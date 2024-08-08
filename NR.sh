#!/bin/bash

#nipe installation folder path
nipe_path="/home/$USER/Desktop/nipe"

#check if the required packages are installed or not
#check geoip-bin is installed or not and install it if not installed
if ! command -v geoiplookup &> /dev/null; then
	echo "[*] geoip-bin is not installed. Installing..."
	sudo apt-get update -q -y
	sudo apt-get upgrade -q -y
	sudo apt-get install -y geoip-bin
	sleep 1
else
	echo "[#] geoip-bin is already installed."
	sleep 1
fi

#check tor is installed or not and install it if not installed
if ! command -v tor &> /dev/null; then
	echo "[*] tor is not installed. Installing..."
	sudo apt-get install -y tor
	sleep 1
else
	echo "[#] tor is already installed."
	sleep 1
fi

#check sshpass is installed or not and install it if not installed
if ! command -v sshpass &> /dev/null; then
	echo "[*] sshpass is not installed. Installing..."
	sudo apt-get install -y sshpass
	sleep 1
else
	echo "[#] sshpass is already installed."
	sleep 1
fi

#check nipe is installed or not and install it if not installed
#check nipe folder exists
if [ ! -d "$nipe_path" ]; then
	echo "[*] nipe is not installed. Installing..."
	installation_folder="/home/$USER/Desktop"
	cd "$installation_folder"
	git clone https://github.com/htrgouvea/nipe && cd nipe
	sudo apt-get install -y cpanminus
	cpanm --installdeps .
	sudo cpan install Switch JSON LWP::UserAgent Config::Simple
	sudo perl nipe.pl install
	sudo perl nipe.pl restart
	sudo perl nipe.pl start
else
	echo "[#] nipe is already installed."
	cd $nipe_path
	sudo perl nipe.pl restart
	sudo perl nipe.pl start
fi

#check if the nipe service is started or not
status_nipe=$(sudo perl nipe.pl status)

#check true is present in the status of nipe service or not, if not present then exit
if [[ $status_nipe == *"true"* ]]; then
    echo "[*] You are anonymous .. Connecting to the remote server."
else
    echo "[*] You are not anonymous .. exiting"
    exit 1
fi
echo " "

#get the spoofed ip address and country
spoofed_ip=$(curl -s ifconfig.io)
country=$(geoiplookup "$spoofed_ip" | cut -d, -f 2)

echo "[*] Your spoofed IP address is: $spoofed_ip , Spoofed country: $country"

#get the ip address of the ssh server
read -p "[?] Specify a Domain/IP address to scan: " domain_ip 
echo " "
#get the server details from the user
ipaddress="$domain_ip"
#get the username of the ssh server
read -p "Please enter the username of the SSH server: "  username
#get the password of the ssh server
read -s -p "Please enter the password of the SSH server: "  password
echo " "

echo -e "[*] Connecting to Remote server:"

#check vsftpd is installed or not and install it if not installed
if ! command -v vsftpd &> /dev/null; then
    echo "[*] vsftpd is not installed on the remote system. Installing..."
    sudo apt-get install -y vsftpd
    sshpass -p "$password" ssh -t "$username@$ipaddress" -q && sudo service vsftpd start
    sleep 1
else
    echo "[#] vsftpd is already installed on the remote system."
    sleep 1
fi
echo " "

#run the uptime command on the remote server
#print the ip address and country of the remote server
sshpass -p "$password" ssh -t "$username@$ipaddress" -q '
echo "Uptime:" && uptime
echo "Ip address: $(curl -s ifconfig.io)"
echo "Country: $(geoiplookup $(curl -s ifconfig.io) | cut -d, -f 2)"
'
echo " "

#create a file name for whois scan
file_name_whois="~/whois_$domain_ip"

#create a file name for nmap scan
file_name_nmap="~/nmap_$domain_ip"

#execute nmap and whois commands on a random domain/ip address like
#run whois scan and save the output
echo "[*] Whoising victim's address: "
sshpass -p "$password" ssh -t "$username@$ipaddress" -q "
whois $domain_ip > $file_name_whois "
echo "[@] Whois data was saved into $file_name_whois"
echo " "

#run nmap scan and save the output
echo "[*] Scanning victim's address: "
sshpass -p "$password" ssh -t "$username@$ipaddress" -q "
nmap $domain_ip > $file_name_nmap "
echo "[@] Nmap scan was saved into $file_name_nmap"
echo " "

#copy data from remote to local
ftp -n <<EOF
open $ipaddress
user $username $password
get /home/$username/whois_$domain_ip ./whois_$domain_ip
bye
EOF

ftp -n <<EOF
open $ipaddress
user $username $password
get /home/$username/nmap_$domain_ip ./nmap_$domain_ip
bye
EOF

#create log
echo "$(date)- [*] whois data collected for: $domain_ip" >> /home/kali/Desktop/nr.log
echo "$(date)- [*] Nmap data collected for: $domain_ip" >> /home/kali/Desktop/nr.log

cat /home/kali/Desktop/nr.log
