#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
    printf '[runtime-smoke] FEHLER: %s\n' "$1" >&2
    exit 1
}

/usr/local/bin/palworld-umu-image-preflight
python3 --version
palworld-umu-start --self-test

python3 - <<'PY'
import base64
import json
import urllib.request

assert base64.b64encode(b"admin:test").decode("ascii") == "YWRtaW46dGVzdA=="
assert json.loads('{"version":"v1"}')["version"] == "v1"
request = urllib.request.Request("http://127.0.0.1:8212/v1/api/info")
assert request.full_url.endswith("/v1/api/info")
print("[runtime-smoke] REST-Clientmodule verfügbar.")
PY

if [[ -e /home/container/Pal/Binaries/Linux/PalServer-Linux-Shipping ]]; then
    [[ -x /home/container/Pal/Binaries/Linux/PalServer-Linux-Shipping ]] || \
        fail "Eingehängter nativer Palworld-Server ist nicht ausführbar."
else
    printf '[runtime-smoke] INFO: Spielserverprüfung übersprungen; kein Pelican-Servervolume eingehängt.\n'
fi

printf '[runtime-smoke] OK: nativer Linux-Launcher, REST-Client und Entrypoint sind ausführbar.\n'
