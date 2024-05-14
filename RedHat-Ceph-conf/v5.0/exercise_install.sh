#!/bin/bash
#
# run the script on root@serverc to deploy ceph cluster
# modified by lhua@redhat.com on 2024-05-14

echo -e "\n---> Prepare deploy environment..."
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
  host_pattern: 'server*'
data_devices:
  paths:
    - /dev/vdb
#    - /dev/vdc
#    - /dev/vdd

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
