#!/bin/bash
# ----------------------------------------------------
# Name: deploy_linuxbridge_vlan.sh 
# Function: config linux vlan through linux bridge
# Date: 2018-04-06 21:45
# Author: hualf
# ----------------------------------------------------

# IEEE 802.1q supports VLAN, so 8021q module must be loaded. 
modprobe 8021q
lsmod | grep -i 8021q

# Add vlan virtual interfaces of eth0 called `eth0.10' and `eth0.20'.
# So two vlans have been created: VLAN 10, VLAN20.
# eth0 interface acts as `L2 VLAN switch' which can't be configured ip address and netmask.
ip link set eth0 up
ip address flush dev eth0
# delete any ip address
vconfig add eth0 10
vconfig add eth0 20
## cat /proc/net/vlan/config

# Create linux bridge and add vlan virtual interfaces on linux bridge.
# eth1 interface could link upstream vlan switch to receive frames acting as `access port'.
brctl addbr brvlan10
brctl addbr brvlan20
brctl addif brvlan10 eth0.10
brctl addif brvlan20 eth0.20
brctl addif brvlan10 eth1
# If you want to delete linux bridge, you must run following steps:
#   ip link set brX down
#	  rm -f /etc/sysconfig/network-scripts/ifcfg-brX
#   brctl delif brX <INTERFACE>
#   brctl delbr brX

# Configure ip address for linux bridge
ifconfig brvlan10 192.168.0.254/24 up
ifconfig brvlan20 192.168.1.254/24 up
