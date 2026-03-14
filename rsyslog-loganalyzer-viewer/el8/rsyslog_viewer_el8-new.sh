#!/bin/bash
#
# Modified on 2026-03-14 by hualongfeiyyy@163.com
# Usage:
#   [root@serverb ~]# sh ./rsyslog_viewer_el8-new.sh
#

echo -e "\n>>>>> Start to deploy loganalyzer viewer <<<<<"

MYSQL_ADDR=172.25.250.11
CNI_GATEWAY=10.88.0.1
SE_HTTP_PORT=8881

SYSLOG_USER=syslogroot
SYSLOG_PASS=syslogpass
LOGANALYZER_USER=lyzeruser
LOGANALYZER_PASS=lyzeruser

### install associated packages ###
echo -e "\n---> Install associated packages..."
dnf install -y podman mysql rsyslog-mysql
# rsyslog-mysql driver used to connect to mysql

### disable firewalld service ###
echo -e "\n---> Disable firewalld service..."
if $(systemctl is-active firewalld.service > /dev/null); then
  systemctl stop firewalld.service
  systemctl disable firewalld.service
fi
echo ""

### configure selinux http port ###
echo -e "\n---> Configure selinux http port..."
SESTATUS=$(getenforce)
if [[ ${SESTATUS} == "Enforcing" ]]; then
  semanage port -a -t http_port_t -p tcp ${SE_HTTP_PORT}
  echo "--> Current SELinux http port..."
  semanage port -l | grep -w http_port_t
fi
echo ""

### downloading log system container images ###
echo -e "\n---> Downloading log system container images..."
for img in mysql-55-rhel7:v5.5 loganalyzer-viewer:1.0; do
  echo " --> ${img} downloading..."
  podman pull quay.io/alberthua/${img}
  [[ $? -eq 0 ]] || (echo "--> Downloading failed..." && exit 2)
done
echo ""

### deploy mysql database container ###
echo -e "\n---> Deploy mysql database container..."
mkdir -p /var/lib/mysql && chown 27:27 /var/lib/mysql
podman run -d \
  --name rsyslog-mysqldb \
  -e MYSQL_ROOT_PASSWORD=redhat \
  -p 3306:3306 \
  -v /var/lib/mysql:/var/lib/mysql/data:Z \
  quay.io/alberthua/mysql-55-rhel7:v5.5
echo "--> Wait several seconds to init mysql database..."
sleep 10s
if $(podman ps --format={{.Names}} | grep rsyslog-mysqldb &> /dev/null); then
  echo -e "--> [$(date +'%F %T') \033[1;36mNote\033[0m] rsyslog-mysqldb container running..."
else
  echo -e "--> [$(date +'%F %T') \033[1;31mERROR\033[0m] rsyslog-mysqldb container with ERRORs..."
  exit 1
fi

echo "--> Authorize mysql user for database..."
echo "    Insert rsyslog-mysql database..."
echo "    Type mysql root password to insert initial db..."
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

### deploy rsyslog server ###
echo -e "\n---> Deploy rsyslog server..."
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
echo -e "\n---> Deploy httpd and loganalyzer(php) container..."
echo "--> Set SELinux boolean to allow php connect to mysql..."
setsebool -P httpd_can_network_connect on && \
setsebool -P httpd_can_network_connect_db on && \
echo "--> Set SELinux boolean successfully..."
podman run -d --name loganalyzer-viewer \
  -p 8881:8881 \
  quay.io/alberthua/loganalyzer-viewer:1.0
sleep 5s
if $(podman ps --format={{.Names}} | grep loganalyzer-viewer &> /dev/null); then
  echo -e "--> [$(date +'%F %T') \033[1;36mNote\033[0m] loganalyzer-viewer container running"
else
  echo -e "--> [$(date +'%F %T') \033[1;31mERROR\033[0m] loganalyzer-viewer container with ERRORs"
  exit 1
fi
echo "--> All container as followings..."
podman ps --format="table {{.Names}} {{.Ports}} {{.Status}}"; echo ""

echo -e "\n---> Deploy successfully!\n"

