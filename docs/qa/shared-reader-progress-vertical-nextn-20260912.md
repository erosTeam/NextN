# NextN optional shared-reader vertical progress — 2026-09-12

## Outcome

LIMITED accepted on phone 197. The optional, explicitly write-enabled shared Reader preserves the same source
anchor while switching from horizontal single-page to vertical paging, writes the next source page after a physical
vertical turn, and restores that page after close/reopen. The shared Reader remains debug-only and does not replace
the production Reader or migrate settings.

## Device 197 acceptance

Target `192.168.50.197:12345`, ALN-AL80, portrait 1260x2720. Matching signed candidates were installed with
replace-only install:

- main HAP: 47,141,576 bytes,
  `557bc1b259105556584e2b276f195bf55f2856ada3fc637a467dc1239c42bb17`;
- ohosTest HAP: 43,802,170 bytes,
  `0a6a9374270c88982b68f7556ec50f483c85b1e472bafcabdaaed91d762c5691`.

The checked `ReaderProgressPersistenceVerticalTrial` then proved:

1. Exact eight-column history state was snapshot before the trial, source index 2 was seeded, and the first actual
   original emitted and persisted index 2 with `3 / 14`.
2. Selecting vertical paging retained the same `rkit-part-2-whole`, `3 / 14`, and did not publish a duplicate
   progress event for the unchanged source anchor.
3. One physical upward page turn displayed `rkit-part-3-whole` with `4 / 14`; event and durable index both became 3.
4. After close, a new explicit single-page session opened directly on `rkit-part-3-whole` with `4 / 14` and emitted
   its new-session initial event without rewriting another source.
5. The exact event sequence was `[2,3,3]`, durable index was 3, and same-anchor mode-switch deduplication held.
   Hypium reported 1 run, 1 pass, 0 failures, and 0 errors in 30.638 seconds.
6. The test restored the exact original history in `finally`; independent cleanup passed with
   `snapshotAbsent=true`. The device returned to the launcher in portrait with MUSIC volume 3 and timeout override
   10000 ms, and the lease was released.

Evidence:

- `.hermes-artifacts/20260912-shared-progress-vertical-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-native/run-metadata.json`
- `01-native/vertical-initial.png`
- `01-native/vertical-next.png`
- `01-native/vertical-reopen.png`
- `02-cleanup/run-metadata.json`
- `02-cleanup/screen.jpeg`

The source images are extreme long strips displayed in paged containment. These captures accept page identity,
gesture direction, deduplication, and durable progress only; they are not a readability or whole-reader visual
acceptance.

## Remaining boundary

Default replacement remains OPEN. This checkpoint does not cover vertical RTL custom tap regions, thumbnail entry
followed by vertical paging, failure/retry around the vertical turn, chapter-boundary progress, or equivalent
physical writeback paths in NextE and Koma.
