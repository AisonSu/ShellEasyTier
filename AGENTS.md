# AGENTS.md

This file applies to the entire `ShellEasytier/` repository tree.

## Project Purpose

`ShellEasyTier` is a Shell-based EasyTier deployment and management toolkit for:

- OpenWrt / procd routers
- Xiaomi / Redmi router environments
- Padavan-like firmware
- OpenRC systems
- Generic Linux hosts

It is intentionally closer to a **router-friendly orchestrator** than a generic
desktop wrapper.

## Working Principles

- Prefer small, targeted changes over clever abstractions.
- Preserve the current split between `local` mode and `remote` mode.
- Default to POSIX / ash-friendly shell. Do not introduce bash-only syntax into
  runtime scripts unless the file is already explicitly bash-only.
- Keep generated artifacts out of git unless the user explicitly asks.
- Respect the release model: lightweight script tarball, runtime binaries as
  separate assets.

## Files That Define Core Behavior

- `install.template.sh`, `uninstall.template.sh`: source templates for localized remote entry scripts
- `build_installers.sh`: generates localized install/uninstall scripts into `dist/`
- `scripts/init.sh`: initialization, migration, service registration, profile
  injection
- `scripts/start.sh`: runtime lifecycle entrypoint
- `scripts/menu.sh`: user-facing interactive menu
- `scripts/libs/get_config.sh`: defaults + effective config loading
- `scripts/libs/set_profile.sh`: selected alias persistence + profile recovery
- `scripts/libs/build_command.sh`: local/remote command generation
- `scripts/libs/prepare_runtime.sh`: runtime binary download and placement
- `scripts/libs/pkg_profile.sh`: architecture + storage layout decision
- `scripts/libs/compatibility.sh`: firewall / ShellCrash compatibility layer
- `scripts/starts/snapshot_init.sh`: snapshot-firmware boot recovery and late
  startup repair
- `scripts/uninstall.sh`: installed full cleanup logic

## Session Recovery Checklist

If the conversation context is lost, re-establish project state in this order:

1. Read `CURRENT-STATUS.md` for the latest tracked project snapshot.
2. Read `README.md` and `README.zh-CN.md` for current install and release model.
3. Inspect `scripts/libs/get_config.sh` for effective defaults.
4. Inspect `scripts/menu.sh` for the current menu structure and mode split.
5. Inspect `scripts/libs/build_command.sh` for how local/remote commands are
   actually generated.
6. Inspect `scripts/libs/prepare_runtime.sh` and `scripts/libs/pkg_profile.sh`
   for runtime binary placement and download rules.
7. Inspect `scripts/libs/compatibility.sh` for firewall/ShellCrash coexistence
   logic.
8. Inspect `scripts/starts/snapshot_init.sh` and `scripts/libs/set_profile.sh`
   for snapshot boot recovery and alias persistence behavior.

When debugging a live router install, the minimum runtime files to inspect are:

- `/etc/ShellEasytier/configs/ShellEasytier.cfg` or `/data/ShellEasytier/configs/ShellEasytier.cfg`
- `configs/command.env`
- `/tmp/ShellEasytier/ShellEasytier.log`
- `/tmp/ShellEasytier/easytier-core.run.log`
- `/tmp/ShellEasytier/easytier-web.run.log`

## Current Operational Model

- Script bundle is light; runtime binaries are downloaded separately.
- Default install source points to GitHub Releases `latest/download`.
- Runtime binary download prefers flat release assets and may fall back to
  legacy `pkg/<arch>/...` paths.
- `local` mode and `remote` mode must remain different products in one UI, not
  one blended mode.
- The router compatibility layer is enabled by default and should remain low-
  input for end users.
- Xiaomi / snapshot-like targets currently use a conservative boot recovery
  model: early `firewall include` trigger plus `/data/auto_start.sh` late
  fallback.
- Alias recovery must follow saved `my_alias`; the default installer choice is
  currently `se`.

## Current Release Contract

The current expected delivery model is:

- installer base URL points to GitHub Releases `latest/download`
- `ShellEasytier.tar.gz` contains scripts only
- runtime binaries are separate assets
- runtime binary downloader prefers flat release assets and may fall back to
  legacy `pkg/<arch>/...` paths

At this point in the project, the following assumptions should be treated as
current truth unless the user explicitly changes them:

- release tarball size should remain in the tens-of-KB range
- `pkg/` is a distribution source or fallback source, not part of the script
  release bundle
- test HTTP servers may still expose legacy `pkg/` paths even after switching
  the default release source to GitHub Releases

## Current Menu Model

- Main menu is state-driven, not static.
- Tools/status should only appear when core is running.
- Service/Web menus should expose state-appropriate actions.
- Effective values, not raw config file text, should be shown whenever possible.
- Advanced features should stay grouped by capability.

## Menu Stability Rules

- Do not casually reorder top-level menu responsibilities.
- `local` and `remote` must remain distinct top-level experiences.
- Do not reintroduce a flat advanced settings page.
- Do not expose tools/status views before the relevant runtime is actually
  available.
- Service menus should behave like state toggles when possible.
- When changing menu layout, preserve the idea that novice users should not need
  to understand every low-level EasyTier flag before getting a usable system.

## User Experience Priorities

Prefer these priorities in order:

1. A working install / start / stop path
2. Clear mode separation
3. Sensible automatic detection and defaults
4. Human-readable diagnostics
5. Advanced override points only where needed

This project is optimized for router operators first, not for exposing every
possible internal implementation detail up front.

## Current Debugging Priorities

When something breaks, debug in this order:

1. Install / upgrade path
2. Runtime binary preparation
3. Command generation and quoting
4. Core start / status path
5. Snapshot boot recovery chain (`firewall include`, `/data/auto_start.sh`,
   profile restore, service restore)
6. Web start / status path
7. Compatibility layer side effects
8. Menu visibility and restart prompts
9. Release packaging / artifact publishing

Do not jump straight into advanced menu changes before confirming the core
install-start-status chain is healthy.

## Troubleshooting First Steps

When a user reports a runtime issue, inspect these in order:

1. `/tmp/ShellEasytier/ShellEasytier.log`
2. `/tmp/ShellEasytier/easytier-core.run.log`
3. `/tmp/ShellEasytier/easytier-web.run.log`
4. `configs/command.env`
5. `start.sh status` / `start.sh compat-status`

For snapshot-firmware reboot / alias / autostart issues, inspect in this order:

1. `uci show firewall.ShellEasytier`
2. `grep 'ShellEasytier初始化脚本' /data/auto_start.sh`
3. `grep 'ShellEasytier/menu.sh' /etc/profile`
4. `ls -l /etc/init.d/shelleasytier`
5. `pidof easytier-core`

For router networking issues specifically, prefer checking:

- compatibility status output
- route table for stale metrics
- actual iptables chain presence
- whether ShellCrash is currently detected

## Hard Project Invariants

### 1. `local` and `remote` mode must stay clearly separated

- `remote` mode menus should only expose remote-relevant configuration and
  diagnostics.
- `local` mode menus may expose local networking, routing, and advanced runtime
  options.
- Do not casually mix `local`-only CLI diagnostics into `remote` mode.

### 2. `get_config.sh` must not recurse into `init.sh`

- Config loading must be safe to run repeatedly.
- Do not reintroduce `init.sh -> get_config.sh -> init.sh` recursion.
- Missing config should be recovered by copying an example/default file, not by
  source-calling the initializer.

### 3. `command.env` values must be shell-safe

- Any persisted command string must survive `source` without being split or
  partially executed.
- When changing command generation, make sure command strings are stored as safe
  shell literals.

### 4. Release tarball must stay lightweight

- `ShellEasytier.tar.gz` is the script release bundle only.
- It must not include `pkg/`, runtime binaries, `dist/`, or generated runtime
  files.
- Be careful with case-sensitive path exclusions in `pack_release.sh`.

### 5. Runtime binaries are separate assets

- Runtime download currently prefers release-style flat assets:
  - `easytier-core-<arch>`
  - `easytier-cli-<arch>`
  - `easytier-web-embed-<arch>`
- Legacy fallback to `pkg/<arch>/...` still exists for compatibility and test
  servers.
- Do not break fallback unless the user explicitly requests removal.

### 6. Menu output must be state-driven

- When core is not running, hide or reduce tools/status views.
- Service/Web menus should show start vs stop actions according to current
  runtime state.
- Current values shown in menus should reflect **effective values**, including
  defaults, not only raw file contents.

### 7. Compatibility mode should stay simple by default

The firewall/ShellCrash compatibility layer is intentionally designed to be:

- auto-detect first
- minimal in required user input
- overridable only when auto-detection is wrong

Avoid turning compatibility into a giant expert-only configuration page.

### 8. Early boot hooks must stay trigger-only

- Anything entered via `firewall include`, `firewall.user`, or platform boot
  snippets must return quickly.
- Do not put foreground wait loops, long sleeps, or heavy stop/start service
  logic directly in early boot hooks.
- If late resources are needed, trigger a background recovery script and let it
  own the waiting.

### 9. Alias recovery must follow saved `my_alias`

- Reboot recovery should write the configured alias only, not a bundle of
  fallback aliases.
- Alias/profile restoration must not be skipped just because `easytier-core` is
  already running.
- Profile changes must remain reversible during uninstall/cleanup.

### 10. Service-manager stop paths must not recurse

- `stop_service()` for procd/systemd/OpenRC wrappers must kill the managed
  process directly.
- Do not re-enter the public `start.sh stop` dispatcher from service-manager
  callbacks.
- Failure fuses should disable future autostart, not only drop a marker file.

## When Adding Or Changing Config Keys

If you add a new persistent config item, check whether it must also be updated
in these places:

1. `configs/ShellEasytier.cfg.example`
2. `scripts/libs/get_config.sh` default assignment
3. `scripts/libs/build_command.sh` or `scripts/libs/render_local_toml.sh`
4. `scripts/menu.sh` if it is user-facing
5. `scripts/lang/chs/menu.lang`
6. `scripts/lang/en/menu.lang`
7. `snapshot_core_runtime_config()` or `snapshot_web_runtime_config()` if it
   should trigger restart prompts
8. README/docs if the setting affects installation, release flow, or runtime
   behavior

## Change Impact Matrix

Use this as a quick dependency checklist:

- If you change installer or uninstaller templates:
  - check installer prompts
  - check profile injection behavior
  - check README install commands
- If you change `scripts/libs/get_config.sh`:
  - check defaults
  - check effective value rendering in menus
  - check recursion/init boundaries
- If you change `scripts/libs/build_command.sh`:
  - check `command.env`
  - check `debug`, `start`, and `daemon-run`
  - check shell quoting assumptions
- If you change `scripts/libs/prepare_runtime.sh` or `scripts/libs/pkg_profile.sh`:
  - check binary placement
  - check release asset download paths
  - check install-time storage expectations
- If you change `scripts/libs/compatibility.sh`:
  - check `compat-status`
  - check menu text and restart flow
  - check persistence hook behavior
- If you change `scripts/libs/set_profile.sh`:
  - check saved `my_alias`
  - check reboot-time alias restoration
  - check uninstall cleanup of profile entries
- If you change `pack_release.sh`:
  - check tarball size
  - check exclusion rules on case-sensitive paths
  - check release workflow expectations
- If you change `scripts/menu.sh`:
  - check both `local` and `remote`
  - check hidden/shown menu behavior in stopped vs running states
  - check restart prompt behavior
- If you change `scripts/starts/*.sh` or service templates:
  - check failure fuse behavior
  - check no stop recursion is introduced
  - check cold reboot restores alias and autostart on snapshot targets

## Runtime Binary Placement Rules

This project supports:

- `binary_storage_mode=auto`
- `binary_storage_mode=persistent`
- `binary_storage_mode=tmp`
- `binary_storage_mode=custom`

When touching binary placement logic:

- Preserve user choice over storage strategy.
- Do not force `/tmp` just because it is easy.
- Respect `install_web` when calculating storage requirements.
- Router users may prefer persistent binary storage to avoid re-downloading
  after reboot.

## Compatibility Layer Rules

`scripts/libs/compatibility.sh` exists because real router environments are not
single-process networking systems.

It should continue to support:

- LAN interface auto-detection
- EasyTier TUN auto-detection
- forwarding rules
- MASQUERADE for zero-config return traffic
- ShellCrash bypass insertion
- route metric cleanup and repair
- persistence hooks (`/etc/firewall.d` or `/etc/firewall.user` fallback)

When extending compatibility:

- Prefer detection over hardcoded interfaces and subnets.
- Keep status output human-readable first; raw/internal output second.
- Treat multi-overlay coexistence as a coordination problem, not an install
  order problem.
- Compatibility must degrade safely when detection is incomplete; avoid making
  users fill every network parameter manually.

## Router-Specific Reality Checks

- OpenWrt `FORWARD` defaults and zone rules matter.
- ShellCrash coexistence is a first-class scenario, not an edge case.
- Stale route metrics and iptables rebuilds are normal failure modes.
- Lack of `/etc/firewall.d` is normal; fallback persistence paths matter.
- `/tmp` vs persistent binary placement is a real user choice, not just a
  storage optimization.

## Service Model Rules

- Manual interactive start and service-manager daemon start are different paths.
- Manual/menu start must provide synchronous success/failure feedback.
- Background-only follow-up tasks are allowed only for non-critical work.
- Do not reintroduce late error messages that appear after the menu already
  returned.

## Web Rules

- Only `easytier-web-embed` is supported as the local web component.
- Web menu visibility depends on:
  - architecture support
  - `install_web=ON`
  - runtime placement policy allowing web payload
- Keep core and web autostart logically independent.

## Installer Rules

- Installer must support both fresh install and in-place upgrade.
- Installer must remain interactive.
- Installer should not assume `sudo` exists on routers.
- Installer profile injection must be idempotent and must not leave malformed
  aliases behind.
- Always preserve the ability to override `url` at install time.

## Release Rules

Default release source is GitHub Releases:

- `https://github.com/AisonSu/ShellEasyTier/releases/latest/download`

Release workflow expectations:

- On tag push, workflow rewrites `version` in workflow workspace
- Builds `ShellEasytier.tar.gz`
- Publishes flat runtime assets per architecture
- Overwrites assets on retag when needed

Release sanity rules:

- `ShellEasytier.tar.gz` should stay small (tens of KB, not tens of MB).
- If release tarball size jumps unexpectedly, suspect packaging exclusions first.
- The tarball must not include `pkg/`, `.git/`, runtime `bin/`, or `dist/`.

Do not assume `raw.githubusercontent.com` is the active distribution path.

## Validation Checklist

When touching runtime code, at minimum run syntax checks on changed shell files.
Typical commands:

```sh
bash build_installers.sh
sh -n dist/install.sh
sh -n dist/install_en.sh
sh -n dist/uninstall.sh
sh -n dist/uninstall_en.sh
sh -n scripts/init.sh
sh -n scripts/start.sh
sh -n scripts/menu.sh
```

If touching boot recovery or autostart on router targets, also validate:

```sh
sh -n scripts/starts/general_init.sh
sh -n scripts/starts/snapshot_init.sh
sh -n scripts/starts/afstart.sh
sh -n scripts/starts/start_error.sh
sh -n scripts/starts/shelleasytier.procd
```

If touching packaging/release flow, also validate:

```sh
bash -n pack_release.sh
bash pack_release.sh
```

If touching `pack_release.sh`, verify the tarball stays small and does not
include `pkg/`.

## WSL Notes

- WSL is useful for fast smoke testing, but it is not equivalent to OpenWrt.
- Do not assume WSL autostart behavior represents router autostart behavior.
- Non-interactive `wsl bash -lc` may not inherit the same SSH agent environment
  as an interactive WSL shell.
- If SSH-based git actions fail in automation but work manually, prefer `wsl bash -ic`.

## Documentation Rules

- If behavior changes for installation, release flow, binary placement, or
  compatibility, update both:
  - `README.md`
  - `README.zh-CN.md`
- If startup, alias persistence, or boot recovery behavior changes, also update
  `CURRENT-STATUS.md`.
- Longer troubleshooting material belongs under `docs/`.

## Things To Avoid

- Do not reintroduce raw release tarball tracking in git.
- Do not collapse advanced settings back into one giant ungrouped menu.
- Do not hardcode router-specific values when they can be detected.
- Do not silently break fallback download paths.
- Do not make users configure subnets/interfaces manually unless auto-detection
  truly fails.
