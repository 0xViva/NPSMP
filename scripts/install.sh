#!/bin/sh
# Install the systemd/Quadlet units from this repo into the user's config dirs.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

mkdir -p "$HOME/.config/containers/systemd" "$HOME/.config/systemd/user"

install -m 0644 "$ROOT/units/np.container"       "$HOME/.config/containers/systemd/np.container"
install -m 0644 "$ROOT/units/np-backup.service"  "$HOME/.config/systemd/user/np-backup.service"
install -m 0644 "$ROOT/units/np-backup.timer"    "$HOME/.config/systemd/user/np-backup.timer"

chmod +x "$ROOT/scripts/"*.sh "$ROOT/scripts/"*.py "$ROOT/console"
systemctl --user daemon-reload

cat <<EOF
units installed.

  build:  podman build -t localhost/np-server:25 "$ROOT/container"
  start:  systemctl --user start np
  enable: systemctl --user enable np-backup.timer
          (the Quadlet np unit is enabled by its [Install] section)

The playit agent is shared with atm11 (units/playit.service in that repo).
Create the second tunnel with: "$ROOT/scripts/playit-tunnel.py" create
EOF
