#!/bin/bash
# 
# Edited : 2017.11.12 08:05 by hualf.
# Usage  : Used to configure firewall by 'iptables'.

iptables -F
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT

iptables -I INPUT -i ens3 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

iptables -A INPUT -i ens3 -s 192.168.0.0/24 -p icmp -j ACCEPT
iptables -A INPUT -i ens3 -s 192.168.0.0/24 -p tcp --dport 22 -j ACCEPT

# web service
iptables -A INPUT -i ens3 -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -i ens3 -p tcp --dport 8080 -j ACCEPT

# dns service and keepalived(vrrp)
iptables -A INPUT -i ens3 -p udp --sport 53 -j ACCEPT
iptables -A INPUT -i ens3 -p vrrp -j ACCEPT

service iptables save
