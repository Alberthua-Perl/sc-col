#!/bin/bash
#
# Compatible with RHEL9.x
# Modified on 2026-03-14 by hualongfeiyyy@163.com
#
# 关键问题：
#   1. 此处使用 PHP 5.4.16 连接 MySQL 8.4，但由于 MySQL 8.x 需要 PHP 8.x，
#      而 LogAnalyzer 项目已停止更新，使用旧版本 PHP 已无法连接成功。
#   2. 此脚本依然可运行成功，但无法通过 LogAnalyzer 前端访问数据库！
#   3. 可作为新版本升级的参考。

echo -e "\n>>>>> Start to deploy loganalyzer viewer <<<<<"

MYSQL_ADDR=172.25.250.11
CNI_GATEWAY=10.88.0.1
SE_HTTP_PORT=8881

SYSLOG_USER=syslogroot
SYSLOG_PASS=syslogpass
LOGANALYZER_USER=lyzeruser
LOGANALYZER_PASS=lyzeruser

### install associated packages ###
echo -e "\n---> Install associated packages"
dnf install -y podman mysql rsyslog-mysql
# rsyslog-mysql driver used to connect to mysql

### disable firewalld service ###
echo -e "\n---> Disable firewalld service"
if $(systemctl is-active firewalld.service > /dev/null); then
  systemctl stop firewalld.service
  systemctl disable firewalld.service
fi
echo ""

### configure selinux http port ###
echo -e "\n---> Configure selinux http port"
SESTATUS=$(getenforce)
if [[ ${SESTATUS} == "Enforcing" ]]; then
  semanage port -a -t http_port_t -p tcp ${SE_HTTP_PORT}
  echo "--> Current SELinux http port ..."
  semanage port -l | grep -w http_port_t
fi
echo ""

### downloading log system container images ###
echo -e "\n---> Downloading log system container images"
for img in mysql-84:9.7 loganalyzer-viewer:1.0; do
  echo " --> ${img} downloading..."
  podman pull quay.io/alberthua/${img}
  [[ $? -eq 0 ]] || (echo "--> Downloading failed..." && exit 2)
done
echo ""

### deploy mysql database container ###
echo -e "\n---> Deploy mysql database container"
mkdir -p /var/lib/mysql && chown 27:27 /var/lib/mysql
podman run -d \
  --name rsyslog-mysqldb \
  -e MYSQL_ROOT_PASSWORD=redhat \
  -p 3306:3306 \
  -v /var/lib/mysql:/var/lib/mysql/data:Z \
  quay.io/alberthua/mysql-84:9.7
# 注意：此容器镜像中使用 MySQL 8.4
echo "--> Wait several seconds to init mysql database ..."
sleep 10s
if $(podman ps --format={{.Names}} | grep rsyslog-mysqldb &> /dev/null); then
  echo -e "--> $(date +'%F %T') [\033[1;36mNote\033[0m] rsyslog-mysqldb container running"
else
  echo -e "--> $(date +'%F %T') [\033[1;31mERROR\033[0m] rsyslog-mysqldb container with ERRORs"
  exit 1
fi

echo "--> Authorize mysql user for database"
echo "    Insert rsyslog-mysql database"
echo "    Type mysql root password to insert initial db"
mysql -u root -h ${MYSQL_ADDR} -p < /usr/share/doc/rsyslog/mysql-createDB.sql
# sql file from rsyslog-mysql package
echo "--> Type mysql root password to auth mysql user"
mysql -u root -h ${MYSQL_ADDR} -p -e "
CREATE USER IF NOT EXISTS '${SYSLOG_USER}'@'127.0.0.1' IDENTIFIED BY '${SYSLOG_PASS}';
CREATE USER IF NOT EXISTS '${SYSLOG_USER}'@'${MYSQL_ADDR}' IDENTIFIED BY '${SYSLOG_PASS}';
CREATE USER IF NOT EXISTS '${SYSLOG_USER}'@'${CNI_GATEWAY}' IDENTIFIED BY '${SYSLOG_PASS}';

GRANT ALL PRIVILEGES ON Syslog.* TO '${SYSLOG_USER}'@'127.0.0.1';
GRANT ALL PRIVILEGES ON Syslog.* TO '${SYSLOG_USER}'@'${MYSQL_ADDR}';
GRANT ALL PRIVILEGES ON Syslog.* TO '${SYSLOG_USER}'@'${CNI_GATEWAY}';

FLUSH PRIVILEGES;

CREATE DATABASE IF NOT EXISTS loganalyzer;

CREATE USER IF NOT EXISTS '${LOGANALYZER_USER}'@'${MYSQL_ADDR}' IDENTIFIED BY '${LOGANALYZER_PASS}';
CREATE USER IF NOT EXISTS '${LOGANALYZER_USER}'@'${CNI_GATEWAY}' IDENTIFIED BY '${LOGANALYZER_PASS}';

GRANT ALL PRIVILEGES ON loganalyzer.* TO '${LOGANALYZER_USER}'@'${MYSQL_ADDR}';
GRANT ALL PRIVILEGES ON loganalyzer.* TO '${LOGANALYZER_USER}'@'${CNI_GATEWAY}';

FLUSH PRIVILEGES;

SELECT User, Host FROM mysql.user;

QUIT
"
# 注意：以上 SQL 语句兼容 MySQL 8.4 数据库引擎
echo ""

### deploy rsyslog server ###
echo -e "\n---> Deploy rsyslog server"
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
echo -e "\n---> Deploy httpd and loganalyzer(php) container"
echo "--> Set SELinux boolean to allow php connect to mysql ..."
setsebool -P httpd_can_network_connect on && \
setsebool -P httpd_can_network_connect_db on && \
echo "--> Set SELinux boolean successfully"
podman load -i loganalyzer-viewer-1.0.tar
podman run -d --name loganalyzer-viewer \
  -p 8881:8881 \
  quay.io/alberthua/loganalyzer-viewer:1.0
# 注意：此容器镜像中使用 PHP 5.4.16

sleep 5s
if $(podman ps --format={{.Names}} | grep loganalyzer-viewer &> /dev/null); then
  echo -e "--> $(date +'%F %T') [\033[1;36mNote\033[0m] loganalyzer-viewer container running"
else
  echo -e "--> $(date +'%F %T') [\033[1;31mERROR\033[0m] loganalyzer-viewer container with ERRORs"
  exit 1
fi
echo "--> All container as followings ..."
podman ps --format="table {{.Names}} {{.Ports}} {{.Status}}"; echo ""

echo -e "\n---> Deploy successfully!\n"

