# Architektur

## Leitidee

REAPER wird nicht erweitert, indem seine DAW-Funktionen nachgebaut werden. Composition Lab ergänzt eine semantische KI-Kompositionsschicht für rekursive Arbeit an vorhandener Musik.

```text
REAPER project
    |
    | selected MIDI items
    v
existing ReaScript adapter
    |
    | CompositionLab-Reaper-Bridge
    v
Composition Lab · DAW-Kommunikation
    |
    | shared musical context + free request
    v
MusicChat / AI composer
    |
    | musical result + return semantics
    v
ReaScript adapter
    |
    v
unchanged / revised / new material in REAPER
```

## Auswahlmodell

REAPER sendet genau die ausgewählten MIDI-Items. Alle übertragenen Items stehen der KI als gemeinsamer musikalischer Kontext zur Verfügung.

Es gibt **keine technischen TARGET-/CONTEXT-Rollen im REAPER-Projekt**. Der natürliche Kompositionsauftrag bestimmt, welche musikalische Rolle ein übertragenes Element in diesem konkreten Schritt hat.

Beispiel:

`Klavier unverändert lassen, Cello überarbeiten und eine Klarinette ergänzen.`

Die Auswahl kann Klavier und Cello enthalten. Aus dem Auftrag ergeben sich die Rückgaberollen: Klavier unverändert, Cello bearbeitet, Klarinette neu.

## Bestehendes Composition Package

Der stabile Ausgangspunkt ist `CompositionLab-Reaper-Bridge-0.6`. Bereits transportiert werden insbesondere:

- Format-/Quelleninformation
- Tempo und Taktart
- mehrere Tracks
- Tracknamen
- relative musikalische Zeitlage
- Noten
- rohe MIDI-Ereignisse, darunter CC, Program Change, Pitch Bend, Pressure, SysEx/Meta und REAPER-CCBZ

Das Protokoll wird nicht vorsorglich neu entworfen. Erweiterungen erfolgen nur dort, wo die neue Rückgabesemantik zusätzliche Identität oder Metadaten tatsächlich benötigt.

## DAW-Kommunikation in Composition Lab V4.0

Die App erhält eine eigene Seite zwischen Noten und Technik:

`Main – Noten – DAW-Kommunikation – Technik`

Aufgaben dieser Seite:

1. Quelle und empfangenes DAW-Material darstellen.
2. Track-/Stimmenübersicht des übertragenen Materials zeigen.
3. den vorhandenen MusicChat als freien Kompositionsdialog verwenden.
4. Ergebniszuordnung verständlich darstellen.
5. die Rückgabe nach REAPER kontrolliert auslösen.

Die Seite ist Verwaltungs- und Kommunikationsschicht, keine zweite Kompositionsengine.

## Rückgabesemantik

Für jedes relevante Ergebnis gibt es drei semantische Zustände:

- **unverändert** – vorhandenes REAPER-Material bleibt bestehen und muss nicht erneut erzeugt werden.
- **bearbeitet** – das Ergebnis gehört zu vorhandenem Material und wird standardmäßig nicht destruktiv als neue Version zurückgegeben.
- **neu** – das Ergebnis hat kein vorhandenes Quellelement und wird als neues Material an geeigneter Position/Spur angelegt.

Damit `bearbeitet` später eindeutig auf ein konkretes REAPER-Item bezogen werden kann, darf das Bridge-Protokoll um stabile Quellidentitäten erweitert werden. Diese Erweiterung muss rückwärtskompatibel zur funktionierenden V0.6-Basis bleiben.

## Verantwortlichkeiten

### REAPER
Auswahl, Arrangement, Spuren, Clips/Items, Instrumente, Mixer, Transport, Projektzustand.

### Bridge
Transport der ausgewählten musikalischen Daten und der für eine sichere Rückgabe nötigen Metadaten.

### Composition Lab / DAW-Kommunikation
Darstellung des empfangenen Materials, Verwaltung des rekursiven Arbeitsschritts und explizite Rückgabeabsicht.

### MusicChat / KI
Musikalische Analyse, Komposition und Transformation anhand des freien Auftrags und des ausgewählten Materials.

## Abgrenzung

Nicht neu zu bauen sind:

- eigener Transport als DAW-Ersatz
- eigener Mixer
- Plugin-Hosting
- Piano Roll als DAW-Ersatz
- Audio-Engine
- Instrumentenverwaltung
- eigene Projektdatei als Ersatz für `.rpp`

Composition Lab darf seine bereits vorhandenen Player-, Noten- und Projektfunktionen behalten; sie werden jedoch nicht zu einer neuen DAW ausgebaut.
