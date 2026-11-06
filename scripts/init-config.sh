#!/bin/sh
# Create the local server.properties from the example with fresh secrets.
#
#   scripts/init-config.sh
#
# Refuses to overwrite an existing server.properties.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TARGET="$ROOT/server.properties"

if [ -e "$TARGET" ]; then
    echo "server.properties already exists; not overwriting" >&2
    exit 1
fi

python3 - "$ROOT" <<'PY'
import pathlib
import secrets
import sys

root = pathlib.Path(sys.argv[1])
text = (root / "server.properties.example").read_text()
text = text.replace("rcon.password=CHANGE_ME", f"rcon.password={secrets.token_hex(16)}")
text = text.replace(
    "management-server-secret=CHANGE_ME",
    f"management-server-secret={secrets.token_hex(16)}",
)
target = root / "server.properties"
target.write_text(text)
target.chmod(0o600)
print("wrote server.properties with fresh RCON and management secrets")
PY
