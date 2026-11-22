# Installing apps, themes, bar styles and plugins

`asura-store` is ASURA's store, with a window and a command line. It installs
Void packages (XBPS), Flatpaks, and ASURA catalogue items (themes, bar styles,
plugins).

## Commands

```sh
asura-store --help
asura-store check                 # which providers (xbps, flatpak) are available
asura-store catalog               # the catalogue as JSON
asura-store search QUERY          # search the catalogue and the package sources
asura-store install ID            # install an item
asura-store remove ID             # remove an item
asura-store open                  # open the Store window
asura-store settings              # the Store's settings
```

Look an item up (`search`, `catalog`) before installing, and use its exact id.

## Plain packages

For a package the catalogue does not list, the system's package manager works
directly; installing needs root, so say what you would run first:

```sh
xbps-query -Rs NAME               # search the repositories
sudo xbps-install -S NAME         # install
sudo xbps-remove NAME             # remove
```

`apm` is ASURA's shorthand for the same verbs (`apm install NAME`).

## Afterwards

A new app appears in the launcher at once. A theme or bar style may need
`asura refresh` (or a logout) to take effect. A desktop that misbehaves after
an install: see [`diagnostics.md`](diagnostics.md).
