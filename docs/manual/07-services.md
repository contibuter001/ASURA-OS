# Services, firmware and downloads

## Optional services

Off until you need them, one command each:

```sh
asura enable --list        # each one, on or off
asura enable docker        # also: bluetooth, printing, ssh, libvirt, tailscale
asura disable docker
```

Enabling installs what is missing, starts the service now and at every boot,
and adds you to its group (log out and in once for that).

## The firewall

Incoming connections are blocked; everything you start (browsing, updates)
works. Services you enable that listen for connections (SSH, for example) may
need a rule in `/etc/nftables.conf`.

## Faster downloads

```sh
asura mirror fastest       # time the mirrors and use the quickest
asura mirror list
asura mirror reset
```
