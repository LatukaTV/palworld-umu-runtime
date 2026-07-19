# Palworld Windows Mod Platform

## Scope

The v0.2.9 runtime provides a generic Windows dedicated-server environment for Palworld server mods. It downloads, bundles and enables zero third-party mods. PalDefender, UE4SS and every other mod remain user-managed files.

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

The launcher creates this initial configuration automatically:

```text
/home/container/Mods/PalModSettings.ini
```

```ini
[PalModSettings]
bGlobalEnableMod=true
WorkshopRootDir=Z:\home\container\Mods\Workshop
```

Add one line for every enabled package, using the `PackageName` value from `Info.json`:

```ini
ActiveModList=PackageNameFromInfoJson
```

The launcher also passes the same Workshop root through Palworld's supported `-workshopdir` option. Palworld deploys enabled packages on restart according to their `Info.json` install rules.

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

## v0.2.10 save-path correction

The v0.2.9 shared-save symlink is historical. v0.2.10 removes that link before SteamCMD runs and uses this real Windows save directory:

```text
/home/container/ModdedServer/Pal/Saved
```

The native fallback remains here:

```text
/home/container/Pal/Saved
```

On the first v0.2.10 start, the launcher:

1. creates a complete archive under `/home/container/.loryvant-backups/saves`;
2. copies the native world, player data and configuration into the real Windows save directory;
3. selects the existing world folder in `WindowsServer/GameUserSettings.ini` through `DedicatedServerName`;
4. runs the configuration parser from `/home/container/ModdedServer`;
5. verifies copy and atomic rename operations in the Windows save target.

After migration, both runtimes have separate persistent save trees. Windows mod-server progress stays in `ModdedServer/Pal/Saved`; the confirmed native v0.2.8 fallback remains unchanged until an administrator intentionally copies data between them.
