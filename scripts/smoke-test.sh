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
    if ! "$@"; then
        local rc=$?
        fail "${label} fehlgeschlagen (Exit ${rc}): $*"
    fi
}

trap 'rc=$?; printf "[runtime-smoke] FEHLER: Zeile %s, Exit %s, Befehl: %s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

/usr/local/bin/palworld-umu-image-preflight

run_check "Python-Aufruf" python3 --version
run_check "UMU-CLI-Aufruf" umu-run --version
run_check "RCON-CLI-Aufruf" rcon --help

# SteamCMD wird von Pelican in das persistente Servervolume installiert. Im
# nackten GHCR-Image ist dieses Volume nicht vorhanden.
if [[ -e /home/container/steamcmd/steamcmd.sh ]]; then
    step "SteamCMD im eingehängten Pelican-Servervolume"
    [[ -x /home/container/steamcmd/steamcmd.sh ]] || \
        fail "/home/container/steamcmd/steamcmd.sh ist nicht ausführbar."
else
    printf '[runtime-smoke] INFO: SteamCMD-Prüfung übersprungen; kein Pelican-Servervolume eingehängt.\n'
fi

printf '[runtime-smoke] OK: UMU 1.4.0 und GE-Proton11-1 sind ausführbar.\n'
