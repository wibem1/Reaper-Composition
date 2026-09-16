# Composition Studio – Bedienungsanleitung und Funktionskatalog

Stand: 0.1-test9 / Spezifikation für die nächste Entwicklungsstufe

## Grundidee

Composition Studio erweitert REAPER um eine natürlichsprachliche Ebene für Komposition, MIDI-Bearbeitung und Arrangement. REAPER bleibt die DAW. Composition Studio interpretiert den freien Auftrag, die KI übernimmt musikalische Entscheidungen und Lua führt kontrollierte REAPER-Operationen aus.

**Grundsatz:** Die Auswahl sagt Composition Studio, welche Musik bzw. welche Objekte gemeint sind. Der freie Auftrag sagt, was damit geschehen soll.

## Status

- **Funktioniert:** im aktuellen Skript praktisch vorhanden.
- **Nächster Ausbau:** für die unmittelbar folgende Entwicklungsstufe vorgesehen.
- **Später:** prinzipiell vorgesehen, aber nicht Teil des nächsten Schritts.
- **Nicht vorgesehen:** REAPER-Funktionen, die Composition Studio nicht nachbauen soll.

## Funktionskatalog

| Bereich | Beispiel | Ausführung | Status |
|---|---|---|---|
| Neue Komposition | „Komponiere ein Stück für Cello und Klavier.“ | KI + Lua | Funktioniert |
| Stimme ergänzen | „Füge zu Klavier und Cello eine Klarinette hinzu.“ | KI + Lua | Funktioniert |
| Variation | „Erstelle eine Variation dieser Cellostimme.“ | KI + Lua | Funktioniert |
| Freier Kontext | Mehrere ausgewählte MIDI-Items als gemeinsamer musikalischer Kontext | KI + Lua | Funktioniert |
| Uminstrumentieren | „Mache aus der Cellostimme eine Violinstimme.“ | KI + Lua | Nächster Ausbau |
| Bereich verändern | „Variiere Takt 5 bis 8 der Cellostimme.“ | KI + Lua | Nächster Ausbau |
| Fortsetzen | „Verlängere das Stück sinngemäß um 12 Takte.“ | KI + Lua | Nächster Ausbau |
| Einleitung/Schluss | „Schreibe eine achttaktige Einleitung.“ | KI + Lua | Nächster Ausbau |
| Transponieren | „Transponiere die Cellostimme eine Oktave höher.“ | Lua | Nächster Ausbau |
| Spur erzeugen | „Erstelle drei neue Spuren für Violine, Viola und Cello.“ | Lua | Nächster Ausbau |
| Spur benennen | „Benenne diese Spur in Violine um.“ | Lua | Nächster Ausbau |
| MIDI verschieben/kopieren | „Verschiebe diesen Abschnitt vier Takte nach hinten.“ | Lua | Später |
| Takte/Abschnitte einfügen | „Füge zwischen Takt 8 und 9 vier Takte ein.“ | Lua + ggf. KI | Später |
| Tempo ändern | „Setze das Tempo auf 76 BPM.“ | Lua/REAPER | Später |
| Velocity bearbeiten | „Mache die ausgewählten Noten etwas leiser.“ | Lua | Später |
| Chat/Analyse | „Was hältst du von der Cellostimme in Takt 5 bis 8?“ | KI | Nächster Ausbau |
| Rekursiver Dialog | „Mach das.“ bezieht sich auf den vorherigen Vorschlag | KI + Lua | Nächster Ausbau |

## Aufgabenteilung

### REAPER / Lua

Deterministische und überprüfbare Operationen: Spuren, Items, Positionen, Taktbereiche, MIDI-Noten, Transposition, Benennung, Auswahl und Undo.

### KI

Musikalische Entscheidungen: Komponieren, Variieren, Fortsetzen, Uminstrumentieren, Analyse, Vorschläge und Interpretation freier Sprache.

### Kombination

Bei gemischten Aufträgen zerlegt Composition Studio die Aufgabe intern. Beispiel: „Erstelle drei Spuren für Violine, Cello und Klavier und komponiere darauf ein 16-taktiges Stück.“ Lua erzeugt die REAPER-Struktur, die KI komponiert das musikalische Material, Lua schreibt das Ergebnis in REAPER.

## Sicherheits- und Arbeitsprinzipien

- Bestehendes musikalisches Material wird bei KI-Varianten grundsätzlich nicht ungefragt überschrieben.
- Änderungen werden als REAPER-Undo-Schritt ausgeführt.
- Technische Operationen sollen nach Möglichkeit deterministisch durch Lua statt durch generierte MIDI-Daten ausgeführt werden.
- Die technische Befehlssprache ist interne Verkehrssprache. Der Benutzer arbeitet mit freier natürlicher Sprache.
- Musikalische Aufträge werden nicht durch unnötige Stil- oder Kompositionsregeln eingeengt.
- Neue Fähigkeiten werden erst in diesen Katalog aufgenommen und dann implementiert, statt das Skript mit unkoordinierten Sonderfällen zu erweitern.

## Benutzeroberfläche – nächste Stufe

Das bisherige einzelne Auftragsfenster wird nicht weiter zur Komfortoberfläche ausgebaut. Vorgesehen ist ein **andockbares Composition-Studio-Panel in REAPER** mit:

- scrollbarem Chatverlauf,
- freiem mehrzeiligem Eingabefeld,
- Rückmeldungen und Erklärungen der KI,
- Gesprächskontext für Folgeaufträge,
- Anzeige des aktuellen REAPER-Auswahlkontexts,
- klarer Trennung zwischen Gespräch und tatsächlich ausgeführten Aktionen.

ReaImGui ist dafür die bevorzugte Oberfläche. Das REAPER-Arrangement bleibt die grafische Darstellung der Spuren und MIDI-Items; Composition Studio baut keine zweite Arrangementansicht.

## Grenzen

Composition Studio ersetzt keine DAW-Funktionen, die REAPER bereits gut bereitstellt. Es baut insbesondere keinen eigenen Transport, Mixer, Piano-Roll oder Plugin-Host. Klangabhängige Aufgaben können nur so weit zuverlässig ausgeführt werden, wie die benötigten Instrumente/Plugins in REAPER vorhanden und über die REAPER-API kontrollierbar sind. Audioanalyse und tiefgreifende Audio-Bearbeitung gehören zunächst nicht zum Kernbereich.
