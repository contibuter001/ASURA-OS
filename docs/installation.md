# Installation & Live ISO Building

This document covers the installation pipeline in ASURA OS: generating live bootable media,
running the guided system installer, configuring full-disk encryption, and bootstrapping
the Void Linux package repository.

---

## 1. Live ISO Generation (`build-iso-void.sh`)

ASURA OS builds hybrid UEFI/BIOS bootable ISO images based on Void Linux glibc x86_64 using
`void-mklive` and packages defined in `system/packages-void.yaml`.

The builder script is located at `installation/build-iso-void.sh`.

### Key Features
- **Deterministic Package Extraction**: Reads the reviewed package fleet from
  `system/packages-void.yaml`, automatically excluding unsupported or conflict packages.
- **Runit User Supervision**: Injects default runit user services into `/etc/skel/.config/service/`.
- **Automatic Live Autologin**: Configures `agetty-tty1` to automatically log into the live user session
  (`asura`) with standard group memberships (`_seatd`, `video`, `audio`, `input`, `wheel`).
- **Hyprland + Quickshell Session**: Automatically starts the Wayland session via `asura-session`
  upon console login.
- **Installer Integration**: Stages `asura-installer.sh` and the desktop shortcut
  `session/applications/asura-installer.desktop` to launch the guided installer from the live environment.

### Building the ISO

```sh
# Ensure dependencies are installed (void-mklive, xbps, squasfs-tools, xorriso)
sudo xbps-install -S void-mklive xorriso squashfs-tools

# Run ISO build
sudo ./installation/build-iso-void.sh
```

---

## 2. Guided Installer (`asura-installer.sh`)

The installer is a terminal and GUI-driven disk partitioner, rootfs unpacker, and configuration
engine located at `installation/asura-installer.sh`. It can be run directly from terminal or
via `asura install` / `asura-installer.desktop`.

### Installation Steps

1. **Target Selection**: Enumerates non-removable block devices using `lsblk` and `/sys/block/`.
2. **Partitioning Scheme**:
   - EFI System Partition (ESP): 1024 MiB, formatted FAT32 (`vfat`), mounted at `/boot/efi`.
   - Boot Partition: 1024 MiB ext4 partition at `/boot` (used for LUKS2 encrypted setups).
   - Root Partition: Remainder of drive formatted Btrfs or ext4, mounted at `/`.
3. **Full-Disk Encryption (LUKS2)**:
   - Optional full-disk encryption using `cryptsetup luksFormat --type luks2 --pbkdf argon2id`.
   - Integrated with Dracut `crypt` module and Plymouth password prompt on boot.
4. **Btrfs Subvolumes**:
   - Subvolume `@` mounted at `/`.
   - Subvolume `@home` mounted at `/home`.
   - Subvolume `@snapshots` mounted at `/.snapshots` for rollback integration.
5. **Base System Deployment**:
   - Deploys base packages via XBPS into target mount (`/mnt`).
   - Copies user services, configuration skeletons, and desktop binaries.
6. **Bootloader Configuration**:
   - Installs GRUB EFI (`grub-install --target=x86_64-efi --efi-directory=/boot/efi`).
   - Generates `/etc/fstab` using persistent UUIDs.
   - Generates initial RAM disk via `dracut --force`.

---

## 3. Package Repository Bootstrapping (`apply-repo.sh`)

`installation/apply-repo.sh` configures the host or target chroot to use the ASURA OS binary
XBPS repository. It generates `/usr/share/xbps.d/asura.conf` and installs the repository
signing key.

```sh
# Apply local or remote repository to running system or chroot
sudo ./installation/apply-repo.sh /path/to/repo [target_root]
```
