# DEVELOPMENT – Reaper Composition

Dieses Dokument ist vor jeder Entwicklungsarbeit an diesem Repository zu lesen. Es ist Teil der technischen Spezifikation, nicht nur ein Entwicklungs-Tagebuch.

## 1. Verbindliche Entwicklungsregeln

### Stabilität vor Funktionsmenge
Es werden keine Versionen zur Abnahme herausgegeben, von denen bereits bekannte automatisierbare Fehler bestehen. Erst einen zusammenhängenden Stand fertigstellen und prüfen, dann testen lassen.

### Keine Klecker-Versionen
Nicht für jeden kleinen Fehler eine neue Installationsversion erzeugen. Zusammengehörige Korrekturen werden gesammelt, sauber in den Code integriert und gemeinsam geprüft.

### Keine Patch-Ketten
Neue Funktionen und Fehlerbehebungen werden in die passende vorhandene Struktur eingearbeitet. Keine wachsende Folge von nachträglichen Patch-Skripten als Architektur.

### Kurze Entwicklungszyklen
Bevorzugt ReaScript/Lua und REAPER-eigene Funktionen. Kompilierte Komponenten nur, wenn eine benötigte Funktion anders nachweislich nicht sinnvoll erreichbar ist.

### Installation minimieren
Ziel ist eine einmalige Einrichtung. Danach sollen normale Updates möglichst nur Script-/Bridge-Dateien ersetzen bzw. aktualisieren. Keine wiederholten großen Build- und Installationsprozeduren.

### Versionsdisziplin
Jeder freigegebene Teststand erhält eine eindeutige Versions-/Buildnummer. Git-Commits beschreiben den tatsächlichen zusammenhängenden Entwicklungsschritt.

### Dokumentation zuerst lesen
Vor Änderungen: README.md, DEVELOPMENT.md und relevante Dateien unter docs/ lesen. Nach wesentlichen Architekturentscheidungen, Fehlerfällen oder Änderungen DEVELOPMENT.md aktualisieren.

## 2. Musikalisches Leitbild

Das System soll kreatives Komponieren unterstützen, nicht musikalische Entscheidungen durch ein starres Regelwerk ersetzen. Freie natürliche Kompositionsaufträge haben Vorrang vor immer detaillierteren technischen Promptvorgaben.

REAPER ist der dauerhafte musikalische Arbeitsraum. Die KI arbeitet rekursiv auf ausgewähltem Material und erhält bei Bedarf andere Projektteile als unveränderlichen Kontext.

Kernbegriffe:

- **TARGET** – Material, das die KI verändern, ersetzen oder ergänzen darf.
- **CONTEXT** – Material, das die KI berücksichtigen soll, aber nicht verändern darf.
- **RESULT** – neue Variante oder Ergänzung, die nicht destruktiv nach REAPER zurückkehrt.
- **ITERATION** – RESULT kann im nächsten Schritt TARGET oder CONTEXT werden.

## 3. Technisches Zielbild

### REAPER-Seite
ReaScript/Lua übernimmt möglichst:

- Ermitteln ausgewählter MIDI-Items/Tracks
- Ermitteln einer Zeit-/Taktselektion
- Lesen relevanter Projektmetadaten
- Export/Übergabe des musikalischen Pakets
- sichere Rückgabe von Ergebnissen
- spätere Verwaltung von TARGET/CONTEXT/Varianten

### Bridge
Die Bridge soll klein bleiben. Sie transportiert musikalische Daten und Metadaten zwischen REAPER und der bereits vorhandenen KI-/MusicChat-Welt. Sie soll keine zweite DAW und keine zweite Kompositionsengine werden.

### KI-Seite
Die KI erhält musikalisches Material, Rolleninformation (TARGET/CONTEXT) und einen freien Auftrag. Provider-/Modellvergleich soll grundsätzlich möglich bleiben, ohne die REAPER-Seite an einen einzelnen Anbieter zu koppeln.

## 4. MVP – erster Beweis

Der erste Entwicklungsmeilenstein ist bewusst klein:

1. Ein oder mehrere MIDI-Items in REAPER auswählen.
2. Daten zuverlässig erfassen/exportieren.
3. Tempo, Taktbezug und Track-Zuordnung erhalten.
4. Ergebnisdatei wieder zuverlässig importieren.
5. Original nicht überschreiben.
6. Mehrspurigkeit von Anfang an im Datenmodell berücksichtigen.

Erst wenn dieser Roundtrip stabil ist, folgt die eigentliche TARGET/CONTEXT- und KI-Logik.

## 5. Teststrategie

Vor einer Übergabe werden soweit automatisierbar geprüft:

- Lua-Syntax/Struktur
- leeres Projekt
- keine Auswahl
- ein MIDI-Item
- mehrere MIDI-Items
- mehrere Tracks
- unterschiedliche Item-Startpositionen
- Tempo-/Taktmetadaten
- sichere Behandlung fehlender Dateien/Daten
- keine unbeabsichtigte Änderung vorhandener Items

REAPER-spezifische Interaktion, die nicht automatisiert simuliert werden kann, wird als klar begrenzter manueller Test ausgewiesen.

## 6. Bekannte Erfahrung aus Vorgängerarbeiten

Eine frühere ReaScript-Verbindung zwischen REAPER und Composition Lab funktionierte bereits grundsätzlich in beide Richtungen. In der Entwicklung traten unter anderem folgende Fälle auf, die hier von Anfang an berücksichtigt werden müssen:

- Rückgabe erzeugte zunächst unerwünschte Spurkopien.
- Tempo war zunächst fälschlich auf 120 BPM festgelegt und wurde später korrekt übertragen.
- Mehrspurübertragung musste gesondert stabilisiert werden.
- Eine Rückgabe mit dichtem Notenmaterial führte zeitweise zu einem Absturz.
- Für leere Projekte wurde explizit Fehlerabfang statt Absturz gefordert.
- CC- und Program-Change-Daten sollen perspektivisch erhalten bleiben.
- SWS/Trackfarben waren nützlich, dürfen aber keine unnötige harte Abhängigkeit des Kerns werden.

Die damaligen Skripte sind aktuell nicht im bekannten GitHub-Bestand auffindbar. Deshalb werden ihre bewährten Workflow-Prinzipien übernommen, aber keine unbekannte Altimplementierung vorausgesetzt.

## 7. Entwicklungsphasen

**Phase 0:** Dokumentation und Architektur – begonnen 2026-09-16.

**Phase 1:** Minimaler stabiler REAPER-MIDI-Roundtrip ohne KI.

**Phase 2:** TARGET/CONTEXT-Paket und rekursive Varianten.

**Phase 3:** MusicChat/KI-Anbindung.

**Phase 4:** komfortabler REAPER-Workflow (Aktionen, Shortcuts, Varianten/Takes, Bereichsbearbeitung).

**Später:** Prüfung einer Ableton-Live-Anbindung auf Basis desselben Bridge-Konzepts.

## 8. Definition of Done für einen Teststand

Ein Stand wird erst zur manuellen Abnahme gegeben, wenn:

- der geplante Umfang vollständig implementiert ist,
- bekannte automatisierbare Fehler behoben sind,
- Tests dokumentiert sind,
- Versionsnummer aktualisiert ist,
- Dokumentation dem Code entspricht,
- Installation/Update so klein wie möglich gehalten wurde.
