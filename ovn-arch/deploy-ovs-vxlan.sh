#!/bin/bash
# -------------------------------------------
# Name    : deploy_ovs_vxlan_master.sh
# Function: deploy Open vSwitch vxlan tunnel
# Author  : Longfei Hua
# Modified: 2018-05-10
# -------------------------------------------

# Check current os kernel version
echo "--> Check current os kernel version"
echo "    * `uname -r`"

# Load openvswitch kernel module and activate OVS
echo "--> Check openvswitch module status"
lsmod | grep openvswitch
if [ $? -eq 0 ]; then
  echo "    * Open vSwitch has been loaded ..."
else
  echo "    * Open vSwitch hasn't been loaded, so LOADING it ..."
  modprobe openvswitch
  systemctl start ovsdb-server.service
  systemctl start ovs-vswitchd.service

  # `ovsdb-server' must be loaded first, then load `ovs-vswitchd'.
  # Only when all previous service have been loaded, OVS bridge managed by
  # Open vSwitch can be shown using `ip address show'.
fi

# Delete previous OVS bridge
echo "--> Delete existed OVS bridge"
ip link show ovs-br0 && ovs-vsctl del-br ovs-br0 &>/dev/null
ip link show ovs-br1 && ovs-vsctl del-br ovs-br1 &>/dev/null

# Deploy new OVS bridge
echo "--> Deploy new OVS bridge"
ovs-vsctl add-br ovs-br0 && ip link set ovs-br0 up
ovs-vsctl add-br ovs-br1 && ip link set ovs-br1 up

# Check current network and deploy OVS vxlan
echo "--> Specified NIC and deploy OVS vxlan"

for GATEWAY in 172.31.216.1 10.197.11.191; do
  # banmcomm gateway: 172.31.216.1; home gateway: 10.197.11.191
  ping -c 5 ${GATEWAY} > /dev/null
  if [ $? -eq 0 ]; then
    if [ ${GATEWAY} == "172.31.216.1" ]; then 
      echo "    * Current gateway is ${GATEWAY}"
      NIC="eth1"
      ip address flush dev ${NIC}
      ovs-vsctl add-port ovs-br0 ${NIC}
      ip address add 172.31.218.46/16 dev ovs-br0
      # Type of port `eth1' is `Normal', which can't be configured ip address.
      ip route add default via ${GATEWAY} dev ovs-br0
      ovs-vsctl add-port ovs-br1 tun0 -- set Interface tun0 type=vxlan options:remote_ip=172.31.218.47

      # Deploy virtual port `tun0' for vxlan, please pay attention to the format of vxlan message.
      # You can use `tcpdump -i eth1' to dump data packages to verify VXLAN.
      # Packages from 10.0.1.3 will be packaged attched 172.31.218.47 ip header.

      ip address add 10.0.1.3/24 dev ovs-br1
      ovs-vsctl show
      echo "--> Deploy complete"
      
    elif [ ${GATEWAY} == "10.197.11.191" ]; then
      echo "    * Current gateway is ${GATEWAY}"
      NIC="eth0"
      ip address flush dev ${NIC}
      ovs-vsctl add-port ovs-br0 ${NIC}
      ip address add 10.197.11.208/24 dev ovs-br0
      ip route add default via ${GATEWAY} dev ovs-br0
      ovs-vsctl add-port ovs-br1 tun0 -- set Interface tun0 type=vxlan options:remote_ip=10.197.11.201
      ip address add 10.0.1.3/24 dev ovs-br1
      ovs-vsctl show
      echo "--> Deploy complete"
    fi
  fi
done
