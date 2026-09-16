# Architektur – Composition Studio for REAPER

## Leitidee

REAPER ist die DAW und der musikalische Projektzustand. Composition Studio ergänzt ausschließlich eine semantische KI-Kompositionsschicht für rekursive Arbeit an vorhandener Musik.

```text
REAPER project
    |
    | selected MIDI items / tracks / ranges
    v
Composition Studio.lua
    |
    | shared musical context + free natural-language request
    v
AI composer
    |
    | validated musical result + result semantics
    v
Composition Studio.lua
    |
    v
non-destructive revised / new material directly in REAPER
```

Es gibt keine Composition-Lab-Laufzeitkomponente und keine Send-/Import-Bridge zwischen zwei Apps.

## Auswahlmodell

Composition Studio liest direkt die in REAPER ausgewählten MIDI-Items. Alle ausgewählten Elemente stehen der KI als gemeinsamer musikalischer Kontext zur Verfügung.

Es gibt keine technischen TARGET-/CONTEXT-Rollen. Der natürliche Kompositionsauftrag bestimmt die musikalische Rolle im jeweiligen Arbeitsschritt.

Beispiel:

`Klavier unverändert lassen, Cello überarbeiten und eine Klarinette ergänzen.`

Sind Klavier und Cello ausgewählt, ergibt sich allein aus dem Auftrag: Klavier ist Kontext und bleibt bestehen, Cello wird bearbeitet, Klarinette wird neu erzeugt.

## Verantwortlichkeiten

### REAPER

Arrangement, Spuren, Items, Instrumente, Mixer, Transport, Tempo-/Taktkarte, MIDI-Editor, Projektzustand und Undo.

### Composition Studio.lua

- aktuelle musikalische Auswahl erfassen
- MIDI-Daten und notwendige Projektmetadaten lesen
- freien Auftrag erfassen
- Kontext kompakt für die KI serialisieren
- KI-Kommunikation durchführen
- Antwort validieren
- Ergebnissemantik anwenden
- neue oder bearbeitete Musik nicht destruktiv in REAPER erzeugen

### KI

Musikalische Analyse, Komposition und Transformation anhand des freien Auftrags und des ausgewählten Materials. Die KI soll musikalisch entscheiden können; das Script soll sie nicht durch unnötige Kompositionsregeln deterministisch einschränken.

## Interne musikalische Darstellung

Für die KI wird keine MIDI-Datei hin- und hergeschickt. Composition Studio erzeugt intern eine kompakte strukturierte Darstellung der ausgewählten Musik. Benötigt werden mindestens:

- Spur-/Item-Identität für sichere Rückzuordnung
- Spur- und Take-Namen
- musikalische Start-/Endlage
- Tempo und Taktart, soweit für den Kontext erforderlich
- Noten mit Start, Dauer, Tonhöhe, Velocity, Kanal
- später bei Bedarf relevante CC-, Program-Change-, Pitch-Bend- und weitere MIDI-Ereignisse

Die Darstellung ist ein internes Protokoll von Composition Studio und keine Verbindung zu Composition Lab.

## Ergebnissemantik

Die KI-Antwort muss zwischen musikalischem Inhalt und technischer Zuordnung unterscheiden können. Für Basic reichen drei Bedeutungen:

- `unchanged`: vorhandenes Material bleibt unangetastet
- `revised`: neue nicht destruktive Variante eines vorhandenen Quellelements
- `new`: neue Stimme / neues musikalisches Material

Composition Studio validiert technische Felder, bevor REAPER verändert wird. Eine fehlerhafte oder unvollständige Antwort darf das Projekt nicht beschädigen.

## Nicht destruktives Arbeiten

Originale werden standardmäßig nicht überschrieben. Eine überarbeitete Stimme wird zunächst als neue Variante/Item erzeugt. Neue Stimmen werden als neue Items bzw. bei Bedarf neue Tracks angelegt. Ein kompletter Apply-Vorgang wird in einen REAPER-Undo-Schritt gekapselt.

## KI-Kommunikation

Composition Studio spricht die KI-APIs selbst an. API-Schlüssel dürfen weder im Repository noch fest im Lua-Code gespeichert werden.

Für Basic soll die Lösung möglichst ohne zusätzliche REAPER-Erweiterung funktionieren. Auf macOS kann ein lokaler HTTPS-Aufruf über das vorhandene Systemwerkzeug `curl` als Transport dienen. Die endgültige Implementierung muss verhindern, dass ein fehlgeschlagener Netzwerk-/KI-Aufruf Änderungen am REAPER-Projekt hinterlässt.

## Basic vor Komfort

Die erste Entwicklungsstufe beweist den vollständigen technischen Kreislauf. Das GUI bleibt bewusst klein. Erst danach wird derselbe Kern um ein komfortables dockbares Interface, MusicChat, Provider-/Modellauswahl und Variantenverwaltung ergänzt.

## Abgrenzung

Nicht neu zu bauen sind:

- Transport
- Mixer
- Plugin-Hosting
- Piano Roll
- Audio-Engine
- Instrumentenverwaltung
- eigene Projektdatei als Ersatz für `.rpp`
- eine zweite DAW-Oberfläche

## Altbestand

Composition Lab V3.2.9 und seine funktionierenden REAPER-Send-/Import-Skripte bleiben unverändert. Sie sind ein separates bestehendes System und keine Komponente von Composition Studio.
