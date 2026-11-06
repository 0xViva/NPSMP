#!/bin/sh
# Consistent snapshot of the world and config.
#
# Minecraft keeps writing region files while it runs, so a live tar can capture
# a torn world. This stops the service (which saves and exits), archives, then
# starts it again if it was running. Expect ~10-20s of downtime per run.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# Optional off-site copy. Configure NP_BACKUP_REMOTE in ~/.config/np/backup.env.
if [ -f "$HOME/.config/np/backup.env" ]; then
    . "$HOME/.config/np/backup.env"
fi

DEST=${NP_BACKUP_DIR:-"$ROOT/backups"}
KEEP=${NP_BACKUP_KEEP:-14}
STAMP=$(date +%Y%m%d-%H%M%S)

umask 077
mkdir -p "$DEST"
chmod 700 "$DEST"

exec 9>"$DEST/.lock"
flock -n 9 || { echo "another backup is already running" >&2; exit 0; }

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

tar -C "$ROOT" -czf "$DEST/np-$STAMP.tar.gz" \
    --exclude='./server.jar' \
    --exclude='./libraries' \
    --exclude='./versions' \
    --exclude='./logs' \
    --exclude='./backups' \
    --exclude='./crash-reports' \
    --exclude='./.git' \
    --exclude='./container' \
    --exclude='./units' \
    --exclude='./scripts' \
    --exclude='./world/session.lock' \
    .

ls -1t "$DEST"/np-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r f; do
    rm -f "$f"
done

if [ -n "${NP_BACKUP_REMOTE:-}" ]; then
    echo "syncing to $NP_BACKUP_REMOTE"
    rsync -a --delete --exclude='.lock' --chmod=D700,F600 \
        -e "ssh -o BatchMode=yes -o ConnectTimeout=15" \
        --timeout=300 \
        "$DEST/" "$NP_BACKUP_REMOTE"
fi

echo "backup written: $DEST/np-$STAMP.tar.gz"
