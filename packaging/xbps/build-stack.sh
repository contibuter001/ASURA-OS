#!/bin/sh
# Build the Hyprland stack packages from ASURA-OS/void-packages (branch asura).
#
# Usage: packaging/xbps/build-stack.sh [OUT_DIR] [VOID_PACKAGES_DIR]
#
# Clones ASURA-OS/void-packages at the asura branch (or uses VOID_PACKAGES_DIR if provided),
# builds the Hyprland stack packages with xbps-src, and collects them in OUT_DIR.
set -eu

OUT_DIR=${1:-build/repo/current}
VOID_PACKAGES_DIR=${2:-}
ARCH=x86_64

mkdir -p "$OUT_DIR"
OUT_DIR=$(CDPATH='' cd -- "$OUT_DIR" && pwd)

STACK_PACKAGES="
hyprutils
hyprwayland-scanner
hyprlang
hyprcursor
hyprgraphics
aquamarine
hyprland-protocols
hyprwire
hyprtoolkit
hyprland
xdg-desktop-portal-hyprland
hypridle
hyprlock
hyprpicker
"

# If a local void-packages directory wasn't provided, clone ASURA-OS/void-packages
WORK_DIR=""
if [ -z "$VOID_PACKAGES_DIR" ] || [ ! -d "$VOID_PACKAGES_DIR" ]; then
	WORK_DIR=$(mktemp -d -t asura-void-packages-XXXXXX)
	trap 'rm -rf "$WORK_DIR"' EXIT INT TERM
	echo "build-stack: cloning ASURA-OS/void-packages at branch asura..."
	git clone --depth 1 -b asura https://github.com/ASURA-OS/void-packages.git "$WORK_DIR"
	VP_DIR="$WORK_DIR"
else
	VP_DIR="$VOID_PACKAGES_DIR"
fi

echo "build-stack: preparing to build stack in $VP_DIR..."
cd "$VP_DIR"

if [ -x "./xbps-src" ]; then
	if [ ! -d "masterdir" ]; then
		echo "build-stack: binary-bootstrap for xbps-src..."
		./xbps-src -A "$ARCH" binary-bootstrap || true
	fi
	for pkg in $STACK_PACKAGES; do
		if [ -d "srcpkgs/$pkg" ]; then
			echo "build-stack: building $pkg..."
			./xbps-src -A "$ARCH" pkg "$pkg" || {
				echo "build-stack: failed to build $pkg" >&2
				exit 1
			}
		fi
	done

	# Copy built packages to OUT_DIR
	if [ -d "hostdir/binpkgs" ]; then
		find hostdir/binpkgs -name "*.xbps" -exec cp -f {} "$OUT_DIR/" \;
	fi
else
	echo "build-stack: xbps-src not executable in $VP_DIR; skipping xbps-src compilation step"
fi

# Index repository if xbps-rindex exists
if command -v xbps-rindex >/dev/null 2>&1; then
	echo "build-stack: indexing repository at $OUT_DIR..."
	for pkg in "$OUT_DIR"/*.xbps; do
		[ -e "$pkg" ] || continue
		xbps-rindex -a "$pkg"
	done

	# Retain up to 3 versions per package name
	if command -v python3 >/dev/null 2>&1; then
		python3 - "$OUT_DIR" <<'PY'
import os, sys, glob, re

out_dir = sys.argv[1]
xbps_files = glob.glob(os.path.join(out_dir, "*.xbps"))
pkgs = {}
for f in xbps_files:
    fname = os.path.basename(f)
    m = re.match(r"^(.+)-([0-9].+)\.([^.]+)\.xbps$", fname)
    if m:
        name = m.group(1)
        pkgs.setdefault(name, []).append((os.path.getmtime(f), f))

for name, files in pkgs.items():
    if len(files) > 3:
        files.sort(key=lambda x: x[0], reverse=True)
        for _, old_f in files[3:]:
            try:
                os.remove(old_f)
                sig_f = old_f + ".sig2"
                if os.path.exists(sig_f):
                    os.remove(sig_f)
                print(f"pruned old package version: {os.path.basename(old_f)}")
            except OSError:
                pass
PY
	fi

	xbps-rindex -c "$OUT_DIR" 2>/dev/null || true
	xbps-rindex -r "$OUT_DIR" 2>/dev/null || true

	# Sign repository and packages if key is set
	if [ -n "${XBPS_SIGNING_KEY:-}" ]; then
		echo "build-stack: signing repository and packages..."
		xbps-rindex --sign --signedby "ASURA OS" --privkey "$XBPS_SIGNING_KEY" "$OUT_DIR"
		for pkg in "$OUT_DIR"/*.xbps; do
			[ -e "$pkg" ] || continue
			xbps-rindex --sign-pkg --privkey "$XBPS_SIGNING_KEY" "$pkg"
		done
	else
		echo "build-stack: XBPS_SIGNING_KEY is not set; packages and repository are unsigned."
	fi
fi

echo "build-stack: complete."
