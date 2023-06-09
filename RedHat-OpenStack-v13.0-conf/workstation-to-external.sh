#!/bin/bash
#
# Configure workstation node to internet in cl210 rhosp 13.0 course.
# Modified by hualf on 2022-04-18.
#

ssh root@foundation0 '
  iptables -t nat -A POSTROUTING -s 172.25.254.0/24 -j SNAT --to-source 192.168.110.140 &&
  route add -net default gw 192.168.110.1 dev ens38'
# add snat rule and default route rule to internet
# replace 192.168.110.140 and 192.168.110.1 to your ip address to access internet 

ssh root@classroom '
	route add -net default gw 172.25.254.250 dev eth0 &&
	iptables -t nat -A POSTROUTING -s 172.25.252.0/24 -j SNAT --to-source 172.25.254.254'
# configure classroom node as gateway for workstation node

ssh root@workstation '
	route add -net default gw 172.25.252.254 dev eth1'
# configure default gateway to classroom node

