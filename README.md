# Reaper Composition

Reaper Composition ist die Architektur- und ReaScript-Seite der rekursiven DAW-Komposition mit Composition Lab. REAPER bleibt DAW, Projektzustand und musikalischer Arbeitsraum; Composition Lab/MusicChat liefert die semantische KI-Kompositionsschicht.

## Ziel

Nicht nur komplette MIDI-Kompositionen erzeugen, sondern vorhandene Musik schrittweise weiterentwickeln:

- einzelne Stimmen, MIDI-Items oder Taktbereiche bearbeiten
- neue Stimmen zu vorhandenem Material komponieren
- Varianten erzeugen und vergleichen
- mehrere Stimmen zusammenführen oder weiterentwickeln
- bereits gelungenes Material durch den Auftrag unverändert lassen
- Ergebnisse sicher und nachvollziehbar nach REAPER zurückgeben

Grundprinzip:

`REAPER-Auswahl -> Bridge -> Composition Lab / MusicChat -> Ergebnis + Rückgabeabsicht -> REAPER`

## Architekturprinzipien

1. **Keine eigene DAW.** Arrangement, Transport, MIDI, Instrumente, Plugins, Mixer und Projektverwaltung bleiben Aufgaben von REAPER.
2. **Bestehenden Roundtrip nutzen.** Die funktionierende V0.6-ReaScript-Bridge ist Ausgangsbasis, kein Neubau.
3. **Auswahl ist gemeinsamer musikalischer Kontext.** REAPER überträgt genau die ausgewählten MIDI-Items. Es gibt keine technischen TARGET-/CONTEXT-Markierungen.
4. **Der freie Auftrag bestimmt die Rollen.** MusicChat entscheidet anhand des Auftrags, was unverändert bleibt, bearbeitet oder neu ergänzt wird.
5. **Originale schützen.** Rückgaben sind standardmäßig nicht destruktiv.
6. **Rekursive Arbeit.** Ein Ergebnis kann unmittelbar Ausgangspunkt des nächsten Kompositionsschritts werden.

## Bereits vorhanden

Die Bridge `CompositionLab-Reaper-Bridge-0.6` unterstützt bereits ausgewählte MIDI-Items, Mehrspurigkeit, relative Zeitpositionen, Tracknamen, Noten sowie relevante Nicht-Noten-Ereignisse wie CC, Program Change, Pitch Bend, Pressure und weitere rohe MIDI-Ereignisse.

Die produktiven REAPER-Aktionen bleiben lokal unter `Scripts/Composition Lab` mit ihren bestehenden Dateinamen und Shortcuts. Eine Sicherung der wiedergefundenen Skripte liegt im Repository unter `scripts/legacy/`.

## Nächster Schritt: Composition Lab V4.0

Composition Lab erhält die neue Seite **DAW-Kommunikation**. Vorgesehene Tab-Reihenfolge:

`Main – Noten – DAW-Kommunikation – Technik`

Die Seite zeigt das empfangene DAW-Material, verwendet den bestehenden MusicChat für den freien Kompositionsauftrag und macht die geplante Rückgabe sichtbar: **unverändert**, **bearbeitet** oder **neu**.

## Projektstruktur

- `scripts/` – ReaScript/Lua und gesicherte Bridge-Skripte
- `bridge/` – Austauschformat und leichte Kommunikation
- `docs/` – Architektur, Entscheidungen und Tests
- `tests/` – automatisierbare Prüfungen
- `DEVELOPMENT.md` – verbindliche Entwicklungsregeln

## Entwicklungsregel

Vor jeder Änderung muss `DEVELOPMENT.md` gelesen und berücksichtigt werden. Keine ungeprüften Zwischenstände, keine Klecker-Versionen und keine Kette nachträglicher Notfall-Patches.

## Status

**Stabiler Basis-Roundtrip vorhanden. Aktive Entwicklungsstufe: Composition Lab V4.0 – DAW-Kommunikation und explizite Rückgabesemantik.**
