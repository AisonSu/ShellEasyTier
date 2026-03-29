# ShellCrash 兼容与网对网排错实录

本文整理了在小米路由器 / OpenWrt 环境中使用 EasyTier 做子网代理、网对网时的完整排错思路，尤其覆盖了与 `ShellCrash` / Clash / Mihomo 并存时的兼容性问题。

这不是一篇泛化到所有 Linux 主机的“理论说明”，而是一份面向路由器实战的经验总结。

## 文档目标

- 解释为什么官方 `network-to-network` 文档在 OpenWrt 场景下显得过于简略
- 记录从“端口未联通”到“可长期稳定运行”的完整排错路径
- 区分哪些结论是普遍规律，哪些是当前网络环境的场景特例
- 为后续把这套兼容逻辑沉淀到 `ShellEasyTier` 提供依据

## 问题起点

故障环境：

- 设备：小米路由器 / OpenWrt
- 组件：EasyTier + ShellCrash
- 现象：
  - 局域网电脑 `ping 192.168.8.16` 返回“来自 192.168.31.1：端口未联通”
  - 局域网无法 `ping 10.126.126.126`

排查起点：

```sh
ip addr | grep tun
ip route | grep tun
iptables -L FORWARD -v -n | head -10
```

早期关键信息：

- EasyTier `tun0` 已存在
- 到 `10.126.126.0/24` 的路由已存在
- OpenWrt `FORWARD` 默认策略为 `DROP`

这意味着：**即使 EasyTier 已经创建了 TUN 和路由，跨接口流量仍可能被路由器自身的防火墙拒绝。**

## 第一阶段：基础连通性修复

最先确认的是：OpenWrt 上 EasyTier 的流量仍然走内核网络栈。

无论是否开启 `--proxy-forward-by-system`，只要使用 TUN，局域网访问路径都仍然是：

```text
br-lan -> 内核路由 -> FORWARD 链 -> tun0 -> 对端
```

因此，最基础的修复是：

```sh
iptables -I FORWARD -i br-lan -o tun0 -j ACCEPT
iptables -I FORWARD -i tun0 -o br-lan -j ACCEPT
```

但仅靠放行还不够，因为还存在**回程路由**问题。

### 为什么需要 MASQUERADE

如果局域网电脑以 `192.168.31.x` 为源地址访问远端子网，对端设备往往并不知道如何返回这个网段。

因此需要：

```sh
iptables -t nat -I POSTROUTING -s 192.168.31.0/24 -o tun0 -j MASQUERADE
```

这样对端看到的来源会变成 EasyTier 虚拟网段地址，回复包可以自然回到本端，再由路由器做 NAT 还原。

**结论**：如果目标是“对端零配置”，那在路由器侧做 NAT 通常是最实用的方案。

## 第二阶段：为什么官方 network-to-network 文档不够用

官方页面：

- `https://easytier.cn/guide/network/network-to-network.html`

这页文档本质上是一个**功能示意页**，而不是适用于 OpenWrt / 小米路由器 / ShellCrash 共存环境的完整部署指南。

它的成立前提非常理想化：

- 节点本身就是子网网关
- 没有复杂防火墙默认策略
- 没有额外 TUN 设备竞争
- 没有 DNS 劫持
- 没有 ShellCrash 之类的透明代理
- 回程路由天然成立，或者读者会自己补齐

它之所以在你的环境“不工作”，不是因为文档内容完全错误，而是因为它遗漏了路由器环境下最关键的几件事：

1. **没有讲 NAT / 回程路由**
2. **没有按 OpenWrt zone / FORWARD DROP 模型写**
3. **没有讲 metric 优先级竞争**
4. **没有考虑 ShellCrash / Clash / 双 TUN**
5. **没有讲如何持久化和防规则被覆盖**

一句话说：

> 官方文档讲的是“EasyTier 支持网对网”，不是“在 OpenWrt + 小米路由器 + ShellCrash 环境下怎样稳定地做网对网”。

## 第三阶段：ShellCrash 介入后的复杂化

当系统同时启用了 ShellCrash 透明代理，环境会从单一 TUN 变成双 TUN：

- EasyTier：`tun0`
- ShellCrash：`utun`

这时问题不再只是“防火墙没放行”，而是出现了三类竞争：

### 1. 路由优先级竞争

实测里曾出现：

```text
192.168.8.0/24 dev tun0 metric 65535
```

`metric 65535` 几乎是最低优先级。如果同时存在 ShellCrash 构造的更高优先级路由，流量根本不会走 `tun0`。

### 2. DNS 劫持竞争

ShellCrash 会劫持 53 端口，例如：

```sh
iptables -t nat -L PREROUTING | grep 53
```

这可能导致 EasyTier 内网域名、远端主机名解析被 Fake-IP 或代理 DNS 影响。

### 3. 防火墙规则覆盖

ShellCrash 可能在模式切换、重启、重建规则时重置 iptables，导致手工加入的 EasyTier 兼容规则被清空。

因此会出现一种典型现象：

- 刚修完可用
- 过一段时间又失效
- 不是 EasyTier 自己变了，而是规则被 ShellCrash 覆盖了

## 第四阶段：兼容性完整方案

为了兼顾：

- 局域网访问远端子网
- 对端零配置
- ShellCrash 代理仍然正常可用
- 系统重启后可恢复

完整方案至少包括以下几部分。

### 1. 修正路由优先级

```sh
ip route del 192.168.8.0/24 dev tun0 metric 65535 2>/dev/null
ip route add 192.168.8.0/24 dev tun0 metric 10 2>/dev/null
ip route add 10.126.126.0/24 dev tun0 metric 10 2>/dev/null
```

### 2. 基础防火墙放行

```sh
iptables -I FORWARD -i br-lan -o tun0 -j ACCEPT
iptables -I FORWARD -i tun0 -o br-lan -j ACCEPT
```

### 3. 零配置回程的 NAT

```sh
iptables -t nat -I POSTROUTING -s 192.168.31.0/24 -o tun0 -j MASQUERADE
```

### 4. 防止 ShellCrash 劫持 EasyTier 流量

```sh
iptables -t nat -I PREROUTING -s 192.168.31.0/24 -d 10.126.126.0/24 -j RETURN
iptables -t nat -I PREROUTING -s 192.168.31.0/24 -d 192.168.8.0/24 -j RETURN
```

### 5. Clash / Mihomo 层直连绕过

在 ShellCrash 使用的规则配置里补：

```yaml
rules:
  - IP-CIDR,10.126.126.0/24,DIRECT,no-resolve
  - IP-CIDR,192.168.8.0/24,DIRECT,no-resolve
  - IP-CIDR,192.168.31.0/24,DIRECT,no-resolve
```

否则即使系统路由正确，代理规则也可能把流量错误地送进 `utun`。

### 6. 使用 firewall.d 持久化恢复

因为 ShellCrash 会重建自己的规则，EasyTier 兼容规则最好放进持久化脚本，在防火墙重启后重新应用。

示例思路：

- 等待 ShellCrash 初始化完成
- 重新添加 EasyTier 路由
- 重新添加 `FORWARD` 放行
- 重新添加 `POSTROUTING MASQUERADE`
- 重新添加 `PREROUTING RETURN`

## 第五阶段：哪些结论是普遍的，哪些是场景特例

### 普遍规律

这些结论具有通用性：

- OpenWrt 路由器上，TUN 流量通常仍受内核转发与防火墙控制
- 做子网代理时，常常要在“回程路由”和“MASQUERADE”之间二选一
- 与 ShellCrash 共存时，需要额外处理路由、DNS 和防火墙竞争
- 手工修复通常必须再做持久化，否则会被系统或代理脚本覆盖

### 场景特例

这些值不能写死在程序里，只能参数化：

- `br-lan`
- `tun0`
- `utun`
- `192.168.31.0/24`
- `192.168.8.0/24`
- `10.126.126.0/24`
- `shellcrash_dns`
- Clash 配置文件路径

因此，后续如果要把这套兼容性做进 `ShellEasyTier`，应该做成：

- 检测
- 引导
- 参数化配置
- 可选启用

而不是直接把这些固定值硬编码进主流程。

## 对 ShellEasyTier 的落地建议

如果要把这次经验沉淀进 `ShellEasyTier`，更合理的方式是新增一个：

- `ShellCrash 兼容` 子菜单 / 兼容模式

建议能力包括：

1. 自动检测是否存在 ShellCrash
2. 自动识别 LAN 网段与 EasyTier TUN 接口
3. 生成防火墙兼容规则
4. 生成 `firewall.d` 持久化脚本
5. 提示用户补 Clash `DIRECT` 规则
6. 将“对端零配置”与“显式回程路由”作为两种模式供用户选择

## 一键修复命令（当前案例）

以下命令适用于当前案例环境，用于快速恢复：

```sh
ip route add 192.168.8.0/24 dev tun0 metric 10 2>/dev/null; \
iptables -I FORWARD -i br-lan -o tun0 -j ACCEPT; \
iptables -I FORWARD -i tun0 -o br-lan -j ACCEPT; \
iptables -t nat -I POSTROUTING -s 192.168.31.0/24 -o tun0 -j MASQUERADE; \
iptables -t nat -I PREROUTING -s 192.168.31.0/24 -d 10.126.126.0/24 -j RETURN; \
iptables -t nat -I PREROUTING -s 192.168.31.0/24 -d 192.168.8.0/24 -j RETURN; \
echo "修复完成"
```

注意：

- 这是**当前案例环境**的一键修复命令
- 不是适用于所有 OpenWrt / ShellCrash / EasyTier 环境的固定模板

## 总结

从“端口未联通”一路排到最终稳定运行，真正形成的认知不是“再补几条 iptables 就好了”，而是：

1. EasyTier 的子网代理在路由器上一定要放回内核网络栈和防火墙模型里理解
2. 对端零配置的关键通常不是路由，而是 NAT
3. 一旦引入 ShellCrash，问题就会变成“多系统竞争”，而不是单一 EasyTier 配置问题
4. 稳定性来自规则持久化与旁路规则，而不是一次性手工修复

这份文档的目的，不是替代官方文档，而是补足官方文档在路由器与双 TUN 场景下没有展开的现实细节。
