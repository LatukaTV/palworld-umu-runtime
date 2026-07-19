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

step "Wine-Modlaufzeit"
for command_name in python3 wine64 wineboot wineserver Xvfb dbus-run-session palworld-umu-start pelican-entrypoint; do
    command -v "${command_name}" >/dev/null || fail "${command_name} fehlt."
done
wine64 --version
[[ -s /etc/machine-id ]] || fail "/etc/machine-id fehlt."

step "Launcher"
[[ "$(palworld-umu-start --version)" == "palworld-umu-start 0.2.10" ]] || fail "Launcher-Version stimmt nicht."
palworld-umu-start --self-test
grep -Fq 'SAVE_ROOT = SERVER_ROOT / "Pal/Saved"' /usr/local/bin/palworld-umu-start || fail "Eigenständiger Windows-Save-Pfad fehlt."
grep -Fq 'prepare_independent_saved()' /usr/local/bin/palworld-umu-start || fail "Save-Migration fehlt."
grep -Fq 'Aktive Welt für WindowsServer' /usr/local/bin/palworld-umu-start || fail "DedicatedServerName-Zuordnung fehlt."
grep -Fq 'Atomarer Windows-Save-Pfad geprüft' /usr/local/bin/palworld-umu-start || fail "Atomarer Save-Pfadtest fehlt."

step "Entrypoint"
STARTUP='printf entrypoint-ok' pelican-entrypoint > /tmp/loryvant-entrypoint-test.txt
grep -Fq 'entrypoint-ok' /tmp/loryvant-entrypoint-test.txt || fail "Entrypoint-Test fehlgeschlagen."
rm -f /tmp/loryvant-entrypoint-test.txt

printf '\n[image-preflight] OK: Wine64, Xvfb, D-Bus, isolierter Save-Pfad, Launcher und Pelican-Entrypoint geprüft.\n'
