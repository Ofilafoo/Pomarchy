# Anforderungsdokument – Pomarchy

Status: Entwurf für Version 1.0  
Plugin-ID: `io.github.ofilafoo.pomarchy`  
Zielplattform: Omarchy Quattro mit `omarchy-shell` und Quickshell

## 1. Zweck

Pomarchy ist ein Pomodoro-Timer für die Omarchy-Top-Bar. Das Plugin soll
Fokusphasen und Pausen zuverlässig steuern, den aktuellen Zustand unmittelbar
in der Bar anzeigen und vollständig mit Touchpad und Tastatur bedienbar sein.

Die Zeitmessung darf nicht von einem dauerhaft geöffneten Panel oder einem
sekündlich fehlerfrei laufenden QML-Timer abhängen. Ein Neustart der Omarchy
Shell sowie Suspend und Resume dürfen die tatsächliche Restzeit nicht
verfälschen.

## 2. Ziele

- Fokusphasen, kurze Pausen und lange Pausen abbilden.
- Bedienung ohne Maus-Sonderaktionen ermöglichen.
- Eine kompakte, verständliche Anzeige in der Omarchy-Bar bieten.
- Timerzustand über Shell-Neustarts und Suspend/Resume erhalten.
- Phasenenden zuverlässig melden.
- Pomarchy-Zustand sicher, atomar und ausschließlich im Benutzerkontext
  verwalten.
- Eine solide Grundlage für spätere Statistiken und optionale Integrationen
  schaffen.

## 3. Nicht-Ziele der Version 1.0

- Aufgabenverwaltung oder Projektzuordnung
- Kalender- oder Cloud-Synchronisierung
- Benutzerkonten oder Netzwerkzugriffe zur Laufzeit
- Wochen-, Monats- oder Streak-Statistiken
- automatische Änderung von Idle-, Lock- oder Screensaver-Einstellungen
- erzwungener Fokusmodus oder Blockieren anderer Anwendungen
- mehrere gleichzeitig laufende Timer
- frei programmierbare globale Hyprland-Tastenkürzel

## 4. Zielgruppe und Nutzungskontext

Pomarchy richtet sich an einzelne Omarchy-Benutzer, die ihre Arbeits- und
Pausenintervalle direkt aus der Bar steuern möchten. Die primären Eingaben
erfolgen über:

1. einen normalen Linksklick beziehungsweise Touchpad-Tap auf das Bar-Widget;
2. sichtbare Schaltflächen im geöffneten Panel;
3. Tastaturnavigation innerhalb des Panels;
4. optionale IPC-Kommandos für spätere eigene Tastenkürzel oder Skripte.

Mausrad, Mittelklick, Rechtsklick und versteckte Gesten sind weder erforderlich
noch als exklusiver Zugang zu einer Funktion zulässig.

## 5. Begriffe

- **Fokusphase:** produktives Arbeitsintervall.
- **Kurze Pause:** Pause zwischen regulären Fokusphasen.
- **Lange Pause:** Pause nach einer konfigurierbaren Zahl abgeschlossener
  Fokusphasen.
- **Zyklus:** Abfolge der Fokusphasen bis zur langen Pause.
- **Bereit:** eine Phase ist ausgewählt, aber nicht gestartet.
- **Laufend:** der Endzeitpunkt der aktuellen Phase ist aktiv.
- **Pausiert:** die verbleibende Zeit ist gespeichert; kein Endzeitpunkt läuft.
- **Abgeschlossen:** eine Fokusphase hat ihr reguläres Ende erreicht.
- **Übersprungen:** die aktuelle Phase wurde bewusst vorzeitig beendet.

## 6. Standardkonfiguration

| Einstellung | Standard | Zulässiger Bereich |
|---|---:|---:|
| Fokusdauer | 25 Minuten | 1–120 Minuten |
| Kurze Pause | 5 Minuten | 1–60 Minuten |
| Lange Pause | 15 Minuten | 1–120 Minuten |
| Fokusphasen bis lange Pause | 4 | 1–12 |
| Nächste Phase automatisch starten | aus | an/aus |
| Desktop-Benachrichtigung | an | an/aus |
| Signalton | aus | an/aus |

Geänderte Einstellungen gelten für die nächste neu gestartete Phase. Eine
bereits laufende oder pausierte Phase wird dadurch nicht rückwirkend verändert.

## 7. Funktionale Anforderungen

### F-01 – Plugin-Vertrag

- Pomarchy MUSS als Omarchy-Plugin vom Typ `bar-widget` bereitgestellt werden.
- Das Manifest MUSS im Repository-Stamm liegen.
- Die dauerhafte ID MUSS überall `io.github.ofilafoo.pomarchy` lauten.
- `BarWidget.qml` MUSS das Panel intern laden und dessen Lifecycle
  `opened`, `open()`, `close()` und `closeForPopoutSwitch()` an die Shell
  weiterreichen.
- Das Widget DARF keinen zweiten Quickshell-Prozess starten.

### F-02 – Bar-Anzeige

- Im Zustand **Bereit** MUSS die Bar die geplante Dauer oder ein klar
  erkennbares Timer-Symbol anzeigen.
- Während einer laufenden oder pausierten Phase MUSS die Bar die Restzeit im
  Format `MM:SS` anzeigen.
- Bei Dauern ab 60 Minuten MUSS die Anzeige eindeutig bleiben, beispielsweise
  `H:MM:SS`.
- Fokusphase, Pause und pausierter Zustand MÜSSEN visuell unterscheidbar sein.
- Der Tooltip MUSS Phase, Status und Restzeit in Textform benennen.
- Ein normaler Linksklick MUSS das Panel öffnen beziehungsweise schließen.
- Die Countdown-Anzeige MUSS deaktivierbar sein. Im Symbolmodus MUSS ein
  monochromes Tomatenlogo neutral erscheinen, wenn keine Phase läuft, die
  Theme-Grünfarbe während einer Fokusphase und die Theme-Rotfarbe während
  einer laufenden Pause verwenden. Der Tooltip MUSS die Restzeit weiter nennen.

### F-03 – Panel

- Das Panel MUSS die aktuelle Phase, Restzeit und den Fortschritt anzeigen.
- Das Panel MUSS je nach Zustand passende, sichtbare Hauptaktionen anbieten:
  - Start
  - Pause
  - Fortsetzen
  - Phase überspringen
  - Zurücksetzen beziehungsweise Abbrechen
- Nicht verfügbare Aktionen MÜSSEN ausgeblendet oder eindeutig deaktiviert
  sein.
- Reset beziehungsweise Abbrechen MUSS bei einer bereits laufenden Phase eine
  Bestätigung verlangen.
- Alle Schaltflächen MÜSSEN großzügige Klickflächen besitzen und mit einem
  Touchpad zuverlässig anwählbar sein.
- Einstellbare Zeitwerte MÜSSEN über sichtbare Minus-/Plus-Aktionen und direkte
  Zahleneingabe erreichbar sein. Ein Slider ist nicht erforderlich.

### F-04 – Tastaturbedienung

- Nach Öffnen des Panels MUSS die Tastaturbedienung ohne zusätzlichen
  Pointer-Klick möglich sein.
- `j`/`k` und Pfeil hoch/runter MÜSSEN zwischen Bedienelementen navigieren.
- `h`/`l` und Pfeil links/rechts MÜSSEN den Wert eines ausgewählten
  Einstellungsfeldes verändern.
- `Enter` und Leertaste MÜSSEN die ausgewählte Aktion auslösen.
- `Escape` MUSS Eingaben abbrechen beziehungsweise das Panel schließen.
- `Tab` und `Shift+Tab` MÜSSEN das von Omarchy vorgesehene Wechseln zwischen
  Bar-Panels unterstützen.
- Der aktuelle Tastaturfokus MUSS jederzeit sichtbar sein.
- Direkttasten DÜRFEN ergänzend angeboten werden, dürfen jedoch keine exklusiv
  nur darüber erreichbare Funktion einführen.

### F-05 – Phasenablauf

- Nach einer regulär abgeschlossenen Fokusphase MUSS eine kurze Pause
  vorbereitet werden.
- Nach der konfigurierten Anzahl abgeschlossener Fokusphasen MUSS stattdessen
  eine lange Pause vorbereitet werden.
- Nach jeder Pause MUSS eine Fokusphase vorbereitet werden.
- Ist automatischer Start aktiviert, MUSS die vorbereitete Folgephase
  unmittelbar gestartet werden.
- Ist automatischer Start deaktiviert, MUSS Pomarchy im Zustand **Bereit** auf
  eine bewusste Startaktion warten.
- Eine übersprungene Fokusphase DARF nicht als abgeschlossen gezählt werden.
- Eine übersprungene Pause DARF den Fokuszähler nicht verändern.

### F-06 – Start, Pause und Fortsetzen

- Beim Start MUSS ein absoluter Endzeitpunkt gespeichert werden.
- Beim Pausieren MUSS die verbleibende Zeit aus dem Endzeitpunkt berechnet und
  gespeichert werden.
- Beim Fortsetzen MUSS ein neuer Endzeitpunkt aus aktueller Zeit plus
  gespeicherter Restzeit berechnet werden.
- Wiederholte oder sehr schnelle Aktionen DÜRFEN keinen negativen Timer, keine
  doppelte Phase und keine konkurrierenden Ablaufaktionen erzeugen.

### F-07 – Zurücksetzen und Überspringen

- Zurücksetzen MUSS eine Fokusphase mit ihrer vollständigen konfigurierten
  Dauer in **Bereit** versetzen. Aus einer kurzen oder langen Pause MUSS es
  zu einer bereiten Fokusphase zurückkehren.
- Abbrechen MUSS den aktiven Durchlauf beenden, ohne eine Fokusphase als
  abgeschlossen zu zählen.
- Überspringen MUSS die aktuelle Phase beenden und nach den Regeln aus F-05 die
  nächste Phase bestimmen.
- Jede dieser Aktionen MUSS einen zugehörigen Hintergrundtimer sicher
  entfernen oder ersetzen.

### F-08 – Persistenz

- Einstellungen und Sitzungsdaten MÜSSEN ausschließlich unter folgendem Pfad
  gespeichert werden:

  ```text
  ~/.local/state/omarchy/io.github.ofilafoo.pomarchy/
  ```

- Einstellungen und Sitzungszustand MÜSSEN logisch getrennt gespeichert
  werden.
- Zustandsdateien MÜSSEN atomar geschrieben werden.
- Zustandsändernde Operationen MÜSSEN mit `flock` serialisiert werden.
- Die leere Koordinationsdatei MUSS außerhalb des durch Cleanup löschbaren
  Sitzungsordners eine stabile Inode behalten, damit wartende und neu
  eintreffende Prozesse niemals verschiedene Lock-Domänen verwenden.
- Beschädigte oder unvollständige Zustandsdaten DÜRFEN die Omarchy Shell nicht
  zum Absturz bringen.
- Bei ungültigem Zustand MUSS Pomarchy einen sicheren **Bereit**-Zustand
  herstellen und den Fehler protokollieren.

### F-09 – Zeitgenauigkeit und Hintergrundablauf

- Die verbleibende Zeit MUSS aus einem absoluten Endzeitpunkt berechnet werden.
- QML DARF die sichtbare Anzeige sekündlich aktualisieren, ist aber nicht die
  maßgebliche Zeitquelle.
- Zwei eindeutig benannte, wechselnde transiente systemd-User-Timer MÜSSEN das
  Phasenende unabhängig vom geöffneten Panel auslösen können. Ein ablaufender
  Dienst MUSS den Nachfolger unter dem jeweils anderen Unit-Namen planen.
- Shell-Neustart sowie Suspend/Resume MÜSSEN die Restzeit korrekt rekonstruieren.
- Ist der Endzeitpunkt beim nächsten Start bereits überschritten, MUSS genau
  ein Phasenende verarbeitet werden.

### F-10 – Benachrichtigungen

- Bei Phasenende MUSS standardmäßig eine Omarchy-Desktop-Benachrichtigung
  erscheinen.
- Der Text MUSS die abgeschlossene und die nächste Phase nennen.
- Benachrichtigungen MÜSSEN deaktivierbar sein.
- Ein optionaler Signalton DARF nur abgespielt werden, wenn er aktiviert und
  auf dem System verfügbar ist.
- Ein fehlender Audio-Player oder eine fehlende Sounddatei DARF den
  Phasenwechsel nicht verhindern.

### F-11 – Tagesfortschritt

- Pomarchy MUSS die Anzahl regulär abgeschlossener Fokusphasen des aktuellen
  lokalen Kalendertags anzeigen.
- Pomarchy MUSS die abgeschlossene Fokuszeit des Tages anzeigen.
- Pausierte, abgebrochene oder übersprungene Fokusphasen DÜRFEN nicht als
  vollständig abgeschlossen gezählt werden.
- Der Tageswechsel MUSS anhand der lokalen Zeitzone erfolgen.
- Historische Detailstatistiken über den aktuellen Tag hinaus sind für Version
  1.0 nicht erforderlich.

### F-12 – IPC und Kommandozeile

- Die Kernaktionen MÜSSEN unabhängig von der Oberfläche über ein lokales
  Kommando verfügbar sein: `status`, `start`, `pause`, `resume`, `skip`,
  `reset` und `cleanup`.
- `status` MUSS maschinenlesbares JSON ausgeben.
- Ungültige Kommandos und Werte MÜSSEN mit einem Exitcode ungleich null und
  einer verständlichen Fehlermeldung auf `stderr` enden.
- Das Bar-Widget SOLL passende Omarchy-Shell-IPC-Aufrufe anbieten, damit das
  Panel geöffnet und Kernaktionen später an Hyprland-Tastenkürzel gebunden
  werden können.

### F-13 – Cleanup und Entfernung

- Ein idempotentes Cleanup-Kommando MUSS bereitgestellt werden.
- Cleanup MUSS ausschließlich Pomarchy-eigene systemd-User-Units und
  Zustandsdateien bearbeiten.
- Cleanup DARF die persistente Koordinationsdatei nicht entfernen, weil noch
  wartende Prozesse deren Inode halten können.
- Ist aus einer Entwicklungsversion noch `operation.lock` im Sitzungsordner
  vorhanden, MUSS Pomarchy nach dem stabilen Lock zusätzlich diesen
  Legacy-Anker sperren und darf ihn nicht entfernen. Der ansonsten leere
  Sitzungsordner DARF ausschließlich für diesen sicheren Upgrade-Anker
  bestehen bleiben.
- Mehrfaches Cleanup MUSS gefahrlos möglich sein.
- Das Plugin MUSS dokumentieren, welche Dateien und Units es erzeugt.
- Die Entfernung DARF keine Omarchy-, Idle- oder Screensaver-Einstellungen
  verändern.

## 8. Zustandsmodell

```text
                         ┌───────────┐
                  ┌─────▶│ pausiert  │─────┐
                  │      └───────────┘     │ fortsetzen
                  │ pausieren              ▼
┌────────┐ start  │                   ┌───────────┐
│ bereit │────────┴──────────────────▶│ laufend   │
└────────┘                            └───────────┘
    ▲                                   │       │
    │ reset                             │ Ende  │ skip
    └───────────────────────────────────┴───────┘
                      nächste Phase
```

Erlaubte Phasentypen sind `focus`, `short-break` und `long-break`. Erlaubte
Laufzustände sind `ready`, `running` und `paused`.

## 9. Datenmodell

Das genaue Format darf während der Implementierung verfeinert werden, muss
aber versioniert sein. Ein möglicher Sitzungszustand ist:

```json
{
  "schemaVersion": 1,
  "status": "running",
  "phase": "focus",
  "startedAt": 1786900000,
  "endsAt": 1786901500,
  "remainingSeconds": 1500,
  "durationSeconds": 1500,
  "completedInCycle": 2,
  "transitionId": "1786900000-focus",
  "unitSlot": "a",
  "daily": {"date": "2026-08-16", "focusSessions": 2, "focusSeconds": 3000}
}
```

`transitionId` MUSS die doppelte Verarbeitung desselben Phasenendes
verhindern. `unitSlot` MUSS bei laufendem Zustand `a` oder `b`, sonst leer
sein.

## 10. Nichtfunktionale Anforderungen

### NF-01 – Sicherheit

- Pomarchy DARF keine Root-Rechte, `sudo` oder `pkexec` benötigen.
- Pomarchy DARF zur Laufzeit keine Netzwerkverbindung aufbauen.
- Alle Shell-Argumente und Pfade MÜSSEN korrekt quotiert sein.
- Externe Eingaben MÜSSEN vor Verwendung validiert werden.
- Das Plugin MUSS alle externen Programme und Zustandsorte dokumentieren.

### NF-02 – Zuverlässigkeit

- Ein Fehler in einer Benachrichtigung DARF den Timerzustand nicht beschädigen.
- Ein fehlerhafter Hintergrundprozess MUSS in QML über Exitcode und `stderr`
  sichtbar oder diagnostizierbar sein.
- Timeraktionen MÜSSEN wiederholbar und bei konkurrierenden Aufrufen
  deterministisch sein.
- Automatische Phasenwechsel MÜSSEN auch nach einem Shell-Neustart genau einmal
  erfolgen.

### NF-03 – Bedienbarkeit

- Primäre Schaltflächen MÜSSEN eindeutig beschriftet sein.
- Symbole DÜRFEN Text unterstützen, aber nicht als einzige Erklärung einer
  kritischen Aktion dienen.
- Farbe DARF nicht das einzige Mittel zur Statusunterscheidung sein.
- Die Oberfläche MUSS mit horizontaler und vertikaler Bar funktionieren oder
  eine klar dokumentierte Einschränkung besitzen.

### NF-04 – Wartbarkeit

- UI, Zustandslogik und persistente Operationen SOLLEN getrennt bleiben.
- Wiederverwendbare, reine Berechnungen SOLLEN in einem QML/JavaScript-Modell
  oder testbaren Skriptmodul liegen.
- Alle IDs, Pfade und Unit-Namen SOLLEN aus einer zentral definierten
  Plugin-ID abgeleitet werden.
- Das Repository MUSS Manifest, README, Lizenz, Changelog und sichere
  Installations-/Entfernungshinweise enthalten.

### NF-05 – Kompatibilität

- Das Plugin MUSS gegen die auf dem Entwicklungssystem installierte Omarchy-
  Quattro-Version validiert werden.
- Änderungen unter `/usr/share/omarchy/` sind verboten.
- Benutzerdateien unter `~/.config/omarchy/plugins/` dürfen nur für lokale
  Installation und Tests angelegt werden.

## 11. Abnahmekriterien für Version 1.0

Version 1.0 gilt als abnahmefähig, wenn alle folgenden Szenarien erfüllt sind:

1. Das Plugin wird durch `omarchy plugin validate` ohne Fehler akzeptiert.
2. Das Widget lässt sich aktivieren und in der Bar anzeigen.
3. Ein Linksklick öffnet und schließt das Panel wiederholt zuverlässig.
4. Alle Hauptaktionen sind ausschließlich per Tastatur ausführbar.
5. Alle Hauptaktionen sind per normalem Touchpad-Tap auf sichtbare Elemente
   ausführbar.
6. Ein verkürzter Fokus-/Pausenzyklus läuft vollständig und wechselt korrekt
   zwischen den Phasen.
7. Pause und Fortsetzen erhalten die verbleibende Zeit korrekt.
8. Eine übersprungene Fokusphase erhöht den Abschlusszähler nicht.
9. Die vierte regulär abgeschlossene Fokusphase führt mit Standardwerten zur
   langen Pause.
10. Ein Shell-Neustart während einer laufenden und einer pausierten Phase
    erhält den Zustand.
11. Suspend/Resume führt zu einer anhand der Echtzeit korrekten Restzeit.
12. Gleichzeitige oder schnelle wiederholte Aktionen erzeugen keinen doppelten
    Phasenwechsel.
13. Benachrichtigungsfehler verhindern keinen Phasenwechsel.
14. Tageszähler und Fokusminuten werden nur bei regulären Abschlüssen erhöht.
15. Cleanup stoppt Pomarchy-eigene Timer und entfernt Pomarchy-eigenen Zustand
    ohne andere Omarchy-Zustände zu verändern.
16. `bash -n`, `qmllint`, JSON- und Manifestvalidierung sind erfolgreich.
17. Shell- und systemd-Journal enthalten nach den Tests keine Pomarchy-QML-,
    Prozess- oder Unit-Fehler.
18. Der ursprüngliche Desktop- und Timerzustand ist nach den Tests
    wiederhergestellt.

## 12. Lieferumfang

Für Version 1.0 werden mindestens folgende Dateien erwartet:

```text
Pomarchy/
├── manifest.json
├── BarWidget.qml
├── Panel.qml
├── Model.js
├── pomarchy
├── cleanup
├── README.md
├── REQUIREMENTS.md
├── ARCHITECTURE.md
├── CHANGELOG.md
├── SECURITY.md
├── LICENSE
└── .github/workflows/validate.yml
```

Eine optimierte `preview.png` ist für die spätere Marketplace-Einreichung
empfohlen, aber keine Laufzeitvoraussetzung.

## 13. Offene Produktentscheidungen

Diese Punkte sind vor oder während der ersten Implementierungsphase endgültig
festzulegen:

1. Soll die Bar im Zustand **Bereit** `25:00` oder nur ein Symbol anzeigen?
2. Soll automatischer Start getrennt für Fokusphasen und Pausen konfigurierbar
   sein oder als ein gemeinsamer Schalter?
3. Ab welcher bereits verstrichenen Fokuszeit verlangt Abbrechen eine
   Bestätigung?
4. Soll der Tageszähler manuell zurücksetzbar sein?
5. Welcher optionale Standardton wird verwendet und darf er als Asset im
   Repository mitgeliefert werden?
