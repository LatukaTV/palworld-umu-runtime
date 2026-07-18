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
printf '[image-preflight] uname=%s\n' "$(uname -m)"
printf '[image-preflight] uid=%s gid=%s user=%s\n' "$(id -u)" "$(id -g)" "$(id -un)"
printf '[image-preflight] HOME=%s\n' "${HOME:-<leer>}"
printf '[image-preflight] PATH=%s\n' "${PATH:-<leer>}"
[[ "$(uname -m)" == "x86_64" ]] || fail "Nur linux/amd64 wird unterstützt."
[[ "$(id -u)" -ne 0 ]] || fail "Der Image-Preflight darf nicht als root laufen."
[[ "${HOME:-}" == "/home/container" ]] || fail "Unerwartetes HOME: ${HOME:-<leer>}"

step "Im Image enthaltene Programme"
for command_name in python3 rcon umu-run bwrap; do
    command_path="$(command -v "${command_name}" || true)"
    printf '[image-preflight] %s=%s\n' "${command_name}" "${command_path:-<nicht gefunden>}"
    [[ -n "${command_path}" ]] || fail "${command_name} fehlt."
done

step "Installierte UMU-Dateien"
ls -la /opt/umu /usr/local/bin/umu-run
[[ -x /opt/umu/umu-run ]] || fail "/opt/umu/umu-run ist nicht ausführbar."
resolved_umu="$(readlink -f /usr/local/bin/umu-run)"
printf '[image-preflight] umu-symlink=%s\n' "${resolved_umu}"
[[ "${resolved_umu}" == "/opt/umu/umu-run" ]] || \
    fail "/usr/local/bin/umu-run verweist nicht auf /opt/umu/umu-run."

step "Installierte GE-Proton-Dateien"
ls -la /opt/ge-proton/proton /opt/ge-proton/version
[[ -x /opt/ge-proton/proton ]] || fail "/opt/ge-proton/proton ist nicht ausführbar."
[[ -f /opt/ge-proton/version ]] || fail "GE-Proton-Versiondatei fehlt."
printf '[image-preflight] GE-Proton-Versiondatei: '
cat /opt/ge-proton/version
grep -Fq 'GE-Proton11-1' /opt/ge-proton/version || \
    fail "Installierte GE-Proton-Version ist nicht GE-Proton11-1."
grep -Fq 'CURRENT_PREFIX_VERSION="GE-Proton11-1"' /opt/ge-proton/proton || \
    fail "GE-Proton-Prefixversion stimmt nicht."

printf '\n[image-preflight] OK: Statische Image-Prüfungen bestanden.\n'
