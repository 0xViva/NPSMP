# Vanilla Minecraft server (rootless Podman)

Vanilla Minecraft **26.3** — Java 25 — running in a rootless Podman container,
exposed only through a playit.gg tunnel.

Public address: **`jensen-angie.tun.ply.gg`** (the `np-vanilla` tunnel).
Minecraft clients normally use the name without a port because playit
publishes an SRV record; the explicit address is
`jensen-angie.tun.ply.gg:9369`.

## Why this layout

- **Rootless container.** The JVM runs as root inside a user namespace, which
  maps to your host user. It can only see `/data` (this directory). It has no
  capabilities, no new privileges, and a read-only root filesystem.
- **Loopback-only ports.** The container publishes `127.0.0.1:25566:25565` for
  the game and `127.0.0.1:25576:25575` for RCON. Nothing is reachable on the LAN
  or WAN; the host-side playit agent is the only client.
- **Playit instead of port forwarding.** Players connect to a `*.ply.gg`
  address, so your home IP never leaves your network. The host runs one shared
  playit agent (the one installed for atm11); the `np-vanilla` tunnel is a
  second tunnel under that same agent. The agent's unit description still says
  "ATM11 server", but it serves both tunnels.
- **This directory is the git repo.** `server.properties`, `whitelist.json`,
  `ops.json`, `user_jvm_args.txt` and `VERSION` are tracked; `server.jar`,
  `libraries/`, `versions/`, `world/` and `logs/` are ignored.

## Layout

| Path | Tracked | Purpose |
|---|---|---|
| `container/Containerfile` | yes | Java 25 runtime, pinned by digest |
| `units/np.container` | yes | Quadlet unit (Podman → systemd) |
| `units/np-backup.{service,timer}` | yes | nightly world+config archive |
| `scripts/*.sh`, `scripts/*.py` | yes | install, download, backup, RCON, playit tunnel |
| `server.properties` | yes | server config (contains RCON password) |
| `whitelist.json`, `ops.json` | yes | player access |
| `user_jvm_args.txt`, `VERSION` | yes | JVM flags and pinned MC version |
| `server.jar`, `libraries/`, `versions/` | no | downloaded/extracted on first run |
| `world/` | no | your save |
| `backups/` | no | local archives |

## First-time setup

```sh
# 1. Download the pinned Minecraft server jar (or the latest release)
scripts/download.sh

# 2. Build the runtime image
podman build -t localhost/np-server:25 container

# 3. Install the units (Quadlet reads ~/.config/containers/systemd)
scripts/install.sh

# 4. Start and enable
systemctl --user start np          # Quadlet units are enabled by [Install]
systemctl --user enable --now np-backup.timer

# 5. Create the second playit tunnel (the agent is shared with atm11)
scripts/playit-tunnel.py create
```

The playit agent itself is installed by the atm11 repo (`units/playit.service`).
If `systemctl --user status playit` is not active, start it there first.

## Day-to-day

```sh
systemctl --user start|stop|restart np
systemctl --user status np
journalctl --user -u np -f            # server console/log
podman ps                              # container view
podman exec -it np bash                # shell in the container

./console                              # persistent console (tmux); detach Ctrl-b d
scripts/rcon.py list
scripts/rcon.py whitelist add SomeName
scripts/rcon.py save-all

scripts/playit-tunnel.py list          # public address + tunnel state
systemctl --user status playit
journalctl --user -u playit -f
```

`./console` keeps the container's stdin open inside a tmux session, so closing
Ghostty or SSH only detaches. `--sig-proxy=false` means Ctrl-C cannot stop the
server — use `systemctl --user stop np` for that.

RCON listens on `127.0.0.1:25576` only and reads its password from
`server.properties`. That file is tracked, so keep the repo private.

## Friends and access

The server is currently open: `white-list=false`, `enforce-whitelist=false`,
and `whitelist.json` is empty. Anyone with the playit address can join.

To restrict it later, add names and turn the whitelist on:

```sh
scripts/rcon.py whitelist add TheirMinecraftName
scripts/rcon.py whitelist list
```

Then set `white-list=true` and `enforce-whitelist=true` in
`server.properties` and restart. Remove a name with
`scripts/rcon.py whitelist remove TheirMinecraftName`. There are no ops: use
RCON or the console for admin commands.

## Updating Minecraft

```sh
# latest release (updates VERSION)
scripts/download.sh

# or pin a specific release
scripts/download.sh 26.3

systemctl --user restart np
git diff VERSION
```

Back up first. If a newer release needs a newer Java, bump the digest in
`container/Containerfile`, rebuild the image, then restart. 26.3 requires Java 25.

## Backups

`scripts/backup.sh` stops the server (consistent save), tars the world and
config into `backups/`, and restarts it. The timer runs daily at 04:45 and keeps
14 copies.

```sh
systemctl --user start np-backup.service   # run now
scripts/backup.sh                         # same, directly
```

Restore:

```sh
systemctl --user stop np
tar -C . -xzf backups/np-YYYYMMDD-HHMMSS.tar.gz
systemctl --user start np
```

Keep copies off this machine too (`rsync`/restic to the VPS or a NAS) — local
archives do not survive disk failure.

## Playit tunnel

The tunnel is named `np-vanilla` and forwards the shared agent's
`127.0.0.1:25566` to the container. It is normally managed at
<https://playit.gg/account/tunnels>; `scripts/playit-tunnel.py` is a small
convenience wrapper around playit's agent-key API.

Current allocation:

| Field | Value |
|---|---|
| Public name | `jensen-angie.tun.ply.gg` |
| SRV target | `jensen-angie.tun.ply.gg:9369` |
| Local target | `127.0.0.1:25566` |

```sh
scripts/playit-tunnel.py list     # name, local target, public address, state
scripts/playit-tunnel.py create   # idempotent: does nothing if it exists
```

Minecraft clients can usually enter the `assigned_domain` without a port
because playit publishes an SRV record. If your client does not use SRV, append
the tunnel's `port_start` (`domain:port`). The script prints both pieces.

The agent secret lives in `~/.config/playit_gg/playit.toml`. Anyone with it can
manage the tunnels, so keep it private.

## Security notes

- **This server is open.** `white-list=false`, so anyone with the playit
  address can join. Turn the whitelist on if that changes.
- `server.properties` contains an RCON password and a management-server secret.
  Treat the repo as private; don't push it to a public remote.
- The container bounds a compromise to this directory. It does not make
  Minecraft memory-safe: keep the server and Java updated, and don't install
  random plugins or datapacks.
- playit sees your traffic metadata and your home IP; Minecraft's session is
  encrypted after login. That's the trade for not forwarding a port.
