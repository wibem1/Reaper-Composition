# CompositionLab–REAPER Bridge 0.7

V0.7 erweitert den bestehenden V0.6-Transport ausschließlich um die Identität, die für eine sichere rekursive Rückgabe nötig ist. V0.6-Dokumente bleiben lesbar.

## REAPER → Composition Lab

Top-Level zusätzlich optional:

- `project_anchor_qn`: absolute REAPER-QN-Position des frühesten übertragenen Items.

Pro übertragenem Track/Item zusätzlich optional:

- `source_id`: stabile REAPER-MediaItem-GUID.
- `source_track_id`: stabile REAPER-Track-GUID.
- `source_offset`: QN-Abstand des Items zum frühesten übertragenen Item.

Alle ausgewählten Items bleiben gemeinsamer musikalischer Kontext. Die IDs erzeugen keine TARGET-/CONTEXT-Rollen.

## Composition Lab → REAPER

Ergebnisformat bei vorhandenen V0.7-Identitäten: `CompositionLab-Reaper-Result-0.7`.

Pro Ergebnis-Track:

- `return_action`: `unchanged`, `revised` oder `new`.
- `source_id`: bei `revised` die GUID des zugehörigen Ausgangsitems.
- `source_track_id`: zugehörige Ausgangsspur, soweit vorhanden.
- `source_offset`: ursprüngliche relative Position, soweit vorhanden.

Top-Level wird `project_anchor_qn` zurückgegeben.

## Semantik

- `unchanged`: REAPER verändert nichts und erzeugt keine Kopie.
- `revised`: REAPER sucht das Ausgangsitem über `source_id` und legt die neue Fassung **nicht destruktiv** auf derselben Spur und an derselben musikalischen Position als neues MIDI-Item an. Das Original bleibt bestehen.
- `new`: neues Material wird relativ zu `project_anchor_qn` angelegt; existiert keine passende Quellspur, wird eine neue Spur erzeugt.

Ein fehlendes `return_action` wird vom V0.7-Importer aus Rückwärtskompatibilität wie das bisherige V0.6-Verhalten als `new` behandelt.

## Sicherheitsregeln

1. Kein vorhandenes MIDI-Item wird still überschrieben oder gelöscht.
2. Eine unbekannte `source_id` darf nicht zum Überschreiben eines anderen Items führen.
3. `unchanged` erzeugt keine Dublette.
4. V0.6 bleibt als Fallback verwendbar.
5. MIDI-Noten und rohe Nicht-Noten-Ereignisse bleiben Bestandteil des Transports.
