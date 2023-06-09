#!/bin/bash
#
# Function: create basic samba server automaticlly
# Author  : hualongfeiyyy@163.com
# Create  : 2017-05-14 00:10 release 1.0
# Modified: 2019-02-10 11:10 release 1.1
#

SAMBA_LOG="/tmp/samba_status.$(date +'%Y-%m-%d').log"
SAMBA_NET="10.197.11.0/24"

## Install samba packages for RHEL 7.x/CentOS 7.x
echo "---> Installing samba packages ..."
yum -y install samba* >> ${SAMBA_LOG} 
systemctl enable smb nmb >> ${SAMBA_LOG}
systemctl status smb nmb >> ${SAMBA_LOG} 

## Create samba directory
[[ -e /mnt/public ]] || mkdir /mnt/public
## Configure selinux policy for samba directory
# chcon -t samba_share_t /mnt/public		
## List the selinux content of /mnt/public
# ls -ldZ /mnt/public

## Create share group for samba
## Other samba users could be add into share group.
echo ""
groupadd winshare >> ${SAMBA_LOG}
echo ""

## Specified samba user
read -p "--> Please specify samba user: " SMBUSER
if `id ${SMBUSER} > /dev/null 2>&1`; then
  usermod -aG winshare ${SMBUSER}
  smbpasswd -a ${SMBUSER}
else	
  useradd ${SMBUSER}; echo "redhat" | passwd --stdin ${SMBUSER}
  usermod -aG winshare ${SMBUSER}
  smbpasswd -a ${SMBUSER}
fi
echo -e "\n---> The samba users are: \n$(pdbedit -L)\n"

## Configure the samba configure file: /etc/samba/smb.conf
echo -e "\n[public]\npath = /mnt/public\nhosts allow = ${SAMBA_NET}\nbrowseable = yes\nwrite list = ${SMBUSER},@winshare" >> /etc/samba/smb.conf

## Configure acl for samba directory
setfacl -m u:${SMBUSER}:rwx /mnt/public >> ${SAMBA_LOG}
setfacl -m g:winshare:rwx /mnt/public >> ${SAMBA_LOG}
DIR_PERMISSION=$(getfacl /mnt/public)
echo -e "\n---> The dir /mnt/public permission is: \n${DIR_PERMISSION}\n"

## Restart samba service
systemctl restart smb nmb >> ${SAMBA_LOG}
systemctl status smb nmb
# firewall-cmd --permanent --add-service=samba > /dev/null
# firewall-cmd --permanent --add-service=mountd > /dev/null
# firewall-cmd --reload > /dev/null

