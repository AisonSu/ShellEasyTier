# ShellEasyTier

- English
- [简体中文](README.zh-CN.md)

ShellEasyTier is a Shell-based EasyTier deployment and management toolkit for
routers, embedded Linux devices, and generic Linux hosts.

It follows the ShellCrash style of project organization and interaction model,
but focuses on EasyTier's networking lifecycle instead of proxy workflows.

## Features

- Interactive installer for routers and generic Linux
- Dual operation modes:
  - `local`: render local config and start `easytier-core`
  - `remote`: connect to a remote config server and manage client lifecycle
- Architecture-aware runtime binary download
- Optional local `easytier-web-embed`
- Core and Web autostart managed independently
- Local/remote menus split by responsibility
- Advanced feature menus grouped by capability instead of one large flat list
- Designed for OpenWrt, Xiaomi/Redmi routers, Padavan-like firmware, and Linux

## Supported Targets

- Generic Linux
- OpenWrt / procd
- Xiaomi / Redmi router environments
- Padavan-like firmware
- OpenRC systems
- Legacy environments without modern init systems

## Supported Architectures

- `x86_64`
- `aarch64`
- `arm`
- `armhf`
- `armv7`
- `armv7hf`
- `mips`
- `mipsel`

## Repository Layout

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

## Install

Default install source:

- `https://github.com/AisonSu/ShellEasyTier/releases/latest/download`

Chinese installer:

```sh
export url='https://github.com/AisonSu/ShellEasyTier/releases/latest/download' && \
sh -c "$(curl -kfsSl "$url/install.sh")" && \
. /etc/profile
```

English installer:

```sh
export url='https://github.com/AisonSu/ShellEasyTier/releases/latest/download' && \
sh -c "$(curl -kfsSl "$url/install_en.sh")" && \
. /etc/profile
```

If your runtime binaries are hosted on another server, override `url` when
installing, or update `update_url` in the menu after installation.

During installation, ShellEasyTier also asks where runtime binaries should be
stored.

Available storage modes:

- `auto`: choose automatically based on free space
- `persistent`: always store binaries under the install directory
- `tmp`: always store binaries under `/tmp`
- `custom`: store binaries under a custom base path chosen by the user

## Runtime Model

### Local Mode

- Stores core settings in `configs/ShellEasytier.cfg`
- Stores repeated list-style values in dedicated `*.list` files
- Renders runtime config into `TMPDIR`
- Starts `easytier-core -c <generated-config>` plus command-line overrides

### Remote Mode

- Uses `--config-server`
- Uses `--machine-id` for remote config recovery
- Keeps menus focused on remote identity, service control, logs, and runtime
  diagnostics

## Config Files

Primary config:

- `configs/ShellEasytier.cfg`

List configs:

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

ACL config:

- `configs/acl.toml`

Generated command env:

- `configs/command.env`

## Advanced Menus

Advanced features are grouped by capability:

- `监听与发现 / Listeners and Discovery`
- `路由与转发 / Routing and Forwarding`
- `性能与传输 / Performance and Transport`
- `安全与 P2P / Security and P2P`
- `RPC 与日志 / RPC and Logging`
- `ACL 与访问控制 / ACL and Access Control`

This grouping currently covers items such as:

- listeners, mapped listeners, STUN servers, `no-listener`
- port forwarding, relay network whitelist, relay bandwidth limits
- compression, multi-threading, KCP/QUIC proxy options
- encryption, IPv6, P2P, hole punching, relay RPC behavior
- RPC portal, config dir, log levels, file log rotation
- ACL enablement and ACL file path

This keeps the menu manageable on router terminals.

## Runtime Binary Delivery

ShellEasyTier does not bundle binaries into `ShellEasytier.tar.gz`.

Instead:

1. `install.sh` downloads only the script release tarball
2. First service start downloads the current architecture runtime binaries from:
   - `update_url/easytier-core-<arch>`
   - `update_url/easytier-cli-<arch>`
   - `update_url/easytier-web-embed-<arch>` if enabled
3. For backward compatibility, the runtime downloader can still fall back to
   legacy `pkg/<arch>/...` paths when available

This keeps the installer lightweight while preserving multi-architecture support.

## Release Workflow

Prepare binary payloads:

```sh
bash prepare_pkg.sh
```

Build the script release tarball:

```sh
bash pack_release.sh
```

On tag push, GitHub Actions rewrites `version` in workflow workspace, builds the
release tarball, and publishes release assets automatically.

## Recommended Publish Targets

For direct installation to work, the publish root should contain:

- `install.sh`
- `install_en.sh`
- `ShellEasytier.tar.gz`
- `easytier-core-<arch>`
- `easytier-cli-<arch>`
- `easytier-web-embed-<arch>` where supported

Examples:

- GitHub Releases assets
- A static web server
- An object storage bucket with public HTTP access

## Development Notes

- Menu logic is in `scripts/menu.sh`
- Core lifecycle is in `scripts/start.sh`
- Runtime preparation is in `scripts/libs/prepare_runtime.sh`
- Command generation is in `scripts/libs/build_command.sh`
- Local TOML rendering is in `scripts/libs/render_local_toml.sh`

## License

MIT. See `LICENSE`.
