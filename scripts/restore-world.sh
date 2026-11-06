#!/bin/sh
# Restore a world snapshot into world/ and restart the server.
#
#   scripts/restore-world.sh [snapshot]
#
# With no argument, use the newest snapshots/world-*.tar.gz.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

SNAPSHOT=${1:-}
if [ -z "$SNAPSHOT" ]; then
    SNAPSHOT=$(ls -1t "$ROOT"/snapshots/world-*.tar.gz 2>/dev/null | head -1 || true)
fi
[ -n "$SNAPSHOT" ] || { echo "no snapshot found in $ROOT/snapshots" >&2; exit 1; }

case "$SNAPSHOT" in
    /*) ;;
    *) SNAPSHOT="$PWD/$SNAPSHOT" ;;
esac
[ -f "$SNAPSHOT" ] || { echo "snapshot not found: $SNAPSHOT" >&2; exit 1; }

systemctl --user stop np.service
rm -rf "$ROOT/world"
tar -C "$ROOT" -xzf "$SNAPSHOT" ./world
systemctl --user start np.service
echo "restored $SNAPSHOT"
