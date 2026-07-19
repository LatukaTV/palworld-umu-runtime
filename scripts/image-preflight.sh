#!/usr/bin/env bash
set -Eeuo pipefail
fail(){ printf '[image-preflight] FEHLER: %s\n' "$1" >&2; exit 1; }
step(){ printf '\n[image-preflight] PRÜFE: %s\n' "$1"; }
trap 'rc=$?; printf "[image-preflight] FEHLER: Zeile %s, Exit %s, Befehl: %s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

step "Ausführungsumgebung"
printf '[image-preflight] uname=%s uid=%s gid=%s user=%s HOME=%s\n' "$(uname -m)" "$(id -u)" "$(id -g)" "$(id -un)" "${HOME:-<leer>}"
[[ "$(uname -m)" == "x86_64" ]] || fail "Nur linux/amd64 wird unterstützt."
[[ "$(id -u)" -ne 0 ]] || fail "Preflight läuft als root."
[[ "${HOME:-}" == "/home/container" ]] || fail "Unerwartetes HOME."

step "Steam Linux Runtime 4"
[[ -f /opt/loryvant-steamrt4-base ]] || fail "SteamRT4-Basismarker fehlt."
grep -Fxq steamrt4 /opt/loryvant-steamrt4-base || fail "SteamRT4-Basismarker ist ungültig."
cat /etc/os-release || true
glibc_version="$(getconf GNU_LIBC_VERSION | awk '{print $2}')"
printf '[image-preflight] glibc=%s\n' "${glibc_version}"
dpkg --compare-versions "${glibc_version}" ge 2.38 || fail "glibc ist älter als 2.38."

step "Programme"
for command_name in python3 umu-run Xvfb palworld-umu-start pelican-entrypoint; do
    command -v "${command_name}" >/dev/null || fail "${command_name} fehlt."
done

step "Launcher"
[[ "$(palworld-umu-start --version)" == "palworld-umu-start 0.2.7" ]] || fail "Launcher-Version stimmt nicht."
palworld-umu-start --self-test

step "GE-Proton"
[[ -x /opt/ge-proton-host/proton ]] || fail "GE-Proton-Hostschicht fehlt."
[[ -s /opt/ge-proton-host/toolmanifest.vdf ]] || fail "GE-Proton-Manifest fehlt."
! grep -q require_tool_appid /opt/ge-proton-host/toolmanifest.vdf || fail "Manifest fordert pressure-vessel an."
grep -Fq GE-Proton11-1 /opt/ge-proton/version || fail "GE-Proton-Version stimmt nicht."

step "Entrypoint"
STARTUP='printf entrypoint-ok' pelican-entrypoint > /tmp/loryvant-entrypoint-test.txt
grep -Fq 'entrypoint-ok' /tmp/loryvant-entrypoint-test.txt || fail "Entrypoint-Test fehlgeschlagen."
rm -f /tmp/loryvant-entrypoint-test.txt

printf '\n[image-preflight] OK: SteamRT4, Launcher und GE-Proton geprüft.\n'
