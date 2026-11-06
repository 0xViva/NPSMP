#!/bin/sh
# Start the np server.
set -eu

systemctl --user start np.service
echo "np started"
