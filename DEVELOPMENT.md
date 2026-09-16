# DEVELOPMENT – Composition Studio for REAPER

Dieses Dokument ist vor jeder Entwicklungsarbeit zu lesen. Es ist Teil der technischen Spezifikation.

## Verbindliche Architekturentscheidung – 2026-09-16

Der geplante Ausbau von Composition Lab V4.0 um eine Seite „DAW-Kommunikation“ wird nicht weiterverfolgt.

Composition Lab V3.2.9 bleibt eigenständig. Die beiden bereits funktionierenden REAPER-Bridge-Skripte für Composition Lab bleiben unverändert und werden durch Composition Studio nicht ersetzt.

Das neue Projekt heißt **Composition Studio** und läuft direkt innerhalb von REAPER als ReaScript/Lua. Laufzeitarchitektur:

`REAPER + Composition Studio.lua + KI-APIs`

Composition Lab ist keine Laufzeitabhängigkeit. Bewährte Konzepte und geeignete Logik dürfen als Entwicklungsquelle übernommen werden.

## Entwicklungsregeln

- Stabilität vor Funktionsmenge.
- Keine Klecker-Versionen.
- Keine Patch-Ketten; Änderungen sauber in die vorhandene Struktur integrieren.
- ReaScript/Lua hat Vorrang. Keine kompilierte Extension, solange eine benötigte Funktion mit REAPER/ReaScript sinnvoll erreichbar ist.
- Kein Neubau von DAW-Funktionen, die REAPER bereits bereitstellt.
- Bestehende Composition-Lab-Skripte nicht verändern.
- `Composition Studio.lua` ist eine neue, eigenständige REAPER-Action.
- Normaler Entwicklungszyklus: Lua-Code ändern, in REAPER neu ausführen, testen. Kein App-Build und keine Installationsserie.
- Dokumentation vor Änderungen lesen und bei Architekturänderungen aktualisieren.
- Freie natürliche Kompositionsaufträge haben Vorrang vor starren musikalischen Promptregeln.

## Musikalisches Leitbild

REAPER ist Projektzustand, Arrangement und musikalischer Arbeitsraum. Composition Studio ermöglicht rekursives Komponieren auf ausgewähltem Material.

Die Auswahl bestimmt, welche Musik die KI kennt. Der freie Auftrag bestimmt, was unverändert bleibt, bearbeitet oder neu ergänzt wird. Keine TARGET-/CONTEXT-Markierungen.

Originalmaterial wird standardmäßig geschützt. KI-Ergebnisse werden zunächst nicht destruktiv erzeugt und müssen mit REAPER Undo rückgängig zu machen sein.

## Zweistufige Entwicklung

### Schritt 1 – Composition Studio Basic

Einfaches Interface, aber vollständiger technischer Kern:

1. ausgewählte MIDI-Items direkt erkennen
2. MIDI-Inhalt, Spuren und relative musikalische Lage lesen
3. freien Kompositionsauftrag erfassen
4. KI-API direkt aus der REAPER-Lösung ansprechen
5. Ergebnis validieren
6. vorhandene Stimmen nicht destruktiv variieren
7. neue Stimmen als neue Items/Tracks erzeugen
8. Mehrspurigkeit und REAPER Undo
9. Ergebnis unmittelbar für den nächsten rekursiven Schritt verwenden

Basic ist kein Wegwerfprototyp.

### Schritt 2 – Komfortversion

Erst nach bewiesenem Basic-Kern: ansprechendes dockbares GUI, MusicChat, Provider-/Modellauswahl, Variantenverwaltung, A/B-Arbeit und weitere Komfortfunktionen.

## V0.1 – erster praktischer Test

Die erste Stufe enthält bewusst noch keine KI. `Composition Studio.lua` ermittelt direkt alle ausgewählten MIDI-Items und zeigt Trackname, Start, Länge und Notenzahl an.

Ziel des ersten manuellen Tests: beweisen, dass das neue eigenständige Script in REAPER läuft und die Auswahl zuverlässig erkennt. Erst danach wird derselbe Kern um musikalische Datenerfassung und KI erweitert.

## Definition of Done für Basic

Basic gilt erst als technisch bewiesen, wenn der vollständige Kreislauf funktioniert:

`REAPER-Auswahl -> KI-Auftrag -> KI-Komposition -> nicht destruktives Ergebnis in REAPER -> nächster rekursiver Schritt`

Automatisierbare Fehler werden vor Übergabe behoben. REAPER-spezifische Interaktion wird als klar begrenzter manueller Test ausgewiesen.
