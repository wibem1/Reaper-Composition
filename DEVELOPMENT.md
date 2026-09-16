# DEVELOPMENT – Composition Studio for REAPER

Dieses Dokument ist vor jeder Entwicklungsarbeit zu lesen. Es ist Teil der technischen Spezifikation.

## Verbindliche Architekturentscheidung – 2026-09-16

Composition Lab V3.2.9 bleibt eigenständig. Seine beiden funktionierenden REAPER-Bridge-Skripte bleiben unverändert. **Composition Studio** läuft direkt in REAPER als ReaScript/Lua:

`REAPER + Composition Studio.lua + KI-APIs`

Composition Lab ist keine Laufzeitabhängigkeit.

## Entwicklungsregeln

- Stabilität vor Funktionsmenge; keine Klecker-Versionen oder Patch-Ketten.
- ReaScript/Lua hat Vorrang; keine kompilierte Extension, solange ReaScript genügt.
- Keine DAW-Funktionen neu bauen, die REAPER bereits bereitstellt.
- Bestehende Composition-Lab-Skripte nicht verändern.
- `Composition Studio.lua` ist eine neue eigenständige REAPER-Action.
- Dokumentation vor Änderungen lesen und bei Architekturänderungen aktualisieren.
- Freie natürliche Kompositionsaufträge haben Vorrang vor starren musikalischen Promptregeln.

## Musikalisches Leitbild

REAPER ist Projektzustand, Arrangement und musikalischer Arbeitsraum. Die Auswahl bestimmt, welche Musik die KI kennt; der freie Auftrag bestimmt, was unverändert bleibt, bearbeitet oder ergänzt wird. Keine TARGET-/CONTEXT-Markierungen. Originalmaterial wird standardmäßig geschützt.

## Zweistufige Entwicklung

### Schritt 1 – Composition Studio Basic

Vollständiger technischer Kern mit einfachem Interface: Auswahl lesen, MIDI erfassen, freien Auftrag an KI senden, Ergebnis validieren, vorhandene Stimmen nicht destruktiv variieren, neue Stimmen/Tracks erzeugen, Mehrspurigkeit, Undo und direkte rekursive Weiterarbeit.

### Schritt 2 – Komfortversion

Erst nach bewiesenem Basic-Kern: dockbares GUI, MusicChat, Provider-/Modellauswahl, Variantenverwaltung, A/B-Arbeit und weitere Komfortfunktionen.

## Basic-Kern – Stand 2026-09-16

Implementierter Codepfad:

`REAPER-Auswahl -> MIDI lesen -> freier Auftrag -> OpenAI -> Antwort validieren -> nicht destruktiv anwenden -> neue Ergebnisse auswählen`

Sicherheitsregeln:

- API-Schlüssel steht niemals im Repository oder Projekt.
- Beim ersten Start fragt Basic den OpenAI-Key einmal ab und speichert ihn lokal über REAPER `ExtState` (`CompositionStudio/OpenAIAPIKey`, persistent).
- Damit ist keine Umgebungsvariable mehr nötig.
- Hinweis: ExtState ist Komfortspeicherung, keine macOS-Keychain-Verschlüsselung. Für die spätere Komfortversion kann eine sicherere Schlüsselverwaltung ergänzt werden.
- KI-Antworten werden vor jeder Projektänderung validiert.
- `revised` darf nur auf eine tatsächlich ausgewählte Quell-GUID zeigen und erzeugt ein zusätzliches MIDI-Item auf der vorhandenen Spur.
- `new` erzeugt eine neue REAPER-Spur.
- Originale bleiben erhalten.
- Notenwerte werden validiert.
- Der Apply-Schritt ist ein REAPER-Undo-Schritt; Fehler beim Apply werden unmittelbar zurückgenommen.
- Neue Ergebnisse werden anschließend ausgewählt und können direkt der nächste rekursive Ausgangspunkt sein.

Noch nicht praktisch bewiesen: REAPER-spezifisches Verhalten und realer API-Aufruf auf dem Ziel-Mac.

## Erster manueller Test

1. `Composition Studio.lua` als neue Action in REAPER laden.
2. Ein MIDI-Item auswählen und Script starten.
3. Einen einfachen freien Auftrag eingeben.
4. Beim ersten Lauf OpenAI API-Key einmal eingeben; danach soll keine erneute Eingabe nötig sein.
5. Prüfen, ob neue/bearbeitete MIDI-Items entstehen und Originale erhalten bleiben.
6. Prüfen, ob die neuen Items ausgewählt sind.
7. Ein REAPER-Undo muss den gesamten erzeugten Schritt entfernen.

## Definition of Done für Basic

Basic gilt erst nach praktischem Nachweis des vollständigen Kreislaufs als technisch bewiesen:

`REAPER-Auswahl -> KI-Auftrag -> KI-Komposition -> nicht destruktives Ergebnis in REAPER -> nächster rekursiver Schritt`
