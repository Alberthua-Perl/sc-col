#!/bin/bash
#
# Run script on servera or serverb to recover GRUB2 boot kernel menu on RHEL9.
# Copy right by lhua@redhat.com
#
# Though the script used in RH199v9.0 course environment, most steps could be used
# to recover kernel boot menu which is not existing. Without kernel boot menu, system
# will be booted directly using default kernel, so we can NOT select kernel.
# 

#------------------------------------------------------------------------------
### fix /etc/hosts
echo "---> Fix /etc/hosts ..."
# After changing course between rh199 and rh294, /etc/hosts could be reset,
# if the file has been reset, dnf repository can't be access. So fix it.
sh -c ">/etc/hosts"
cat > /etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

172.25.254.250  foundation0.ilt.example.com  foundation0
172.25.254.254  classroom.example.com  classroom
172.25.254.254  content.example.com  content
172.25.250.254  bastion.lab.example.com bastion

172.25.250.9    workstation.lab.example.com workstation
172.25.250.10   servera.lab.example.com servera
172.25.250.11   serverb.lab.example.com serverb
172.25.250.220  utility.lab.example.com utility
172.25.250.220  registry.lab.example.com registry
EOF
#------------------------------------------------------------------------------

### insert root uuid and resume uuid for grub2 config
echo "---> Insert root uuid and resume uuid for grub2 config ..."
ROOT=$(blkid | grep root | cut -d ' ' -f 3 | cut -d '"' -f 2)
RESUME=$(blkid | grep boot | cut -d ' ' -f 3 | cut -d '"' -f 2)
sh -c ">/etc/default/grub"
cat > /etc/default/grub <<EOF
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Red Hat Enterprise Linux"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU="true"
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="root=UUID=${ROOT} resume=UUID=${RESUME} rhgb quiet rd.shell=0 selinux=0"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG="true"
EOF
# Set GRUB_ENABLE_BLSCFG="true" to enable generate /boot/bls.cfg file for dracut-rescue, or dracue-rescue
# reports ERROR. GRUB_CMDLINE_LINUX specifies arguements on GRUB2 during boot.

### rebuild grub2 config
echo "---> Rebuild GRUB2 config ..."
grub2-mkconfig -o /boot/grub2/grub.cfg
kernel-install add $(uname -r) /lib/modules/$(uname -r)/vmlinuz
# IMPORTANT:
#   If vmlinuz-$(uname -r) and initramfs-$(uname -r) have been removed from /boot, use kernel-install 
#   command to reinstall them and conf file located /boot/loader/entries/.
#   Kernel menu list during boot is definied in /boot/loader/entries/, so we should NOTICE files in
#   /boot/loader/entries/ in which they will appear on kernel menu list. It looks like as following:
#  
#     $ ls -lh /boot/loader/entries/
#     total 8.0K
#     -rw-r--r--. 1 root root 468 Nov 22 22:16 ace63d6701c2489ab9c0960c0f1afe1d-0-rescue.conf
#     # this file generated from dracue-config-rescue
#     -rw-r--r--. 1 root root 412 Nov 22 22:14 ace63d6701c2489ab9c0960c0f1afe1d-5.14.0-70.13.1.el9_0.x86_64.conf
#   
#   Reference link: 
#    - https://access.redhat.com/solutions/5847011#masthead
#    - https://ahelpme.com/linux/centos-stream-9/generate-the-rescue-kernel-boot-entry-in-centos-stream-9/ 

### use dracut to generate rescue vmlinuz and initramfs
echo "---> Install dracut-config-rescue package ..."
dnf install -y dracut-config-rescue
echo "---> Use dracut to generate rescue vmlinuz, initramfs and entry config ..."
/usr/lib/kernel/install.d/51-dracut-rescue.install add $(uname -r) /boot /boot/vmlinuz-$(uname -r)
mv /boot/loader/entries/ffff*.conf /tmp
# remove anonymous kernel config
echo -e "\n  NOTE: Please \033[32mREBOOT\033[0m system to verify kernel menu\n"
