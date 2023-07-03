## DHCP 原理与配置

### DHCP 的作用：
- DHCP (Dynamic Host Configuration Protocol，动态主机配置协议)，为网络中的设备提供动态 IP 地址信息，包括 IP 地址、网关、DNS 等。
- DHCP 可以使得整网络的地址分配变得非常简单，大大降低了网络管理员的工作量。
- DHCP 基于 `UDP` 协议，采用端口号为 `67` 和 `68`，其中 68 端口为 DHCP 客户端采用，67 端口为 DHCP 服务端采用。

### DHCP 的优缺点：
- 优点：
  - 网络管理员可以验证 IP 地址和其它配置参数，而不用去检查每个主机。
  - DHCP 不会同时租借相同的 IP 地址给两台主机
  - DHCP 管理员可以约束特定的计算机使用特定的 IP 地址
  - 可以为每个 DHCP 作用域设置很多选项
  - 客户机在不同子网间移动时不需要重新设置 IP 地址
- 缺点：
  - DHCP 不能发现网络上非 DHCP 客户机已经在使用的 IP 地址
  - 当网络上存在多个 DHCP 服务器时，一个 DHCP 服务器不能查出已被其它服务器租出去的 IP 地址。
  - DHCP 服务器不能跨路由器与客户机通信，除非路由器允许 `BOOTP` 转发。

### DHCP 的工作流程：
- **发现阶段**：DHCP Client 运行后寻找 DHCP Server 的阶段，以广播的方式发送 **`DHCPDISCOVER`** 消息（由于 DHCP Server 的 IP 地址对于 Client 来说是未知的）发送 DHCPDISCOVER 消息来寻找 DHCP Server，即向 `255.255.255.255` 地址发送特定的广播信息。网络上每一台安装了 TCP/IP 协议的主机都会接收到这种广播信息，但只有 DHCP Server 才会做出响应。
- **提供阶段**：DHCP Server 提供 IP 地址的阶段，DHCP Server 收到 DHCPDISCOVER 消息后，从 IP 地址池中选择一个尚未租用的 IP 地址，以单播的方式发送 **`DHCPOFFER`** 消息给客户端。
- **请求阶段**：也称为 **选择阶段**，DHCP Client 选择某台 DHCP Server 提供的 IP 地址的阶段，DHCP Client 收到 DHCPOFFER 消息后，以广播方式发送一个 **`DHCPREQUEST`** 消息，该 DHCPREQUEST 消息携带 DHCP Server 的标识，意图向 Server 请求获取 DHCPOFFER 中提供的 IP 地址。DHCP Client 若收到多份 DHCPOFFER 信息，一般取第一个收到的，其他的 Server 收到 DHCPREQUEST 广播后，会明白 Client 拒绝了自己的 DHCPOFFER，进而收回给予该 Client 的 DHCPOFFER。之所以要以广播方式应答，是为了通知所有的 DHCP Server，Client 将选择某台 DHCP Server 所提供的 IP 地址。
- **确认阶段**：DHCP Server 确认所提供的 IP 地址的阶段，DHCP Server 收到 DHCPREQUEST 消息后，向 Client 发送单播 **`DHCPACK`** 消息，确认获取 IP 地址成功，或者单播发送 **`DHCPNAK`** 消息，说明 IP 地址获取失败，需要重新获取 IP 地址。
- **重新登录**：以后 DHCP Client 每次重新登录网络时，就不需要再发送 DHCPDISCOVER 发现消息了，而是直接发送包含前一次所分配的 IP 地址的 DHCPREQUEST 请求消息。当 DHCP Server 收到这一消息后，它会尝试让 DHCP Client 继续使用原来的 IP 地址，并响应一个 DHCPACK 确认消息。如果此 IP 地址已无法再分配给原来的 DHCP Client 使用时（比如此 IP 地址已分配给其它 DHCP Client 使用），则 DHCP Server 给 DHCP Client 响应一个 DHCPNAK 否认消息。当原来的 DHCP Client 收到此 DHCPNAK 否认消息后，它就必须重新发送 DHCPDISCOVER 发现消息来请求新的 IP 地址。
- **更新租约**：DHCP Server 向 DHCP Client 出租的 IP 地址一般都有租借期限，期满后 DHCP Server 便会收回出租的 IP 地址。如果 DHCP Client 要延长其 IP 租期，则必须更新其 IP 租期。DHCP Client 启动时和 IP 租期期限过一半时，DHCP Client 都会自动向 DHCP Server 发送更新其 IP 租期的信息。

### DHCP 原理图解：
- DHCP 工作流示意：
  ![](https://github.com/Alberthua-Perl/sc-col/blob/master/dhcp-server-conf/dhcp-request-response-demo.png)  
- [DHCP Client 抓包](https://github.com/Alberthua-Perl/sc-col/blob/master/dhcp-server-conf/dhcp-client-auto.pcap) 示意：
  ![](https://github.com/Alberthua-Perl/sc-col/blob/master/dhcp-server-conf/wireshark-dhcp-client-pcap.png)  
