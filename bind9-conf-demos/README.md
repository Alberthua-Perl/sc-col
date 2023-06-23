## 多个 BIND named 服务之间的关系

- RH358v8.1 (Red Hat Services Management and Automation) 实验环境中配置有多个 BIND named 服务并分别位于多个节点，以下为各个节点中的服务说明与关系：
- `foundation0.ilt.example.com` 节点：
  - IPv4 地址：`172.25.254.250`
  - `ilt.example.com` 域中的功能：主 DNS 名称服务器
  - `example.com` 域：对该域的名称解析将转发至 `172.25.254.254` 节点 (classroom 节点)
- `classroom.example.com` 节点：
  - IPv4 地址：`172.25.254.254`
  - `example.com` 域中的功能：主 DNS 名称服务器
- `bastion.lab.example.com` 节点：
  - IPv4 地址：`172.25.250.254`
  - `lab.example.com` 域中的功能：主 DNS 名称服务器
  - `example.com` 域中的功能：从 DNS 名称服务器
