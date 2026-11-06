#!/bin/sh
# Consistent public world snapshot for the repo. Keeps 5 date-named archives.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ -f "$HOME/.config/np/backup.env" ]; then
    . "$HOME/.config/np/backup.env"
fi

DEST=${NP_BACKUP_DIR:-"$ROOT/backups"}
SNAPSHOTS=${NP_SNAPSHOT_DIR:-"$ROOT/snapshots"}
KEEP=${NP_SNAPSHOT_KEEP:-5}
DATE=$(date +%Y%m%d)

umask 077
mkdir -p "$DEST" "$SNAPSHOTS"
chmod 700 "$DEST"

exec 8>"$DEST/.lock"
flock -n 8 || { echo "another backup or snapshot is already running" >&2; exit 0; }

was_active=0
if systemctl --user is-active --quiet np.service; then
    was_active=1
    systemctl --user stop np.service
fi

cleanup() {
    if [ "$was_active" -eq 1 ]; then
        systemctl --user start np.service
    fi
}
trap cleanup EXIT INT TERM

tar -C "$ROOT" -czf "$SNAPSHOTS/world-$DATE.tar.gz" \
    --exclude='./world/session.lock' \
    --exclude='./world/players' \
    --exclude='./world/playerdata' \
    --exclude='./world/stats' \
    --exclude='./world/advancements' \
    ./world

ls -1t "$SNAPSHOTS"/world-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r f; do
    rm -f "$f"
done

echo "snapshot written: $SNAPSHOTS/world-$DATE.tar.gz"
