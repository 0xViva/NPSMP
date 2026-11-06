#!/bin/sh
# Preload recent journal history, then attach to the live container console.
#
#   scripts/console-live.sh [history-lines]
#
# `podman attach` only shows output from the moment it connects, so the
# journalctl preload is what puts older lines into the tmux scrollback.
set -eu

HISTORY=${1:-200}

echo "=== np journal: last $HISTORY lines ==="
journalctl --user -u np -n "$HISTORY" --no-pager || true
echo
echo "=== live console ==="
echo "Type a command and press Enter. Ctrl-b d detaches; Ctrl-b [ scrolls; q exits scroll mode."
echo

exec podman attach --sig-proxy=false np
