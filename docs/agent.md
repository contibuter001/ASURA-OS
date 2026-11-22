# ASURA Agent

ASURA Agent (`asura-agent`) connects local coding assistants and resident agents directly to the
ASURA OS desktop and system state. It lives in `desktop/cmd/asura-agent` and provides both the
CLI wiring harness for local coding agents and the knowledge skill suite.

---

## The CLI Wiring Harness

The `asura-agent` binary automatically detects, wires, and inspects agent harnesses installed on
the machine.

### Commands

```sh
# Report detection in PATH and skill wiring status for all supported agents
asura-agent status [--json]

# Symlink the Asura skill suite into all or a specific agent
asura-agent wire [agent]

# Wire every supported agent that is installed (asura-session runs this at login)
asura-agent wire --installed

# Remove the Asura skill symlink from all or a specific agent
asura-agent unwire [agent]
```

`asura-agent` is installed with the system (`/usr/bin/asura-agent`), and every login wires the
skills into the assistants that are on PATH, so OpenCode (shipped in the ISO) knows ASURA out of
the box. Assistants that are not installed get no folders.

### The shell panels (`ask`, `chat`)

ASURA's own shell has a quick-ask panel and a chat panel that run `asura-agent ask` and
`asura-agent chat`. ASURA does not ship a resident assistant, so these hand the question to
OpenCode in a terminal (`asura-app terminal -- opencode`) and answer in the panels' line
protocols (`@answer {json}` for ask; JSON lines ending in `{"type":"done"}` for chat), instead of
failing. `asura-agent chat --skills` lists the wired skills.

### Supported Agents

| Agent | Configured Skill Target Path |
|---|---|
| **OpenCode** | `~/.config/opencode/skills/asura` |
| **Pi** | `~/.pi/agent/skills/asura` |
| **Claude Code** | `~/.claude/skills/asura` |
| **Gemini CLI / Antigravity** | `~/.gemini/skills/asura` |

When wired, the agent gains direct access to the Asura skill suite (`shell/agent/skills/asura`)
and runit system shims (`shell/agent/skills/systemd-bridge`).

---

## The Skill Suite

The skills located in `shell/agent/skills/` (and staged to `/usr/share/asura/shell/agent/skills/` on
installed systems) expose deep OS integration to coding agents:

- **`asura`**: the system skill. `SKILL.md` sets the rules (never edit shipped files, user files
  and commands instead) and routes to:
  - `desktop.md`: the default end-4 desktop: its settings file, Hyprland files, keybind functions,
    and the overlay rule for changing end-4's code.
  - `update.md`: `asura update`, the CI gate, `--check`/`--wait`/`--force`, rollback.
  - `store.md`: installing apps, themes and plugins with `asura-store`.
  - `diagnostics.md`: `asura doctor --json`, logs, runit services, a desktop that will not load.
  - `bar.md`, `gui.md`, `plugins.md`: ASURA's own shell (`desktop-shell` = `asura`) only.
- **`systemd-bridge`**: Bridges traditional `systemctl` and `journalctl` invocations to native
  Void Linux `runit` (`sv`) and `svlogd` logging structures.

A Go test (`desktop/cmd/asura/skills_commands_test.go`) fails when a skill names an `asura`
subcommand or `asura-*` tool that does not exist, so the skills cannot drift from the commands.

---

## Planned Architecture: Resident ACP Daemon

A resident knowledge vault and Agent Client Protocol (ACP) daemon are planned for future
milestones:

- **Google Open Knowledge Format (OKF v0.1)**: Structured markdown vault generated under
  `~/.local/share/asura/agent/` (`index.md`, `system.md`, `desktop.md`, `packages.md`, `habits.md`).
- **Pluggable ACP Engine**: Connecting agents via JSON-RPC 2.0 through `engine.command` in
  `~/.config/asura/agent/config.json`.
- **Launcher & Terminal Integration**: Quick ask from the launcher and terminal command safety tiers.
