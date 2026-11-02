## OVN architecture introduction and advance

- ovn-arch directory includes native `linux bridge vlan`, native `linux vxlan tunnel`, `Open vSwitch (OVS) vxlan tunnel`, Open Virtual Network (`OVN`) associated deploy and configuration.
- Use **`ip link`**, **`ovs-vsctl`**, **`ovn-nbctl`**, **`ovn-sbctl`** to manage linux network namespace, OVS, OVN and so on.
- Following docs about OVN arch, logical switch, logical router, gateway chassis, load balance, ACL and container connection:
  - 👉 [**OVN architecture - Open Virtual Network（OVN）概述与分析**]()
  - 👉 [**OVN logical switch - 配置 OVN 逻辑交换机**]()
  - 👉 [**OVN logical router - 配置 OVN 逻辑路由器**]()
  - 👉 [**OVN OpenStack OpenFlow Analysis - OVN 在 OpenStack 中的集成与流表分析**]()
