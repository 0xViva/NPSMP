#!/usr/bin/env python3
"""Create or inspect the playit.gg tunnel for this server.

The host runs one shared playit agent (atm11's units/playit.service). A single
agent can carry several tunnels, so this adds a second tunnel that forwards the
agent's local 127.0.0.1:25566 to the np container.

Tunnel management normally happens at https://playit.gg/account/tunnels; this
script is a small convenience wrapper around playit's agent-key API.

    scripts/playit-tunnel.py list
    scripts/playit-tunnel.py create
"""
import json
import os
import pathlib
import sys
import tomllib
import urllib.error
import urllib.request

API = "https://api.playit.gg"
NAME = "np-vanilla"
LOCAL_IP = "127.0.0.1"
LOCAL_PORT = 25566


def secret():
    value = os.environ.get("PLAYIT_SECRET")
    if value:
        return value.strip()
    path = pathlib.Path(
        os.environ.get("PLAYIT_CONFIG", "~/.config/playit_gg/playit.toml")
    ).expanduser()
    with path.open("rb") as f:
        return tomllib.load(f)["secret_key"]


def api(path, payload):
    request = urllib.request.Request(
        API + path,
        data=json.dumps(payload).encode(),
        headers={
            "Authorization": f"agent-key {secret()}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            body = json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        sys.exit(f"{path}: HTTP {error.code}: {detail}")
    if body.get("status") != "success":
        sys.exit(f"{path}: {json.dumps(body)}")
    return body["data"]


def address(tunnel):
    alloc = (tunnel.get("alloc") or {}).get("data") or {}
    domain = alloc.get("assigned_domain") or alloc.get("assigned_srv")
    port = alloc.get("port_start")
    if not domain:
        return "(not allocated yet)"
    return f"{domain}:{port}" if port else domain


def tunnels():
    return api("/tunnels/list", {}).get("tunnels", [])


def agent_id():
    return api("/v1/agents/rundata", {})["agent_id"]


def find_np(items):
    for tunnel in items:
        origin = (tunnel.get("origin") or {}).get("data") or {}
        if tunnel.get("name") == NAME and origin.get("local_port") == LOCAL_PORT:
            return tunnel
    return None


def cmd_list():
    items = tunnels()
    if not items:
        print("no tunnels")
        return
    for tunnel in items:
        origin = (tunnel.get("origin") or {}).get("data") or {}
        state = "active" if tunnel.get("active") else "inactive"
        print(
            f"{tunnel.get('name')}: {tunnel.get('tunnel_type')} "
            f"{tunnel.get('port_type')} "
            f"{origin.get('local_ip')}:{origin.get('local_port')} -> "
            f"{address(tunnel)} [{state}]"
        )


def cmd_create():
    existing = find_np(tunnels())
    if existing:
        print(f"tunnel already exists: {address(existing)}")
        return

    data = api(
        "/tunnels/create",
        {
            "name": NAME,
            "tunnel_type": "minecraft-java",
            "port_type": "tcp",
            "port_count": 1,
            "origin": {
                "type": "agent",
                "data": {
                    "agent_id": agent_id(),
                    "local_ip": LOCAL_IP,
                    "local_port": LOCAL_PORT,
                },
            },
            "enabled": True,
            "alloc": None,
            "firewall_id": None,
            "proxy_protocol": None,
        },
    )
    tunnel = data.get("tunnel", data) if isinstance(data, dict) else data
    print(f"created tunnel: {address(tunnel)}")
    print("Re-run `list` in a few seconds if the address is still pending.")


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {"list", "create"}:
        sys.exit("usage: playit-tunnel.py list|create")
    {"list": cmd_list, "create": cmd_create}[sys.argv[1]]()


main()
