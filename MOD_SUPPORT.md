# Palworld Windows Mod Platform

## Scope

The v0.2.9 runtime provides a generic Windows dedicated-server environment for Palworld server mods. It does not download, bundle or enable PalDefender, UE4SS or any other third-party mod.

The confirmed native Linux v0.2.8 runtime remains available through its immutable image tag and release ZIP. The modded Windows server is installed separately below `/home/container/ModdedServer`.

## Persistent paths

```text
/home/container/ModdedServer
/home/container/ModdedServer/Pal/Binaries/Win64
/home/container/Mods
/home/container/Mods/Workshop
/home/container/Mods/PalModSettings.ini
/home/container/Pal/Saved
/home/container/.wine-palworld-modded
/home/container/.loryvant-backups/mods
```

`ModdedServer/Pal/Saved` links to `/home/container/Pal/Saved`. The Windows mod runtime therefore uses the existing world, player data and `WindowsServer` configuration while the installed Windows binaries remain isolated from the native server files.

`ModdedServer/Mods` links to `/home/container/Mods`. This exposes the official Palworld mod root directly through SFTP.

## Official Workshop format

Place each server-compatible mod below:

```text
/home/container/Mods/Workshop/<folder>/Info.json
```

After the first Windows-server start, configure:

```text
/home/container/Mods/PalModSettings.ini
```

Example:

```ini
[PalModSettings]
bGlobalEnableMod=true
ActiveModList=PackageNameFromInfoJson
```

The Palworld server deploys enabled packages on restart according to their `Info.json` install rules.

## Manual DLL loaders

Place proxy DLLs and their companion files beside the Windows server binary:

```text
/home/container/ModdedServer/Pal/Binaries/Win64
```

The launcher detects these common proxy names and configures Wine native-first loading automatically:

```text
d3d9.dll
winmm.dll
version.dll
xinput1_3.dll
dxgi.dll
```

`MOD_DLL_OVERRIDES=auto` uses detection. A comma-separated custom list can be supplied when another loader name is required.

## UE4SS, Lua and PAK destinations

The official Palworld Workshop deployment can populate these locations:

```text
/home/container/Mods/NativeMods/UE4SS
/home/container/Mods/NativeMods/UE4SS/Mods/<PackageName>
/home/container/ModdedServer/Pal/Content/Paks/LogicMods
/home/container/ModdedServer/Pal/Content/Paks/~WorkshopMods/<PackageName>
```

Manual mod archives must be inspected before extraction and copied to the path documented by their author.

## Backups

With `MOD_BACKUP_ON_START=1`, the launcher archives existing Workshop files, common DLL loaders, UE4SS directories and PAK mod directories before SteamCMD updates. Ten recent archives are retained below:

```text
/home/container/.loryvant-backups/mods
```

The panel command `modbackup` creates an additional snapshot on demand.

## Panel commands

```text
mods
modcheck
modbackup
modpaths
```

- `mods` lists `Info.json` packages and active package names.
- `modcheck` reports duplicate package names, missing active packages, invalid JSON and missing server install rules.
- `modbackup` creates a mod snapshot.
- `modpaths` prints all relevant SFTP locations.

## Safety boundary

Third-party server mods execute inside the Palworld Windows process. A faulty or outdated DLL, UE4SS module or PAK can crash the process or corrupt saves. Install one change at a time, keep the automatic backups enabled and complete a reconnect/save test after each mod update.
