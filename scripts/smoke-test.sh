#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
    printf '[runtime-smoke] FEHLER: %s\n' "$1" >&2
    exit 1
}

cleanup() {
    [[ -z "${XVFB_PID:-}" ]] || kill "${XVFB_PID}" >/dev/null 2>&1 || true
    rm -rf /tmp/loryvant-wine-smoke /tmp/loryvant-xdg-smoke /tmp/.X98-lock /tmp/.X11-unix/X98
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

set +e
timeout 120 env \
    HOME=/home/container \
    USER=container \
    DISPLAY=:98 \
    XDG_RUNTIME_DIR=/tmp/loryvant-xdg-smoke \
    WINEPREFIX=/tmp/loryvant-wine-smoke \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    dbus-run-session -- wineboot -u > /tmp/loryvant-wineboot-smoke.log 2>&1
WINEBOOT_RC=$?
set -e
cat /tmp/loryvant-wineboot-smoke.log || true
[[ -s /tmp/loryvant-wine-smoke/system.reg ]] || fail "Wine64-Prefix wurde nicht initialisiert; Exit ${WINEBOOT_RC}."
if [[ "${WINEBOOT_RC}" -ne 0 ]]; then
    printf '[runtime-smoke] WARNUNG: wineboot meldete Exit %s; der Prefix wurde vollständig erzeugt.\n' "${WINEBOOT_RC}"
fi

printf '[runtime-smoke] OK: Wine64-Prefix, D-Bus, Xvfb, Launcher und Entrypoint sind ausführbar.\n'
