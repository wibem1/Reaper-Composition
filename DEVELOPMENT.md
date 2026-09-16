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

Originalmaterial wird standardmäßig geschützt. KI-Ergebnisse werden nicht destruktiv erzeugt und müssen mit REAPER Undo rückgängig zu machen sein.

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

## Basic-Kern – Stand 2026-09-16

Der vollständige Codepfad ist jetzt implementiert:

`REAPER-Auswahl -> MIDI lesen -> freier Auftrag -> OpenAI -> Antwort validieren -> nicht destruktiv anwenden -> neue Ergebnisse auswählen`

Technische Sicherheitsregeln:

- API-Schlüssel wird nicht im Repository gespeichert; Basic erwartet `OPENAI_API_KEY` in der lokalen Umgebung.
- KI-Antworten werden vor jeder Projektänderung validiert.
- `revised` darf nur auf eine tatsächlich ausgewählte Quell-GUID zeigen.
- `new` erzeugt eine neue REAPER-Spur.
- `revised` erzeugt ein zusätzliches MIDI-Item auf der vorhandenen Spur; das Original bleibt bestehen.
- Notenwerte werden auf gültige MIDI-/Zeitbereiche geprüft.
- Der komplette Apply-Schritt ist ein REAPER-Undo-Schritt.
- Bei einem Fehler während des Apply-Schritts wird dieser Undo-Schritt unmittelbar zurückgenommen.
- Nach erfolgreichem Apply werden die neu erzeugten Items ausgewählt, damit der nächste rekursive Kompositionsschritt direkt möglich ist.

Noch nicht als praktisch bewiesen gilt dieser Stand: REAPER-spezifisches Verhalten und der reale API-Aufruf müssen auf dem Ziel-Mac getestet werden. Insbesondere darf ein funktionierender Codepfad nicht mit einem bestandenen Praxistest verwechselt werden.

## Nächster Testpunkt

Jetzt ist erstmals ein manueller REAPER-Test sinnvoll. Zu prüfen sind:

1. Script wird als neue eigenständige Action geladen.
2. Ein oder mehrere ausgewählte MIDI-Items werden erkannt.
3. Der freie Auftrag wird angenommen.
4. API-Aufruf funktioniert mit lokal verfügbarem `OPENAI_API_KEY`.
5. Eine gültige Antwort erzeugt zusätzliche MIDI-Items/Spuren, ohne Originale zu verändern.
6. Neue Items sind anschließend ausgewählt.
7. Ein einziges REAPER-Undo entfernt den gesamten erzeugten Schritt.

Erst nach diesem Praxistest wird Basic als technisch bewiesen bezeichnet.

## Definition of Done für Basic

Basic gilt erst als technisch bewiesen, wenn der vollständige Kreislauf praktisch funktioniert:

`REAPER-Auswahl -> KI-Auftrag -> KI-Komposition -> nicht destruktives Ergebnis in REAPER -> nächster rekursiver Schritt`

Automatisierbare Fehler werden vor Übergabe behoben. REAPER-spezifische Interaktion wird als klar begrenzter manueller Test ausgewiesen.
