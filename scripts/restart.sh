#!/bin/sh
# Restart the np server (clean save on stop, then start again).
set -eu

systemctl --user restart np.service
echo "np restarted"
