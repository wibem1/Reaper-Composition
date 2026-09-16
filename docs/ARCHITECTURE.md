# Architektur

## Leitidee

REAPER wird nicht erweitert, indem seine DAW-Funktionen nachgebaut werden. Reaper Composition ergänzt nur eine semantische KI-Kompositionsschicht.

```text
REAPER project
    |
    | selected MIDI + project context
    v
ReaScript adapter
    |
    | Composition Package
    v
Lightweight Bridge
    |
    v
MusicChat / AI composer
    |
    | Result Package
    v
ReaScript adapter
    |
    v
new take / item / track in REAPER
```

## Composition Package

Das Austauschformat soll von Anfang an mehrere Spuren unterstützen. Vorgesehene Informationen:

- schema/version
- project/session id
- request/iteration id
- tempo map bzw. für MVP mindestens wirksames Tempo
- time signatures
- selection/range
- Track-ID und Trackname
- Item-ID und Position
- Rolle TARGET oder CONTEXT
- MIDI-Daten
- später: CC, Program Change und weitere relevante MIDI-Ereignisse

Das genaue Serialisierungsformat wird erst nach Prüfung des einfachsten robusten REAPER-Workflows festgelegt. Keine unnötige Infrastruktur vor dem ersten Roundtrip.

## Rückgabe

Standard ist nicht destruktiv. Ein RESULT darf vorhandenes Material nicht still überschreiben. Die konkrete Standardform (neuer Take, neues Item oder neue Spur) wird im MVP praktisch getestet und danach festgelegt.

## Abgrenzung

Nicht Teil dieses Projekts:

- eigener Transport
- eigener Mixer
- Plugin-Hosting
- Piano Roll
- Audio-Engine
- Instrumentenverwaltung
- eigene Projektdatei als Ersatz für .rpp

Diese Funktionen existieren bereits in REAPER.
