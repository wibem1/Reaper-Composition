# Composition Studio for REAPER

Composition Studio ist eine speziell für REAPER entwickelte KI-Kompositionsumgebung auf ReaScript/Lua-Basis.

## Grundidee

REAPER ist die vollständige DAW. Composition Studio ergänzt ausschließlich die fehlende KI-Kompositionsschicht. Es baut weder Transport, Arrangement, MIDI-Editor, Mixer, Plugin-Hosting noch Projektverwaltung nach.

Ziel ist rekursives Komponieren direkt im REAPER-Projekt:

- ausgewählte MIDI-Items unmittelbar als musikalischen Kontext verwenden
- einzelne Stimmen oder Passagen weiterentwickeln
- neue Stimmen zu vorhandenem Material komponieren
- Varianten nicht destruktiv erzeugen und vergleichen
- Ergebnisse direkt im REAPER-Projekt weiterverwenden
- den nächsten Kompositionsschritt unmittelbar auf dem bisherigen Ergebnis aufbauen

Grundprinzip:

`REAPER-Auswahl -> Composition Studio -> KI -> Ergebnis direkt in REAPER`

Es gibt keine Transport-Bridge zu Composition Lab und kein Hin- und Herschicken zwischen zwei Programmen.

## Abgrenzung zu Composition Lab

Composition Lab V3.2.9 bleibt eine eigenständige Anwendung. Die vorhandenen funktionierenden REAPER-Skripte für Composition Lab werden nicht verändert und bleiben als separate Lösung erhalten.

Composition Studio darf Ideen und geeignete Logik aus Composition Lab übernehmen, hat aber zur Laufzeit keine Abhängigkeit von der App.

## Entwicklung in zwei Schritten

### Schritt 1 – Composition Studio Basic

Bewusst einfaches Interface, vollständiger technischer Kern:

1. ausgewählte MIDI-Items direkt erkennen und lesen
2. musikalische MIDI-Daten kompakt für die KI darstellen
3. freien Kompositionsauftrag entgegennehmen
4. KI direkt ansprechen
5. Ergebnis sicher und nicht destruktiv in REAPER erzeugen
6. Mehrspurigkeit, neue Stimmen und REAPER-Undo unterstützen
7. rekursiven nächsten Arbeitsschritt ermöglichen

Basic ist kein Wegwerfprototyp. Sein Kern bleibt Grundlage der Komfortversion.

### Schritt 2 – Composition Studio Komfortversion

Nach erfolgreichem Basic-Kern folgen ein ansprechendes dockbares GUI, MusicChat, Provider-/Modellauswahl, Variantenverwaltung, komfortables Übernehmen/Verwerfen und weitere Funktionen aus der praktischen Arbeit.

## Musikalisches Prinzip

Die REAPER-Auswahl bestimmt, welche Musik die KI kennt. Der freie natürliche Kompositionsauftrag bestimmt, was damit geschehen soll. Keine technischen TARGET-/CONTEXT-Markierungen und keine unnötig starren musikalischen Regeln.

## Aktueller Stand

Branch `composition-studio`: Beginn von Composition Studio Basic V0.1. Die erste technische Stufe erkennt ausgewählte MIDI-Items direkt in REAPER. KI-Anbindung und Rückschreiben folgen erst, nachdem dieser Kern praktisch bestätigt wurde.
