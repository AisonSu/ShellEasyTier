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
├── install.sh
├── install_en.sh
├── menu.sh
├── start.sh
├── init.sh
├── version
├── README.md
├── README.zh-CN.md
├── LICENSE
├── ShellEasytier.tar.gz
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

- `https://raw.githubusercontent.com/AisonSu/ShellEasyTier/main`

中文安装入口：

```sh
export url='https://raw.githubusercontent.com/AisonSu/ShellEasyTier/main' && \
sh -c "$(curl -kfsSl "$url/install.sh")" && \
. /etc/profile
```

英文安装入口：

```sh
export url='https://raw.githubusercontent.com/AisonSu/ShellEasyTier/main' && \
sh -c "$(curl -kfsSl "$url/install_en.sh")" && \
. /etc/profile
```

如果你的运行时二进制不放在同一台服务器上，可以：

- 安装时覆盖 `url`
- 或安装后在菜单里修改 `update_url`

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

这样更适合在路由器终端上使用，不会把几十个选项挤在一个页面里。

## 运行时二进制分发

`ShellEasytier.tar.gz` 不包含实际运行二进制。

当前分发方式：

1. `install.sh` 只下载安装脚本主体
2. 首次启动服务时，按当前架构从以下路径下载二进制：
   - `update_url/pkg/<arch>/easytier-core`
   - `update_url/pkg/<arch>/easytier-cli`
   - 如果启用 Web，则再下载 `update_url/pkg/<arch>/easytier-web-embed`

这种方式可以保持安装包很小，同时保留多架构支持能力。

## 发布流程

准备二进制：

```sh
bash prepare_pkg.sh
```

构建脚本发布包：

```sh
bash pack_release.sh
```

如果你使用 GitHub raw 作为默认安装源，那么目标分支根目录下必须同时发布：

- `ShellEasytier.tar.gz`
- `pkg/`

## 推荐发布目标

为了保证一键安装可用，发布根目录应包含：

- `install.sh`
- `install_en.sh`
- `ShellEasytier.tar.gz`
- `pkg/<arch>/...`

典型发布方式：

- GitHub 仓库 raw 文件
- 静态网站目录
- 可公网访问的对象存储

## 开发说明

- 菜单主逻辑：`scripts/menu.sh`
- Core 生命周期：`scripts/start.sh`
- 运行时准备：`scripts/libs/prepare_runtime.sh`
- 启动命令生成：`scripts/libs/build_command.sh`
- 本地 TOML 渲染：`scripts/libs/render_local_toml.sh`

## 许可证

MIT，详见 `LICENSE`。
