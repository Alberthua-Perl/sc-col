#!/bin/bash
#
# Run script on serverc.lab.example.com in CL260 RHCS5 course environment.
# Modified by hualongfeiyyy@163.com
# 
# Method to deploy Ceph Storage Cluster:
#   - service specification:
#       - cephadm bootstrap to boot ONE node
#       - ceph service specification file
#   - placement specification:
#       - cephadm bootstrap to boot ONE node
#       - ceph orch host add
#       - ceph orch host apply
#       - ceph orch apply
#       - ceph orch daemon add osd
#       - ceph orch host add label
#
# In this scenario, we use SECOND method to deploy RHCS5.

### set variables
START="\033[1;37m"
END="\033[0m"
TGT_NODE=serverc.lab.example.com
RGW_SPEC_FILE=/root/rgw-service.yml

### destroy prebuild ceph cluster
echo -e "\n${START}---> Destroy prebuild ceph cluster...${END}"
ssh student@workstation 'lab start deploy-deploy'

### verify deploy node
echo -e "\n${START}---> Verify deploy node if or not serverc...${END}"
if [[ $(hostname) == ${TGT_NODE} ]]; then
  echo -e " ${START}--> Start deploy RHCS5...${END}\n"
else
  echo " ${START}--> NO correct deploy node, EXIT...${END}"
  echo -e " ${START}--> Please run script on serverc node...${END}\n"
  exit 2
fi

### install cephadm-ansible package
echo -e "${START}---> Install cephadm-ansible and setup cephadm-preflight...${END}"
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
echo -e "\n${START}---> Bootstrap ceph cluster...${END}"
cephadm bootstrap --mon-ip 172.25.250.12 \
--initial-dashboard-password redhat \
--dashboard-password-noupdate \
--allow-fqdn-hostname \
--registry-url registry.lab.example.com \
--registry-username registry \
--registry-password redhat

### copy ceph.pub for other ceph nodes and add nodes
echo -e "\n${START}---> Copy nodes ceph.pub and add nodes...${END}"
ssh-copy-id -f -i /etc/ceph/ceph.pub root@serverd
ssh-copy-id -f -i /etc/ceph/ceph.pub root@servere
ssh-copy-id -f -i /etc/ceph/ceph.pub root@clienta
ceph orch host add serverd.lab.example.com
ceph orch host add servere.lab.example.com
ceph orch host add clienta.lab.example.com

### setup ceph monitor service on nodes
echo -e "\n${START}---> Deploy ceph monitor service on nodes...${END}"
ceph orch apply mon --placement="serverc.lab.example.com serverd.lab.example.com servere.lab.example.com"

### setup ceph manager service on nodes
echo -e "\n${START}---> Deploy ceph manager service on nodes...${END}"
ceph orch apply mgr --placement="serverc.lab.example.com serverd.lab.example.com servere.lab.example.com"

### setup rados gateway instances on nodes
echo -e "\n${START}---> Deploy rados gateway instances on nodes...${END}"
cat > ${RGW_SPEC_FILE} <<EOF
service_type: rgw
service_id: realm.zone
service_name: rgw.realm.zone
placement:
  count: 2
  # each host including one instance
  hosts:
    - serverc.lab.example.com
    - serverd.lab.example.com
EOF
ceph orch apply -i ${RGW_SPEC_FILE}

### setup ceph osds
echo -e "\n${START}---> Deploy ceph osds...${END}"
for i in {c..e}; do
  echo -e " ${START}--> Start add OSDs on server${i}...${END}"
  ceph orch daemon add osd server${i}.lab.example.com:/dev/vdb
  ceph orch daemon add osd server${i}.lab.example.com:/dev/vdc
  ceph orch daemon add osd server${i}.lab.example.com:/dev/vdd
  sleep 3
done

### setup ceph cluster admin nodes
echo -e "\n${START}---> Setup ceph cluster admin nodes...${END}"
ceph orch host label add serverc.lab.example.com _admin
ceph orch host label add clienta.lab.example.com _admin
scp /etc/ceph/ceph.conf /etc/ceph/ceph.client.admin.keyring root@clienta:/etc/ceph
echo -e " ${START}--> Verify ceph cluster status...${END}"
cephadm shell -- ceph status
# verify ceph cluster status

### login admin@clienta to verify cluster admin
echo -e "\n${START}---> Verify ceph cluster status from admin@clienta...${END}"
echo -e "${START}---> Waiting ceph cluster${END} \033[1;32mHEALTH_OK\033[0m ${START}...${END}"
# setup interval to wait ceph cluster to become health,
# If cluster still report HEALTH_WARN without any other messages, 
# please wait until HEALTH_OK. 
sleep 30 &
PID=$!
FRAMES="/ | \\ -"
while [[ -d /proc/$PID ]]; do
  for FRAME in $FRAMES; do
    printf "\r%s ${START}Waiting...${END}" "$FRAME"  # DO NOT use variables in printf
    sleep 0.5
  done
done; printf "\n"
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

