#!/bin/bash
#
# Run script on serverc.lab.example.com in CL260 RHCS5
# course environment. In this scenario, we use cephadm 
# and ceph command to complete deploy.
# modified by hualongfeiyyy@163.com

### verify deploy node
echo "---> Verify deploy node if or not serverc..."
if [[ $(hostname) == 'serverc.lab.example.com' ]]; then
  echo -e " --> Start deploy RHCS5...\n"
else
  echo " --> NO correct deploy node, EXIT..."
  echo -e " --> Please run script on serverc node...\n"
  exit 2
fi

### install cephadm-ansible package
echo "---> Install cephadm-ansible and setup cephadm-preflight..."
dnf install -y cephadm-ansible
cat > /usr/share/cephadm-ansible/hosts <<EOF
clienta.lab.example.com
serverc.lab.example.com
serverd.lab.example.com
servere.lab.example.com
EOF
ansible-playbook -i /usr/share/cephadm-ansible/hosts \
/usr/share/cephadm-ansible/cephadm-preflight.yml \
--extra-vars "ceph_origin="
# setup ceph repository customized other than default

### bootstrap ceph cluster through customized registry
echo -e "\n---> Bootstrap ceph cluster..."
cephadm bootstrap --mon-ip 172.25.250.12 \
--initial-dashboard-password redhat \
--dashboard-password-noupdate \
--allow-fqdn-hostname \
--registry-url registry.lab.example.com \
--registry-username registry \
--registry-password redhat

### copy ceph.pub for other ceph nodes and add nodes
echo -e "\n---> Copy nodes ceph.pub and add nodes..."
ssh-copy-id -f -i /etc/ceph/ceph.pub root@serverd
ssh-copy-id -f -i /etc/ceph/ceph.pub root@servere
ssh-copy-id -f -i /etc/ceph/ceph.pub root@clienta
ceph orch host add serverd.lab.example.com
ceph orch host add servere.lab.example.com
ceph orch host add clienta.lab.example.com

### setup ceph monitor nodes
echo -e "\n---> Deploy all ceph monitor nodes..."
ceph orch apply mon --placement="serverc.lab.example.com serverd.lab.example.com servere.lab.example.com"

### setup ceph manager nodes
echo -e "\n---> Deploy all ceph manager nodes..."
ceph orch apply mgr --placement="serverc.lab.example.com serverd.lab.example.com servere.lab.example.com"

### setup ceph osds
echo -e "\n---> Deploy all ceph osds..."
for i in {c..e}; do
  ceph orch daemon add osd server${i}.lab.example.com:/dev/vdb
  ceph orch daemon add osd server${i}.lab.example.com:/dev/vdc
  ceph orch daemon add osd server${i}.lab.example.com:/dev/vdd
  sleep 5
done

### setup ceph cluster admin nodes
echo -e "\n---> Setup ceph cluster admin nodes..."
ceph orch host label add serverc.lab.example.com _admin
ceph orch host label add clienta.lab.example.com _admin
scp /etc/ceph/ceph.conf /etc/ceph/ceph.client.admin.keyring root@clienta:/etc/ceph
echo " --> Verify ceph cluster status..."
cephadm shell ceph status
# verify ceph cluster status

### login admin@clienta to verify cluster admin
echo -e "\n---> Verify ceph cluster status from admin@clienta..."
echo -e "---> Waiting ceph cluster \033[1;32mHEALTH_OK\033[0m ..."
# setup interval to wait ceph cluster to become health,
# If cluster still report HEALTH_WARN without any other messages, 
# please wait until HEALTH_OK. 
sleep 20 &
PID=$!
FRAMES="/ | \\ -"
while [[ -d /proc/$PID ]]; do
	for FRAME in $FRAMES; do
  	printf "\r$FRAME Waiting..."
		sleep 0.5
	done
done
printf "\n"
# use previous while loop under bash NOT zsh
ssh admin@clienta 'sudo cephadm shell ceph status'

# Note:
#  Sometimes ceph cluster reports HEALTH_WARN like '1 stray daemon(s) not managed by cephadm',
#  and this bug causes it under https://bugzilla.redhat.com/show_bug.cgi?id=2018906.
#  So use following command to fix it:
#
#   $ ceph config set mgr mgr/cephadm/warn_on_stray_daemons false
#
#  Cephadm is used as module for ceph manager.

