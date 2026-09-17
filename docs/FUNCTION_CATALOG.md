# Composition Studio – Bedienungsanleitung und Aktionskatalog

Stand: 0.2-test13 / Entwurf der kontrollierten Steuerungsebene

## Grundidee

Composition Studio erweitert REAPER um eine natürlichsprachliche Ebene für Komposition, MIDI-Bearbeitung und Arrangement. REAPER bleibt die DAW. Composition Studio interpretiert den freien Auftrag, die KI übernimmt musikalische Entscheidungen und Lua führt kontrollierte REAPER-Operationen aus.

**Grundsatz:** Die Auswahl sagt Composition Studio, welche Musik bzw. welche Objekte gemeint sind. Der freie Auftrag sagt, was damit geschehen soll.

Es gibt keine Triggerwörter und keine vom Benutzer zu lernende Befehlssprache. Die technische Aktionssprache existiert ausschließlich intern zwischen KI und Lua.

## Transparenz und Sicherheit

Die KI darf nur Aktionen anfordern, die im Aktionskatalog ausdrücklich freigegeben sind. Lua prüft Ziel, Parameter und Ausführbarkeit, bevor REAPER verändert wird.

Wenn ein Auftrag nicht eindeutig ist, wird nicht geraten. Composition Studio soll dann:

- gezielt nachfragen, welches Item, welche Spur, welcher Bereich oder welche Bedeutung gemeint ist;
- offen sagen, wenn eine gewünschte Operation noch nicht unterstützt wird;
- bei riskanten oder mehrdeutigen Veränderungen vor der Ausführung klären, was verändert werden soll;
- nach Möglichkeit verständlich mitteilen, welche Aktion ausgeführt wurde.

Bestehendes musikalisches Material wird bei KI-Varianten grundsätzlich nicht ungefragt überschrieben. Änderungen werden als REAPER-Undo-Schritt ausgeführt.

## Daten- und Kostenprinzip

So viel REAPER-Information wie möglich bleibt lokal im Lua-Skript. An die KI wird nur der für die jeweilige Aufgabe notwendige Kontext geschickt.

Reine Organisationsoperationen benötigen normalerweise keine MIDI-Notendaten. Musikalische Notendaten werden erst übertragen, wenn eine Aufgabe tatsächlich musikalischen Kontext benötigt. Dadurch bleiben Datenmenge und API-Kosten klein.

## Aktionskatalog

### 1. MIDI – deterministische Bearbeitung

| Aktion | Freie Formulierung – Beispiel | Interne Aufgabe | Kontextbedarf | Status |
|---|---|---|---|---|
| Transponieren | „Das Cello eine Oktave höher.“ | ausgewähltes MIDI um Halbtöne transponieren | kein Notenkontext nötig | Nächster Ausbau |
| Noten zeitlich verschieben | „Setz diese Noten etwas später.“ | MIDI-Noten zeitlich versetzen | Positionsdaten | Nächster Ausbau |
| Noten kopieren | „Wiederhole diese Passage danach.“ | MIDI-Bereich kopieren | Positionsdaten | Nächster Ausbau |
| Noten löschen | „Nimm diese Passage heraus.“ | MIDI-Bereich löschen | Positionsdaten | Nächster Ausbau |
| Velocity ändern | „Mach das etwas leiser.“ | Velocity relativ/absolut ändern | MIDI-Metadaten | Nächster Ausbau |

### 2. Items und Arrangement

| Aktion | Beispiel | Interne Aufgabe | Kontextbedarf | Status |
|---|---|---|---|---|
| Item verschieben | „Schieb den Abschnitt vier Takte nach hinten.“ | Itemposition ändern | Item-ID + Position | Nächster Ausbau |
| Item kopieren | „Mach eine Kopie direkt dahinter.“ | Item duplizieren/positionieren | Item-ID + Position | Nächster Ausbau |
| Item teilen | „Teil das bei Takt 12.“ | Item an Position teilen | Item-ID + Position | Nächster Ausbau |
| Bereich ersetzen | „Ersetze Takt 9 bis 12 durch eine Überleitung.“ | Bereich bestimmen, musikalisch neu erzeugen, einsetzen | musikalischer Kontext nötig | Nächster Ausbau |
| Fortsetzen | „Verlängere das Stück sinngemäß um 12 Takte.“ | Endpunkt bestimmen, Fortsetzung komponieren und einsetzen | musikalischer Kontext nötig | Nächster Ausbau |
| Einleitung/Schluss | „Schreib einen kurzen Schluss.“ | passenden neuen Abschnitt erzeugen und einsetzen | musikalischer Kontext nötig | Nächster Ausbau |

### 3. Spuren

| Aktion | Beispiel | Interne Aufgabe | Kontextbedarf | Status |
|---|---|---|---|---|
| Spur finden/zuordnen | „Nimm die Klavierspur.“ | vorhandene Spur anhand Kontext/Name bestimmen | kompakte Spurstruktur | Nächster Ausbau |
| Spur erzeugen | „Erstelle eine Klarinettenspur.“ | neue REAPER-Spur erzeugen | keiner | Nächster Ausbau |
| Spur umbenennen | „Nenne die Spur Violoncello.“ | Spur benennen | Spur-ID | Nächster Ausbau |
| Spur löschen | „Entferne die leere Spur.“ | Spur nach Prüfung löschen | Spur-ID + Zustand | Nächster Ausbau |

### 4. Musikalische Komposition

| Aktion | Beispiel | Ausführung | Status |
|---|---|---|---|
| Neue Komposition | „Komponiere ein Stück für Cello und Klavier.“ | KI + Lua | Funktioniert |
| Stimme ergänzen | „Füge zu Klavier und Cello eine Klarinette hinzu.“ | KI + Lua | Funktioniert |
| Variation | „Erstelle eine Variation dieser Cellostimme.“ | KI + Lua | Funktioniert |
| Mehrere ausgewählte Items als Kontext | „Schreib dazu eine dritte Stimme.“ | KI + Lua | Funktioniert |
| Uminstrumentieren | „Mache aus der Cellostimme eine Violinstimme.“ | KI + Lua | Nächster Ausbau |
| Bereich verändern | „Variiere Takt 5 bis 8.“ | KI + Lua | Nächster Ausbau |
| Ersatzpassage | „Mach diese vier Takte interessanter.“ | KI + Lua | Nächster Ausbau |

### 5. Projektorganisation

| Aktion | Beispiel | Ausführung | Status |
|---|---|---|---|
| Tempo lesen | „Welches Tempo hat das Stück?“ | Lua/REAPER | Nächster Ausbau |
| Tempo ändern | „Setze das Tempo auf 76 BPM.“ | Lua/REAPER | Nächster Ausbau |
| Takt/Position bestimmen | „Wo beginnt dieses Item?“ | Lua/REAPER | Nächster Ausbau |
| Taktart lesen | „Welche Taktart haben wir hier?“ | Lua/REAPER | Nächster Ausbau |

## Interne Steuerungsebene

Die KI erhält eine kompakte Beschreibung der erlaubten Werkzeuge. Sie kann daraus eine strukturierte Aktion an Lua zurückgeben, zum Beispiel sinngemäß:

```text
ACTION|MIDI_TRANSPOSE|selected|semitones=12
ACTION|ITEM_MOVE|selected|bars=4
ACTION|TRACK_CREATE|name=Klarinette
```

Diese Syntax ist **keine Benutzersprache**. Sie ist nur die interne Schnittstelle zwischen KI und Lua.

Bei einer Aufgabe, für die musikalische Daten nötig sind, kann die erste Interpretation stattdessen zusätzlichen Kontext anfordern. Erst dann werden die benötigten MIDI-Daten übertragen. Die genaue interne Syntax wird bei der Implementierung festgelegt und versioniert.

## Umgang mit Mehrdeutigkeit

Composition Studio soll Bedeutung nicht aus einzelnen Schlüsselwörtern ableiten. Die KI interpretiert die vollständige natürliche Äußerung zusammen mit der aktuellen REAPER-Auswahl und dem Gesprächskontext.

Beispiele:

- „Das Cello könnte hier höher liegen.“ kann als Transpositionswunsch verstanden werden, sofern Ziel und Richtung eindeutig sind.
- „Mach das höher.“ ist ohne eindeutigen Gesprächs- oder Auswahlkontext möglicherweise unklar; dann wird nachgefragt.
- „Verschiebe das.“ wird nur ausgeführt, wenn eindeutig ist, welches Objekt und welche Zielposition gemeint sind.
- Eine nicht vorhandene Fähigkeit wird nicht durch eine ähnliche Aktion ersetzt. Composition Studio sagt, dass die gewünschte Operation derzeit nicht unterstützt wird.

## Aufgabenteilung

### REAPER / Lua

Deterministische und überprüfbare Operationen: Spuren, Items, Positionen, Taktbereiche, MIDI-Noten, Transposition, Benennung, Auswahl, Validierung und Undo.

### KI

Interpretation freier Sprache, musikalische Entscheidungen, Komponieren, Variieren, Fortsetzen, Uminstrumentieren, Analyse, Vorschläge und Auswahl einer freigegebenen Skriptaktion.

### Kombination

Bei gemischten Aufträgen zerlegt Composition Studio die Aufgabe intern. Beispiel: „Erstelle drei Spuren für Violine, Cello und Klavier und komponiere darauf ein 16-taktiges Stück.“ Lua erzeugt die REAPER-Struktur, die KI komponiert das musikalische Material, Lua schreibt das Ergebnis kontrolliert in REAPER.

## Aktueller Stand der Oberfläche

Composition Studio besitzt ein andockbares ReaImGui-Panel in REAPER mit Chat, freiem Eingabefeld und Anzeige des Auswahlkontexts. Das REAPER-Arrangement bleibt die grafische Darstellung der Spuren und MIDI-Items; Composition Studio baut keine zweite Arrangementansicht.

Der Gesprächskontext ist vorhanden, indirekte Bezüge wie „Mach das“ sollen jedoch erst dann als zuverlässig gelten, wenn Ziel und Aktion eindeutig aus dem Kontext hervorgehen. Im Zweifel wird nachgefragt.

## Grenzen

Composition Studio ersetzt keine DAW-Funktionen, die REAPER bereits bereitstellt. Es baut insbesondere keinen eigenen Transport, Mixer, Piano-Roll, Plugin-Browser oder Plugin-Host.

Die KI erhält derzeit keinen vollständigen permanenten Spiegel des REAPER-Projekts. Projekt- und MIDI-Kontext sollen gezielt und sparsam bereitgestellt werden. Audio, Plugin-Klang und Automation gehören zunächst nicht zum Kern der musikalischen Interpretation.

## Entwicklungsregel

Neue Steuerungsmöglichkeiten werden zuerst in diesem Aktionskatalog definiert. Erst danach werden sie in Lua implementiert und für die KI freigegeben. So bleibt transparent, was Composition Studio tatsächlich kann, was noch geplant ist und was nicht unterstützt wird.
