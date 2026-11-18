# Packaging & XBPS Repository Architecture

ASURA OS uses the native **XBPS (X Binary Package System)** package manager from Void Linux.
System components, desktop shells, and tools are built and distributed as XBPS binary packages.

The packaging infrastructure resides in `packaging/xbps/`.

---

## Package Templates

Package build instructions are stored as templates in `packaging/xbps/`:

| Package Template | Description |
|---|---|
| `asura-desktop.template` | Core desktop control binary (`asura`), configuration schemas, session launchers, and runit service scripts. |
| `asura-shell.template` | Quickshell UI surfaces, theme tokens, widgets, icons, wallpapers, and Hub backend. |
| `asura-installer.template` | Guided system installer script, desktop launcher, and partition utilities. |
| `asura-store.template` | Software store CLI data plane (`asura-store`) and catalog manifests. |
| `asura-sysmon.template` | System resource monitor daemon (`asura-sysmon`) and desktop entry. |

---

## Building Binary Packages & Repository (`build-repo.sh`)

Binary packages are created using `xbps-create` and indexed with `xbps-rindex`.
The build workflow is driven by `packaging/xbps/build-repo.sh`.

### Package Build Pipeline

1. **Compilation**: Binaries are compiled with Go (`go build`) and stripped of debug symbols.
2. **Directory Staging**: Files are placed into target staging roots following Void filesystem hierarchy (`/usr/bin/`, `/usr/share/asura/`, `/etc/sv/`).
3. **Metadata Specification**:
   - `architecture`: `x86_64`
   - `maintainer`: `ASURA OS Team <team@asura-os.org>`
   - `license`: `GPL-3.0-only`
   - `pkgname` and `version`
4. **Package Creation**:
   ```sh
   xbps-create -A x86_64 -m "ASURA OS Team" -l "GPL-3.0-only" -s "Short summary" -V "0.1.0_1" destdir
   ```
5. **Repository Indexing**:
   ```sh
   xbps-rindex -a *.xbps
   xbps-rindex --sign --signedby "ASURA OS Signing Key" *.xbps
   ```

---

## Target System Configuration

A machine running ASURA OS registers the repository via `/usr/share/xbps.d/asura.conf`:

```text
# /usr/share/xbps.d/asura.conf
repository=https://repo.asura-os.org/current
```

Updates and package installations use native XBPS commands:

```sh
# Synchronize repositories and update all system packages
sudo xbps-install -Su

# Install ASURA specific packages
sudo xbps-install -S asura-desktop asura-shell asura-store asura-sysmon
```
