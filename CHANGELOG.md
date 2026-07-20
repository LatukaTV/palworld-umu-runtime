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

## 0.1.7 – 2026-07-19

- Stillstand nach `fsync: up and running` und zwei Meldungen zu fehlendem `XDG_RUNTIME_DIR` aus dem ersten realen Palworld-Windowsserver-Start ausgewertet.
- Xvfb als containerinternes, headless X11-Backend ergänzt; dafür ist keine Änderung am Pelican-Node oder Root-Server erforderlich.
- Image-Preflight verlangt jetzt das Programm `Xvfb`.
- Runtime-Smoke-Test startet Xvfb als unprivilegierter `container`-Benutzer, legt ein XDG-Laufzeitverzeichnis mit Modus `0700` an und prüft den erzeugten X11-Socket.
- Der Egg-Startup setzt weiterhin direkt `exec umu-run`; Xvfb wird ausschließlich als Hintergrundprozess im normalen Startup-Feld gestartet.

## 0.1.8 – 2026-07-19

- Den gesamten Start-, Parser-, Save-, UE4SS-, Xvfb- und RCON-Ablauf in den image-internen Befehl `/usr/local/bin/palworld-umu-start` verlagert.
- Das Egg benötigt dadurch nur noch den kurzen Startup-Befehl `palworld-umu-start`.
- Der Launcher maskiert Passwortwerte aus der Parserausgabe, prüft die Runtime, startet Headless-X11, leitet Pelican-Konsolenbefehle an RCON weiter und überwacht die RCON-Bereitschaft.
- Shell-Arithmetik und Globbing befinden sich nicht mehr im Egg-Startup-Feld; damit kann Wings den Befehl nicht mehr durch Dateinamenexpansion beschädigen.
- Image-Preflight und Runtime-Smoke-Test prüfen Launcher-Version, Ausführbarkeit und Selbsttest vor der Veröffentlichung.

## 0.1.9 – 2026-07-19

- Die drei geerbten Palworld-Altparameter `-useperfthreads`, `-NoAsyncLoadingThread` und `-UseMultithreadForDS` aus dem v1.0-Startprofil entfernt.
- `-logformat=text` ergänzt und die effektiven, nicht geheimen Palworld-Argumente beim Start sichtbar gemacht.
- Nach erfolgreicher RCON-Bereitschaft einen dauerhaften Healthcheck im Abstand von 15 Sekunden ergänzt.
- Sechs aufeinanderfolgende RCON-Ausfälle lösen nach 90 Sekunden einen eindeutigen Soft-Lock-Fehler aus.
- Bei erkanntem Soft-Lock beendet der Launcher die vollständige UMU-/Proton-Prozessgruppe und liefert Exit-Code `70`, damit Pelican keinen hängenden Server weiter als gesund behandelt.
- Der Selbsttest weist die entfernten Altparameter zurück und prüft das 90-Sekunden-Watchdog-Fenster.

## 0.1.10 – 2026-07-19

- Den Palworld-RCON-Dienst im v0.2.6-Laufzeitprofil abgeschaltet und das Startargument `-rcon` entfernt.
- Readiness und Soft-Lock-Watchdog auf die lokale Palworld-REST-API unter `127.0.0.1:8212` umgestellt.
- Der Config-Parser setzt verbindlich `RESTAPIEnabled=True`, `RESTAPIPort=8212`, `RCONEnabled=False` und `LogFormatType=Text`.
- Pelican-Konsolenbefehle wie `info`, `showplayers`, `save`, `shutdown`, `broadcast`, `kickplayer` und `banplayer` werden intern auf offizielle REST-Endpunkte abgebildet.
- Die REST-API bleibt containerlokal und erhält keine öffentliche Portzuweisung.
- Der Watchdog prüft weiterhin alle 15 Sekunden und beendet einen 90 Sekunden anhaltenden Soft-Lock mit Exit-Code `70`.

## 0.1.11 – 2026-07-19

- Den äußeren Container-Userspace auf Valves Steam Linux Runtime 4 umgestellt, die für Proton 11 vorgesehen ist.
- GE-Proton läuft im passenden SteamRT4-Userspace; der unter Pelican blockierte verschachtelte pressure-vessel-Aufruf bleibt entfallen.
- Einen eigenen Python-Entrypoint ergänzt, sodass der Pelican-Startup exakt `palworld-umu-start` bleibt.
- SteamCMD-Updateprüfung in den Runtime-Launcher verlagert.
- Dauerhafte REST-Abfragen nach der Bereitschaft entfernt; nach dem Fertigmarker entstehen keine automatischen Verwaltungszugriffe mehr.
- Die gemessene Palworld-Prozessstartzeit wird unmittelbar nach der Bereitschaft ausgegeben.

## 0.1.12 – 2026-07-19

- Den Windows-/Proton-Laufzeitpfad vollständig durch Pocketpairs nativen Linux-Dedicated-Server ersetzt.
- UMU, GE-Proton, Wine, Xvfb, SteamRT4-SDK und D-Bus-Abhängigkeiten aus dem Runtime-Image entfernt.
- SteamCMD lädt und aktualisiert App `2394010` ausdrücklich als Linux-Depot.
- Eine vorhandene `WindowsServer/PalWorldSettings.ini` wird einmalig gesichert und nach `LinuxServer` übernommen.
- `Pal/Saved/SaveGames` bleibt unverändert und wird direkt weiterverwendet.
- Readiness und Panelkonsole bleiben über die lokale REST-API erhalten.
- Der Container startet `PalServer-Linux-Shipping` direkt und benötigt weder privilegierten Betrieb noch Hostanpassungen.

## 0.1.13 – 2026-07-19

- Einen eigenständigen Windows-Modlaufzeitpfad unter `/home/container/ModdedServer` ergänzt; der bestätigte native v0.2.8-Serverbestand bleibt getrennt erhalten.
- Debian Wine 10, Xvfb und einen lokalen D-Bus-Sessionbus als unprivilegierte Containerlaufzeit eingebaut.
- SteamCMD lädt App `2394010` ausdrücklich als Windows-Depot in das isolierte Modserververzeichnis.
- Die gemeinsamen Save-Daten bleiben unter `/home/container/Pal/Saved`; der Windows-Modserver bindet diesen Pfad über einen geprüften Symlink ein.
- Die offiziellen Palworld-Modpfade `Mods/Workshop`, `Mods/ManagedMods`, `Mods/NativeMods` sowie PAK- und LogicMods-Ziele vorbereitet.
- DLL-Loader wie `d3d9.dll`, `winmm.dll`, `version.dll`, `xinput1_3.dll` und `dxgi.dll` werden automatisch erkannt und über Wine als native DLLs priorisiert.
- Vor SteamCMD-Updates werden vorhandene Workshop-, UE4SS-, DLL- und PAK-Moddateien in rotierenden Archiven gesichert.
- Die Panelkonsole erhält `mods`, `modcheck`, `modbackup` und `modpaths` für Inventur, Plausibilitätsprüfung, Sicherung und Pfadanzeige.
- Das Runtime-Image enthält selbst keine PalDefender-, UE4SS- oder sonstigen Fremdmoddateien.

## 0.1.14 – 2026-07-19

- Den gemeinsamen Save-Symlink des Windows-Modservers durch `/home/container/ModdedServer/Pal/Saved` als realen, eigenständigen Save-Pfad ersetzt.
- Vor der Einmalmigration wird der native Stand unter `/home/container/.loryvant-backups/saves` vollständig archiviert.
- Vorhandene Welt-, Spieler- und Konfigurationsdaten werden einmalig in den Windows-Save-Pfad kopiert; der native v0.2.8-Rückfallstand bleibt unverändert.
- `WindowsServer/GameUserSettings.ini` erhält automatisch den vorhandenen Weltordner als `DedicatedServerName`.
- Der Config-Parser läuft aus `/home/container/ModdedServer` und muss den isolierten Windows-Konfigurationspfad bestätigen.
- Ein Laufzeit-Preflight prüft Datei-Kopie und atomisches Umbenennen direkt im Windows-Save-Ziel.
- Der Container-Smoke-Test reproduziert Migration, Weltwahl und atomaren Zielpfad mit einem temporären Teststand.

## 0.1.15 – 2026-07-19

- Den von der nativen Linux-Welt übernommenen, ausschließlich generierten Welt-Unterbaum `backup` vor dem Windows-Start einmalig aus dem aktiven Save-Pfad entfernt.
- Der alte Backup-Unterbaum bleibt vollständig unter `/home/container/.loryvant-backups/saves/generated-backup-tree-<Welt>-<Zeit>` erhalten.
- Für die aktive Welt werden frische Verzeichnisse `backup/local` und `backup/world` erzeugt und durch Kopieren plus atomisches Umbenennen validiert.
- Der aktive Weltstand, `Level.sav`, `LevelMeta.sav`, `Players` und die übrigen produktiven Save-Dateien bleiben unverändert.
- Ein versionsgebundener Marker verhindert wiederholte Bereinigungen; `RESET_WORLD_BACKUP_TREE=1` erlaubt einen ausdrücklich angeforderten erneuten Lauf.
- Image-Preflight und Runtime-Smoke-Test prüfen Wrapper, Kernlauncher, Save-Migration und die datenhaltende Backup-Unterbaum-Reparatur getrennt.

## 0.1.16 – 2026-07-19

- Debian Wine 10 durch das offizielle WineHQ-Entwicklungspaket `11.13~trixie-1` für amd64 und i386 ersetzt.
- Den WineHQ-Paketschlüssel anhand der Repository-Schlüssel-ID geprüft und die Paketversion im Docker-Build fest angeheftet.
- `wine64`, `wineboot` und `wineserver` zeigen verbindlich auf `/opt/wine-devel`; der Image-Preflight verlangt exakt `wine-11.13`.
- Einen bestehenden Wine-10-Prefix vor dem ersten Wine-11.13-Start vollständig unter `/home/container/.loryvant-backups/wine-prefixes` archiviert.
- `RESET_WINE_PREFIX=1` wird durch denselben gesicherten Migrationspfad verarbeitet; Welt-, Konfigurations- und Moddaten bleiben außerhalb des Prefixes.
- Runtime-Smoke-Test simuliert einen Wine-10-Prefix, prüft dessen Erhalt und validiert anschließend den frischen Wine-11.13-Prefixaufbau.

## 0.1.17 – 2026-07-20

- Die funktionale Wine64-Probe aus der laufenden `wineboot`-Initialisierung entfernt.
- Der Wrapper wartet zuerst auf die vollständigen 64-Bit-Prefixdateien, beendet anschließend Wineboot und Wineserver kontrolliert und startet erst danach eine neue `cmd.exe`-Probe.
- Fehlgeschlagene Initialisierungen protokollieren Wineboot-Ausgabe, Probe-Exit und den verbleibenden Prozessstatus.
- Ein nicht ausführbarer Prefix verliert weiterhin `system.reg`, damit der Kernlauncher den Start abbricht und der nächste Lauf den Prefix gesichert ersetzt.
