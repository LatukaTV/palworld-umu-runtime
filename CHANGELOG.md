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

## 0.1.3 – 2026-07-18

- Docker-Buildprüfung und Laufzeitprüfung getrennt.
- Statischer Image-Preflight ergänzt.
- GitHub Actions baut zuerst ein lokales Kandidatenimage, prüft es und veröffentlicht erst danach GHCR-Tags.
- Fehlerausgaben enthalten Zeile, Exit-Code und fehlgeschlagenen Befehl.

## 0.1.4 – 2026-07-18

- Den statischen Image-Preflight vollständig aus der Docker-Buildschicht entfernt.
- Ursache: BuildKit reduziert Fehler aus `RUN /usr/local/bin/palworld-umu-image-preflight` in der Annotation auf einen undifferenzierten Exit-Code 1.
- Kandidatenimage wird jetzt zuerst vollständig gebaut und lokal geladen.
- Image-Preflight und Runtime-Smoke-Test laufen anschließend als getrennte Actions-Schritte.
- Beide Testschritte schreiben ihre vollständige Ausgabe zusätzlich in die GitHub-Actions-Schrittzusammenfassung.
- `HOME` und `USER` werden im Runtime-Image ausdrücklich gesetzt.
- Der Image-Preflight protokolliert Architektur, Benutzer, Pfade, Programme, Symlinks und GE-Proton-Version vor der jeweiligen Prüfung.

## 0.1.5 – 2026-07-18

- Konkrete Ursache aus dem separaten Image-Preflight behoben.
- Das offizielle UMU-1.4.0-Zipapp-Archiv enthält `/opt/umu/umu-run` im gebauten Image mit Modus `0644` statt ausführbar.
- Der Docker-Build setzt deshalb nach verifizierter Extraktion ausdrücklich `chmod 0755 /opt/umu/umu-run`.
- Die Ausführbarkeitsprüfung bleibt direkt danach erhalten, sodass ein erneuter Berechtigungsfehler den Build früh und eindeutig stoppt.

## 0.1.6 – 2026-07-19

- Den Container-Userspace auf Debian 13 `trixie` aktualisiert, ohne Änderungen am Pelican-Node oder am geerbten SteamCMD-Einstieg.
- Buildprüfung für glibc 2.38 oder neuer ergänzt; damit wird die von GE-Proton11-1 benötigte ABI vor Veröffentlichung geprüft.
- Eine container-native GE-Proton-Hostschicht unter `/opt/ge-proton-host` eingebaut.
- Die Hostschicht entfernt ausschließlich `require_tool_appid` aus dem kopierten Manifest und verhindert damit den unter Pelican blockierten pressure-vessel-Aufruf.
- Der Image-Preflight prüft Debian-Version, glibc-Version, Manifest, Symlinkziel und den unveränderten GE-Proton11-1-Unterbau.
