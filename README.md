# Palworld UMU Runtime

Custom `linux/amd64` runtime image for Pelican/Pterodactyl Palworld Windows dedicated servers.

## Purpose

The existing `ghcr.io/parkervcp/steamcmd:proton_8` image launches GE-Proton directly outside Steam's container runtime. In the observed Palworld test this produced an escalating `IClientUtils::SetLauncherType took too long` loop. GE-Proton officially supports non-Steam launches only through `umu-launcher`, which recreates the Steam Linux Runtime environment.

This repository therefore builds:

- base image: `ghcr.io/parkervcp/steamcmd:debian`
- UMU: `1.4.0`, verified by the upstream SHA-256 digest
- GE-Proton: `GE-Proton11-1`, verified with the upstream release SHA-512 file
- target: `linux/amd64`
- package: `ghcr.io/latukatv/palworld-umu-runtime`

## Image tags

- `latest`
- `umu-1.4.0-ge-proton11-1`
- immutable commit tag `sha-<commit>`

## Runtime paths

```text
/usr/local/bin/umu-run
/opt/umu/umu-run
/opt/ge-proton/proton
/home/container
```

## Expected Pelican launch environment

```bash
export GAMEID=2394010
export STORE=steam
export PROTONPATH=/opt/ge-proton
export WINEPREFIX=/home/container/.umu/prefixes/2394010
export STEAM_COMPAT_INSTALL_PATH=/home/container
export XDG_DATA_HOME=/home/container/.local/share
export PROTON_USE_XALIA=0
```

The Palworld executable is then launched with:

```bash
umu-run /home/container/Pal/Binaries/Win64/PalServer-Win64-Shipping.exe <arguments>
```

## Validation boundary

A successful container build proves only that the pinned tools were downloaded, verified and installed. The runtime is accepted for production only after all of these live tests pass:

1. server reaches `Running Palworld dedicated server on`;
2. no escalating Steam IPC loop;
3. player joins and completes character creation;
4. world and player save succeed;
5. disconnect and reconnect work without server restart;
6. the same sequence passes again with UE4SS enabled.

## Security

- No credentials or server data are built into the image.
- Upstream release artifacts are checksum-verified during the image build.
- GitHub Actions publishes with the repository-scoped `GITHUB_TOKEN`.
- The final process runs as the inherited unprivileged `container` user.

## Status

Initial runtime implementation. Live Palworld validation is pending.

## Current container-native runtime – 2026-07-19

The historical launch example above is retained for traceability. The current verified image uses these corrected paths and constraints:

```text
PROTONPATH=/opt/ge-proton-host
XDG_RUNTIME_DIR=/tmp/loryvant-xdg-runtime
DISPLAY=:99
```

- `/opt/ge-proton-host` keeps the verified GE-Proton11-1 files and removes only the manifest edge that would request pressure-vessel.
- Debian 13 supplies glibc 2.38 or newer for the GE-Proton host mode.
- Xvfb supplies an isolated headless X11 display inside the game container.
- `XDG_RUNTIME_DIR` is created in Pelican's writable `/tmp` tmpfs with mode `0700`.
- Xvfb listens only on the local Unix socket; TCP listening is disabled.
- No Docker, AppArmor, Seccomp, capability, kernel or Root-server changes are required.
- The Egg launches Xvfb inline in its normal startup field and then replaces the shell with `exec umu-run ...`; no server-side startup script is used.
