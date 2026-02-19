#!/bin/bash
#
# Prometheus 监控节点（客户端）安装 node_exporter 代理
#

echo -e "\n---> 解压并安装 node_exporter（客户端） ..."
echo " --> 安装节点 $(hostname) ..."
tar -zxf node_exporter-1.10.2.linux-amd64.tar.gz -C /usr/local/
ln -s /usr/local/node_exporter-1.10.2.linux-amd64 /usr/local/node_exporter
if $(grep prometheus /etc/group &>/dev/null); then
    echo " --> prometheus 组存在 ..."
else
    echo " --> prometheus 组不存在，创建该组 ..."
    groupadd -r prometheus
fi
if $(id prometheus &>/dev/null); then
    echo " --> prometheus 用户存在 ..."
else
    echo " --> prometheus 用户不存在，创建该用户 ..."
    useradd -r -g prometheus -M -c "Prometheus Daemon" -s /sbin/nologin prometheus    
fi
echo " --> 设置 node_exporter 目录属组 ..."
chown -R prometheus:prometheus /usr/local/node_exporter
chown -R prometheus:prometheus /usr/local/node_exporter-1.10.2.linux-amd64/
ls -lh /usr/local/node_exporter/

echo -e "\n---> 配置 node_exporter ..."
cp ./node_exporter.service /etc/systemd/system/node_exporter.service
systemctl daemon-reload
echo " --> 启动 node_exporter 代理服务 ..."
systemctl enable --now node_exporter.service
systemctl status node_exporter.service
ss -tunlp | grep node_exporter
