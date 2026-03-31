# CURRENT-STATUS.md

This file is a tracked project-state snapshot for conversation recovery.

Use it to answer:

- what is already finished
- what is intentionally supported
- what is still pending or only partially verified
- what should be tested next

## Release Snapshot

- Last updated for context handoff: 2026-03-31
- Latest released tag target: `v0.2.1`
- `v0.2.1` currently points to: `7397bdd`
- `v0.2.1` includes the snapshot boot recovery, alias persistence, and
  autostart loop fixes validated during the latest AX6000 test round

## Current Workspace Note

The repository may still contain newer local-only documentation or handoff-file
changes that are not part of the latest released tag.

When resuming work after context loss, always check:

```sh
git status --short
git log --oneline -n 5
git tag --list --sort=-version:refname | sed -n '1,5p'
```

This prevents confusing “latest local state” with “latest released state”.

## Current Product State

`ShellEasyTier` is now in a usable router-oriented state with the following core
capabilities implemented:

- interactive installer for fresh install and upgrade install
- `local` mode and `remote` mode with clearly separated main menus
- runtime binary download separated from the script tarball
- configurable runtime binary placement:
  - `auto`
  - `persistent`
  - `tmp`
  - `custom`
- `easytier-web-embed` as the only supported local web mode
- core and web autostart configured independently
- advanced settings grouped by capability instead of one giant flat page
- automatic firewall and ShellCrash compatibility enhancement for router targets
- snapshot-firmware boot recovery that restores profile alias, service files,
  and core/web autostart
- standalone uninstall path with startup hook cleanup

## Current Release Model

- default installer source points to GitHub Releases `latest/download`
- `ShellEasytier.tar.gz` must remain a lightweight script-only bundle
- runtime binaries are expected as separate release assets:
  - `easytier-core-<arch>`
  - `easytier-cli-<arch>`
  - `easytier-web-embed-<arch>`
- release workflow now validates the expected runtime asset matrix before publish
- legacy fallback to `pkg/<arch>/...` is still supported for compatibility and
  test-server usage

## Implemented Feature Areas

### Installer

- interactive install path
- upgrade detection
- alias/profile injection
- default alias choice now prefers `se` while still allowing custom aliases
- install-time `url` override
- install-time runtime binary storage selection
- install-time web component selection

### Modes

- `local` mode: local config generation + runtime flags
- `remote` mode: config-server driven client mode with focused menus

### Menu UX

- mode-dependent main menu layout
- state-driven visibility for tools/status
- state-driven service/web start/stop entries
- restart prompt after config changes
- current effective value rendering
- grouped advanced settings menus

### Runtime

- shell-safe command persistence in `command.env`
- manual interactive start separated from daemon-run path
- runtime logs written to `/tmp/ShellEasytier/`
- shared readiness checks now require `pid + rpc_portal + easytier-cli node`
- web readiness now checks both process and local web API port listening
- start failure fuse writes `.start_error` and disables future autostart
- procd stop path no longer recurses through `start.sh stop`
- menu CLI queries no longer shell-wrap `easytier-cli` through `sh -c`

### Boot Recovery

- snapshot boot recovery script with lock + late initialization
- `firewall include` trigger plus `/data/auto_start.sh` fallback on Xiaomi
  snapshot targets
- alias restoration follows saved `my_alias`
- service file restoration re-enables autostart without force-restarting an
  already-running core
- compatibility and recovery hooks now gate on shared readiness probes instead
  of raw pid-only shortcuts

### Uninstall

- generated `dist/uninstall.sh` / `dist/uninstall_en.sh` remote entrypoints
- `scripts/uninstall.sh` full cleanup path
- uninstall cleanup removes profile aliases, startup hooks, system services, and
  snapshot recovery artifacts

### Release Assets

- generated `dist/install.sh` / `dist/install_en.sh`
- generated `dist/uninstall.sh` / `dist/uninstall_en.sh`
- generated `dist/ShellEasytier.tar.gz`
- generated `.sha256` files for release assets
- release workflow validates runtime asset matrix before publish

### Compatibility

- LAN interface auto-detection
- TUN interface auto-detection
- ShellCrash detection
- `FORWARD` rule insertion
- `POSTROUTING MASQUERADE`
- ShellCrash bypass chain insertion
- route metric cleanup / repair
- persistence hook via `/etc/firewall.d` or `/etc/firewall.user`
- human-readable compatibility status output

### Docs / Repo

- English README
- Chinese README
- compatibility troubleshooting docs
- `AGENTS.md`
- `SELF-DEV-AGENT.md` for local-only personal workflow
- CI + Release GitHub Actions workflows

## Current Known Good Behaviors

### WSL-verified

- installer runs
- localized install/uninstall assets generate into `dist/`
- release tarball builds into `dist/`
- `dist/` assets now include matching `.sha256` files
- local/remote mode switching works
- runtime binaries download correctly
- remote mode can connect to config-server
- local mode can start with current command generation
- local `node/peer/route` menu flow was repaired via RPC portal adjustments
- web-start / web-stop works when `install_web=ON`
- syntax checks pass for updated boot-recovery and startup scripts

### Router-validated

- AX6000 installs interactively
- compatibility detection can identify:
  - LAN interface
  - EasyTier TUN interface
  - ShellCrash presence
  - LAN subnet and routed EasyTier subnets
- compatibility rules are applied and visible in iptables
- cold reboot on AX6000 now restores the saved alias, recreates
  `/etc/init.d/shelleasytier`, and auto-starts `easytier-core`
- Xiaomi snapshot path no longer falls into the previously observed autostart /
  stop recursion loop

## Current Design Boundaries

- only `easytier-web-embed` is supported for local web
- no non-embed split web mode
- no multi-instance support
- compatibility layer is currently optimized for ShellCrash coexistence first
- remote mode tools remain intentionally simpler than local mode tools
- Xiaomi snapshot targets currently use a conservative dual-entry boot recovery
  model (`firewall include` + `/data/auto_start.sh` fallback)

## Current Known Limitations / Watchpoints

- WSL autostart is not representative of router autostart and should not be
  treated as a release blocker for router-focused behavior
- GitHub release assets must actually exist before `latest/download` becomes a
  trustworthy installer source
- test HTTP server may still be required for fast router validation before
  trusting GitHub Releases end-to-end
- multi-overlay coexistence beyond ShellCrash (for example future
  ShellTailscale integration) is not finished yet
- compatibility logic is intentionally minimal-input, which means weird custom
  topologies may still require interface overrides
- snapshot boot recovery is now stable enough for AX6000 testing, but the dual
  entry model should remain until more cold-boot validation is accumulated

## Current Open Questions

- whether additional router-facing compatibility guidance should be surfaced in
  the installer or docs
- how far to go with automatic handling for other overlay systems beyond
  ShellCrash
- whether to add a richer ACL editor/wizard instead of file-only ACL path
  management
- how much strict validation should be added to advanced menu inputs
- whether Xiaomi snapshot boot recovery can eventually collapse back to a single
  stable entry once enough cold-boot evidence exists
- whether `se` should remain the long-term default alias or become an
  installer-only safe default

## Recommended Next Work

1. Validate GitHub Release assets end-to-end for `v0.2.1` against the current
   `latest/download` model
2. Continue cold-boot validation on Xiaomi / snapshot targets to decide whether
   the dual boot hook model can be simplified
3. Continue improving compatibility UX for novice users
4. Add validation for advanced numeric / enum inputs

## Recovery Advice For New Sessions

If context is lost, read in this order:

1. `CURRENT-STATUS.md`
2. `AGENTS.md`
3. `README.zh-CN.md` or `README.md`
4. `SELF-DEV-AGENT.md` if local workflow details are needed

Then inspect these source files first:

- `scripts/libs/get_config.sh`
- `scripts/libs/build_command.sh`
- `scripts/libs/set_profile.sh`
- `scripts/libs/prepare_runtime.sh`
- `scripts/libs/pkg_profile.sh`
- `scripts/libs/compatibility.sh`
- `scripts/starts/snapshot_init.sh`
- `scripts/starts/start_error.sh`
- `scripts/starts/shelleasytier.procd`
- `scripts/menu.sh`
- `scripts/start.sh`
