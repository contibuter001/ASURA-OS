# ASURA's package repository

ASURA is built into one XBPS package, `asura`, holding everything
`installation/apply-repo.sh` installs: the Go tools, the desktop, the session,
the migrations and the system configuration. The `xbps-repo` workflow builds it
and publishes a signed repository.

## How it is built

1. `installation/apply-repo.sh --no-packages . build/stage` fills a staging
   tree, Go tools included.
2. `packaging/xbps/build-repo.sh OUT STAGE` (in a Void container) checks the
   stage holds the essentials, makes `asura-0.1.<commits>_1`, indexes `OUT`,
   and signs both when `XBPS_SIGNING_KEY` names a private key.
   - Files under `/etc` are configuration: a locally edited one is kept, and
     the new copy is installed beside it. `/etc/sv` service scripts always
     update.
   - `/etc/nftables.conf` and `/etc/turnstile/turnstile.conf` belong to other
     Void packages, so they stay out of the package; `apply-repo.sh` still
     installs ASURA's copies.
3. The package is installed in a clean Void container, with the Hyprland
   repository ASURA uses, so a broken package fails CI.

Every pull request that touches the packaging, and every `dev-unstable` commit
whose `ci` workflow passed, runs this. The built repository is kept as the
`asura-xbps-repo` artifact for seven days.

## Turning publishing on (once, by the owner)

Nothing is published until these are done. An unsigned repository is never
published.

1. **Make the signing key** on your own machine, and keep it private:

   ```sh
   openssl genrsa -out asura-repo.pem 4096
   ```

2. **Add it to the repository** as the Actions secret `XBPS_SIGNING_KEY`
   (Settings → Secrets and variables → Actions), pasting the whole PEM file.
3. **Turn on Pages** with "GitHub Actions" as the source (Settings → Pages).
4. Push to `dev-unstable` (or run the workflow by hand). Once `ci` passes, the
   repository is at `https://<owner>.github.io/<repo>/current`.

## Pointing machines at it (a follow-up change)

Once the repository is published:

- Add `repository=https://<owner>.github.io/<repo>/current` first in
  `system/xbps.d/asura.conf`, so new installs use it.
- Ship the public key so no one is asked to trust it by hand: after the first
  signed sync on any machine, copy its key file from `/var/db/xbps/keys/` into
  the repository, and install it with the ISO build and a migration.
- Add a migration that writes the repository line on existing machines, then
  `sudo xbps-install -Su` updates ASURA like any other package.

Until then, `asura update` installs ASURA from `dev-unstable` as it does now.
