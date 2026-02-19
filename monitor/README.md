# 一键部署二进制 Prometheus+Alertmanager+Granafa 监控平台

1. 项目目录结构：

   ```bash
   $ tree .
   .
   ├── 10-mon_sys_install.sh          #主安装脚本程序    
   ├── 20-node_exporter_install.sh    #新增节点安装 node_exporter 代理脚本程序
   ├── alertmanager_email_auth.log    #Alertmanager 对接邮箱错误日志（仅作参考）
   ├── alertmanager.service           #Alertmanager 服务端 service 单元文件
   ├── alertmanager.yml               #Alertmanager 服务端主配置文件
   ├── dashboards
   │   └── 1860_rev42.json            #Grafana dashboard 的 node exporter 配置文件
   ├── dev_nodes.yml                  #Prometheus 服务端的 targets 文件
   ├── email.tmpl                     #Alertmanager 服务端的邮箱模板文件
   ├── grafana.service                #Grafana 的 service 单元文件
   ├── node_alerts.yml                #Prometheus 服务端的告警规则文件
   ├── node_exporter.service          #node exporter 的 service 单元文件
   ├── packages                       #各组件的二进制安装包
   │   ├── alertmanager-0.30.0.linux-amd64.tar.gz
   │   ├── grafana-enterprise_12.3.3_21957728731_linux_amd64.tar.gz
   │   ├── node_exporter-1.10.2.linux-amd64.tar.gz
   │   └── prometheus-3.8.0.linux-amd64.tar.gz
   ├── prometheus.service             #Prometheus 服务端的 service 单元文件
   ├── prometheus.yml                 #Prometheus 服务端的主配置文件
   └── README.md

   3 directories, 18 files
   ```

2. 运行部署脚本程序前，请先确认修改以下配置文件中的参数（CHANGEME 注释部分）：

- prometheus.yml
  - 修改 Alertmanager 服务端地址
  - 可选：修改 rule_files 部分中的告警规则文件所在路径
  - 修改 node_exporter 部分中的被监控主机的 IP 地址与端口
  - 可选：修改 node_service_discovery 部分中的 targets 文件所在路径
- dev_nodes.yml
  - targets 文件中发现的被监控主机的 IP 地址
- alertmanager.yml
  - 修改相关的 smtp 邮箱、用户与授权码

3. 为了加速二进制软件包的下载，可使用以下方式：

   ```bash
   $ cd /opt/monitor/packages
   $ wget https://rh-course-materials.oss-cn-hangzhou.aliyuncs.com/monitor/prometheus-3.8.0.linux-amd64.tar.gz
   $ wget https://rh-course-materials.oss-cn-hangzhou.aliyuncs.com/monitor/node_exporter-1.10.2.linux-amd64.tar.gz
   $ wget https://rh-course-materials.oss-cn-hangzhou.aliyuncs.com/monitor/alertmanager-0.30.0.linux-amd64.tar.gz
   $ wget https://rh-course-materials.oss-cn-hangzhou.aliyuncs.com/monitor/grafana-enterprise_12.3.3_21957728731_linux_amd64.tar.gz
   # 以上软件包均来自官方软件源的备份，当前目录中不包含。
   ```

4. 将此目录置于 /opt 目录中，并运行 10-mon_sys_install.sh 完成安装：

   ```bash
   $ cd /opt/monitor
   $ sh ./10-mon_sys_install.sh
   ```

5. 可选：在单独的节点上安装 node_exporter 被 Prometheus 服务端监控

   ```bash
   $ cd /opt/monitor
   $ sh ./20-node_exporter_install.sh
   ```

6. 部署完成后，可将 Grafana 接入 Prometheus 数据源并使用 dashboard 演示：

   <img src="images/grafana-dashboard-demo.jpg" style="width:80%">
