# Hardware

- `asura hardware report`: what ASURA found in your machine.
  `asura hardware report --profile` writes a profile you can share when you
  report a problem; it helps ASURA support your model.
- **Two graphics cards** (laptops): `asura gpu status` shows them;
  `asura gpu run APP` (or `prime-run APP`) runs an app on the faster one.
- **Power**: `asura power status`; `asura power profile balanced|performance|battery`.
- **Monitors**: **Super + P** switches displays (laptop screen, external,
  both); details and pins go in `~/.config/asura/hyprland/monitors-user.conf`.
- **Firmware**: `asura firmware` (see the updates chapter).
- **Secure Boot** is not supported yet: keep it off in your firmware settings.
