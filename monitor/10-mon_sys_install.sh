#!/bin/bash
# Copyright (C) 2026 hualongfeiyyy@163.com
# 
# 脚本功能：二进制方式安装部署 Prometheus + Alertmanager + Grafana 监控告警系统
# 安装包下载地址：
#   1. Prometheus: https://github.com/prometheus/prometheus/releases
#   2. Altermanager: https://github.com/prometheus/alertmanager/releases
#   3. node_exporter: https://github.com/prometheus/node_exporter/releases
#   4. Grafana: https://grafana.com/grafana/download
#   5. Dashboard - Node Exporter Full: https://grafana.com/grafana/dashboards/1860-node-exporter-full/
# 参考链接：https://mp.weixin.qq.com/s/Q7Q2TFbP7WCsinl7uy_gIw
# 

echo -e "\n********** Prometheus + Alertmanager + Grafana 监控告警系统部署 **********"

INSTALL_DIR=/opt/monitor

function check_port {
    echo " --> 查看 ${PORT}/tcp 端口是否被占用 ..."
    if $(lsof -i :${PORT} >/dev/null); then
        echo "  -> [失败] ${PORT}/tcp 端口占用 ..."
        exit 5
    else
        echo "  -> [通过] ${PORT}/tcp 端口可用 ..."
    fi
}


### 1. 关闭 SELinux ###
function setup_se {
    echo -e "\n---> 关闭 SELinux ..."
    setenforce 0
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    grubby --update-kernel ALL --args selinux=0
    echo " --> 请稍后重启主机彻底关闭 SELinux ..."
}


### 2. 设置 firewalld 防火墙 ###
function setup_firewall {
    echo -e "\n---> 设置 firewalld 防火墙 ..."
    echo " --> 启用 firewalld 服务 ..."
    systemctl start firewalld.service
    systemctl is-active firewalld.service
    systemctl is-enabled firewalld.service

    echo " --> 放行服务端口 ..."
    firewall-cmd --permanent --add-port={9090/tcp,9100/tcp,9093/tcp,3000/tcp}
    # Prometheus 服务端  ：9090/tcp
    # Prometheus 客户端  ：9100/tcp
    # Alertmanager 服务端：9093/tcp
    # Grafana 服务端     ：3000/tcp
    firewall-cmd --reload
    echo " --> 防火墙放行的端口如下 ..."
    firewall-cmd --list-port
}


### 3. 设置 chronyd 时间同步 ###
function setup_time {
    echo -e "\n---> 设置 chronyd 时间同步 ..."
    echo " --> 设置时间同步服务器 ..."
    echo "pool ntp.aliyun.com iburst" >> /etc/chrony.conf
    systemctl restart chronyd.service

    chronyc makestep                       #立即校正时间
    chronyc sources -v                     #查看同步状态
    chronyc tracking                       #查看主同步详情
    chronyc sourcestats                    #统计各源稳定性
    chronyc tracking | grep "Last offset"  #验证时间同步精度（包括毫秒级偏移）

    echo " --> 设置时区 ..."
    timedatectl set-timezone Asia/Shanghai
    
    echo " --> 同步 UTC 时间至 RTC 时间 ..."
    hwclock set-local-rtc 0                #强制将 RTC 设置为 UTC（Linux 默认行为）
    #hwclock --systohc -l                  #将系统时间（Local time）写入硬件时钟（RTC）
    hwclock --systohc -u                   #将 UTC 时间（Universal time）写入硬件时钟（RTC）
}


### 4. 解压并安装 Prometheus ###
function install_prom {
    echo -e "\n---> 解压并安装 Prometheus ..."
    echo " --> 解压 prometheus tar 包 ..."
    cd ${INSTALL_DIR}/packages/
    tar -zxf prometheus-3.8.0.linux-amd64.tar.gz -C /usr/local/
    ln -s /usr/local/prometheus-3.8.0.linux-amd64 /usr/local/prometheus
    ls -lh /usr/local/prometheus

    echo " --> 添加 prometheus 组与用户 ..."
    groupadd -r prometheus
    useradd -r -g prometheus -M -c "Prometheus Daemon" -s /sbin/nologin prometheus
    mkdir /usr/local/prometheus/data
    chown -R prometheus:prometheus /usr/local/prometheus
    chown -R prometheus:prometheus /usr/local/prometheus-3.8.0.linux-amd64/
    ls -lh /usr/local/prometheus/

    local PORT=9090
    check_port
}


### 5. 设置 Prometheus 服务端配置文件（添加被监控的客户端主机） ###
function setup_prom {
    echo -e "\n---> 设置 Prometheus 服务端配置文件（添加被监控的客户端主机）..."
    cp /usr/local/prometheus/prometheus.yml /usr/local/prometheus/prometheus.yml.bak

    #1. 配置 service 单元文件
    cd ${INSTALL_DIR}
    cp prometheus.service /etc/systemd/system/prometheus.service   # !!! 重要配置文件 !!!

    #2. 设置主配置文件
    cp prometheus.yml /usr/local/prometheus/prometheus.yml         # !!! 重要配置文件 !!!
    #3. 设置 targets（创建目录存储基于文件的服务发现的主机信息）
    mkdir /usr/local/prometheus/targets
    chown -R prometheus:prometheus /usr/local/prometheus/targets/
    cp dev_nodes.yml /usr/local/prometheus/targets/                # !!! 重要配置文件 !!!
    #4. 设置 rules
    mkdir /usr/local/prometheus/rules
    chown -R prometheus:prometheus /usr/local/prometheus/rules/
    cp node_alerts.yml /usr/local/prometheus/rules/                # !!! 重要配置文件 !!!

    #5. 检查主配置文件
    echo " --> 检查 Prometheus 主配置文件 ..."
    cd /usr/local/prometheus
    ./promtool check config ./prometheus.yml
    if [[ $? -eq 0 ]]; then
        echo "  -> 检测通过，继续 ..."
    else
        echo "  -> 检测失败，退出 ..."
        exit 5
    fi

    systemctl daemon-reload
    echo " --> 启动 Prometheus 服务 ..."
    systemctl enable --now prometheus.service
    systemctl status --no-pager prometheus.service
    ss -tunlp | grep prometheus
}
# 部署完 Prometheus 后验证：访问 http://<prometheus_server>:9090/metrics


### 6. 解压并安装 node_exporter（客户端） ###
function install_ne {
    echo -e "\n---> 解压并安装 node_exporter（客户端） ..."
    echo " --> 安装节点 $(hostname) ..."
    cd ${INSTALL_DIR}/packages
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

    local PORT=9100
    check_port
}


### 7. 配置 node_exporter ###
# 说明：
#   1. 此处在 Prometheus 服务端部署 node_exporter
#   2. 执行 node_exporter_install.sh 脚本用于新增 Prometheus 客户端（监控节点）
function setup_ne {
    echo -e "\n---> 配置 node_exporter ..."
    cd ${INSTALL_DIR}
    cp node_exporter.service /etc/systemd/system/node_exporter.service    # !!! 重要配置文件 !!!

    systemctl daemon-reload
    echo " --> 启动 node_exporter 代理服务 ..."
    systemctl enable --now node_exporter.service
    systemctl status --no-pager node_exporter.service
    ss -tunlp | grep node_exporter
}
# 部署完 node_exporter 后验证：访问 http://<node_exporter_host>:9100/metrics


### 8. Prometheus 服务端安装 Altermanager 告警模块 ###
# 说明：Alertmanager 是独立的告警模块，也可以单独作为一台服务器，此处和 Prometheus 放在一起。
function install_alert {
    echo -e "\n---> Prometheus 服务端安装 Altermanager 告警模块 ..."
    cd ${INSTALL_DIR}/packages
    tar -zxf alertmanager-0.30.0.linux-amd64.tar.gz -C /usr/local/
    ln -s /usr/local/alertmanager-0.30.0.linux-amd64 /usr/local/alertmanager
    ls -lh /usr/local/alertmanager/
    chown -R root:root /usr/local/alertmanager/*
    cd ${INSTALL_DIR}
    cp alertmanager.service /etc/systemd/system/alertmanager.service    # !!! 重要配置文件 !!!
}


### 9. 配置 Alertmanager 配置文件 ###
function setup_alert {
    echo -e "\n---> 配置 Alertmanager 配置文件 ..."
    #read -p "请输入邮箱地址：" EMAIL
    #printf "请输入邮箱授权码："
    #read -s PASSWORD
    #echo ""
    cp /usr/local/alertmanager/alertmanager.yml /usr/local/alertmanager/alertmanager.yml.bak
    cd ${INSTALL_DIR}
    cp alertmanager.yml /usr/local/alertmanager/alertmanager.yml        # !!! 重要配置文件 !!!

    #检查主配置文件
    cd /usr/local/alertmanager
    ./amtool check-config ./alertmanager.yml    
    if [[ $? -eq 0 ]]; then
        echo "  -> 检测通过，继续 ..."
    else
        echo "  -> 检测失败，退出 ..."
        exit 5
    fi

    local PORT=9093
    check_port
}


### 10. 设置 Alertmanager 邮件告警模板 ###
function setup_tmpl {
    mkdir /usr/local/alertmanager/templates
    cd ${INSTALL_DIR}
    cp email.tmpl /usr/local/alertmanager/templates

    systemctl daemon-reload
    systemctl enable --now alertmanager.service
    systemctl status --no-pager alertmanager.service

    #故障排除
    #journalctl -u alertmanager.service --no-pager -f  #动态观察邮箱转发是否成功（常见 163 邮箱认证登陆失败）
}
# 部署完 Altermanager 后验证：访问 http://<altermanager_server>:9093/#/alerts


### 11. 安装配置 Grafana 服务端 ###
function setup_grafana {
    echo -e "\n---> 安装配置 Grafana 服务端 ..."
    cd ${INSTALL_DIR}/packages
    tar -zxf grafana-enterprise_12.3.3_21957728731_linux_amd64.tar.gz -C /usr/local/
    cd /usr/local
    ln -s /usr/local/grafana-12.3.3 grafana
    cd ${INSTALL_DIR}
    cp grafana.service /etc/systemd/system/grafana.service

    local PORT=3000
    check_port

    systemctl daemon-reload
    systemctl enable --now grafana.service
    systemctl status --no-pager grafana.service
    ss -tunlp | grep 3000
    #浏览器端登陆 admin:admin，更新密码为 admin:redhat，再添加 Prometheus 数据源。
}

### 调用各函数 ###
echo -e "\n***** 系统基础设置 *****"
setup_se
setup_firewall
setup_time

echo -e "\n***** Prometheus 安装与配置 *****"
install_prom
setup_prom

echo -e "\n***** Node Exporter 安装与配置 *****"
install_ne
setup_ne

echo -e "\n***** Altermanager 安装与配置 *****"
install_alert
setup_alert
setup_tmpl

echo -e "\n***** Grafana 服务端安装 *****"
setup_grafana

echo -e "\n\n********** 安装部署结束 **********\n\n"
