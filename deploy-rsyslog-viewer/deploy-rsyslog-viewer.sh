#!/bin/bash
#
# Deploy rsyslog server which collect local or remote 
# system log and transform them into mysql database.
#
# Display log through loganalyzer coded by php on web
# frontend, so httpd and php should be deployed.
# 
# Logical architecture:
#   user --> loganalyzer(php) container --> mysql container
#   rsyslog server --> mysql container
# 
# Created by hualongfeiyyy@163.com on 2021-04-03.
#
# In this case, rsyslog server, mysql container, httpd
# and loganalyzer are deployed on the same node as LAMP.
# 

MYSQL_ADDR=172.25.250.11
CNI_GATEWAY=10.88.0.1
SE_HTTP_PORT=8881

SYSLOG_USER=syslogroot
SYSLOG_PASS=syslogpass
LOGANALYZER_USER=lyzeruser
LOGANALYZER_PASS=lyzeruser

### install associated packages ###
echo "---> Install associated packages"
wget -O /etc/yum.repos.d/updates.repo  http://materials.example.com/updates.repo
yum install -y mysql rsyslog-mysql \
  podman-1.9.3-2.module+el8.2.1+6867+366c07d6.x86_64 skopeo; echo ""
# rsyslog-mysql driver used to connect to mysql

### disable firewalld service ###
echo "---> Disable firewalld service"
if `systemctl is-active firewalld.service > /dev/null`; then
  systemctl stop firewalld.service
  systemctl disable firewalld.service
fi
# Note:
#   iptables conflict with firewalld, if firewalld is running
#   all iptables rules will disapear, so container port mapping
#   will be no effect!
echo ""

### configure selinux http port ###
echo "---> Configure selinux http port"
SESTATUS=$(getenforce)
if [[ ${SESTATUS} == "Enforcing" ]]; then
  semanage port -a -t http_port_t -p tcp ${SE_HTTP_PORT}
  echo "--> Current SELinux http port ..."
  semanage port -l | grep -w http_port_t
fi
echo ""

### configure environment for login registry ###
echo "---> Configure environment for login registry"
sed -i "48c registries = ['registry.lab.example.com']" /etc/containers/registries.conf
# this line is different from 1.6.x or 1.9.x podman
mkdir -p /etc/docker/certs.d/registry.lab.example.com
cp ssl.crt /etc/docker/certs.d/registry.lab.example.com/
echo -e "--> $(date +'%F %T') [\033[1;36mNote\033[0m] Please type password of root@utility: redhat"
scp ssl.crt root@utility:/etc/quay/ssl.cert
scp ssl.key root@utility:/etc/quay/ssl.key
podman login registry.lab.example.com --username admin --password redhat321
echo ""

### deploy mysql database container ###
echo "---> Deploy mysql database container"
mkdir -p /var/lib/mysql && chown 27:27 /var/lib/mysql
# mysql uid in redhat container image is 27, and not change
# the owner and group of this directory will lead to container
# failure.

skopeo inspect \
  docker://registry.lab.example.com/rhscl/mysql-57-rhel7:latest &> /dev/null
# ensure mysql-57-rhel7 container image in Quay
# If rhscl organization is not existed, please create it first,
# or this container image can be pushed into Quay!
if [[ $? -eq 0 ]]; then
  podman run -d \
    --name rsyslog-mysqldb \
    -e MYSQL_ROOT_PASSWORD=redhat \
    -p 3306:3306 \
    -v /var/lib/mysql:/var/lib/mysql/data:Z \
    registry.lab.example.com/rhscl/mysql-57-rhel7:latest
  echo "--> Wait several seconds to init mysql database ..."
  sleep 10s
  if `podman ps --format={{.Names}} | grep rsyslog-mysqldb &> /dev/null`; then
    echo -e "--> $(date +'%F %T') [\033[1;36mNote\033[0m] rsyslog-mysqldb container running"
  else
    echo -e "--> $(date +'%F %T') [\033[1;31mERROR\033[0m] rsyslog-mysqldb container with ERRORs"
    exit 1
  fi
else
  echo -e "--> $(date +'%F %T') [\033[1;31mERROR\033[0m] No mysql container image in registry"
  exit 1
fi

echo "--> Authorize mysql user for database"
echo "--> Insert rsyslog-mysql database"
echo "--> Type mysql root password to insert initial db"
mysql -u root -h ${MYSQL_ADDR} -p < /usr/share/doc/rsyslog/mysql-createDB.sql
# sql file from rsyslog-mysql package
echo "--> Type mysql root password to auth mysql user"
mysql -u root -h ${MYSQL_ADDR} -p -e "
grant all on Syslog.* to '${SYSLOG_USER}'@'127.0.0.1' identified by '${SYSLOG_PASS}';
grant all on Syslog.* to '${SYSLOG_USER}'@'${MYSQL_ADDR}' identified by '${SYSLOG_PASS}';
grant all on Syslog.* to '${SYSLOG_USER}'@'${CNI_GATEWAY}' identified by '${SYSLOG_PASS}';
flush privileges;
create database loganalyzer;
grant all on loganalyzer.* to '${LOGANALYZER_USER}'@'${MYSQL_ADDR}' identified by '${LOGANALYZER_PASS}';
grant all on loganalyzer.* to '${LOGANALYZER_USER}'@'${CNI_GATEWAY}' identified by '${LOGANALYZER_PASS}';
flush privileges;
select User,Host from mysql.user;
quit
"
echo ""
# Note:
#   As httpd, loganalyzer and mysql are deployed on the same node,
#   loganalyzer container connect to mysql container through cni-podman0
#   which is CNI gateway pre-allocated 10.88.0.1.
#   So you should add this address to mysql user.
#   If previous container is deployed on different node, just use
#   specified node NIC.

### deploy rsyslog server ###
echo "---> Deploy rsyslog server"
cp /etc/rsyslog.conf /etc/rsyslog.conf.bak

cat > /etc/rsyslog.conf <<EOF
#### MODULES ####
module(load="imuxsock"
       SysSock.Use="off")
module(load="imjournal"
       StateFile="imjournal.state")
module(load="imklog")

module(load="imudp")
input(type="imudp" port="514")
module(load="imtcp")
input(type="imtcp" port="514")
module(load="ommysql")

#### GLOBAL DIRECTIVES ####
global(workDirectory="/var/lib/rsyslog")
module(load="builtin:omfile" Template="RSYSLOG_TraditionalFileFormat")
include(file="/etc/rsyslog.d/*.conf" mode="optional")

#### RULES ####
local7.*        /var/log/boot.log
*.*							/var/log/messages
*.*             :ommysql:${MYSQL_ADDR},Syslog,${SYSLOG_USER},${SYSLOG_PASS}
EOF
# rsyslog configure file different from CentOS 7.x and CentOS 8.x

systemctl restart rsyslog.service
echo ""

### deploy httpd and loganalyzer(php) container ###
echo "---> Deploy httpd and loganalyzer(php) container"
echo "--> Set SELinux boolean to allow php connect to mysql ..."
setsebool -P httpd_can_network_connect on && \
setsebool -P httpd_can_network_connect_db on && \
echo "--> Set SELinux boolean successfully"
podman load -i loganalyzer-viewer-1.0.tar
podman run -d --name loganalyzer-viewer \
  -p 8881:8881 \
  registry.lab.example.com/rhscl/loganalyzer-viewer:1.0

sleep 5s
if `podman ps --format={{.Names}} | grep loganalyzer-viewer &> /dev/null`; then
  echo -e "--> $(date +'%F %T') [\033[1;36mNote\033[0m] loganalyzer-viewer container running"
else
  echo -e "--> $(date +'%F %T') [\033[1;31mERROR\033[0m] loganalyzer-viewer container with ERRORs"
  exit 1
fi
echo "--> All container as followings ..."
podman ps --format="table {{.Names}} {{.Ports}} {{.Status}}"; echo ""

echo "---> Deploy successfully!"

  # Note:
  #   As previous mention, all container deployed on the same node.
  #   If you don't use podman container, you can also use rpm packages
  #   to deploy services. 
  #   Just like as followings:
  # 
  # yum install -y httpd php php-mysqlnd php-gd
  # # php-mysql in CentOS 7.x and php-mysqlnd in CentOS 8.x
  # echo "--> Deploy loganalyzer(php) ..."
  # mkdir -pv /web/loganalyzer/
  # tar -zxf loganalyzer-4.1.11.tar.gz
  # cp -r loganalyzer-4.1.11/src/* /web/loganalyzer/
  # cp -r loganalyzer-4.1.11/contrib/*.sh /web/loganalyzer/
  # touch /web/loganalyzer/config.php && chmod 666 /web/loganalyzer/config.php
  # semanage fcontext -a -t httpd_sys_content_t '/web(/.*)?'
  # echo "--> Current selinux file context ..."
  # restorecon -Rv /web > /dev/null && ls -ldZ /web
  # chcon -t httpd_sys_rw_content_t /web/loganalyzer/config.php && \
  # 	ls -lZ /web/loganalyzer/config.php
  ## httpd_sys_rw_content_t file context ensure the file could
  ## be writeable
  # setsebool -P httpd_can_network_connect on && \
  # setsebool -P httpd_can_network_connect_db on
  ## set SELinux boolean to allow php connect to mysql
  # cat > /etc/httpd/conf.d/loganalyzer-viewer.conf <<EOF
  # Listen 8881
  # <VirtualHost *:8881>
  #   ServerName loganalyzer-viewer.lab.example.com
  #   DocumentRoot /web/loganalyzer
  #   LogLevel debug
  #   <Directory /web/loganalyzer>
  #     DirectoryIndex index.php index.html index.html.var
  #     AllowOverride None
  #     Require all granted
  #   </Directory>
  # </VirtualHost>
  # EOF
  # 
  # echo "--> Apache httpd server status is ..."
  # systemctl start httpd.service
  # systemctl status httpd.service
