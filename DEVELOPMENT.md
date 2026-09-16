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
REAPER-seitig bevorzugt ReaScript/Lua und vorhandene REAPER-Funktionen. Kompilierte Komponenten nur, wenn eine benötigte Funktion anders nachweislich nicht sinnvoll erreichbar ist.

### Verbindlicher REAPER-Arbeitsstand
Die produktiven REAPER-Aktionen liegen lokal unter:

`~/Library/Application Support/REAPER/Scripts/Composition Lab/`

Die bestehenden Aktionsdateien und Shortcuts bleiben erhalten:

- `Composition Lab - Send to Composition Lab.lua`
- `Composition Lab - Import from Composition Lab.lua`

Keine Umbenennung und keine parallelen Ersatz-Aktionen ohne zwingenden Grund.

### Installation minimieren
Normale Änderungen werden in bestehende Dateien integriert. Keine wiederholten großen Build- und Installationsprozeduren und keine Serie von Test-Apps.

### Versionsdisziplin
Jeder freigegebene Teststand erhält eine eindeutige Versions-/Buildnummer. Git-Commits beschreiben einen tatsächlichen zusammenhängenden Entwicklungsschritt.

### Dokumentation zuerst lesen
Vor Änderungen: README.md, DEVELOPMENT.md und relevante Dateien unter docs/ lesen. Nach wesentlichen Architekturentscheidungen, Fehlerfällen oder Änderungen DEVELOPMENT.md aktualisieren.

## 2. Musikalisches Leitbild

Das System soll kreatives Komponieren unterstützen, nicht musikalische Entscheidungen durch ein starres Regelwerk ersetzen. Freie natürliche Kompositionsaufträge haben Vorrang vor immer detaillierteren technischen Promptvorgaben.

REAPER ist der dauerhafte musikalische Arbeitsraum. Die KI arbeitet rekursiv auf genau dem Material, das in REAPER ausgewählt und übertragen wurde.

**Wichtige Festlegung:** Es gibt auf REAPER-Seite keine technischen TARGET-/CONTEXT-Markierungen. Alle ausgewählten MIDI-Items werden gemeinsam als musikalischer Kontext übertragen. Der freie Kompositionsauftrag bestimmt semantisch, was unverändert bleiben, verändert oder neu ergänzt werden soll.

Beispiele:

- Auswahl Klavier + Cello; Auftrag: „Klavier unverändert lassen, Cello überarbeiten.“
- Auswahl Klavier; Auftrag: „Füge eine Klarinette hinzu.“
- Auswahl mehrerer Stimmen; Auftrag: „Entwickle daraus eine neue gemeinsame Passage.“

Dasselbe Material kann im nächsten Schritt durch einen anderen Auftrag eine andere Rolle erhalten.

## 3. Technisches Zielbild

### REAPER-Seite
ReaScript/Lua übernimmt:

- Ermitteln der ausgewählten MIDI-Items/Tracks
- Übertragung der relativen Zeitpositionen und Tracknamen
- Übertragung relevanter MIDI-Ereignisse
- sichere Rückgabe von Ergebnissen
- später explizite Anwendung der Rückgabeaktionen unverändert / bearbeitet / neu

### Bridge
Der vorhandene Roundtrip `CompositionLab-Reaper-Bridge-0.6` ist die stabile Ausgangsbasis. Er unterstützt bereits Mehrspurigkeit, relative Zeitpositionen, Tracknamen, Noten sowie weitere rohe MIDI-Ereignisse einschließlich CC, Program Change, Pitch Bend, Pressure, SysEx/Meta und REAPER-CCBZ.

Die Bridge bleibt Transportebene. Sie wird weder zweite DAW noch zweite Kompositionsengine.

### Composition Lab / KI-Seite
Composition Lab erhält mit V4.0 eine eigene Seite **DAW-Kommunikation**. MusicChat bleibt die musikalische Dialog- und Kompositionsebene. Die neue Seite verwaltet das aus der DAW empfangene Material und macht die beabsichtigte Rückgabe explizit sichtbar.

Vorgesehene Rückgabesemantik:

- **unverändert** – vorhandenes REAPER-Material bleibt bestehen
- **bearbeitet** – eine neue, klar zuordenbare Version eines vorhandenen Elements
- **neu** – neu komponiertes Material ohne vorhandenes Quellelement

Nicht destruktives Verhalten ist Standard. Ein stilles Überschreiben vorhandenen Materials ist nicht zulässig.

## 4. Bereits erreichter Stand

Der grundlegende REAPER-MIDI-Roundtrip existiert bereits und muss nicht neu gebaut werden:

1. ausgewählte MIDI-Items werden an Composition Lab übertragen,
2. Mehrspurigkeit und relative Lage bleiben erhalten,
3. Composition Lab kann das Material laden,
4. ein Ergebnis kann zurückgegeben und von REAPER importiert werden,
5. breite MIDI-Ereignisdaten werden im Bridge-Format berücksichtigt.

Die alten produktiven Skripte wurden wiedergefunden und unverändert unter `scripts/legacy/` im Repository gesichert. Der lokale produktive Pfad bleibt jedoch `Scripts/Composition Lab`.

## 5. Nächster Entwicklungsschritt – Composition Lab V4.0

Die nächste zusammenhängende Stufe ist die neue App-Seite **DAW-Kommunikation**. Tab-Reihenfolge:

`Main – Noten – DAW-Kommunikation – Technik`

Ziele:

1. empfangenes DAW-Material übersichtlich anzeigen,
2. vorhandenen MusicChat für freie Kompositionsaufträge weiterverwenden,
3. Ergebnis und Rückgabeabsicht pro Stimme/Element sichtbar machen,
4. bestehende Bridge für den Transport weiterverwenden,
5. das Protokoll anschließend nur soweit erweitern, wie die explizite Rückgabesemantik es tatsächlich erfordert.

REAPER ist zuerst Ziel-DAW. Die Architektur soll später ohne neue Kompositionsengine auch Studio One/Fender Studio oder Ableton anbinden können.

## 6. Teststrategie

Vor einer Übergabe werden soweit automatisierbar geprüft:

- Swift-/Lua-Syntax und Buildfähigkeit der geänderten Komponenten
- leeres Projekt / keine Auswahl
- ein MIDI-Item
- mehrere MIDI-Items
- mehrere Tracks
- unterschiedliche Item-Startpositionen
- Tempo-/Taktmetadaten
- Erhalt unterstützter Nicht-Noten-MIDI-Ereignisse
- sichere Behandlung fehlender Dateien/Daten
- keine unbeabsichtigte Änderung vorhandener Items
- korrekte Tab-Reihenfolge und DAW-Seitenzustände

REAPER-spezifische Interaktion, die nicht automatisiert simuliert werden kann, wird als klar begrenzter manueller Test ausgewiesen.

## 7. Bekannte Erfahrungen aus Vorgängerarbeiten

Bereits gelöste oder besonders zu schützende Punkte:

- Rückgabe erzeugte früher unerwünschte Spurkopien.
- Tempo war zeitweise fälschlich auf 120 BPM festgelegt.
- Mehrspurübertragung musste stabilisiert werden.
- Eine Rückgabe mit dichtem Notenmaterial führte zeitweise zu einem Absturz.
- Leere Projekte benötigen Fehlerabfang statt Absturz.
- SWS/Trackfarben sind nützlich, dürfen aber keine harte Kernabhängigkeit werden.

Diese Fälle dürfen durch V4.0 nicht regressieren.

## 8. Definition of Done für einen Teststand

Ein Stand wird erst zur manuellen Abnahme gegeben, wenn:

- der geplante Umfang vollständig implementiert ist,
- bekannte automatisierbare Fehler behoben sind,
- Tests dokumentiert sind,
- Versions-/Buildnummer aktualisiert ist,
- Dokumentation dem Code entspricht,
- Installation/Update so klein wie möglich gehalten wurde.
