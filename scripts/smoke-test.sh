#!/usr/bin/env bash
set -Eeuo pipefail
fail(){ printf '[runtime-smoke] FEHLER: %s\n' "$1" >&2; exit 1; }
cleanup(){ [[ -z "${XVFB_PID:-}" ]] || kill "${XVFB_PID}" >/dev/null 2>&1 || true; rm -rf /tmp/loryvant-xdg-runtime-smoke /tmp/.X99-lock /tmp/.X11-unix/X99; }
trap cleanup EXIT
/usr/local/bin/palworld-umu-image-preflight
python3 --version
umu-run --version
palworld-umu-start --self-test
mkdir -p /tmp/loryvant-xdg-runtime-smoke
chmod 0700 /tmp/loryvant-xdg-runtime-smoke
XDG_RUNTIME_DIR=/tmp/loryvant-xdg-runtime-smoke DISPLAY=:99 Xvfb :99 -screen 0 1024x768x24 -nolisten tcp -ac -noreset >/tmp/loryvant-xvfb-smoke.log 2>&1 &
XVFB_PID=$!
for _ in $(seq 1 100); do [[ -S /tmp/.X11-unix/X99 ]] && kill -0 "${XVFB_PID}" 2>/dev/null && break; sleep .1; done
[[ -S /tmp/.X11-unix/X99 ]] || { cat /tmp/loryvant-xvfb-smoke.log >&2 || true; fail "Xvfb-Socket fehlt."; }
printf '[runtime-smoke] OK: SteamRT4, UMU, GE-Proton11-1, Entrypoint und Xvfb sind ausführbar.\n'
