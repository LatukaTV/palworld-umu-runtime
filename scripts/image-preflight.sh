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

step "Debian- und glibc-Basis"
cat /etc/os-release
. /etc/os-release
[[ "${ID}" == "debian" ]] || fail "Das Runtime-Image basiert nicht auf Debian."
[[ "${VERSION_CODENAME:-}" == "trixie" ]] || fail "Erwartet wurde Debian 13 trixie."
glibc_version="$(getconf GNU_LIBC_VERSION | awk '{print $2}')"
printf '[image-preflight] glibc=%s\n' "${glibc_version}"
dpkg --compare-versions "${glibc_version}" ge 2.38 || \
    fail "GE-Proton11-1 benötigt im Hostmodus glibc 2.38 oder neuer."

step "Im Image enthaltene Programme"
for command_name in python3 rcon umu-run bwrap Xvfb palworld-umu-start; do
    command_path="$(command -v "${command_name}" || true)"
    printf '[image-preflight] %s=%s\n' "${command_name}" "${command_path:-<nicht gefunden>}"
    [[ -n "${command_path}" ]] || fail "${command_name} fehlt."
done

step "Kompakter Runtime-Launcher"
[[ -x /usr/local/bin/palworld-umu-start ]] || \
    fail "/usr/local/bin/palworld-umu-start ist nicht ausführbar."
launcher_version="$(palworld-umu-start --version)"
printf '[image-preflight] launcher=%s\n' "${launcher_version}"
[[ "${launcher_version}" == "palworld-umu-start 0.2.4" ]] || \
    fail "Unerwartete Launcher-Version: ${launcher_version}"

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

step "Container-native GE-Proton-Hostschicht"
[[ "${PROTONPATH:-}" == "/opt/ge-proton-host" ]] || \
    fail "PROTONPATH verweist nicht auf die geprüfte Hostschicht."
[[ -x /opt/ge-proton-host/proton ]] || fail "Hostschicht enthält kein ausführbares proton."
[[ -s /opt/ge-proton-host/toolmanifest.vdf ]] || fail "Hostschicht enthält kein toolmanifest.vdf."
if grep -q require_tool_appid /opt/ge-proton-host/toolmanifest.vdf; then
    fail "Hostschicht fordert weiterhin pressure-vessel an."
fi
grep -q 'compatmanager_layer_name.*proton' /opt/ge-proton-host/toolmanifest.vdf || \
    fail "Hostschicht ist kein Proton-Kompatibilitätsmanifest."
resolved_host_proton="$(readlink -f /opt/ge-proton-host/proton)"
[[ "${resolved_host_proton}" == "/opt/ge-proton/proton" ]] || \
    fail "Hostschicht verweist nicht auf das geprüfte GE-Proton."

step "Headless-X11-Komponente"
Xvfb -help >/tmp/loryvant-xvfb-help.txt 2>&1 || true
grep -q -- '-screen' /tmp/loryvant-xvfb-help.txt || \
    fail "Xvfb unterstützt die benötigte Bildschirmoption nicht."
rm -f /tmp/loryvant-xvfb-help.txt

printf '\n[image-preflight] OK: Statische Image-Prüfungen bestanden.\n'
