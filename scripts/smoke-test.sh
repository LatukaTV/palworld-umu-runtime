#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
    printf '[runtime-smoke] FEHLER: %s\n' "$1" >&2
    exit 1
}

SMOKE_PREFIX=/home/container/.loryvant-wine-smoke

cleanup() {
    env WINEPREFIX="${SMOKE_PREFIX}" wineserver -k >/dev/null 2>&1 || true
    sleep .2
    [[ -z "${XVFB_PID:-}" ]] || kill "${XVFB_PID}" >/dev/null 2>&1 || true
    rm -rf "${SMOKE_PREFIX}" /tmp/loryvant-xdg-smoke /tmp/.X98-lock /tmp/.X11-unix/X98
}
trap cleanup EXIT

/usr/local/bin/palworld-umu-image-preflight
python3 --version
[[ "$(wine64 --version)" == "wine-11.13" ]] || fail "WineHQ 11.13 fehlt."
palworld-umu-start --self-test
/usr/local/bin/palworld-umu-start-core --self-test

python3 - <<'PY'
import importlib.machinery
import importlib.util
import shutil
import tempfile
from pathlib import Path


def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, path)
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


core = load("launcher_core", "/usr/local/bin/palworld-umu-start-core")
root = Path(tempfile.mkdtemp(prefix="loryvant-save-smoke-"))
try:
    core.HOME = root
    core.SERVER_ROOT = root / "ModdedServer"
    core.EXE = core.SERVER_ROOT / "Pal/Binaries/Win64/PalServer-Win64-Shipping.exe"
    core.WIN64 = core.EXE.parent
    core.DEFAULT_INI = core.SERVER_ROOT / "DefaultPalWorldSettings.ini"
    core.NATIVE_SAVE_ROOT = root / "Pal/Saved"
    core.SAVE_ROOT = core.SERVER_ROOT / "Pal/Saved"
    core.SAVE_GAMES = core.SAVE_ROOT / "SaveGames"
    core.CONFIG_DIR = core.SAVE_ROOT / "Config/WindowsServer"
    core.CONFIG = core.CONFIG_DIR / "PalWorldSettings.ini"
    core.GAME_USER_SETTINGS = core.CONFIG_DIR / "GameUserSettings.ini"
    core.LINUX_CONFIG = core.SAVE_ROOT / "Config/LinuxServer/PalWorldSettings.ini"
    core.LINUX_GAME_USER_SETTINGS = core.SAVE_ROOT / "Config/LinuxServer/GameUserSettings.ini"
    core.MODS_ROOT = root / "Mods"
    core.BACKUP_ROOT = root / ".loryvant-backups"
    core.MOD_BACKUP_ROOT = core.BACKUP_ROOT / "mods"
    core.SAVE_BACKUP_ROOT = core.BACKUP_ROOT / "saves"
    core.MIGRATION_MARKER = core.SAVE_ROOT / ".loryvant-v0.2.10-migrated"

    world = "ABCDEF0123456789"
    world_dir = core.NATIVE_SAVE_ROOT / "SaveGames/0" / world
    world_dir.mkdir(parents=True)
    (world_dir / "Level.sav").write_bytes(b"level")
    linux_config = core.NATIVE_SAVE_ROOT / "Config/LinuxServer"
    linux_config.mkdir(parents=True)
    (linux_config / "PalWorldSettings.ini").write_text("x" * 1300)
    (linux_config / "GameUserSettings.ini").write_text(
        "[/Script/Pal.PalGameLocalSettings]\nDedicatedServerName=" + world + "\n"
    )
    core.prepare_directories()
    core.prepare_independent_saved()
    assert not core.SAVE_ROOT.is_symlink()
    core.DEFAULT_INI.parent.mkdir(parents=True, exist_ok=True)
    core.DEFAULT_INI.write_text("x" * 1300)
    core.migrate_configuration()
    selected = core.select_world_name()
    assert selected == world
    core.write_dedicated_name(selected)
    core.MODS_ROOT.mkdir(parents=True, exist_ok=True)
    core.prepare_storage()
    assert core.read_dedicated_name(core.GAME_USER_SETTINGS) == world
    assert core.MIGRATION_MARKER.is_file()

    wrapper = load("launcher_wrapper", "/usr/local/bin/palworld-umu-start")
    wrapper.HOME = root
    wrapper.SAVE_ROOT = core.SAVE_ROOT
    wrapper.SAVE_GAMES = core.SAVE_ROOT / "SaveGames/0"
    wrapper.GAME_USER_SETTINGS = core.GAME_USER_SETTINGS
    wrapper.BACKUP_ROOT = root / ".loryvant-backups/saves"
    wrapper.MARKER = wrapper.SAVE_ROOT / ".loryvant-v0.2.12-backup-tree-reset"
    wrapper.WINE_PREFIX = root / ".wine-palworld-modded"
    wrapper.WINE_BACKUP_ROOT = root / ".loryvant-backups/wine-prefixes"
    wrapper.WINE_MARKER = wrapper.WINE_PREFIX / ".loryvant-wine-version"
    wrapper.WINE_SYSTEM_REG = wrapper.WINE_PREFIX / "system.reg"
    wrapper.WINE_KERNEL32 = wrapper.WINE_PREFIX / "drive_c/windows/system32/kernel32.dll"

    wrapper.WINE_PREFIX.mkdir(parents=True)
    wrapper.WINE_SYSTEM_REG.write_text("old-prefix")
    wrapper.WINE_MARKER.write_text("wine-10.0\n")
    wrapper.prepare_wine_runtime()
    assert wrapper.WINE_MARKER.read_text().strip() == "wine-11.13"
    assert not wrapper.WINE_SYSTEM_REG.exists()
    old_prefixes = list(wrapper.WINE_BACKUP_ROOT.glob("wine-prefix-incomplete-*"))
    assert len(old_prefixes) == 1
    assert (old_prefixes[0] / "system.reg").read_text() == "old-prefix"

    old_tree = wrapper.SAVE_GAMES / world / "backup"
    (old_tree / "local/old").mkdir(parents=True)
    (old_tree / "world/old").mkdir(parents=True)
    (old_tree / "local/old/LocalData.sav").write_bytes(b"old-local")
    (old_tree / "world/old/Level.sav").write_bytes(b"old-world")
    wrapper.reset_backup_tree()
    fresh = wrapper.SAVE_GAMES / world / "backup"
    assert (fresh / "local").is_dir()
    assert (fresh / "world").is_dir()
    assert wrapper.MARKER.is_file()
    preserved = list(wrapper.BACKUP_ROOT.glob(f"generated-backup-tree-{world}-*"))
    assert len(preserved) == 1
    assert (preserved[0] / "local/old/LocalData.sav").read_bytes() == b"old-local"
    assert (preserved[0] / "world/old/Level.sav").read_bytes() == b"old-world"
    print("[runtime-smoke] Prefix-Recovery, Save-Migration, Weltzuordnung und Backup-Unterbaum-Reparatur geprüft.")
finally:
    shutil.rmtree(root, ignore_errors=True)
PY

mkdir -p /tmp/loryvant-xdg-smoke
chmod 0700 /tmp/loryvant-xdg-smoke
DISPLAY=:98 XDG_RUNTIME_DIR=/tmp/loryvant-xdg-smoke Xvfb :98 -screen 0 800x600x24 -nolisten tcp -ac -noreset >/tmp/loryvant-xvfb-smoke.log 2>&1 &
XVFB_PID=$!
for _ in $(seq 1 100); do
    [[ -S /tmp/.X11-unix/X98 ]] && kill -0 "${XVFB_PID}" 2>/dev/null && break
    sleep .1
done
[[ -S /tmp/.X11-unix/X98 ]] || { cat /tmp/loryvant-xvfb-smoke.log >&2 || true; fail "Xvfb-Socket fehlt."; }

rm -rf "${SMOKE_PREFIX}"
set +e
timeout 120 env \
    HOME=/home/container \
    USER=container \
    DISPLAY=:98 \
    XDG_RUNTIME_DIR=/tmp/loryvant-xdg-smoke \
    WINEPREFIX="${SMOKE_PREFIX}" \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    dbus-run-session -- bash -lc 'wineboot -u; rc=$?; wineserver -k >/dev/null 2>&1 || true; wineserver -w >/dev/null 2>&1 || true; exit "$rc"' \
    > /tmp/loryvant-wineboot-smoke.log 2>&1
WINEBOOT_RC=$?
timeout 30 env WINEPREFIX="${SMOKE_PREFIX}" wineserver -w >> /tmp/loryvant-wineboot-smoke.log 2>&1
WINESERVER_RC=$?
set -e
cat /tmp/loryvant-wineboot-smoke.log || true
[[ -s "${SMOKE_PREFIX}/system.reg" ]] || \
    fail "Wine64-Prefix wurde nicht initialisiert; wineboot=${WINEBOOT_RC}, wineserver=${WINESERVER_RC}."
[[ -s "${SMOKE_PREFIX}/drive_c/windows/system32/kernel32.dll" ]] || \
    fail "Wine64-Prefix enthält keine kernel32.dll; wineboot=${WINEBOOT_RC}, wineserver=${WINESERVER_RC}."
set +e
timeout 30 env \
    HOME=/home/container \
    USER=container \
    DISPLAY=:98 \
    XDG_RUNTIME_DIR=/tmp/loryvant-xdg-smoke \
    WINEPREFIX="${SMOKE_PREFIX}" \
    WINEARCH=win64 \
    WINEDEBUG=+loaddll,+module \
    dbus-run-session -- bash -lc 'wine64 cmd.exe /c ver; rc=$?; wineserver -k >/dev/null 2>&1 || true; exit "$rc"' \
    > /tmp/loryvant-wine-process-smoke.log 2>&1
WINE_PROCESS_RC=$?
set -e
cat /tmp/loryvant-wine-process-smoke.log || true
[[ "${WINE_PROCESS_RC}" -eq 0 ]] || \
    fail "Wine64-Prefix ist nicht funktional ausführbar; wine-process=${WINE_PROCESS_RC}."
if [[ "${WINEBOOT_RC}" -ne 0 || "${WINESERVER_RC}" -ne 0 ]]; then
    printf '[runtime-smoke] WARNUNG: Prefix funktional; wineboot=%s, wineserver=%s.\n' \
        "${WINEBOOT_RC}" "${WINESERVER_RC}"
fi

printf '[runtime-smoke] OK: WineHQ 11.13, funktionaler Prefix, Prefix-Recovery, Save-Migration, Backup-Unterbaum-Reparatur, D-Bus, Xvfb, Launcher und Entrypoint geprüft.\n'
