#!/bin/bash
#
# run the script on root@serverc to deploy ceph cluster
# modified by lhua@redhat.com on 2024-05-14

echo -e "\n---> Prepare deploy environment..."
yum install -y sshpass
sshpass -p student ssh student@workstation "lab start deploy-deploy"
yum install -y cephadm-ansible

echo -e "\n---> Preflight ceph hosts..."
cd /usr/share/cephadm-ansible
cat > hosts <<EOF
clienta.lab.example.com
serverc.lab.example.com
serverd.lab.example.com
servere.lab.example.com
EOF

ansible-playbook -i ./hosts cephadm-preflight.yml --extra-vars "ceph_origin="

echo -e "\n---> Deploy ceph cluster..."
cat > /tmp/initial-cluster.yml <<EOF
# customized service specification file used by 
# cephadm bootstrap --apply-spec option
service_type: host
addr: 172.25.250.10
hostname: clienta.lab.example.com
---
service_type: host
addr: 172.25.250.12
hostname: serverc.lab.example.com
---
service_type: host
addr: 172.25.250.13
hostname: serverd.lab.example.com
---
service_type: host
addr: 172.25.250.14
hostname: servere.lab.example.com
---
service_type: mon
placement:
  hosts:
    - clienta.lab.example.com
    - serverc.lab.example.com
    - serverd.lab.example.com
    - servere.lab.example.com
---
service_type: rgw
service_id: realm.zone
placement:
  hosts:
    - serverc.lab.example.com
    - serverd.lab.example.com
---
service_type: mgr
placement:
  hosts:
    - clienta.lab.example.com
    - serverc.lab.example.com
    - serverd.lab.example.com
    - servere.lab.example.com
---
service_type: osd
service_id: default_drive_group
placement:
  #host_pattern: 'server*'
  hosts:
    - serverc.lab.example.com
    - serverd.lab.example.com
    # Note: Don't create osd on servere.lab.example.com. Use osd spec file to create on it.
data_devices:
  paths:
    - /dev/vdb
    - /dev/vdc
    - /dev/vdd

# Note:
#  Because guided exercise on p49 expend ceph cluster storage, when using lab
#  command to prepare, ERRORs of zapping devices are always reported which make
#  lab command failed. So we don't deploy osds on /dev/vdc and /dev/vdd.
EOF

cephadm bootstrap --mon-ip=172.25.250.12 \
--apply-spec=/tmp/initial-cluster.yml \
--initial-dashboard-password=redhat \
--dashboard-password-noupdate \
--allow-fqdn-hostname \
--registry-url=registry.lab.example.com \
--registry-username=registry \
--registry-password=redhat

echo -e "\n---> Post-deploy operations..."
ceph orch host label add clienta.lab.example.com _admin
ceph orch host ls
scp /etc/ceph/{ceph.conf,ceph.client.admin.keyring} root@clienta:/etc/ceph

echo -e "\n---> [WARNING] Please add OSDs on servere...\n"
echo -e "     Use initial-osd-servere.yaml to deploy osd on servere by following command: \n"
echo -e "     $ ceph orch apply -i ./initial-osd-servere.yaml\n"
echo "     If you don't deploy osd on servere, pg will be undersized. Because number"
echo "     of pg is great than number of osd. So you should deploy osd on servere to"
echo -e "     keep cluster healthy.\n"

