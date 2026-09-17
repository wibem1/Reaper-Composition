# Composition Studio – aktueller Funktionsstand

**Version:** 0.3-test1  
**Zweck dieser Datei:** Verbindliche Momentaufnahme dessen, was die aktuelle Version kann, was noch nicht implementiert ist und welche Grenzen gelten. Diese Datei wird ab jetzt bei jeder funktionalen Erweiterung von Composition Studio mitgeführt.

## Grundprinzip

Composition Studio ist eine natürlichsprachliche KI-Steuerung innerhalb von REAPER. REAPER bleibt DAW, Arrangement, Transport, MIDI-Editor, Mixer und Plugin-Host. Composition Studio interpretiert freie Sprache; Lua führt ausschließlich freigegebene und validierte REAPER-Aktionen aus.

Es gibt **keine Triggerwörter** und keine vom Benutzer zu lernende Befehlssprache.

## In 0.3-test1 vorhanden

### Oberfläche und Dialog

- Andockbares ReaImGui-Fenster in REAPER.
- Freies mehrzeiliges Texteingabefeld.
- Chatverlauf während der laufenden Script-Sitzung.
- Anzeige der Zahl ausgewählter MIDI-Items.
- Gesprächsantworten ohne Veränderung des REAPER-Projekts.
- Die letzten Dialogeinträge werden als Gesprächskontext an die KI gegeben.
- Fenster-Offen/Geschlossen-Zustand wird für den nächsten REAPER-Start gespeichert.
- Automatische Einrichtung des Composition-Studio-Autostarts über `Scripts/__startup.lua`.

### Kompakter Controller-Aufruf

Vor einer Aktion erhält die KI standardmäßig **keine vollständigen MIDI-Noten**. Übertragen werden nur ein kompakter Kontext mit Tempo sowie für ausgewählte MIDI-Items Item-GUID, Spur-/Take-Name und QN-Zeitbereich. Dadurch werden Datenmenge und API-Kosten reduziert.

Die KI darf zunächst nur zwischen folgenden Antwortarten wählen:

- normale Chatantwort,
- Rückfrage bei Unklarheit,
- eine freigegebene lokale REAPER-Aktion,
- Anforderung musikalischer MIDI-Daten (`NEED_MUSIC`).

Erst bei einer musikalischen Aufgabe werden die Noten der ausgewählten MIDI-Items nachgeladen und an die KI übertragen.

### Freigegebene lokale Aktionen

| Aktion | Ziel | Stand 0.3-test1 |
|---|---|---|
| MIDI transponieren | ein ausgewähltes MIDI-Item | implementiert, zu testen |
| Item verschieben | ein ausgewähltes MIDI-Item | implementiert, zu testen |
| Item kopieren | ein ausgewähltes MIDI-Item | implementiert, zu testen |
| Spur umbenennen | Spur eines ausgewählten MIDI-Items | implementiert, zu testen |

Die KI kann diese Aktionen aus freier Sprache auswählen. Intern werden ausschließlich vorhandene Item-/Track-GUIDs akzeptiert. Unbekannte Aktionen werden verworfen. Änderungen erhalten einen REAPER-Undo-Schritt.

### Musikalische Funktionen

Die bereits vorhandene Kompositionsstrecke bleibt erhalten:

- neue MIDI-Komposition erzeugen,
- zu ausgewähltem Material eine neue Stimme erzeugen,
- ausgewähltes MIDI musikalisch variieren/überarbeiten,
- mehrere ausgewählte MIDI-Items als gemeinsamen musikalischen Kontext verwenden,
- musikalische Analyse bzw. Gespräch über ausgewähltes Material ohne Änderung.

Bei musikalischer Überarbeitung wird das vorhandene Ausgangsmaterial nicht direkt überschrieben; eine Variante wird als neues Material erzeugt.

## Transparenz und Absicherung

- Die KI darf nur im Controller-Protokoll ausdrücklich freigegebene Aktionen anfordern.
- Bei Mehrdeutigkeit soll sie nachfragen statt zu raten.
- Wenn die KI eine unbekannte Aktion liefert, führt Lua nichts aus.
- Ungültige GUIDs oder Parameter werden zurückgewiesen.
- Transpositionen, die MIDI-Pitches außerhalb 0–127 erzeugen würden, werden abgebrochen.
- Item-Verschiebungen/Kopien vor Projektbeginn werden abgebrochen.
- Ausgeführte lokale Aktionen werden im Chat benannt und sind per REAPER Undo rückgängig zu machen.

## Wichtige aktuelle Grenzen

### Auswahl und Projektkenntnis

- Composition Studio arbeitet derzeit mit **ausgewählten MIDI-Items**.
- Nicht ausgewählte Spuren und Items werden der KI nicht als vollständige Projektstruktur mitgeteilt.
- Ein nur ausgewählter Track ohne ausgewähltes MIDI-Item ist derzeit kein vollständiger Arbeitskontext.
- Die KI besitzt keinen permanenten Spiegel des gesamten REAPER-Projekts.
- Spurzuordnung erfolgt derzeit über die Spur des ausgewählten MIDI-Items; eine allgemeine projektweite Suche nach „Klavierspur“, „Cellospur“ usw. ist noch nicht implementiert.

### MIDI-Kontext

Bei musikalischem Nachladen werden derzeit ungemutete MIDI-Noten des aktiven Takes übertragen: Position, Dauer, Pitch, Velocity und MIDI-Kanal.

Derzeit **nicht** als musikalischer KI-Kontext übertragen werden insbesondere:

- gemutete Noten,
- MIDI-CC-Daten,
- Pitch Bend,
- Program Change,
- SysEx,
- Automation,
- Plugin-Zustände oder Instrumentenklang,
- Audio.

### Zeit und Takte

- Lokale Item-Verschiebung und -Kopie arbeiten intern mit QN/Viertelnoten.
- Sprachliche Taktangaben dürfen nur verwendet werden, wenn sie aus dem verfügbaren Kontext eindeutig in QN umsetzbar sind; sonst soll die KI nachfragen.
- Eine allgemeine robuste Bereichslogik für „Takt 5–8“ ist noch nicht implementiert.

### Dialog

- Der Chatverlauf ist derzeit nur im Arbeitsspeicher des laufenden Scripts vorhanden und wird beim Neustart nicht als Projektbestandteil gespeichert.
- Nur ein begrenzter Ausschnitt der letzten Dialogeinträge wird an die KI zurückgegeben.
- Indirekte Bezüge wie „Mach das“ sind deshalb nur dann sicher, wenn Ziel und Aktion aus diesem Kontext eindeutig hervorgehen.

### Technische Grenzen

- Aktuell wird ausschließlich OpenAI GPT-5.6 verwendet; Provider-/Modellauswahl ist noch nicht implementiert.
- KI-Aufrufe erfolgen derzeit synchron über `curl`; während eines API-Aufrufs kann die Oberfläche vorübergehend blockieren.
- Der API-Key wird im persistenten REAPER-ExtState gespeichert, nicht im macOS-Schlüsselbund.
- Es gibt noch keine Kosten-/Tokenanzeige.

## Noch nicht implementiert

Folgende Fähigkeiten gehören zum vorgesehenen Ausbau, sind in 0.3-test1 aber **nicht freigegeben**:

- einzelne MIDI-Noten oder definierte MIDI-Bereiche zeitlich verschieben/kopieren/löschen,
- Velocity gezielt verändern,
- Item teilen,
- Taktbereiche gezielt ersetzen,
- Stück um eine definierte Zahl von Takten fortsetzen,
- Einleitung oder Schluss als kontrollierte Arrangementoperation einsetzen,
- Spur projektweit finden/zuordnen,
- neue Spur als lokale Controller-Aktion erzeugen,
- Spur löschen,
- Uminstrumentieren als kontrollierte Funktion,
- definierte Taktbereiche variieren,
- Tempo lesen/ändern als Controller-Aktion,
- Taktart lesen,
- robuste Takt-/Positionsabfragen,
- Audioanalyse,
- Plugin-/Instrumentensteuerung,
- Automation,
- A/B-Vergleich und explizites Annehmen/Verwerfen von Varianten,
- Provider-/Modellauswahl,
- persistenter projektbezogener Chat.

## Bewusst nicht nachgebaut

Composition Studio soll REAPER nicht ersetzen. Deshalb sind derzeit keine eigenen Versionen von Transport, Mixer, Piano-Roll, Arrangementansicht, Plugin-Browser oder Plugin-Host vorgesehen.

## Nächster Testschritt

0.3-test1 muss zunächst in REAPER praktisch geprüft werden. Zu testen sind insbesondere:

1. freie Formulierung einer eindeutigen Transposition,
2. freie Formulierung einer Item-Verschiebung,
3. freie Formulierung einer Item-Kopie,
4. freie Formulierung einer Spur-Umbenennung,
5. absichtlich mehrdeutige Formulierung – Composition Studio muss nachfragen und darf nichts verändern,
6. nicht unterstützte Aktion – Composition Studio darf keine Ersatzaktion erfinden,
7. musikalischer Auftrag – MIDI-Noten sollen erst nach `NEED_MUSIC` verwendet werden,
8. REAPER Undo für jede ausgeführte lokale Aktion.

## Dokumentationsregel

Bei jeder funktionalen Änderung an Composition Studio wird diese Datei zusammen mit dem Script aktualisiert. Ein neuer Versionsstand gilt erst dann als vollständig dokumentiert, wenn hier **vorhandene Funktionen, Grenzen, nicht implementierte Funktionen und der nächste Teststand** nachvollziehbar festgehalten sind.
