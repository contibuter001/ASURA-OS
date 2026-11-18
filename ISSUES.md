# Known Codebase Issues & Audit Findings

This document tracks identified bugs, test regressions, and configuration drift across **ASURA-OS** and its companion repositories (**asura-store**, **asura-sysmon**).

---

## 1. CI Failure / Drift Between `ASURA-OS` and Standalone `asura-store`

* **Severity**: High (CI Blocker)
* **Affected Files**:
  * [`ASURA-OS/desktop/cmd/asura-store/main.go`](file:///home/mohit/code/asura/ASURA-OS/desktop/cmd/asura-store/main.go#L48-L59)
  * [`asura-store/cmd/asura-store/main.go`](file:///home/mohit/code/asura/asura-store/cmd/asura-store/main.go#L45-L60)
  * [`ASURA-OS/.github/workflows/store-sync.yml`](file:///home/mohit/code/asura/ASURA-OS/.github/workflows/store-sync.yml#L84-L85)

### Problem
Commit `dd5ae68` in `ASURA-OS` added `-h`, `--help`, and `help` flag support to `desktop/cmd/asura-store/main.go`:
```go
	case "-h", "--help", "help":
		fmt.Print(`Usage: asura-store <command> [args]

  catalog            the catalog as JSON
  search QUERY       search the catalog and the package sources
  check              which providers (xbps, flatpak) are available
  install ID         install an app
  remove ID          remove an app
  open               open the Store window
  settings           open the Store's settings
`)
		return nil
```
However, this change was not mirrored into the upstream standalone repository `asura-store`.

### Impact
The GitHub Actions workflow `store-sync.yml` validates exact parity:
```bash
diff -r desktop/cmd/asura-store store-upstream/cmd/asura-store
```
Because of the missing `--help` switch in `asura-store`, the `store-sync` parity check fails in CI.

### Resolution
Apply the `--help` case to [`asura-store/cmd/asura-store/main.go`](file:///home/mohit/code/asura/asura-store/cmd/asura-store/main.go) and commit to `asura-store`'s `main` branch.

---

## 2. Snapshot Snippet Copied After `grub-mkconfig` in `asura-installer.sh`

* **Severity**: Medium (Functional Bug)
* **Affected File**:
  * [`ASURA-OS/installation/asura-installer.sh`](file:///home/mohit/code/asura/ASURA-OS/installation/asura-installer.sh#L904-L915)

### Problem
In `asura-installer.sh`, `grub-mkconfig` is invoked to produce `/boot/grub/grub.cfg` at lines 904 and 907:
```bash
if [ "$IS_UEFI" -eq 1 ]; then
    ...
    chroot "$TARGET_DIR" grub-mkconfig -o /boot/grub/grub.cfg
else
    chroot "$TARGET_DIR" grub-install --target=i386-pc --recheck "$TARGET_DISK"
    chroot "$TARGET_DIR" grub-mkconfig -o /boot/grub/grub.cfg
fi

# Install the Asura snapshot GRUB snippet so /.snapshots entries are generated
if [ -d "$TARGET_DIR/usr/share/asura/session/grub" ]; then
    mkdir -p "$TARGET_DIR/etc/grub.d"
    cp "$TARGET_DIR/usr/share/asura/session/grub"/* "$TARGET_DIR/etc/grub.d/" 2>/dev/null || true
    chmod +x "$TARGET_DIR/etc/grub.d"/40_asura_snapshots 2>/dev/null || true
fi
```
The snapshot script `40_asura_snapshots` is only copied to `$TARGET_DIR/etc/grub.d/` **after** `grub-mkconfig` has already generated the GRUB menu.

### Impact
The initial installation's `/boot/grub/grub.cfg` is created without awareness of `40_asura_snapshots`. Any pre-existing recovery snapshot entries or configurations will not be reflected until the user manually triggers a GRUB rebuild.

### Resolution
Move the copying and chmod of `40_asura_snapshots` into `$TARGET_DIR/etc/grub.d/` before invoking `chroot "$TARGET_DIR" grub-mkconfig -o /boot/grub/grub.cfg`.

---

## 3. Broken Test Script: `installation/build-iso_test.sh`

* **Severity**: Medium (Dead Test / Failure)
* **Affected File**:
  * [`ASURA-OS/installation/build-iso_test.sh`](file:///home/mohit/code/asura/ASURA-OS/installation/build-iso_test.sh#L17-L38)

### Problem
Running `sh installation/build-iso_test.sh` exits immediately with code 1.
The script checks for obsolete Ubuntu/Debian `live-build` artifacts:
* `BASE_FLAVOR=ubuntu-server`
* `system/packages.yaml`
* `apt-get install -y linux-image-generic /tmp/asura.deb`
* `--syslinux-theme live-build`
* `--initsystem systemd`

`installation/build-iso.sh` is now a symlink pointing to `build-iso-void.sh` (Void Linux mklive), causing all of these grep assertions to fail.

### Impact
Anyone running test suites locally encounters a failure. (CI runs `installation/build-iso-void_test.sh` instead).

### Resolution
Remove `build-iso_test.sh` or update it to delegate directly to [`installation/build-iso-void_test.sh`](file:///home/mohit/code/asura/ASURA-OS/installation/build-iso-void_test.sh).

---

## 4. Obsolete Package Verification Script: `system/verify-packages.py`

* **Severity**: Low (Stale Script)
* **Affected File**:
  * [`ASURA-OS/system/verify-packages.py`](file:///home/mohit/code/asura/ASURA-OS/system/verify-packages.py)

### Problem
`verify-packages.py` defaults to verifying `system/packages.yaml` against Ubuntu archive mirrors (`archive.ubuntu.com`). Because ASURA OS migrated to Void Linux and now uses `system/packages-void.yaml`, `system/packages.yaml` no longer exists.

### Impact
Executing `python3 system/verify-packages.py` crashes with a `FileNotFoundError`.

### Resolution
Update `verify-packages.py` to validate `system/packages-void.yaml` against Void Linux XBPS repository indexes, or remove the obsolete script.

---

## 5. Brittle Fixture Scanning in `desktop/cmd/asura/capture_test.go`

* **Severity**: Low (Test Fragility)
* **Affected File**:
  * [`ASURA-OS/desktop/cmd/asura/capture_test.go`](file:///home/mohit/code/asura/ASURA-OS/desktop/cmd/asura/capture_test.go#L30-L58)

### Problem
`capture_test.go` globs all subdirectories in `system/hardware/probe/testdata/*`:
```go
fixtures, err := filepath.Glob(filepath.Join("..", "..", "..", "system", "hardware", "probe", "testdata", "*"))
...
for _, fixture := range fixtures {
    info, err := os.Stat(fixture)
    if err != nil || !info.IsDir() {
        continue
    }
    if filepath.Base(fixture) == "fuzz" {
        continue
    }
    out := t.TempDir()
    captured, _, err := capture(fixture, out)
    if captured == 0 {
        t.Errorf("capture(%s) wrote nothing", filepath.Base(fixture))
    }
}
```
Because [`system/hardware/probe/testdata/gen.py`](file:///home/mohit/code/asura/ASURA-OS/system/hardware/probe/testdata/gen.py) exists in that directory, compiling or running Python creates a `__pycache__` folder. `capture_test.go` mistakes `__pycache__` for a hardware machine fixture and fails:
```
capture(__pycache__) wrote nothing
```

### Impact
Running Python scripts or tests creates bytecode caches that unexpectedly break `go test ./cmd/asura`.

### Resolution
Exclude `__pycache__` and hidden directories:
```go
base := filepath.Base(fixture)
if base == "fuzz" || base == "__pycache__" || strings.HasPrefix(base, ".") {
    continue
}
```


---

## 6. POSIX Compatibility Failure in `session/scripts/monitor_test.sh`

* **Severity**: Medium (Test Failure under `/bin/sh`)
* **Affected File**:
  * [`ASURA-OS/session/scripts/monitor_test.sh`](file:///home/mohit/code/asura/ASURA-OS/session/scripts/monitor_test.sh#L110)

### Problem
`monitor_test.sh` declares `#!/bin/sh` as its shebang, but uses the Bash-specific conditional keyword `[[` on line 110:
```bash
idval="$(ASURA_MONITOR_JSON="$tmp/noedid.json" "$mon" list | jq -r '.[0].id')"
[[ $idval == "HDMI-A-1" ]] || fail "an EDID-less display keyed on '$idval', not its connector"
```
When executed directly with `sh session/scripts/monitor_test.sh` on systems where `/bin/sh` is Dash (such as Debian, Ubuntu, or Void Linux), it fails:
```
session/scripts/monitor_test.sh: 110: [[: not found
FAIL: an EDID-less display keyed on 'HDMI-A-1', not its connector
```

### Impact
Running tests with standard POSIX shells causes unexpected test failure.

### Resolution
Replace `[[ $idval == "HDMI-A-1" ]]` with standard POSIX test syntax:
```bash
[ "$idval" = "HDMI-A-1" ] || fail "an EDID-less display keyed on '$idval', not its connector"
```

---

## 7. Missing D-Bus Environment in `system/runit/user-services/portal/run`

* **Severity**: High (Desktop Service Timeout / Failure)
* **Affected File**:
  * [`ASURA-OS/system/runit/user-services/portal/run`](file:///home/mohit/code/asura/ASURA-OS/system/runit/user-services/portal/run#L24-L40)

### Problem
`portal/run` supervises `xdg-desktop-portal` under user runit. It runs a wait loop checking for the Hyprland backend via `gdbus call --session ...`. However, unlike other user service run scripts (`asurad`, `portal-hyprland`, `asura-idle`), `portal/run` does not set or export `XDG_RUNTIME_DIR` or `DBUS_SESSION_BUS_ADDRESS`.
Under turnstile or clean runsvdir environments, `DBUS_SESSION_BUS_ADDRESS` is absent, causing `gdbus call --session` to fail immediately. The script exhausts all 150 retries (15 seconds delay on login), prints `WARNING: ... never registered; starting the dispatcher anyway`, and executes `xdg-desktop-portal` without `DBUS_SESSION_BUS_ADDRESS`.

### Impact
Adds an artificial 15-second delay to the portal dispatcher startup and risks leaving `xdg-desktop-portal` unable to connect to the session bus.

### Resolution
Export runtime variables at the start of `system/runit/user-services/portal/run`:
```bash
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
if [ -S "$RUNTIME_DIR/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus"
fi
```

---

## 8. Incomplete Rollback Logic in `asura rollback --system`

* **Severity**: High (Data / Recovery Bug)
* **Affected File**:
  * [`ASURA-OS/desktop/cmd/asura/rollback.go`](file:///home/mohit/code/asura/ASURA-OS/desktop/cmd/asura/rollback.go#L110-L148)

### Problem
`rollbackSystem` in `rollback.go` creates a writable subvolume snapshot inside `/` at `/@_restored_<name>`:
```go
restoreTarget := "/@_restored_" + filepath.Base(snapPath)
snapCmd = exec.Command("btrfs", "subvolume", "snapshot", snapPath, restoreTarget)
```
However:
1. `restoreTarget` is created as a nested subvolume inside `@` rather than at top-level Btrfs root.
2. It is never marked as default via `btrfs subvolume set-default`.
3. `/etc/fstab` and GRUB configuration still point to `subvol=@`.
4. `grub-reboot "Asura OS (snapshot <name>)"` only sets a one-time boot into the **read-only** snapshot `/.snapshots/<name>`. On the subsequent reboot, the system reverts back to the original unmodified subvolume `@`.

### Impact
System rollback does not permanently restore the system state despite reporting `Rollback complete`.

### Resolution
Mount the top-level Btrfs volume (`subvolid=5`), replace or set the default subvolume to the restored snapshot, and ensure `/etc/fstab` or Btrfs default subvolume configuration permanently activates the restored target.

---

## 9. Duplicate `runsvdir` Supervision in `asura-user-services`

* **Severity**: Medium (Service Contention / Crash Loop)
* **Affected File**:
  * [`ASURA-OS/session/runit/asura-user-services`](file:///home/mohit/code/asura/ASURA-OS/session/runit/asura-user-services#L84-L90)

### Problem
`start_services()` spawns `runsvdir -P "$USER_SERVICE_DIR" &` without checking if an existing `runsvdir` is already active for the user or verifying `$PID_FILE`:
```bash
if command -v runsvdir >/dev/null 2>&1; then
    echo "asura-user-services: starting runsvdir over $USER_SERVICE_DIR"
    runsvdir -P "$USER_SERVICE_DIR" &
    echo $! > "$PID_FILE"
    return 0
fi
```
If turnstile or a previous call to `asura-user-services` is already supervising `$USER_SERVICE_DIR`, two `runsvdir` instances run simultaneously. Both attempt to lock `supervise/lock`, causing continuous `resource temporarily unavailable` warnings and process restart thrashing.

### Impact
High CPU wakeups, race conditions, and corrupted service states.

### Resolution
Check for an existing running PID or active `runsvdir` before spawning:
```bash
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
    return 0
fi
if pgrep -u "$(id -u)" -x runsvdir >/dev/null 2>&1; then
    return 0
fi
```

---

## 10. Licence Metadata Contradiction in Packaging

* **Severity**: Low (Licensing Inconsistency)
* **Affected Files**:
  * [`ASURA-OS/packaging/xbps/build-repo.sh`](file:///home/mohit/code/asura/ASURA-OS/packaging/xbps/build-repo.sh#L88)
  * [`ASURA-OS/packaging/xbps/asura-daemon/template`](file:///home/mohit/code/asura/ASURA-OS/packaging/xbps/asura-daemon/template#L9)

### Problem
`ASURA-OS` is licensed under `GPL-3.0` (as defined in `LICENSE` and `LICENSING.md`). However:
* `build-repo.sh` sets `xbps-create -l "MIT"`
* `asura-daemon/template` sets `license="MIT"`

### Impact
Built XBPS packages metadata incorrectly advertises MIT license instead of GPL-3.0.

### Resolution
Update both files to state `GPL-3.0-only` or `GPL-3.0`.

---

## 11. Duplicate ID `hover` in `shell/hub/Controls/ListControl.qml`

* **Severity**: Low (QML Syntax Warning)
* **Affected File**:
  * [`ASURA-OS/shell/hub/Controls/ListControl.qml`](file:///home/mohit/code/asura/ASURA-OS/shell/hub/Controls/ListControl.qml#L215-L217) and [line 266](file:///home/mohit/code/asura/ASURA-OS/shell/hub/Controls/ListControl.qml#L266)

### Problem
In `ListControl.qml`, two separate `HoverHandler` instances in the same component define the exact same id:
* Line 215: `HoverHandler { id: hover }` (in row remove button)
* Line 266: `HoverHandler { id: hover }` (in add item button)

`qmllint` warns with:
```
Found a duplicated id. id hover was first declared at 215:21 [syntax.duplicate-ids]
```

### Impact
Property references to `hover.hovered` become ambiguous within the component.

### Resolution
Rename the IDs to `removeHover` and `addHover`, updating the corresponding opacity bindings.
