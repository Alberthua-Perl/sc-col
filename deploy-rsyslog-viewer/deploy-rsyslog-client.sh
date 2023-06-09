#!/bin/bash
#
# Deploy rsyslog client to transform log to 
# remote rsyslog server connected with mysql
# database.
#
# Create on 2021-04-05 by hualongfeiyyy@163.com
#

MYSQL_ADDR=172.25.250.11
# SYSLOG_USER=syslogroot
# SYSLOG_PASS=syslogpass

echo "---> Deploy rsyslog client"
cp /etc/rsyslog.conf /etc/rsyslog.conf.bak

cat > /etc/rsyslog.conf <<EOF
#### MODULES ####
module(load="imuxsock"
       SysSock.Use="off")
module(load="imjournal"
       StateFile="imjournal.state")
module(load="imklog")

#### GLOBAL DIRECTIVES ####
global(workDirectory="/var/lib/rsyslog")
module(load="builtin:omfile" Template="RSYSLOG_TraditionalFileFormat")
include(file="/etc/rsyslog.d/*.conf" mode="optional")

#### RULES ####
*.info;mail.none;authpriv.none;cron.none	/var/log/messages
local7.*				/var/log/boot.log
*.*							@${MYSQL_ADDR}
# *.*             :ommysql:${MYSQL_ADDR},Syslog,${SYSLOG_USER},${SYSLOG_PASS}
EOF

systemctl restart rsyslog.service
systemctl status rsyslog.service
echo "--> Deploy successfully!"

