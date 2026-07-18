# Changelog

## 0.1.0 – 2026-07-18

- Initiales `linux/amd64`-Runtime-Image auf Basis von `ghcr.io/parkervcp/steamcmd:debian` angelegt.
- UMU 1.4.0 und GE-Proton11-1 mit Upstream-Prüfsummen fest angeheftet.
- GHCR-Build- und Veröffentlichungsworkflow ergänzt.
- Build- und Laufzeit-Smoke-Test ergänzt.

## 0.1.1 – 2026-07-18

- Ersten Buildfehler im UMU-Smoke-Test behoben.
- `umu-run --version` wird nicht mehr während des Docker-Builds als `root` ausgeführt; UMU lehnt Root-Ausführungen absichtlich ab.
- Smoke-Test wird jetzt nach `USER container` unter demselben unprivilegierten Benutzer ausgeführt, den Pelican zur Laufzeit nutzt.
- Smoke-Test prüft zusätzlich Benutzer-ID und `HOME=/home/container`.

## 0.1.2 – 2026-07-18

- Zweiten, unabhängigen Smoke-Test-Fehler behoben.
- Falsche Annahme entfernt, dass `/home/container/steamcmd/steamcmd.sh` bereits im unveränderlichen Runtime-Image vorhanden sein müsse.
- SteamCMD wird von Pelican im persistenten Servervolume bereitgestellt und deshalb nur geprüft, wenn dieses Volume tatsächlich eingehängt ist.
- Image-eigene Komponenten `rcon`, `umu-run`, `bwrap`, Python und GE-Proton bleiben verpflichtende Buildprüfungen.
- Alle Smoke-Test-Phasen geben jetzt vor der Prüfung einen eindeutigen Diagnoseschritt aus.
