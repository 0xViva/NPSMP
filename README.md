<h1 align="center">NPSMP</h1>

<p align="center"><strong>Vanilla Minecraft 26.3 in a rootless Podman container. No forwarded ports.</strong></p>

<p align="center">
  <img src="https://img.shields.io/badge/Minecraft-26.3-3C8527?logo=minecraft&logoColor=white" alt="Minecraft 26.3">
  <img src="https://img.shields.io/badge/Java-25-ED8B00?logo=openjdk&logoColor=white" alt="Java 25">
  <img src="https://img.shields.io/badge/Podman-rootless-892CA0?logo=podman&logoColor=white" alt="Podman rootless">
  <img src="https://img.shields.io/badge/playit.gg-tunnel-6C5CE7" alt="playit.gg tunnel">
  <img src="https://img.shields.io/badge/license-unlicensed-lightgrey" alt="Unlicensed">
</p>

> **Play now.** `jensen-angie.tun.ply.gg` (SRV). Use
> `jensen-angie.tun.ply.gg:9369` if your client ignores SRV.

NPSMP is a vanilla Minecraft server for the Norsk programmering community.
It lives at `/home/ajg/servers/npsmp`, runs under systemd in a rootless Podman
container, and reaches players through a playit.gg tunnel. Setup is in
`scripts/`, `units/`, and `container/`.

Unlicensed. Questions go to [GitHub Issues](https://github.com/0xViva/NPSMP/issues).
