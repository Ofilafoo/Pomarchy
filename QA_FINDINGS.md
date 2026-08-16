# QA Findings – Pomarchy

Stand: 2026-08-16  
Prüfgegenstand: aktueller Arbeitsstand in `~/Projects/pomarchy`  
Grundlage: `REQUIREMENTS.md`, `ARCHITECTURE.md`, `README.md` und `Lessons Learned – Pomarchy`

## Zusammenfassung

Der aktuelle Stand erfüllt die automatisierbaren Release-Anforderungen. Es sind
keine offenen P1- oder P2-Findings vorhanden. Bash-, QML-, JSON-, Manifest-,
State-Machine-, Parallelitäts-, reale systemd-, Shell-Neustart- und IPC-Tests
sind ohne Pomarchy-Fehler bestanden. Repository und installierte Laufzeitkopie
stimmen überein; der gesicherte Benutzerzustand wurde wiederhergestellt.

Die weiter unten erhaltenen älteren Findings sind als Prüfverlauf archiviert
und nicht mehr offen. Verbleibende manuelle beziehungsweise P3-Punkte stehen
am Ende dieses Dokuments.

## Abschließender unabhängiger Re-QA – 2026-08-16

- Der reale systemd-Ablauf wechselte mit Auto-Start von Fokus in Slot `a` zu
  kurzer Pause in Slot `b`, erhöhte den Tageszähler genau einmal und erzeugte
  keine gleichnamige Service-Kollision.
- `transitionId` und `unitSlot` sind validierte Session-Invarianten; falsche
  beziehungsweise veraltete Expiry-Aufrufe bleiben wirkungslos.
- Isolierte Paralleltests erzwingen konkurrierende Mutationen, Cleanup mit
  Lockhalter und Waiter sowie die unveränderte Inode beider Lock-Generationen.
- Der reale Upgrade-Zustand mit `operation.lock` wurde geprüft: Cleanup
  entfernte Session und Settings, behielt stabilen und Legacy-Lock-Inode bei,
  und die gesicherten Nutzdaten wurden anschließend bytegleich restauriert.
- Shell-Neustarts während laufender und pausierter Phase erhielten Endzeitpunkt
  beziehungsweise Restzeit. Open/Close/Pause/Resume/Reset über Shell-IPC
  funktionierten; Shell-Prozess und Plugin-Validierung blieben gesund.
- Suspend/Resume sowie Pointer-, Tastatur- und horizontale/vertikale
  Bar-Darstellung wurden in diesem abschließenden Lauf nicht erneut manuell
  ausgeführt; frühere manuelle Ergebnisse bleiben im Prüfverlauf dokumentiert.

## Archivierter unabhängiger Re-QA – 2026-08-16

Die unter **Umsetzung** aufgeführten Änderungen sind im Code vorhanden. Die
statischen Checks, beide Plugin-Validierungen und `tests/test-cli.sh` laufen
erfolgreich durch. Die installierten Laufzeitdateien stimmen mit dem
Entwicklungsrepository überein.

Die ursprünglichen Findings zu direkter Zahleneingabe, Settings-Migration,
State-Invarianten, Tastatur-Skip, Exitcode-Auswertung, Theme-Priorität und IPC
sind anhand der Implementierung geschlossen. Beim Re-QA wurden jedoch zwei
neue funktionale Probleme und eine Testlücke gefunden:

### P1 – Auto-Start scheitert beim regulären Ablauf aus der systemd-Service-Unit

**Fundstellen:** `pomarchy:122-128`, `pomarchy:180-203`, `pomarchy:276-280`

Der Timer startet `pomarchy expire TRANSITION_ID` in
`omarchy-pomarchy-io-github-ofilafoo.service`. Wenn `autoStart` aktiv ist,
versucht `transition()` noch innerhalb dieser laufenden Service-Unit, mit
demselben Unit-Namen den Timer für die nächste Phase anzulegen. Zu diesem
Zeitpunkt ist die zugehörige Service-Unit noch geladen und aktiv.

Ein unabhängiger Test mit einer eigens benannten transienten QA-Unit bestätigt
das systemd-Verhalten:

```text
Failed to start transient service unit: Unit ...service was already loaded or has a fragment file.
```

Pomarchy fängt den Scheduling-Fehler inzwischen sicher ab und stellt die neue
Phase auf `ready`. Der Zustand wird also nicht mehr beschädigt, aber F-05 ist
weiterhin nicht erfüllt: Die Folgephase startet beim regulären, vom
systemd-Timer ausgelösten Phasenende nicht automatisch.

Der nächste Timer benötigt einen Unit-Namen, der nicht mit der gerade laufenden
Service-Unit kollidiert, oder eine Architektur, bei der das Rescheduling erst
nach Ende der aktuellen Service-Unit erfolgt. Die Exactly-once-Absicherung
muss dabei erhalten bleiben.

### P1 – Cleanup kann die `flock`-Serialisierung bei Parallelzugriff aufspalten

**Fundstellen:** `pomarchy:12-14`, `pomarchy:310-314`, Anforderungen F-08,
NF-02

`cleanup` löscht `operation.lock`, während der aktuelle Prozess diese Datei
noch auf Dateideskriptor 9 gesperrt hält. Ein Prozess, der die alte Lockdatei
bereits geöffnet hat und darauf wartet, behält den alten Inode. Nach dem
Unlink kann ein weiterer Prozess den Zustandsordner und eine neue Lockdatei
anlegen. Der wartende Prozess und der neue Prozess verwenden dann
unterschiedliche Locks und können gleichzeitig Zustandsdateien bearbeiten.

Damit stehen „vollständiges Entfernen der Lockdatei“ und die geforderte
Serialisierung in der aktuellen Anordnung in Konflikt. Eine robuste Lösung
braucht beispielsweise ein dauerhaftes Lock außerhalb des entfernbaren
Zustandsordners oder eine andere Cleanup-Koordination. Ein bloßes Schließen
des Deskriptors vor dem Löschen beseitigt das Race nicht.

### P2 – Regressionstests decken die beiden kritischen Lebenszykluspfade nicht ab

**Fundstellen:** `tests/test-cli.sh:14-53`, `.github/workflows/validate.yml:33-35`

Die Rollback-Tests für direkt simulierte `systemd-run`-Fehler sind korrekt und
wirksam. Es fehlen jedoch Tests für:

- Auto-Start, wenn `expire` aus der noch laufenden gleichnamigen
  systemd-Service-Unit ausgeführt wird;
- einen parallelen Cleanup-Aufruf zusammen mit bereits wartenden und neu
  startenden zustandsändernden Kommandos;
- konkurrierende zustandsändernde Aktionen. Der vorhandene Paralleltest
  startet ausschließlich sechs `status`-Lesezugriffe.

Die CI kann deshalb trotz der beiden oben beschriebenen Fehler erfolgreich
durchlaufen. Nach der Korrektur sollten diese Szenarien als Regressionstests
ergänzt werden.

### Umsetzung der Re-QA-Findings

**Entwicklerstatus (historisch):** Implementiert und zunächst mit isolierten
Testdoubles geprüft. Die anschließend ausgeführte unabhängige Re-QA ist im
abschließenden Abschnitt oben dokumentiert.

- **Auto-Start:** Erledigt. Timer verwenden nun die Slots `-a` und `-b`; der
  Ablauf übergibt seinen aktuellen Slot und plant die Folgephase im jeweils
  anderen. Die Slotwahl wird aus dem unter Lock validierten Session-State
  abgeleitet; ein Expiry-Aufruf mit nicht passendem Slot ist wirkungslos.
  `unitSlot` ist Teil der validierten Session-Invarianten.
- **Cleanup-Lock:** Erledigt. Die leere Lockdatei liegt dauerhaft unter
  `~/.local/state/omarchy/.locks/`. Der Sitzungsordner wird erst nach Erwerb
  dieses Locks angelegt und kann deshalb gefahrlos durch Cleanup verschwinden.
- **Regressionstests:** Erledigt. Die Suite simuliert eine noch aktive
  Slot-A-Service-Unit, prüft die Planung in Slot B, parallele Mutationen sowie
  Cleanup mit altem Lock-Waiter und neu eintreffendem Mutator. Dabei wird auch
  geprüft, dass die Lock-Inode unverändert bleibt. Zusätzlich deckt sie einen
  falschen Expiry-Slot und den statusgetriebenen Reconcile-Pfad ab.
- **Dokumentation:** README, Architektur und Anforderungen beschreiben die
  wechselnden Units und die bewusst persistente Koordinationsdatei.

Verifiziert mit `bash -n`, `qmllint`, `omarchy plugin validate .`,
`tests/test-cli.sh` und `git diff --check`.

#### Entwickler-Nachtrag: Legacy-Lock-Migration

Das unabhängige Re-QA fand eine vorhandene `operation.lock` aus dem früheren
Layout. Neue Prozesse erwerben nun zuerst die stabile Koordinationsdatei und,
falls vorhanden, zusätzlich diese Legacy-Lockdatei. Cleanup entfernt den
Legacy-Inode bewusst nicht: Bereits wartende Prozesse einer alten
Laufzeitkopie könnten ihn noch halten; ein Unlink würde die Serialisierung
erneut aufspalten. Session und Settings werden dennoch vollständig entfernt.
Ein Regressionstest serialisiert einen alten Lockhalter, Cleanup und einen neu
eintreffenden Mutator und prüft die unveränderte Inode. Dies ist nur der
Entwicklerstatus; die unabhängige Schließung bleibt beim primären QA-Agenten.

### Ergebnis des Re-QA

**Historisches Ergebnis:** Zu diesem Zwischenstand noch nicht release-ready.
Die damaligen Blocker wurden danach behoben und unabhängig verifiziert; für
den aktuellen Status gilt der abschließende Re-QA am Dokumentanfang.

## Umsetzung

Stand der Bearbeitung: 2026-08-16

- **Scheduling-Rollback (P1): behoben.** `start` stellt bei einem
  `systemd-run`-Fehler den bereiten Zustand wieder her, `resume` den pausierten
  Zustand. Ein fehlgeschlagener Auto-Start hinterlässt die nächste Phase
  sicher in `ready` und meldet den Fehler auf `stderr`.
- **Direkte Zahleneingabe (P1): behoben.** Alle vier Dauer-/Zykluswerte lassen
  sich durch Klick auf den Wert oder durch Tippen einer Ziffer bearbeiten.
  `IntValidator`, Enter, Escape und Fokusverlust behandeln Bereich, Commit und
  Abbruch.
- **Vollständiges Cleanup (P2): behoben.** Cleanup entfernt Session, Settings,
  Lockdatei und anschließend den leeren Pomarchy-Zustandsordner. Mehrfaches
  Cleanup ist im automatisierten Test enthalten.
- **Settings-Vollständigkeit (P2): behoben.** `showCountdown` besitzt eine
  explizite Schema-v1-Migration. Danach sind alle Felder Pflicht; andere
  unvollständige oder ungültige Settings werden protokolliert und vollständig
  auf Defaults zurückgesetzt.
- **State-Invarianten (P2): behoben.** Ganzzahligkeit, erlaubte Werte,
  `transitionId` sowie statusabhängige `endsAt`-/Restzeit-Regeln werden
  validiert. Ein Zykluszähler oberhalb einer geänderten `longBreakAfter`-Grenze
  wird bewusst auf `Grenze - 1` normalisiert.
- **Skip per Tastatur (P2): behoben.** Im Zustand `ready` führt Enter/Space auf
  dem deaktivierten Skip-Ziel kein Kommando mehr aus.
- **Prozess-Exitcodes (P2): behoben.** Panel-, Status- und IPC-Prozesse werten
  Exitcodes aus, zeigen `stderr` oder eine generische Exitcode-Diagnose und
  aktualisieren nach Aktionsfehlern kontrolliert den Status.
- **Theme-Priorität (P3): behoben.** `green`/`red` und `color2`/`color1` werden
  getrennt gesammelt; erst nach dem Parsen gilt unabhängig von der
  Dateireihenfolge die dokumentierte Priorität.
- **Shell-IPC (P3): umgesetzt.** Das Widget bietet Open/Close/Toggle sowie
  Start/Pause/Resume/Skip/Reset unter `io.github.ofilafoo.pomarchy` an. Die
  Handler verwenden bewusst keine QML-Rückgabetypannotation, da die lokal
  installierte `qmllint`-Version bei typisierten `IpcHandler`-Methoden ohne
  Diagnose mit Exitcode 255 abbricht; untypisierte Handler sind zugleich mit
  Quickshell und dem Linter kompatibel.
- **CI-Abdeckung (P3): erweitert.** `tests/test-cli.sh` prüft unter temporärem
  HOME Scheduling-Rollback, Migration, ungültige Pflichtfelder,
  State-Recovery, Skip-Zählung, Parallelzugriffe und idempotentes Cleanup.
  QML- und echte Shelltests bleiben wegen der Omarchy-Laufzeit lokale
  Integrationschecks.

## Archivierte Findings

### P1 – Ein fehlgeschlagenes Anlegen des systemd-Timers hinterlässt einen falschen `running`-Zustand

**Fundstellen:** `pomarchy:153-160`, `pomarchy:201-205`, `pomarchy:214-218`

Bei `start`, `resume` und einem automatisch gestarteten Phasenwechsel wird zuerst der Zustand atomar als `running` gespeichert und erst danach `systemd-run` aufgerufen. Schlägt `systemd-run` fehl, endet das Kommando zwar mit einem Fehler, aber `session.json` bleibt auf `running`. Damit meldet die UI einen laufenden Timer, obwohl kein Hintergrundtimer existiert.

Das verletzt insbesondere F-09 und NF-02. Der Entwickler sollte das Scheduling als Teil einer konsistenten Zustandsänderung behandeln: Fehler explizit abfangen und auf einen sicheren Zustand zurückrollen oder den Timer vor dem finalen Commit des Zustands erfolgreich anlegen. Der Fehler sollte außerdem eindeutig an die UI gelangen.

### P1 – Direkte Zahleneingabe für Dauerwerte fehlt

**Fundstellen:** `Panel.qml:179-183`, Anforderung F-03

Die vier numerischen Einstellungen bieten nur Minus- und Plus-Schaltflächen. Eine direkte Zahleneingabe ist nicht vorhanden. F-03 fordert ausdrücklich, dass einstellbare Zeitwerte sowohl über sichtbare Minus-/Plus-Aktionen als auch über direkte Zahleneingabe erreichbar sind.

Das ist besonders bei großen Änderungen relevant, etwa von 25 auf 120 Minuten. Benötigt werden Eingabefokus, Bereichsvalidierung, Commit/Abbruch sowie ein klar definiertes Verhalten für Enter und Escape.

### P2 – Cleanup entfernt nicht den vollständigen Pomarchy-Zustand

**Fundstellen:** `pomarchy:4-14`, `pomarchy:266-269`, `README.md:76-87`, Anforderung F-13

Jeder Aufruf erzeugt beziehungsweise öffnet `operation.lock`. `cleanup` entfernt anschließend nur `session.json` und `settings.json`. `operation.lock` und der Pomarchy-Zustandsordner bleiben bestehen. Damit stimmt die Implementierung nicht mit der Dokumentation „owned state“ beziehungsweise der Anforderung, Pomarchy-eigene Zustandsdateien zu entfernen, überein.

Der Entwickler sollte festlegen, ob Lockdatei und leerer Zustandsordner absichtlich erhalten bleiben. Falls nicht, muss Cleanup die geöffnete Lockdatei sicher unlinken und den anschließend leeren Plugin-Zustandsordner entfernen, ohne fremde Pfade anzutasten. Mehrfachaufrufe bleiben zu testen.

### P2 – Unvollständige Settings werden teilweise als gültig akzeptiert

**Fundstelle:** `pomarchy:47-56`

Die Prüfung `((.showCountdown // true)|type) == "boolean"` akzeptiert ein fehlendes `showCountdown`-Feld. Eine unvollständige `settings.json` wird dadurch nicht zwingend verworfen oder vollständig auf Defaults migriert. Das widerspricht F-08, wonach beschädigte oder unvollständige Daten erkannt, protokolliert und in einen sicheren Zustand überführt werden sollen.

Alle Pflichtfelder sollten explizit auf Vorhandensein und Typ geprüft werden. Alternativ braucht es eine klar versionierte Migration, die fehlende Felder kontrolliert ergänzt und das Ergebnis erneut validiert.

### P2 – Die Sitzungsvalidierung sichert die Exactly-once-Garantie nicht ausreichend ab

**Fundstellen:** `pomarchy:59-70`, `pomarchy:232-236`, Anforderung F-08/F-09

`valid_state` validiert `transitionId` nicht. Ein laufender Zustand ohne gültige Transition-ID wird akzeptiert. Der bereits geplante systemd-Aufruf kann dann die Phase nicht abschließen, weil `expire` die erwartete ID mit dem ungültigen aktuellen Wert vergleicht. Eine spätere Statusabfrage kann den Ablauf zwar rekonstruieren, aber bei nicht laufender Shell erfolgt der Wechsel nicht zum vorgesehenen Zeitpunkt und die Benachrichtigung verspätet sich.

Zusätzlich prüft `valid_state` keine zustandsabhängigen Invarianten, beispielsweise:

- `running` benötigt einen positiven `endsAt` und eine nichtleere `transitionId`;
- `ready` und `paused` sollten keinen aktiven Endzeitpunkt besitzen;
- Zähler und Zeitwerte sollten ganzzahlig sein;
- `completedInCycle` sollte zur aktuellen Konfiguration passen oder bewusst normalisiert werden.

### P2 – Eine visuell deaktivierte Skip-Aktion bleibt per Tastatur auslösbar

**Fundstellen:** `Panel.qml:115-125`, `Panel.qml:172-176`

Im Zustand `ready` ist der Skip-Button mit `enabled: false` visuell und für den Pointer deaktiviert. `activateCursor()` prüft diesen Zustand jedoch nicht und ruft bei `cursorIndex === 1` trotzdem `skip` auf. Die CLI antwortet darauf mit einem Fehler. Damit ist die Aktion nicht konsistent deaktiviert und die Tastaturbedienung verhält sich anders als die Pointer-Bedienung.

Der Tastaturpfad sollte dieselben Verfügbarkeitsregeln wie der sichtbare Button verwenden. Optional sollte der Cursor deaktivierte Aktionen überspringen.

### P2 – Prozessfehler werden nur über `stderr`, nicht verlässlich über den Exitcode behandelt

**Fundstellen:** `Panel.qml:66-74`, `Panel.qml:136-140`, `BarWidget.qml:76-81`, Anforderung NF-02

Die QML-Prozesse sammeln stdout und stderr, werten aber keinen fehlgeschlagenen Exitcode aus. Ein Programm kann mit Exitcode ungleich null und leerem `stderr` enden; in diesem Fall erhält der Benutzer keine Diagnose. Umgekehrt kann nach einem Fehler eventuell veralteter Zustand sichtbar bleiben.

Der Abschluss-Handler sollte den Exitcode berücksichtigen, eine verständliche Fehlermeldung setzen und danach kontrolliert einen Status-Refresh versuchen.

### P3 – Theme-Fallbacks sind von der Reihenfolge in `colors.toml` abhängig

**Fundstellen:** `BarWidget.qml:44-55`, Anforderung F-02, `Lessons Learned – Pomarchy`

Der Parser schreibt die Fokus- beziehungsweise Pausenfarbe nur, solange die jeweilige Variable leer ist. Steht `color2` vor `green`, gewinnt `color2` dauerhaft; ein später vorhandenes `green` wird ignoriert. Entsprechendes gilt für `color1` und `red`. Dokumentiert ist jedoch die Priorität `green`, ersatzweise `color2`, beziehungsweise `red`, ersatzweise `color1`.

Primär- und Fallbackfarbe sollten getrennt gesammelt und erst nach dem Parsen nach fester Priorität ausgewählt werden.

### P3 – Geforderte beziehungsweise geplante Omarchy-Shell-IPC-Endpunkte fehlen

**Fundstellen:** `Panel.qml:8-12`, gesamtes `BarWidget.qml`, Anforderung F-12

Die CLI-Kernaktionen sind vorhanden. Das Bar-Widget stellt jedoch keine erkennbaren Shell-IPC-Aufrufe für Panel-Open oder Kernaktionen bereit; das Panel setzt sogar `manageIpc: false`. F-12 formuliert dies als SOLL-Anforderung. Falls IPC bewusst auf eine spätere Version verschoben wird, sollte das in Anforderungen und Dokumentation eindeutig festgehalten werden. Andernfalls fehlen Implementierung und Tests.

### P3 – Die CI bildet den lokalen QA-Standard nur teilweise ab

**Fundstelle:** `.github/workflows/validate.yml:10-29`

Die CI prüft Manifest-Grunddaten, Dateien, Executable-Bits und Bash-Syntax. Sie führt weder `qmllint` noch `omarchy plugin validate` noch Zustandsmaschinen-Tests aus. Mehrere zentrale Anforderungen – Transition-ID, Phasenfolge, Tageszähler, Defaults und Parallelzugriffe – sind daher nicht regressionsgeschützt.

Mindestens die reine CLI-Zustandsmaschine lässt sich mit temporärem HOME und kontrollierten `systemctl`-/`systemd-run`-Testdoubles automatisiert testen. Für QML und die echte Shell kann ein separater Integrationscheck dokumentiert bleiben.

## Bestandene statische Checks

Folgende nicht verändernde Checks liefen ohne Ausgabe beziehungsweise Fehler durch:

- `bash -n pomarchy cleanup`
- `jq -e . manifest.json`
- `qmllint BarWidget.qml Panel.qml`
- `omarchy plugin validate .`
- `omarchy plugin validate ~/.config/omarchy/plugins/io.github.ofilafoo.pomarchy`

Die installierte Laufzeitkopie stimmt mit dem Repository bei den Plugin-Dateien überein. Nur `.editorconfig`, `.gitignore`, `.git` und `.github` sind erwartungsgemäß ausschließlich im Entwicklungsrepository vorhanden.

## Historisch empfohlene Reihenfolge für den Entwickler

1. Fehlerbehandlung und Konsistenz rund um `systemd-run` korrigieren.
2. Direkte Zahleneingabe gemäß F-03 ergänzen.
3. Zustands- und Settings-Invarianten verschärfen.
4. Cleanup-Semantik und Dokumentation angleichen.
5. Tastatur- und Prozessfehlerpfade korrigieren.
6. Theme-Priorität und IPC-Entscheidung klären.
7. Automatisierte CLI-Regressionstests in die CI aufnehmen.

## Verbleibende P3- und manuelle Punkte

- Ein echter Suspend/Resume-Vorgang wurde in diesem Lauf nicht ausgelöst, um
  die aktive Benutzersitzung nicht ungefragt zu suspendieren. Absolute
  Endzeitpunkte, überfälliger Reconcile und Shell-Neustarts sind automatisiert
  beziehungsweise real geprüft.
- Pointer-/Touchpad-, vollständige Tastatur-Fokusführung sowie horizontale und
  vertikale Bar-Darstellung bleiben visuelle manuelle Abnahmen.
- `preview.png` ist für eine spätere Marketplace-Präsentation empfohlen, aber
  nach der lokal verfügbaren Manifest- und Plugin-Dokumentation keine
  Laufzeit- oder Validatorvoraussetzung.
- Bei aktualisierten Vorabversionen bleibt ein vorhandener leerer
  `operation.lock` samt ansonsten leerem Sitzungsordner absichtlich als
  Legacy-Koordinationsanker bestehen. Dies ist eine dokumentierte sichere
  Upgrade-Ausnahme, kein Nutzdatenrest.
