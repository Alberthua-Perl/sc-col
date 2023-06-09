#!/bin/bash
#
#  Deploy Open Virtual Network host node.
#
#   - Author: lhua@redhat.com
#   - Date: 2020-04-08
#
#  Please replace variable `OVN_CENTRAL_IP' and `OVN_ENCAP_IP'
#  when host ip changed.
#

# Define OVN variables.
OVN_CENTRAL_IP=172.25.250.187
OVN_ENCAP_IP=172.25.250.188
OVN_SB_DB_PORT=6642

# Install OVS and OVN packages.
echo "--- Install OVS and OVN packages ---"
sudo yum install -y openvswitch openvswitch-ovn-host
sudo yum install -y libibverbs

# Enable and start OVS or OVN service.
echo "--- Enable and start OVS and OVN service ---"
sudo systemctl enable ovsdb-server ovs-vswitchd openvswitch	ovn-controller
sudo systemctl start ovsdb-server ovs-vswitchd openvswitch ovn-controller

# Verify OVS and OVN service status.
echo "--- Checking OVS and OVN service status ---"
for SRV in ovsdb-server ovs-vswitchd openvswitch ovn-controller; do
  STATUS=$(sudo systemctl is-active ${SRV})
  if [ ${STATUS} = "active" ]; then
    echo " * ${SRV}: running ACTIVE ..."
  else
    echo " * ${SRV}: running ERROR ..."
  fi
done

# Set remote OVN chassis controller.
echo "--- Set remote OVN chassis controller ---"
sudo ovs-vsctl set Open_vSwitch . external-ids:ovn-remote=tcp:${OVN_CENTRAL_IP}:${OVN_SB_DB_PORT}
sudo ovs-vsctl set Open_vSwitch . external-ids:ovn-encap-type=geneve
sudo ovs-vsctl set Open_vSwitch . external-ids:ovn-encap-ip=${OVN_ENCAP_IP}
sudo ovs-vsctl list Open_vSwitch
sudo netstat -antp | grep ovn-controller

# Verify OVS bridge and port.
echo "--- Verify OVS bridge and port ---"
sudo ovs-vsctl show

