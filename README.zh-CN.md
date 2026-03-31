# ShellEasyTier

- [English](README.md)
- 简体中文

ShellEasyTier 是一个面向路由器、嵌入式 Linux 设备和通用 Linux 主机的
EasyTier Shell 部署与管理工具。

它延续了 ShellCrash 风格的项目组织和交互方式，但关注点放在 EasyTier 的
组网生命周期，而不是代理内核和代理规则。

## 功能特性

- 面向路由器和 Linux 主机的交互式安装器
- 双模式运行：
  - `local`：生成本地配置并启动 `easytier-core`
  - `remote`：连接远程 config-server，仅管理接入、服务和状态
- 按架构下载运行时二进制
- 可选下载并启动本地 `easytier-web-embed`
- Core 和 Web 独立控制开机自启
- `local` / `remote` 菜单按职责拆分
- 高级功能按能力分组，而不是全部堆在一个页面
- 面向路由器场景的自动防火墙与 ShellCrash 兼容增强
- 适配 OpenWrt、红米/小米路由器、Padavan 类固件和通用 Linux

## 支持平台

- 通用 Linux
- OpenWrt / procd
- 小米 / 红米路由器环境
- Padavan 类固件
- OpenRC 系统
- 不带现代 init 的精简 Linux 环境

## 支持架构

- `x86_64`
- `aarch64`
- `arm`
- `armhf`
- `armv7`
- `armv7hf`
- `mips`
- `mipsel`

## 仓库结构

```text
ShellEasytier/
├── install.template.sh
├── uninstall.template.sh
├── build_installers.sh
├── dist/
├── menu.sh
├── start.sh
├── init.sh
├── version
├── README.md
├── README.zh-CN.md
├── LICENSE
├── pkg/
│   └── <arch>/
│       ├── easytier-core
│       ├── easytier-cli
│       ├── easytier-web-embed
│       └── pkg.info
├── configs/
│   └── ShellEasytier.cfg.example
├── scripts/
│   ├── init.sh
│   ├── uninstall.sh
│   ├── start.sh
│   ├── menu.sh
│   ├── libs/
│   ├── starts/
│   ├── menus/
│   └── lang/
├── prepare_pkg.sh
└── pack_release.sh
```

## 安装

默认安装源：

- `https://github.com/AisonSu/ShellEasyTier/releases/latest/download`

中文安装入口：

```sh
export url='https://github.com/AisonSu/ShellEasyTier/releases/latest/download' && \
sh -c "$(curl -kfsSl "$url/install.sh")" && \
. /etc/profile
```

英文安装入口：

```sh
export url='https://github.com/AisonSu/ShellEasyTier/releases/latest/download' && \
sh -c "$(curl -kfsSl "$url/install_en.sh")" && \
. /etc/profile
```

如果你的运行时二进制不放在同一台服务器上，可以：

- 安装时覆盖 `url`
- 或安装后在菜单里修改 `update_url`

ShellEasyTier 会优先尝试正常的 HTTPS 校验。

在部分老旧路由器环境中，如果本机 `curl` / `wget` 的证书能力不完整，
下载链会退化到兼容模式。

这种退化是为了兼容设备，不等于额外建立了更强的信任链，因此仍需要配合
下载后内容验真。

生成后的远程安装/卸载脚本统一输出到 `dist/` 目录。

安装阶段还会询问运行时二进制的存放位置。

可选模式：

- `auto`：按空间自动判断
- `persistent`：始终保存在安装目录下
- `tmp`：始终保存在 `/tmp`
- `custom`：使用用户指定的基础路径

## 卸载

如需完整移除 ShellEasyTier 及其开机接管项：

```sh
sh "$APPDIR/uninstall.sh"
```

发布产物中也会提供：

- `dist/uninstall.sh`
- `dist/uninstall_en.sh`

卸载脚本会移除：

- 开机服务和启动钩子
- `et` 等 profile 别名
- 防火墙恢复钩子和快照固件恢复钩子
- 运行时缓存目录
- 安装目录本身

## 运行模式

### Local 模式

- 主配置保存在 `configs/ShellEasytier.cfg`
- 重复项配置保存在各类 `*.list` 文件中
- 运行时配置生成到 `TMPDIR`
- 最终通过 `easytier-core -c <生成配置>` 配合命令行参数启动

### Remote 模式

- 使用 `--config-server`
- 使用 `--machine-id` 做远程配置恢复
- 菜单主要聚焦于远程身份、服务控制、日志和运行诊断

## 配置文件

主配置：

- `configs/ShellEasytier.cfg`

列表配置：

- `configs/peers.list`
- `configs/listeners.list`
- `configs/mapped_listeners.list`
- `configs/proxy_networks.list`
- `configs/manual_routes.list`
- `configs/exit_nodes.list`
- `configs/port_forward.list`
- `configs/stun_servers.list`
- `configs/stun_servers_v6.list`
- `configs/external_nodes.list`
- `configs/relay_network_whitelist.list`

ACL 配置：

- `configs/acl.toml`

生成的命令环境文件：

- `configs/command.env`

## 高级功能分组

高级功能已经按能力拆分为以下子菜单：

- `监听与发现`
- `路由与转发`
- `性能与传输`
- `安全与 P2P`
- `RPC 与日志`
- `ACL 与访问控制`

当前这些分组已经覆盖：

- listeners、mapped listeners、STUN servers、`no-listener`
- 端口转发、relay-network-whitelist、转发带宽限制
- compression、多线程、KCP/QUIC 代理选项
- 加密、IPv6、P2P、打洞、RPC 中继行为
- RPC 门户、config-dir、日志级别、文件日志轮转
- ACL 开关与 ACL 文件路径

这样更适合在路由器终端上使用，不会把几十个选项挤在一个页面里。

## 兼容增强模式

ShellEasyTier 现在内置了一套轻量的“兼容与防火墙”增强逻辑，主要面向
OpenWrt / 路由器环境，尤其是与 ShellCrash 共存的场景。

默认会尽量自动完成以下事情：

- 自动识别局域网接口
- 自动识别 EasyTier TUN 接口
- 自动添加 LAN <-> TUN 的转发放行规则
- 自动添加 MASQUERADE，实现对端尽量零配置回程
- 检测到 ShellCrash 时自动添加绕过规则
- 自动修正常见的高 metric 残留路由
- 平台支持时自动挂载防火墙重载恢复钩子

同时菜单中只保留少量必要开关：

- 是否启用兼容增强
- 是否启用 ShellCrash 绕过
- 是否启用 MASQUERADE
- 是否启用路由 metric 修正
- 仅在自动识别不准时，允许手工覆盖 LAN / TUN 接口名

设计目标是：

- 默认尽量智能
- 让小白用户少填参数
- 但依然保留必要的可控性

## 运行时二进制分发

`ShellEasytier.tar.gz` 不包含实际运行二进制。

当前分发方式：

1. `install.sh` 只下载安装脚本主体
2. 首次启动服务时，按当前架构从以下路径下载二进制：
   - `update_url/easytier-core-<arch>`
   - `update_url/easytier-cli-<arch>`
   - 如果启用 Web，则再下载 `update_url/easytier-web-embed-<arch>`
3. 为兼容旧式发布目录，也支持回退到 `pkg/<arch>/...` 路径

当本机下载工具无法在弱设备上完成严格 TLS 校验时，ShellEasyTier 可能回退到
兼容模式下载，然后再做最基本的下载后验真。

这种方式可以保持安装包很小，同时保留多架构支持能力。

## 发布流程

准备二进制：

```sh
bash prepare_pkg.sh
```

生成多语言远程安装/卸载脚本：

```sh
bash build_installers.sh
```

构建脚本发布包：

```sh
bash pack_release.sh
```

构建产物统一输出到 `dist/`。

当推送 tag 时，GitHub Actions 会在工作流中自动改写 `version` 文件、构建
发布包，并自动发布 release assets。

## 推荐发布目标

为了保证一键安装可用，发布根目录应包含：

- `install.sh`
- `install_en.sh`
- `uninstall.sh`
- `uninstall_en.sh`
- `ShellEasytier.tar.gz`
- `ShellEasytier.tar.gz.sha256`
- `easytier-core-<arch>`
- `easytier-cli-<arch>`
- `easytier-web-embed-<arch>`（支持的架构）

典型发布方式：

- GitHub Releases 资产
- 静态网站目录
- 可公网访问的对象存储

发布资产会同时提供对应的 `.sha256` 校验文件。

## 开发说明

- 菜单主逻辑：`scripts/menu.sh`
- Core 生命周期：`scripts/start.sh`
- 运行时准备：`scripts/libs/prepare_runtime.sh`
- 启动命令生成：`scripts/libs/build_command.sh`
- 本地 TOML 渲染：`scripts/libs/render_local_toml.sh`

## 文档

- `docs/README.md`
- `docs/shellcrash-compatibility.zh-CN.md`

## 许可证

MIT，详见 `LICENSE`。
