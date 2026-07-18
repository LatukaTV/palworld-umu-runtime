#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
    printf '[image-preflight] FEHLER: %s\n' "$1" >&2
    exit 1
}

step() {
    printf '[image-preflight] PRÜFE: %s\n' "$1"
}

trap 'rc=$?; printf "[image-preflight] FEHLER: Zeile %s, Exit %s, Befehl: %s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

step "Architektur"
[[ "$(uname -m)" == "x86_64" ]] || fail "Nur linux/amd64 wird unterstützt."

step "Unprivilegierter Laufzeitbenutzer"
[[ "$(id -u)" -ne 0 ]] || fail "Der Image-Preflight darf nicht als root laufen."
[[ "${HOME:-}" == "/home/container" ]] || fail "Unerwartetes HOME: ${HOME:-<leer>}"

step "Im Image enthaltene Programme"
command -v python3 >/dev/null 2>&1 || fail "python3 fehlt."
command -v rcon >/dev/null 2>&1 || fail "rcon fehlt."
command -v umu-run >/dev/null 2>&1 || fail "umu-run fehlt."
command -v bwrap >/dev/null 2>&1 || fail "bubblewrap fehlt."

step "Installierte UMU-Dateien"
[[ -x /opt/umu/umu-run ]] || fail "/opt/umu/umu-run ist nicht ausführbar."
[[ "$(readlink -f /usr/local/bin/umu-run)" == "/opt/umu/umu-run" ]] || \
    fail "/usr/local/bin/umu-run verweist nicht auf /opt/umu/umu-run."

step "Installierte GE-Proton-Dateien"
[[ -x /opt/ge-proton/proton ]] || fail "/opt/ge-proton/proton ist nicht ausführbar."
[[ -f /opt/ge-proton/version ]] || fail "GE-Proton-Versiondatei fehlt."
grep -Fq 'GE-Proton11-1' /opt/ge-proton/version || \
    fail "Installierte GE-Proton-Version ist nicht GE-Proton11-1."
grep -Fq 'CURRENT_PREFIX_VERSION="GE-Proton11-1"' /opt/ge-proton/proton || \
    fail "GE-Proton-Prefixversion stimmt nicht."

printf '[image-preflight] OK: Statische Image-Prüfungen bestanden.\n'
