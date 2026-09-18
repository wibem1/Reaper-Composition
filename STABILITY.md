# STABILITY CONTRACT

## Runtime-stable baseline
- Branch: `stable-runtime-v0.5.15`
- Commit: `ef5ea0d7755b5e1bca7dffac0ee198ceb13e05c3`
- Later Composition Studio versions may have passed CI, but they do not replace this runtime baseline until user-confirmed in REAPER.

## Binding rules
1. Read this file and DEVELOPMENT/architecture documentation before changes.
2. Runtime-confirmed code outranks documentation, CI success, and chat memory.
3. No patch chains or speculative rewrites.
4. One controlled functional change per step, tested before promotion.
5. Keep normal composition/export functionality intact when adding optional layers such as SWAM.
6. Existing MIDI notes are authoritative for existing works.
7. A new STABLE baseline requires explicit user runtime confirmation.
8. Failed development returns to the last stable branch.
