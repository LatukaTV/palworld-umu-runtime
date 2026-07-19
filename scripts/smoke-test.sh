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

printf '[runtime-smoke] OK: Wine64-Prefix, D-Bus, Xvfb, Launcher und Entrypoint sind ausführbar.\n'
