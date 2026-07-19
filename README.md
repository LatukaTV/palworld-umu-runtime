# Palworld Runtime

Custom `linux/amd64` runtime image for Pelican/Pterodactyl Palworld dedicated servers.

## Current profile

Version `0.2.8` runs Pocketpair's native Linux dedicated server directly:

```text
/home/container/Pal/Binaries/Linux/PalServer-Linux-Shipping Pal
```

The Pelican startup remains:

```text
palworld-umu-start
```

The command name is retained for backward compatibility with existing Egg installations. The runtime itself contains no UMU, Proton, Wine, Xvfb or nested sandbox.

## Components

- base image: `ghcr.io/parkervcp/steamcmd:debian`
- target: `linux/amd64`
- package: `ghcr.io/latukatv/palworld-umu-runtime`
- immutable tag: `sha-<commit>`
- moving tags: `native-linux`, `latest`

## Runtime behavior

The image-internal launcher:

- updates Steam App `2394010` with the Linux platform depot;
- migrates an existing `WindowsServer/PalWorldSettings.ini` to `LinuxServer` once;
- keeps `Pal/Saved/SaveGames` unchanged;
- runs the configuration parser with secret redaction;
- enables the container-local REST API;
- disables RCON;
- starts the native Linux server;
- emits the Pelican readiness marker after a successful REST `info` response;
- maps panel commands such as `info`, `showplayers`, `save` and `shutdown` to REST.

## Effective server arguments

```text
Pal
-publiclobby
-port=<SERVER_PORT>
-publicport=<SERVER_PORT>
-players=<MAX_PLAYERS>
-publicip=<PUBLIC_IP, when configured>
-logformat=text
```

## Security

- The process runs as the unprivileged `container` user.
- REST listens inside the container and receives no host allocation.
- Credentials are stored in the server configuration and redacted from parser output.
- The image requires no privileged mode, extra capabilities, host sysctls or relaxed AppArmor/Seccomp profiles.
- GitHub Actions builds one candidate, runs preflight and smoke tests, then publishes that exact image.

## Live acceptance

Production acceptance requires:

1. native Linux binary reaches REST readiness;
2. startup duration is recorded;
3. player joins and plays for at least 15 minutes;
4. world and player saves advance;
5. disconnect and reconnect succeed;
6. REST remains responsive after gameplay.
