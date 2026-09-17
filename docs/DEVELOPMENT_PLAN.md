# Composition Studio – Entwicklungsplan

**Ausgangsstand:** 0.3-test1  
**Zweck:** Verbindliche Reihenfolge der nächsten Entwicklungsschritte. Der Plan wird mit dem Projekt fortgeschrieben und soll verhindern, dass neue Funktionen ohne gesichertes Fundament oder ohne nachvollziehbare Architektur hinzugefügt werden.

## Leitprinzip

Die Entwicklung erfolgt nach **Abhängigkeiten**, nicht nach möglichst vielen Funktionen. Zuerst wird die Kommunikation zwischen KI, Lua und REAPER zuverlässig, kontrollierbar und nachvollziehbar. Danach wird der REAPER-Werkzeugkasten erweitert. Erst auf diesem Fundament entstehen komplexe mehrstufige Aktionspläne und die rekursive Kompositionsarbeit.

Die zentrale Architektur lautet:

**Benutzer → KI → kontrollierter Auftrag → Lua-Prüfung → REAPER → Ergebnisrückmeldung → KI → Benutzer**

Es gibt keine Triggerwörter und keine freie Code-Ausführung durch die KI.

## Künstlerisches Grundprinzip: Freiheit des Kompositionsprozesses

Composition Studio soll den Anwender nicht auf eine bestimmte Art des Komponierens festlegen. Die entscheidende Neuerung ist die Möglichkeit, einen Kompositionsprozess innerhalb einer realen DAW schnell, effektiv, rekursiv und bis ins Detail frei gestaltbar durchzuführen.

Die KI darf deshalb sowohl **Werkzeug im offenen Arbeitsprozess** als auch – wenn der Anwender es ausdrücklich möchte – **weitgehend selbständig komponierender Partner** sein. Es gibt keinen künstlichen Gegensatz zwischen diesen Arbeitsweisen.

Composition Studio soll beispielsweise ermöglichen:

- eine vollständige Komposition mit einem einzigen Auftrag erzeugen zu lassen,
- nur eine einzelne Stimme oder wenige Takte zu erzeugen,
- vorhandenes Material schrittweise weiterzuentwickeln,
- einzelne Ergebnisse zu übernehmen, zu verändern oder zu verwerfen,
- menschliche und KI-erzeugte Arbeit beliebig miteinander zu verbinden,
- zwischen sehr detaillierter Steuerung und weitgehender Delegation jederzeit zu wechseln.

Ob eine auf einen einzigen Auftrag hin erzeugte Komposition bereits als „fertig“ oder sogar „perfekt“ angesehen wird, entscheidet ausschließlich der Anwender. Composition Studio soll weder eine vollständige KI-Komposition verhindern noch den Anwender zu ihr drängen.

**Entwicklungsziel ist maximale gestalterische Wahlfreiheit:** Der Anwender bestimmt jederzeit, **was** delegiert wird, **wie viel** delegiert wird und **wie detailliert** er selbst in den Prozess eingreift.

Die Stärke von Composition Studio liegt damit nicht darin, einen bestimmten „richtigen“ kreativen Workflow vorzuschreiben, sondern sehr unterschiedliche Arbeitsweisen innerhalb desselben REAPER-Projekts schnell zugänglich zu machen.

---

## Phase 1 – Fundament 0.3-test1 praktisch absichern

**Ziel:** Die erste vollständige Kette von natürlicher Sprache bis zur kontrollierten REAPER-Veränderung muss zuverlässig funktionieren.

Zu testen:

1. MIDI-Item aus freier Sprache transponieren.
2. Item aus freier Sprache verschieben.
3. Item aus freier Sprache kopieren.
4. Spur aus freier Sprache umbenennen.
5. Mehrdeutige Formulierung: Composition Studio muss nachfragen und darf nichts verändern.
6. Nicht unterstützte Aktion: keine erfundene Ersatzaktion.
7. Musikalischer Auftrag: MIDI-Noten werden erst nach tatsächlichem Bedarf angefordert.
8. REAPER Undo für jede lokale Veränderung.

**Abschlusskriterium:** Die vier lokalen Aktionen, Rückfragen, Ablehnung unbekannter Aktionen und Undo sind praktisch geprüft. Fehler werden vor dem nächsten Ausbau behoben.

---

## Phase 2 – Transparenz und Aktionsprotokoll

**Ziel:** Keine interne Kommunikation darf ein nicht nachvollziehbares Eigenleben entwickeln.

Zu bauen:

- verständliche Anzeige des aktuellen REAPER-Kontexts,
- Aktivitätsstatus wie „Kontext wird geprüft“, „KI plant“, „Lua prüft“, „REAPER führt aus“, „abgeschlossen/Fehler“,
- aufklappbares Aktionsprotokoll,
- Protokollierung von Benutzerauftrag, Kontext, Datenanforderung, KI-Aktion/Plan, Lua-Prüfung, tatsächlicher REAPER-Aktion, Ergebnis und Undo-Status,
- technische Rohansicht für Diagnosezwecke,
- Ergebnisbestätigung: Eine Aktion gilt erst nach Rückmeldung von Lua/REAPER als ausgeführt.

**Abschlusskriterium:** Jeder verändernde Vorgang lässt sich im Nachhinein rekonstruieren.

---

## Phase 3 – Interne KI–Lua-Kommunikation zum mehrstufigen Dialog ausbauen

**Ziel:** Die KI kann nicht nur eine Einzelaktion anfordern, sondern gezielt fehlende Informationen abfragen und auf Antworten reagieren.

Benötigt werden strukturierte Möglichkeiten für:

- weitere Projektinformationen anfordern,
- MIDI nur bei Bedarf anfordern,
- Zeit-/Taktinformationen anfordern,
- Ziel oder Bereich klären,
- Ergebnisse einer Lua-/REAPER-Operation zurückmelden,
- Fehler an die KI zurückmelden,
- nächsten Schritt aus dem bestätigten Ergebnis ableiten.

**Abschlusskriterium:** Ein Auftrag kann mehrere kontrollierte Kommunikationsschritte durchlaufen, ohne dass die KI freien Lua- oder REAPER-Code ausführen kann.

---

## Phase 4 – REAPER-Werkzeugkasten systematisch erweitern

**Ziel:** Die KI erhält einen ausreichend großen, aber klar begrenzten Werkzeugkasten für die Arbeit im REAPER-Projekt.

### Lesen

- ausgewählte Items und Spuren,
- Projektspuren und eindeutige Zuordnung,
- Zeitselektion,
- Takt- und QN-Positionen,
- Tempo und Taktart,
- definierte MIDI-Bereiche,
- relevante Item-/Take-Eigenschaften.

### Verändern

- Spur erzeugen,
- Items erzeugen, teilen, verschieben und kopieren,
- Bereiche einfügen bzw. freimachen,
- MIDI gezielt einsetzen oder ersetzen,
- definierte MIDI-Bereiche bearbeiten,
- Tempo/Taktart später kontrolliert verändern.

Jedes neue Werkzeug wird zuerst im Aktionskatalog definiert, dann in Lua implementiert, validiert, dokumentiert und getestet. Erst danach wird es für die KI freigegeben.

**Abschlusskriterium:** Der Werkzeugkasten deckt die grundlegenden Arrangement- und MIDI-Operationen ab, die für komplexe Kompositionsaufträge benötigt werden.

---

## Phase 5 – Mehrstufiger Aktionsplaner

**Ziel:** Komplexe natürliche Aufträge werden in nachvollziehbare Folgen vorhandener Werkzeuge zerlegt.

Beispiel:

> „Füge zwischen Takt 8 und 9 vier Takte ein und entwickle beide Stimmen aus dem bisherigen Material weiter.“

Die KI soll daraus einen strukturierten Plan erstellen. Lua prüft jeden Schritt, Ziele und Parameter.

Zunächst wird ein **Nur-planen-Modus** eingeführt: Der Plan wird vollständig erzeugt und angezeigt, REAPER aber nicht verändert. Erst nach ausreichenden Tests wird die kontrollierte Ausführung freigegeben. Für größere Eingriffe kann eine vorherige Benutzerfreigabe als wählbares Bedienkonzept vorgesehen werden. Sie darf jedoch nicht zu einer Bevormundung werden: Der Anwender soll selbst bestimmen können, ob Composition Studio Schritt für Schritt bestätigt, einen Plan als Ganzes ausführt oder – soweit technisch sicher möglich – einen umfangreichen Auftrag selbständig bearbeitet.

**Abschlusskriterium:** Mehrstufige Pläne sind nachvollziehbar, validierbar und im Nur-planen-Modus zuverlässig.

---

## Phase 6 – REAPER-Aktionen und KI-Komposition verbinden

**Ziel:** Technische Arrangementoperationen und musikalische Generierung bilden einen gemeinsamen rekursiven Arbeitsprozess. Derselbe Mechanismus soll aber ebenso vollständige Kompositionsaufträge ermöglichen, wenn der Anwender dies wünscht.

Beispiele:

- vor bestehende Musik eine Einleitung komponieren und korrekt Platz schaffen,
- einen Mittelteil um mehrere Takte erweitern,
- nur eine ausgewählte Stimme weiterentwickeln,
- einen Schluss verlängern,
- einen definierten Bereich musikalisch variieren,
- vorhandene Stimmen unverändert lassen und neue Stimmen ergänzen,
- aus einem freien Auftrag eine vollständige neue Komposition erzeugen und unmittelbar als bearbeitbares REAPER-Projektmaterial bereitstellen.

Hier entsteht die eigentliche flexible Kompositionsumgebung: Composition Studio kann schrittweise am realen REAPER-Projekt arbeiten, aber ebenso weitreichende Kompositionsentscheidungen übernehmen, wenn der Anwender dies verlangt. Beide Arbeitsweisen bleiben gleichberechtigt.

**Abschlusskriterium:** Sowohl ein komplexer rekursiver musikalischer Auftrag als auch ein weitgehend delegierter vollständiger Kompositionsauftrag kann Lesen, Komponieren und kontrollierte REAPER-Aktionen zuverlässig verbinden.

---

## Phase 7 – Komfortoberfläche für den erweiterten Arbeitsprozess

**Ziel:** Die wachsende Funktionalität bleibt übersichtlich und beherrschbar, ohne eine bestimmte Arbeitsweise vorzuschreiben.

Geplant:

- verbesserte Kontextanzeige,
- Planansicht,
- Aktivitäts- und Fehlerstatus,
- Variantenverwaltung,
- A/B-Vergleich,
- Annehmen/Verwerfen,
- verständliche Undo-/Änderungshistorie,
- projektbezogener persistenter Chat,
- Provider-/Modellauswahl,
- Kosten-/Tokenanzeige,
- wählbare Abstufung zwischen detaillierter Kontrolle und weitgehender Delegation.

Die Oberfläche wird nicht losgelöst vorab gebaut, sondern folgt den tatsächlich bewährten Arbeitsabläufen der Phasen 1–6.

---

## Phase 8 – Größere musikalische Fähigkeiten

**Ziel:** Ausbau zur umfassenden KI-gestützten Kompositionsumgebung innerhalb von REAPER.

Mögliche spätere Bereiche:

- differenzierte Bereichsvariation,
- Einleitung, Übergang und Schluss,
- Fortsetzung und formale Erweiterung,
- Uminstrumentierung,
- Velocity und Artikulationsdaten,
- MIDI-CC, Pitch Bend und Program Change,
- weitergehende Projekt- und Automationsfunktionen,
- gegebenenfalls Audio-/Plugin-bezogene Funktionen, sofern sie sich sinnvoll und sicher in die Architektur einfügen lassen.

---

## Unmittelbare Reihenfolge ab 0.3-test1

**Jetzt:** Phase 1 – 0.3-test1 praktisch testen und Fehler beheben.  
**Danach:** Phase 2 – Transparenz und Aktionsprotokoll.  
**Anschließend:** Phase 3 – mehrstufige interne KI–Lua-Kommunikation.  
**Erst danach:** Phase 4 – Werkzeugkasten deutlich erweitern und darauf den Aktionsplaner aufbauen.

## Dokumentationsregel

Dieser Entwicklungsplan wird zusammen mit `CURRENT_STATUS.md`, dem Funktionskatalog und der Anwender-Funktionsübersicht gepflegt. Wenn sich Reihenfolge, Architektur oder Ziel einer Phase ändern, wird die Änderung hier nachvollziehbar eingearbeitet. Neue Funktionsversionen dürfen nicht dazu führen, dass Entwicklungsstand, offene Tests und nächste Schritte unklar werden.
