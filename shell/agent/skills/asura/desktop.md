# The default desktop (end-4)

When `gsettings get org.asura.shell desktop-shell` is `'end4'` (the default),
the desktop is end-4's illogical-impulse Quickshell desktop, shipped at
`/usr/share/asura/shell-end4/` and started by the runit user service
`~/.config/service/quickshell` (`quickshell -p /usr/share/asura/shell-end4`).

## What the user sees (ASURA's layout)

- **Bar** (top, 30 px, plain): workspaces on the left (only the ones that
  exist; the active one underlined, an empty one a dot), media while a player
  has a track, the clock and date in the centre, then the status icons (they
  open the control menu), CPU/RAM and the battery at the right end.
- **Dock**: an island at the bottom with the pinned and running apps. It
  auto-hides while a window is focused and comes back at the bottom edge.
- **Control menu** (right sidebar): quick toggles, volume and brightness
  sliders, notifications, calendar.
- **Overview / launcher**: search apps, run commands, calculate.
- There is no left sidebar (end-4's AI chat and anime browser are not loaded).

## Changing it

**User settings** live in `~/.config/illogical-impulse/config.json`, which the
desktop watches and reloads. The Settings app (from the control menu) edits the
same file. Useful keys:

| Key | What it does |
|---|---|
| `dock.enable` | the dock on or off |
| `dock.pinnedOnStartup` | `true` keeps the dock shown (auto-hide off) |
| `dock.pinnedApps` | desktop-entry ids, e.g. `["com.mitchellh.ghostty", "thunar", "firefox"]` |
| `dock.monochromeIcons` | tint the dock's icons |
| `bar.borderless` | no boxes behind the bar's groups |
| `bar.workspaces.showAppIcons` | app icons in the workspace indicator |
| `sidebar.quickSliders.enable` | volume/brightness sliders in the control menu |

Edit it with a JSON tool that keeps the rest of the file (e.g. `jq`), or point
the user to the Settings app.

**Colours** come from the wallpaper (matugen): `asura-wallpaper wallpaper ui`
opens the picker, `asura-wallpaper wallpaper random` picks one. The palette is
written to `~/.local/state/quickshell/user/generated/colors.json`.

**Hyprland** (gaps, borders, rules, monitors, input): ASURA's config is
`/usr/share/asura/hyprland/hyprland.conf`; put changes in
`~/.config/asura/hyprland/user.conf`. end-4's look (blur, animations, layer
rules) is `/usr/share/asura/shell-end4/asura/hyprland.conf`, loaded through
`~/.config/asura/hyprland/shell.conf` while end-4 is the desktop. Apply with
`hyprctl reload` or `asura refresh`.

## Keybind functions

Keybindings run `asura ipc call asura <function>`, answered by
`shell-end4/asura/AsuraBridge.qml`: `togglePopover <name>`, `toggleOverview`,
`overviewDesktop <delta>`, `advanceSwitcher`, `reverseSwitcher`,
`closeSwitcher`, `toggleCheatsheet`, `session`, `ocr`, `toggleScreenshot`,
`toggleSurface <name>`, `reloadSettings`. Test one by running the same command.

## How ASURA changes end-4 (for code changes, not user requests)

`shell-end4/` in the ASURA repository is end-4's tree **byte for byte** at a
pinned commit; `sh shell-end4/asura/vendor.sh verify` checks it and CI runs
it. A file ASURA changes becomes an **overlay**: listed in `OVERLAYS` in
`shell-end4/asura/vendor.sh` and removed from `shell-end4/asura/manifest.txt`.
Editing a vendored file without that fails CI, and `asura update` then keeps
every machine on the last commit that passed. Every change must also load:
CI's `end4-load` job loads the desktop with Quickshell and fails on any QML
error.

## When the desktop will not load

`tail -n 60 ~/.local/state/asura/quickshell.log`. A "Reload failed" usually
names one file and line ("Cannot assign to non-existent property", "Type X
unavailable"). If end-4 keeps crashing, the service waits 5 s between
restarts; after fixing, `rm -f ~/.local/state/asura/end4-quick-exits` and
`sv restart ~/.config/service/quickshell`.
