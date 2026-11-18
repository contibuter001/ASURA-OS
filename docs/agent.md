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

# Remove the Asura skill symlink from all or a specific agent
asura-agent unwire [agent]
```

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

- **`asura`**: Comprehensive system control skill, covering:
  - `diagnostics.md`: Running `asura doctor`, examining runit service logs, inspecting hardware probes.
  - `bar.md`: Controlling and reconfiguring Quickshell top/bottom bars.
  - `gui.md`: Interacting with shell surfaces, workspaces, and window rules.
  - `plugins.md`: Auditing, packaging, and installing shell plugins.
- **`systemd-bridge`**: Bridges traditional `systemctl` and `journalctl` invocations to native
  Void Linux `runit` (`sv`) and `svlogd` logging structures.

---

## Planned Architecture: Resident ACP Daemon

A resident knowledge vault and Agent Client Protocol (ACP) daemon are planned for future
milestones:

- **Google Open Knowledge Format (OKF v0.1)**: Structured markdown vault generated under
  `~/.local/share/asura/agent/` (`index.md`, `system.md`, `desktop.md`, `packages.md`, `habits.md`).
- **Pluggable ACP Engine**: Connecting agents via JSON-RPC 2.0 through `engine.command` in
  `~/.config/asura/agent/config.json`.
- **Launcher & Terminal Integration**: Quick ask from the launcher and terminal command safety tiers.
