#!/usr/bin/env python3
"""Minimal Minecraft RCON client for the np container.

Reads rcon.password from ../server.properties. The container publishes RCON on
127.0.0.1:25576 (25575 inside the container), so this connects to the host port
unless NP_RCON_PORT says otherwise.

    scripts/rcon.py list
    scripts/rcon.py whitelist add SomeName
    scripts/rcon.py save-all
"""
import os
import pathlib
import socket
import struct
import sys

PROPS = pathlib.Path(__file__).resolve().parent.parent / "server.properties"
HOST_PORT = int(os.environ.get("NP_RCON_PORT", "25576"))


def properties():
    out = {}
    for line in PROPS.read_text().splitlines():
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            out[key] = value
    return out


def read_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise EOFError("connection closed")
        buf += chunk
    return buf


def send(sock, request_id, packet_type, body):
    payload = struct.pack("<ii", request_id, packet_type) + body.encode() + b"\x00\x00"
    sock.sendall(struct.pack("<i", len(payload)) + payload)


def receive(sock):
    length = struct.unpack("<i", read_exact(sock, 4))[0]
    data = read_exact(sock, length)
    request_id, packet_type = struct.unpack("<ii", data[:8])
    return request_id, packet_type, data[8:-2].decode("utf-8", "replace")


def main():
    props = properties()
    if props.get("enable-rcon") != "true":
        sys.exit("enable-rcon is not true in server.properties")
    password = props.get("rcon.password", "")
    if not password:
        sys.exit("rcon.password is empty in server.properties")
    if len(sys.argv) < 2:
        sys.exit("usage: rcon.py <command...>")

    host = "127.0.0.1"
    command = " ".join(sys.argv[1:])

    with socket.create_connection((host, HOST_PORT), timeout=10) as sock:
        send(sock, 1, 3, password)
        request_id, _, _ = receive(sock)
        if request_id == -1:
            sys.exit("RCON authentication failed")

        send(sock, 2, 2, command)
        sock.settimeout(1.0)
        lines = []
        while True:
            try:
                _, _, body = receive(sock)
            except (socket.timeout, EOFError):
                break
            lines.append(body)
            if len(lines) >= 200:
                break

    print("\n".join(line for line in lines if line))


main()
