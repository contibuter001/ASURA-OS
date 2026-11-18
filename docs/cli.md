# The `asura` Control Tool (`asura`)

`asura` is the primary control CLI and system orchestration binary for ASURA OS.
It lives in `desktop/cmd/asura/` and is installed at `/usr/bin/asura`.

The command surface acts as the single source of truth for querying state, triggering updates,
managing hardware profiles, reconfiguring themes, applying settings, and running diagnostics.

---

## Command Reference

```text
asura <command> [flags]
```

### Core Operations & Lifecycle

| Command | Usage | Description |
|---|---|---|
| `update` | `asura update [--force]` | Pulls latest ASURA system tree, updates packages via XBPS, and refreshes the desktop. |
| `rollback` | `asura rollback [--system]` | Re-materializes the previous config revision. With `--system`, stages Btrfs boot rollback. |
| `materialize` | `asura materialize` | Re-lays the baseline configuration and assets, replacing shipped defaults while preserving user overrides. |
| `reset` | `asura reset PATH` | Drops user edits for a specific path back to system base default. |
| `status` | `asura status` | Reports current git revision, system paths, and configuration drift. |
| `doctor` | `asura doctor` | Comprehensive health check: config drift, portals, runit user services, system services, and hardware power. |
| `version` | `asura version` | Prints `asura` version and compilation metadata. |

---

### Hardware, Power & Graphics

| Command | Usage | Description |
|---|---|---|
| `hardware` | `asura hardware report\|match\|lint-profiles\|capture [flags]` | Inspects hardware detection, matches machine profiles from `system/hardware/`, and captures sysfs fixtures. |
| `gpu` | `asura gpu [--json]` | Inspects integrated and discrete GPUs, reports driver status, and executes commands offloaded to discrete graphics. |
| `power` | `asura power [profile]` | Manages CPU governors (performance, powersave), EPP energy preferences, and hybrid GPU runtime power (D3cold). |
| `brightness` | `asura brightness [set\|get\|list] [value]` | Direct backlight control for screens and keyboard illumination without group permission friction. |

---

### Desktop, Shell & Compositor

| Command | Usage | Description |
|---|---|---|
| `config` | `asura config get\|set\|export [key] [val]` | Reads and modifies ASURA desktop settings stored in GSettings / dconf. |
| `state` | `asura state` | Outputs live desktop state as JSON (active windows, workspaces, system tray). |
| `windows` | `asura windows` | Lists switchable windows sorted by most recently focused order. |
| `wm` | `asura wm status\|caps\|act` | Compositor integration seam querying capabilities and window management actions. |
| `ipc` | `asura ipc <verb> [args]` | Directly calls running Quickshell IPC surfaces. |
| `refresh` | `asura refresh` | Re-renders and applies desktop theme and wallpaper tokens to the active session. |
| `reload` | `asura reload` | Sends reload signals to Hyprland, `asurad`, and Quickshell. |
| `menu` | `asura menu` | Opens the ASURA application and action menu. |
| `apps` | `asura apps` | Lists indexed desktop applications as JSON for the launcher. |
| `icons` | `asura icons` | Dumps indexed icon themes and glyph mappings as JSON. |
| `binds` | `asura binds` | Outputs keybinding catalogue as JSON for cheat sheets and diagnostics. |

---

### Theming, Plugins & Packages

| Command | Usage | Description |
|---|---|---|
| `theme` | `asura theme generate\|render [image]` | Generates monochromatic and accent color palettes from an image using `matugen`. |
| `plugin` | `asura plugin new\|audit\|install\|enable\|remove` | Manages Quickshell UI plugins: scaffolds templates, audits safety rules, and manages extensions. |
| `pkg` | `asura pkg install\|remove\|search <name>` | Void Linux package operations wrapper over `xbps-*`. |
| `channel` | `asura channel [name]` | Manages the XBPS repository channel followed by the system. |
| `greeter` | `asura greeter enable\|disable\|test` | Configures and tests SDDM login greeter theme. |
| `install` | `asura install` | Launches the guided ASURA OS system installer GUI. |
| `role` | `asura role switch <role>` | Switches system roles (developer, security, gaming) via native container bridges. |
