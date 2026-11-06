#!/bin/sh
# Download a vanilla Minecraft server.jar from Mojang's version manifest.
#
#   scripts/download.sh            # latest release, updates VERSION
#   scripts/download.sh 26.3       # a specific release
#
# The jar is verified against Mojang's published SHA-1 before it is installed.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=${1:-}

python3 - "$ROOT" "$VERSION" <<'PY'
import hashlib
import json
import pathlib
import sys
import urllib.request

root = pathlib.Path(sys.argv[1])
requested = sys.argv[2].strip()

with urllib.request.urlopen("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json") as r:
    manifest = json.load(r)

version = requested or manifest["latest"]["release"]
entry = next((v for v in manifest["versions"] if v["id"] == version), None)
if entry is None:
    sys.exit(f"unknown Minecraft version: {version}")

with urllib.request.urlopen(entry["url"]) as r:
    meta = json.load(r)

server = meta["downloads"]["server"]
print(f"downloading Minecraft {version} server.jar ({server['size'] / 1_000_000:.1f} MB)")
with urllib.request.urlopen(server["url"]) as r:
    data = r.read()

digest = hashlib.sha1(data).hexdigest()
if digest != server["sha1"]:
    sys.exit(f"sha1 mismatch: got {digest}, expected {server['sha1']}")

(root / "server.jar").write_bytes(data)
(root / "VERSION").write_text(version + "\n")
print(f"installed server.jar for {version}")
PY
