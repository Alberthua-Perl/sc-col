#!/bin/bash

#  Deploy Linux native VXLAN tunnel.
#  Linux kernel version should be >= 3.7.x to support vxlan.
#
#  This script implements one NIC to test communication 
#  through vxlan tunnel like vms between different nodes.
#  veth0 of veth pair could be used as one NIC in vm.
#
#  You should run this script on two different nodes to 
#  deploy vxlan tunnel through replace ip address.
#  
#  Created on 2020-10-10 by hualf (lhua@redhat.com).

### Modify variables if deploy vxlan in different environment.
BRIDGE=br0
#BRIDGE_IP=192.169.0.6
#BRIDGE_PREFIX=24
VNI=100
NIC=eth1
VETH_IP=192.167.0.6
VETH_PREFIX=24

function deploy_native_vxlan_tunnel() {
  echo -e "[\033[1;32m*\033[0m] Create linux bridge to attach link device ..."
  sudo brctl addbr ${BRIDGE}
  sudo ip link set ${BRIDGE} up
  #sudo ip address add ${BRIDGE_IP}/${BRIDGE_PREFIX} dev ${BRIDGE}
  # Linux bridge could be just as ethernet link device to forward packets without address.
  
  echo -e "[\033[1;32m*\033[0m] Create vxlan interface through multicast group ..."
  sudo ip link add vxlan${VNI} type vxlan id ${VNI} group 239.1.1.1 dstport 4789 dev ${NIC}
  # NIC as VTEP device to forward final packets to another VTEP device.
  sudo ip link set vxlan${VNI} up
  sudo brctl addif ${BRIDGE} vxlan${VNI}
  # vxlan interface as link device to attach linux bridge
 
  echo -e "[\033[1;32m*\033[0m] Create veth pair to implement one NIC like vm ..."
  sudo ip link add type veth
  sudo ip link set veth0 mtu 1450
  # Packets will be add 50 bytes vxlan header through vxlan interface.
  # So mtu of veth0 should be set 1450. 
  sudo ip link set veth0 up
  sudo ip address add ${VETH_IP}/${VETH_PREFIX} dev veth0
  sudo ip link set veth1 mtu 1450
  sudo ip link set veth1 up
  sudo brctl addif ${BRIDGE} veth1
  # attach veth1 of veth pair to linux bridge
  echo -e "\n[\033[1;32m*\033[0m] Link device and address showed as follows ..."
  sudo ip address show
  echo -e "\n[\033[1;32m*\033[0m] Route table as follows ..."
  sudo ip route show
  echo -e "[\033[1;32m*\033[0m] Deploy complete ..."
}

function destroy_vxlan_tunnel() {
  echo -e "[\033[1;32m*\033[0m] Destroy vxlan tunnel ..."
  sudo ip link set veth0 down 
  sudo ip link set veth1 down
  sudo ip link del veth0
  # veth pair will be deleted together.
  sudo ip link set vxlan${VNI} down
  sudo ip link del vxlan${VNI}
  sudo ip link set ${BRIDGE} down
  sudo ip link del ${BRIDGE}
}

deploy_native_vxlan_tunnel
#destroy_vxlan_tunnel
