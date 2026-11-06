#!/bin/sh
# Stop the np server. systemd sends SIGTERM, so the world is saved and the
# JVM exits cleanly; this can take a few seconds.
set -eu

systemctl --user stop np.service
echo "np stopped"
