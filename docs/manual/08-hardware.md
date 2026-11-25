# Hardware

- Consult the [Hardware Compatibility Matrix](../hardware.md) for full laptop line support levels, component details, and how to submit new profiles.
- `asura hardware report`: what Toren found in your machine.
  `asura hardware report --submit` prepares a redacted report and opens a pre-filled GitHub issue in your browser.
  `asura hardware report --profile` writes a profile you can share when you
  report a problem; it helps Toren support your model.
- **Two graphics cards** (laptops): `asura gpu status` shows them;
  `asura gpu run APP` (or `prime-run APP`) runs an app on the faster one.
- **Power**: `asura power status`; `asura power profile balanced|performance|battery`.
- **Monitors**: **Super + P** switches displays (laptop screen, external,
  both); details and pins go in `~/.config/asura/hyprland/monitors-user.conf`.
- **Kernels**: Switch Void kernel series with `asura kernel [list | set NAME | remove NAME]`.
  Series include `linux` (stable), `linux-lts` (long-term support), and `linux-mainline`.
  `set` installs the kernel, updates GRUB, and preserves the current kernel as fallback.
  Systems with NVIDIA graphics automatically verify and install matching kernel headers.
- **Windows Virtual Machine**: `asura vm windows` guides through creating a tuned Windows 11
  VM with TPM 2.0, UEFI, 4 cores, 8 GB RAM, and SPICE clipboard/display sharing via quickemu.
  Manage VMs with `asura vm list`, `asura vm launch NAME`, and `asura vm stop NAME`.
- **Firmware**: `asura firmware` (see the updates chapter).
- **Secure Boot** is not supported yet: keep it off in your firmware settings.
