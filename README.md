# Reaper Composition

Reaper Composition ist eine schlanke KI-Kompositionsschicht für REAPER. REAPER bleibt DAW, Projektzustand und musikalischer Arbeitsraum; die KI wird gezielt für rekursive Kompositionsschritte eingesetzt.

## Ziel

Nicht nur komplette MIDI-Kompositionen erzeugen, sondern vorhandene Musik schrittweise weiterentwickeln:

- einzelne Stimmen, MIDI-Items oder Taktbereiche bearbeiten
- neue Stimmen zu vorhandenem Material komponieren
- Varianten erzeugen und vergleichen
- mehrere Stimmen gezielt zusammenführen oder weiterentwickeln
- bereits gelungenes Material unverändert als Kontext verwenden
- Ergebnisse sicher nach REAPER zurückgeben, ohne das Original zu zerstören

Grundprinzip:

`REAPER-Auswahl -> musikalisches Paket -> KI/MusicChat -> MIDI-Ergebnis -> REAPER`

## Architekturprinzipien

1. **Keine eigene DAW.** Arrangement, Transport, MIDI, Instrumente, Plugins, Mixer und Projektverwaltung bleiben Aufgaben von REAPER.
2. **Keine normale Kompilationsschleife.** Die REAPER-Seite wird bevorzugt mit ReaScript/Lua umgesetzt.
3. **Ziel und Kontext werden getrennt.** Ausgewähltes Material kann bearbeitet werden; weiteres Material kann der KI nur als musikalischer Kontext dienen.
4. **Originale bleiben erhalten.** KI-Ergebnisse werden zunächst nicht destruktiv zurückgegeben.
5. **Freier musikalischer Auftrag.** Die Schnittstelle soll die KI nicht durch unnötig starre Kompositionsregeln einschränken.
6. **Rekursive Arbeit.** Ein KI-Ergebnis kann unmittelbar Ausgangspunkt des nächsten Kompositionsschritts werden.

## Geplanter erster funktionsfähiger Zyklus

1. MIDI-Material in REAPER auswählen.
2. Auswahl samt notwendigem Projektkontext exportieren.
3. Freien Kompositionsauftrag an MusicChat/KI übergeben.
4. MIDI-Ergebnis empfangen.
5. Ergebnis sicher als neue Variante in REAPER einsetzen.
6. Diesen Vorgang ohne erneute Installation wiederholen.

## Projektstruktur

- `scripts/` – ReaScript/Lua für REAPER
- `bridge/` – Austauschformat und leichte Kommunikation zur KI-Seite
- `docs/` – Architektur, Entscheidungen und Tests
- `tests/` – automatisierbare Prüfungen
- `DEVELOPMENT.md` – verbindliches Entwicklungsprotokoll

## Entwicklungsregel

Vor jeder Änderung muss `DEVELOPMENT.md` gelesen und berücksichtigt werden. Keine ungeprüften Zwischenstände und keine Kette angehängter Notfall-Patches. Änderungen werden in den bestehenden Stand integriert und nachvollziehbar versioniert.

## Status

**Phase 0 – Projektstruktur und Architektur.**

Noch keine Version zur Installation oder Abnahme. Zuerst wird die bestehende, früher bereits funktionierende REAPER-Verbindung rekonstruiert bzw. sauber neu als minimaler ReaScript-Kern aufgebaut.
