#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
    printf '[runtime-smoke] FEHLER: %s\n' "$1" >&2
    exit 1
}

step() {
    printf '[runtime-smoke] PRÜFE: %s\n' "$1"
}

run_check() {
    local label="$1"
    shift

    step "$label"
    if "$@"; then
        return 0
    else
        local rc=$?
        fail "${label} fehlgeschlagen (Exit ${rc}): $*"
    fi
}

XVFB_PID=""
XDG_TEST_DIR="/tmp/loryvant-xdg-runtime-smoke"
cleanup() {
    if [[ -n "${XVFB_PID}" ]]; then
        kill "${XVFB_PID}" >/dev/null 2>&1 || true
        wait "${XVFB_PID}" >/dev/null 2>&1 || true
    fi
    rm -rf "${XDG_TEST_DIR}" /tmp/.X99-lock /tmp/.X11-unix/X99
}
trap cleanup EXIT
trap 'rc=$?; printf "[runtime-smoke] FEHLER: Zeile %s, Exit %s, Befehl: %s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

/usr/local/bin/palworld-umu-image-preflight

run_check "Python-Aufruf" python3 --version
run_check "UMU-CLI-Aufruf" umu-run --version
run_check "RCON-CLI-Aufruf" rcon --help

step "Headless-X11-Start als Containerbenutzer"
rm -rf "${XDG_TEST_DIR}" /tmp/.X99-lock /tmp/.X11-unix/X99
mkdir -p "${XDG_TEST_DIR}"
chmod 0700 "${XDG_TEST_DIR}"
export XDG_RUNTIME_DIR="${XDG_TEST_DIR}"
export DISPLAY=":99"
unset WAYLAND_DISPLAY || true
Xvfb "${DISPLAY}" -screen 0 1024x768x24 -nolisten tcp -ac -noreset \
    >/tmp/loryvant-xvfb-smoke.log 2>&1 &
XVFB_PID=$!
for _ in $(seq 1 100); do
    if [[ -S /tmp/.X11-unix/X99 ]] && kill -0 "${XVFB_PID}" 2>/dev/null; then
        break
    fi
    sleep 0.1
done
[[ -S /tmp/.X11-unix/X99 ]] || {
    cat /tmp/loryvant-xvfb-smoke.log >&2 || true
    fail "Xvfb hat keinen X11-Socket bereitgestellt."
}
kill -0 "${XVFB_PID}" 2>/dev/null || {
    cat /tmp/loryvant-xvfb-smoke.log >&2 || true
    fail "Xvfb ist während des Smoke-Tests beendet worden."
}
printf '[runtime-smoke] X11-Socket bereit: %s\n' /tmp/.X11-unix/X99

# SteamCMD wird von Pelican in das persistente Servervolume installiert. Im
# nackten GHCR-Image ist dieses Volume nicht vorhanden.
if [[ -e /home/container/steamcmd/steamcmd.sh ]]; then
    step "SteamCMD im eingehängten Pelican-Servervolume"
    [[ -x /home/container/steamcmd/steamcmd.sh ]] || \
        fail "/home/container/steamcmd/steamcmd.sh ist nicht ausführbar."
else
    printf '[runtime-smoke] INFO: SteamCMD-Prüfung übersprungen; kein Pelican-Servervolume eingehängt.\n'
fi

printf '[runtime-smoke] OK: UMU, GE-Proton11-1 und Headless-X11 sind ausführbar.\n'
