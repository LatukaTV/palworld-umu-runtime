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
. /etc/os-release
[[ "${VERSION_CODENAME}" == "trixie" ]] || fail "Debian-13/Trixie-Userspace fehlt."
[[ "$(getconf GNU_LIBC_VERSION)" == "glibc 2.41" ]] || fail "Unerwartete glibc-Version."
getent passwd container >/dev/null || fail "Container-Benutzer fehlt."
[[ -e /usr/lib32/libstdc++.so.6 ]] || fail "SteamCMD libstdc++ 32-Bit fehlt."
[[ -e /usr/lib32/libgcc_s.so.1 ]] || fail "SteamCMD libgcc 32-Bit fehlt."

step "Wine-Modlaufzeit"
for command_name in python3 wine64 wineboot wineserver Xvfb dbus-run-session palworld-umu-start pelican-entrypoint; do
    command -v "${command_name}" >/dev/null || fail "${command_name} fehlt."
done
[[ -x /usr/local/bin/palworld-umu-start-core ]] || fail "palworld-umu-start-core fehlt."
[[ -x /opt/wine-devel/bin/wine ]] || fail "WineHQ-Launcher fehlt."
[[ "${WINELOADER:-}" == "/opt/wine-devel/bin/wine" ]] || fail "WineHQ-Loaderpfad fehlt."
[[ "$(wine64 --version)" == "wine-11.13" ]] || fail "WineHQ 11.13 fehlt."
[[ -x /usr/local/bin/wine64 && ! -L /usr/local/bin/wine64 ]] || fail "wine64 ist kein stabiler Launcher-Wrapper."
grep -Fq 'exec /opt/wine-devel/bin/wine "$@"' /usr/local/bin/wine64 || fail "wine64 ruft den WineHQ-Launcher nicht direkt auf."
[[ "$(readlink -f /usr/local/bin/wineserver)" == "/opt/wine-devel/bin/wineserver" ]] || fail "wineserver zeigt auf eine unerwartete Laufzeit."
[[ -x /usr/local/lib/loryvant/wineboot-real ]] || fail "WineHQ-wineboot fehlt."
[[ -s /etc/machine-id ]] || fail "/etc/machine-id fehlt."

step "Launcher"
[[ "$(palworld-umu-start --version)" == "palworld-umu-start 0.2.15" ]] || fail "Launcher-Version stimmt nicht."
palworld-umu-start --self-test
/usr/local/bin/palworld-umu-start-core --self-test
grep -Fq 'EXPECTED_WINE = "wine-11.13"' /usr/local/bin/palworld-umu-start || fail "Wine-Version-Pinning fehlt."
grep -Fq 'def wine_prefix_usable()' /usr/local/bin/palworld-umu-start || fail "Funktionaler Wine-Prefix-Test fehlt."
grep -Fq '["wine64", r"C:\windows\system32\cmd.exe", "/c", "exit", "0"]' /usr/local/bin/palworld-umu-start || fail "Explizite Wine64-Prefix-Startprobe fehlt."
grep -Fq 'reason = "unusable"' /usr/local/bin/palworld-umu-start || fail "Unbenutzbare Wine-Prefixe werden nicht gesichert."
grep -Fq 'boot_args=(--init)' /usr/local/bin/wineboot-wrapper || fail "Wineboot-Neuinitialisierung fehlt."
grep -Fq "WINEDLLOVERRIDES='mscoree,mshtml='" /usr/local/bin/wineboot-wrapper || fail "Headless-Mono-/Gecko-Unterdrückung fehlt."
grep -Fq 'while (( SECONDS < deadline ))' /usr/local/bin/wineboot-wrapper || fail "Wineboot-Abschlusswartezeit fehlt."
grep -Fq 'Wine-Prozessstatus vor dem erzwungenen Abbruch' /usr/local/bin/wineboot-wrapper || fail "Wineboot-Timeoutdiagnose fehlt."
grep -Fq 'probe_prefix' /usr/local/bin/wineboot-wrapper || fail "Funktionale Prefix-Prüfung nach Wineboot fehlt."
grep -Fq 'SAVE_ROOT = SERVER_ROOT / "Pal/Saved"' /usr/local/bin/palworld-umu-start-core || fail "Eigenständiger Windows-Save-Pfad fehlt."
grep -Fq 'prepare_independent_saved()' /usr/local/bin/palworld-umu-start-core || fail "Save-Migration fehlt."
grep -Fq 'Aktive Welt für WindowsServer' /usr/local/bin/palworld-umu-start-core || fail "DedicatedServerName-Zuordnung fehlt."
grep -Fq 'Atomarer Windows-Save-Pfad geprüft' /usr/local/bin/palworld-umu-start-core || fail "Atomarer Save-Pfadtest fehlt."
grep -Fq 'generated-backup-tree-' /usr/local/bin/palworld-umu-start || fail "Backup-Unterbaum-Sicherung fehlt."
grep -Fq 'Frischer Windows-Backup-Unterbaum geprüft' /usr/local/bin/palworld-umu-start || fail "Backup-Unterbaum-Prüfung fehlt."

step "Entrypoint"
STARTUP='printf entrypoint-ok' pelican-entrypoint > /tmp/loryvant-entrypoint-test.txt
grep -Fq 'entrypoint-ok' /tmp/loryvant-entrypoint-test.txt || fail "Entrypoint-Test fehlgeschlagen."
rm -f /tmp/loryvant-entrypoint-test.txt

printf '\n[image-preflight] OK: Debian 13, WineHQ 11.13, headless Wineboot-Initialisierung, funktionaler Wine64-Prefix, Xvfb, D-Bus, Save-Pfad und Entrypoint geprüft.\n'
