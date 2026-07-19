#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
    printf '[image-preflight] FEHLER: %s\n' "$1" >&2
    exit 1
}

step() {
    printf '\n[image-preflight] PRÜFE: %s\n' "$1"
}

trap 'rc=$?; printf "[image-preflight] FEHLER: Zeile %s, Exit %s, Befehl: %s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

step "Ausführungsumgebung"
printf '[image-preflight] uname=%s uid=%s gid=%s user=%s HOME=%s\n' \
    "$(uname -m)" "$(id -u)" "$(id -g)" "$(id -un)" "${HOME:-<leer>}"
[[ "$(uname -m)" == "x86_64" ]] || fail "Nur linux/amd64 wird unterstützt."
[[ "$(id -u)" -ne 0 ]] || fail "Preflight läuft als root."
[[ "${HOME:-}" == "/home/container" ]] || fail "Unerwartetes HOME."

step "Native Laufzeit"
for command_name in python3 getconf palworld-umu-start pelican-entrypoint; do
    command -v "${command_name}" >/dev/null || fail "${command_name} fehlt."
done
command -v umu-run >/dev/null && fail "UMU ist im nativen Image unerwartet vorhanden."
command -v Xvfb >/dev/null && fail "Xvfb ist im nativen Image unerwartet vorhanden."
[[ ! -e /opt/ge-proton ]] || fail "GE-Proton ist im nativen Image unerwartet vorhanden."

step "Launcher"
[[ "$(palworld-umu-start --version)" == "palworld-umu-start 0.2.8" ]] || \
    fail "Launcher-Version stimmt nicht."
palworld-umu-start --self-test

step "Entrypoint"
STARTUP='printf entrypoint-ok' pelican-entrypoint > /tmp/loryvant-entrypoint-test.txt
grep -Fq 'entrypoint-ok' /tmp/loryvant-entrypoint-test.txt || fail "Entrypoint-Test fehlgeschlagen."
rm -f /tmp/loryvant-entrypoint-test.txt

printf '\n[image-preflight] OK: nativer Linux-Launcher und Pelican-Entrypoint geprüft.\n'
