#!/bin/bash
#
# Use nmcli setup linux networking through NetworkManager, as followings:
# 	- ethernet connection
# 	- linux bridge
# 
# Modified by hualf on 2022-04-29
# 

### config linux bridge ###
if [[ $# -eq 0 ]]; then
	echo "---> Few new arguements... exit..."
	exit 2
fi
nmcli connection add type bridge con-name "System bridge0" ifname bridge0
nmcli connection add type ethernet slave-type bridge con-name "System bridge-port1" ifname ens160 master bridge0
nmcli connection modify "System bridge0" \
	ipv4.addresses 192.168.110.11/24 ipv4.gateway 192.168.110.1 ipv4.dns "192.168.110.1 8.8.8.8" ipv4.method manual
nmcli connection reload
nmcli connection down "System bridge0"
nmcli connection up "System bridge0"
# Note:
# 	$ nmcli -f NAME,UUID,TYPE,DEVICE,FILENAME connection show
# 	# verify nm-connection config file location	

