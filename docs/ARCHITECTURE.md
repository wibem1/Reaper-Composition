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

## Projektleitlinien: Verständlichkeit, Wiederverwendung und Lizenzen

Composition Studio soll bewusst klein, modular und nachvollziehbar bleiben. Der Quelltext ist nicht nur für den Computer bestimmt, sondern soll auch für den Anwender lesbar und lernbar sein. Lua-Code wird deshalb klar strukturiert, verständlich benannt und an wichtigen Stellen auf Deutsch kommentiert. Große, miteinander verwobene Dateien und unnötige Framework-Schichten sollen vermieden werden.

Bei vorhandenen Systemen und Projekten unterscheiden wir strikt zwischen Idee, Code und Abhängigkeit:

- **MAGDA:** Die bisherigen Arbeiten sind ein Erfahrungs- und Ideenpool. Gute musikalische, konzeptionelle oder technische Verfahren dürfen übernommen bzw. in einfacher Form neu implementiert werden. Die MAGDA-Architektur und ihr Ballast werden nicht in Composition Studio hineingezogen.
- **Composition Lab / MusicChat:** Bewährte Erfahrungen mit freiem KI-Dialog, Kompositionsaufträgen, MIDI-Darstellung und mehreren KI-Anbietern dienen als Referenz. Composition Lab wird dadurch nicht zur Laufzeitabhängigkeit von Composition Studio.
- **REAPER-Skript-Ökosystem:** Vorhandene ReaScripts sollen gezielt untersucht werden, um bewährte REAPER-Techniken kennenzulernen und unnötige Neuerfindungen zu vermeiden.

Für fremden Code gilt:

1. **Ideen und Verfahren großzügig studieren.** Gute Lösungsprinzipien dürfen als Anregung für eine eigene, verständliche Implementierung dienen.
2. **Fremden Quellcode nur bewusst übernehmen.** Vor einer direkten Übernahme wird die jeweilige Lizenz geprüft und dokumentiert.
3. **Keine unnötigen Lizenzbindungen.** Code wird nicht übernommen, wenn dadurch unerwünschte Verpflichtungen oder Einschränkungen für Composition Studio entstehen.
4. **Abhängigkeiten sparsam wählen.** Eine externe Bibliothek oder REAPER-Erweiterung wird nur eingesetzt, wenn ihr Nutzen den zusätzlichen Installations-, Wartungs- und Lizenzaufwand klar rechtfertigt.
5. **Eigenständiger Kern.** Composition Studio soll möglichst ohne Sammlung fremder Skripte funktionieren. Techniken können gelernt und sauber selbst implementiert werden.
6. **Lizenzherkunft dokumentieren.** Falls später tatsächlich fremder Code oder eine externe Bibliothek verwendet wird, werden Quelle, Lizenz und Verwendungszweck im Repository festgehalten.

Leitsatz: **Ideen großzügig nutzen, fremden Code sparsam nutzen, Abhängigkeiten bewusst wählen.**

## Entwicklungsprinzip: REAPER nicht nachbauen

Alles, was REAPER bereits gut kann und im Arrangement sichtbar macht, bleibt Aufgabe von REAPER. Composition Studio baut insbesondere keine eigene grafische Repräsentation der MIDI-Items. Das Arrangement ist die visuelle Darstellung der Musik; Composition Studio zeigt nur die Informationen und Bedienelemente, die für den KI-Kompositionsdialog zusätzlich benötigt werden.

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
