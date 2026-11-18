# ASURA OS Documentation Index

This directory contains the complete technical documentation for **ASURA OS**, detailing
architecture, subsystems, developer contracts, and operational guides.

---

## Architecture & System Overview

- [`architecture.md`](architecture.md): Master design document, core technology choices (Void Linux, Hyprland, Quickshell, runit), layer boundaries, and rejected alternatives.
- [`adopting-asura.md`](adopting-asura.md): Migration and adoption design document.
- [`roadmap.md`](roadmap.md): Milestone tracker, deliverables, and release status across development phases.
- [`cli.md`](cli.md): Reference manual for the `asura` control CLI binary (`desktop/cmd/asura/`).
- [`packaging.md`](packaging.md): Void Linux XBPS packaging templates, repository layout, and build automation.
- [`installation.md`](installation.md): Void Linux Live ISO generator (`build-iso-void.sh`), guided partitioner, and full-disk encryption.

---

## Session & System Services

- [`session.md`](session.md): The Wayland session chain, Hyprland startup, environment hand-off, user-level runit supervision, and shutdown flows.
- [`system-services.md`](system-services.md): System-level runit services, seat management (`seatd`), elogind, audio (`pipewire`/`wireplumber`), and daemon architecture.
- [`shell-daemon.md`](shell-daemon.md): `asurad` shell daemon: state caching, workspace telemetry, and D-Bus interfaces.
- [`vm.md`](vm.md): Virtual machine detection and graphics software rendering fallbacks (VirtualBox, VMware, QEMU/KVM).

---

## Hardware & Power Management

- [`hardware-detection.md`](hardware-detection.md): DMI / device-tree hardware probe pipeline, profile schema, and machine-matching engine.
- [`hardware-keys.md`](hardware-keys.md): Hardware key handling: screen brightness, keyboard backlights, audio volume, rfkill, and external monitor DDC/CI control.

---

## Shell, Desktop & Customization

- [`greeter.md`](greeter.md): SDDM login greeter theme, session selection, PAM integration, and testing.
- [`lock.md`](lock.md): Lockscreen architecture using `hyprlock` and `hypridle`.
- [`launcher.md`](launcher.md): Application search and launcher stage (`Super + Space`).
- [`menu.md`](menu.md): Fast action and system power menu.
- [`welcome.md`](welcome.md): First-run onboarding wizard.
- [`theming.md`](theming.md): Dynamic Material You theme generation from wallpaper images (`matugen`).
- [`wallpaper.md`](wallpaper.md): Wallpaper rendering and daemon supervisor (`asura-wallpaper`).
- [`screenshots.md`](screenshots.md): Wayland region and screen capture workflows.
- [`i18n.md`](i18n.md): Multi-language translation catalog and runtime localization.
- [`plugins.md`](plugins.md): Quickshell UI plugins, manifest validation, and auditing.
- [`hyprland-plugins.md`](hyprland-plugins.md): Hyprland compositor C++ shared library plugins (`.so`), ABI matching, and `hyprpm` integration.

---

## Settings & Standalone Applications

- [`hub-backend.md`](hub-backend.md): `asura-hubd` Settings Hub data plane and compositor settings renderer.
- [`store.md`](store.md): ASURA Software Store: showroom UI, XBPS integration, and polkit privilege escalation.
- [`sysmon.md`](sysmon.md): ASURA Resource Monitor: telemetry data plane, process manager, and system gauges.
- [`agent.md`](agent.md): Coding assistant integration harness (`asura-agent`), skill suites, and knowledge vault.
