## 多个 BIND named 服务之间的关系

- `foundation0` 节点：
  - IP 地址：`172.25.254.250`
  - `ilt.example.com` 域：主 DNS 名称服务器
  - `example.com` 域：名称解析将转发至 `172.25.254.254` (classroom 节点)
- `classroom` 节点：
  - IP 地址：`172.25.254.254`
  - `example.com` 域：主 DNS 名称服务器
- `bastion` 节点：
  - IP 地址：`172.25.250.254`
  - `lab.example.com` 域：主 DNS 名称服务器
  - `example.com` 域：从 DNS 名称服务器
