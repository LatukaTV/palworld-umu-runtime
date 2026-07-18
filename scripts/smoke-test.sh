#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
    printf '[runtime-smoke] FEHLER: %s\n' "$1" >&2
    exit 1
}

[[ "$(uname -m)" == "x86_64" ]] || fail "Nur linux/amd64 wird unterstützt."
[[ "$(id -u)" -ne 0 ]] || fail "UMU-Smoke-Test darf nicht als root laufen."
[[ "${HOME:-}" == "/home/container" ]] || fail "Unerwartetes HOME: ${HOME:-<leer>}"

command -v steamcmd >/dev/null 2>&1 || \
    [[ -x /home/container/steamcmd/steamcmd.sh ]] || \
    fail "SteamCMD wurde im Basisimage nicht gefunden."

command -v rcon >/dev/null 2>&1 || fail "rcon fehlt."
command -v umu-run >/dev/null 2>&1 || fail "umu-run fehlt."
command -v bwrap >/dev/null 2>&1 || fail "bubblewrap fehlt."

[[ -x /opt/umu/umu-run ]] || fail "/opt/umu/umu-run ist nicht ausführbar."
[[ -x /opt/ge-proton/proton ]] || fail "/opt/ge-proton/proton ist nicht ausführbar."
[[ -f /opt/ge-proton/version ]] || fail "GE-Proton-Versiondatei fehlt."

grep -Fq 'GE-Proton11-1' /opt/ge-proton/version || \
    fail "Installierte GE-Proton-Version ist nicht GE-Proton11-1."

grep -Fq 'CURRENT_PREFIX_VERSION="GE-Proton11-1"' /opt/ge-proton/proton || \
    fail "GE-Proton-Prefixversion stimmt nicht."

python3 --version
umu-run --version

printf '[runtime-smoke] OK: UMU 1.4.0 und GE-Proton11-1 sind als container-Benutzer installiert.\n'
