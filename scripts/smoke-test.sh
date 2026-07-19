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
wine64 --version
palworld-umu-start --self-test

python3 - <<'PY'
import importlib.machinery
import importlib.util
import shutil
import tempfile
from pathlib import Path

loader = importlib.machinery.SourceFileLoader("launcher", "/usr/local/bin/palworld-umu-start")
spec = importlib.util.spec_from_loader(loader.name, loader)
launcher = importlib.util.module_from_spec(spec)
loader.exec_module(launcher)
root = Path(tempfile.mkdtemp(prefix="loryvant-save-smoke-"))
try:
    launcher.HOME = root
    launcher.SERVER_ROOT = root / "ModdedServer"
    launcher.EXE = launcher.SERVER_ROOT / "Pal/Binaries/Win64/PalServer-Win64-Shipping.exe"
    launcher.WIN64 = launcher.EXE.parent
    launcher.DEFAULT_INI = launcher.SERVER_ROOT / "DefaultPalWorldSettings.ini"
    launcher.NATIVE_SAVE_ROOT = root / "Pal/Saved"
    launcher.SAVE_ROOT = launcher.SERVER_ROOT / "Pal/Saved"
    launcher.SAVE_GAMES = launcher.SAVE_ROOT / "SaveGames"
    launcher.CONFIG_DIR = launcher.SAVE_ROOT / "Config/WindowsServer"
    launcher.CONFIG = launcher.CONFIG_DIR / "PalWorldSettings.ini"
    launcher.GAME_USER_SETTINGS = launcher.CONFIG_DIR / "GameUserSettings.ini"
    launcher.LINUX_CONFIG = launcher.SAVE_ROOT / "Config/LinuxServer/PalWorldSettings.ini"
    launcher.LINUX_GAME_USER_SETTINGS = launcher.SAVE_ROOT / "Config/LinuxServer/GameUserSettings.ini"
    launcher.MODS_ROOT = root / "Mods"
    launcher.BACKUP_ROOT = root / ".loryvant-backups"
    launcher.MOD_BACKUP_ROOT = launcher.BACKUP_ROOT / "mods"
    launcher.SAVE_BACKUP_ROOT = launcher.BACKUP_ROOT / "saves"
    launcher.MIGRATION_MARKER = launcher.SAVE_ROOT / ".loryvant-v0.2.10-migrated"

    world = "ABCDEF0123456789"
    world_dir = launcher.NATIVE_SAVE_ROOT / "SaveGames/0" / world
    world_dir.mkdir(parents=True)
    (world_dir / "Level.sav").write_bytes(b"level")
    linux_config = launcher.NATIVE_SAVE_ROOT / "Config/LinuxServer"
    linux_config.mkdir(parents=True)
    (linux_config / "PalWorldSettings.ini").write_text("x" * 1300)
    (linux_config / "GameUserSettings.ini").write_text(
        "[/Script/Pal.PalGameLocalSettings]\nDedicatedServerName=" + world + "\n"
    )
    launcher.prepare_directories()
    launcher.prepare_independent_saved()
    assert not launcher.SAVE_ROOT.is_symlink()
    launcher.DEFAULT_INI.parent.mkdir(parents=True, exist_ok=True)
    launcher.DEFAULT_INI.write_text("x" * 1300)
    launcher.migrate_configuration()
    selected = launcher.select_world_name()
    assert selected == world
    launcher.write_dedicated_name(selected)
    launcher.MODS_ROOT.mkdir(parents=True, exist_ok=True)
    launcher.prepare_storage()
    assert launcher.read_dedicated_name(launcher.GAME_USER_SETTINGS) == world
    assert launcher.MIGRATION_MARKER.is_file()
    print("[runtime-smoke] Save-Migration, DedicatedServerName und atomarer Zielpfad geprüft.")
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
    dbus-run-session -- wineboot -u > /tmp/loryvant-wineboot-smoke.log 2>&1
WINEBOOT_RC=$?
timeout 120 env WINEPREFIX="${SMOKE_PREFIX}" wineserver -w >> /tmp/loryvant-wineboot-smoke.log 2>&1
WINESERVER_RC=$?
set -e
cat /tmp/loryvant-wineboot-smoke.log || true
[[ -s "${SMOKE_PREFIX}/system.reg" ]] || \
    fail "Wine64-Prefix wurde nicht initialisiert; wineboot=${WINEBOOT_RC}, wineserver=${WINESERVER_RC}."
if [[ "${WINEBOOT_RC}" -ne 0 || "${WINESERVER_RC}" -ne 0 ]]; then
    printf '[runtime-smoke] WARNUNG: Prefix vollständig; wineboot=%s, wineserver=%s.\n' \
        "${WINEBOOT_RC}" "${WINESERVER_RC}"
fi

printf '[runtime-smoke] OK: Wine64-Prefix, Save-Migration, D-Bus, Xvfb, Launcher und Entrypoint sind ausführbar.\n'
