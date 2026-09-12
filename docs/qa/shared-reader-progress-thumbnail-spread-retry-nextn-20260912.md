# NextN optional shared-reader thumbnail/RTL-spread progress — 2026-09-12

## Outcome

LIMITED accepted on phone 197. A real Detail-page P3 thumbnail enters the optional shared Reader as the selected
anchor of an RTL P3/P4 spread. Failure and retry of adjacent P4 do not steal or advance progress; only the physical
turn to P5/P6 writes P5, which is restored after close/reopen. The shared Reader remains debug-only and does not
replace the production Reader or migrate settings.

## Device 197 acceptance

Target `192.168.50.197:12345`, ALN-AL80, portrait 1260x2720. Matching signed candidates were installed with
replace-only install:

- main HAP: 47,141,576 bytes,
  `557bc1b259105556584e2b276f195bf55f2856ada3fc637a467dc1239c42bb17`;
- ohosTest HAP: 43,821,870 bytes,
  `98e20d0b8d4dec384663ebfe8b3b5806fa31d248ee1296f93b2ae2901847c064`.

The checked `ReaderProgressPersistenceThumbnailSpreadRetryTrial` proved:

1. Exact eight-column history state was snapshot, durable P8 was seeded, and the real semantic Detail P3 thumbnail
   was clicked. The RTL spread placed ready `rkit-part-2-whole` on the visual right and failed
   `rkit-part-3-whole`/P4 on the left while chrome stayed `3 / 14`.
2. Selected P3 published and persisted index 2. The neighboring P4 failure card and Retry were visible, but the
   exact event list remained `[2]` and durable history stayed index 2.
3. Retrying P4 produced two decoded originals in the same RTL spread, retained `3 / 14`, emitted no extra event,
   and left durable history at index 2. Thus adjacent decode readiness is not a progress owner.
4. A physical rightward RTL turn displayed P5/P6 (`rkit-part-4-whole` and `rkit-part-5-whole`), changed chrome to
   `5 / 14`, and only then published and persisted index 4.
5. After close, an explicitly write-enabled single-page session restored visible P5 at `5 / 14`. The strict event
   sequence was `[2,4,4]`, covering clicked spread anchor, next spread, and new-session restore. Hypium reported
   1 run, 1 pass, 0 failures, and 0 errors in 44.075 seconds.
6. The test restored the exact original history in `finally`; independent cleanup passed with
   `snapshotAbsent=true`. The device returned to the launcher in portrait with MUSIC volume 3 and timeout override
   10000 ms, and the lease was released.

Evidence:

- `.hermes-artifacts/20260912-shared-progress-thumbnail-spread-retry-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-native/run-metadata.json`
- `01-native/neighbor-failure.png`
- `01-native/neighbor-retried.png`
- `01-native/next.png`
- `01-native/reopen.png`
- `02-cleanup/run-metadata.json`
- `02-cleanup/screen.jpeg`

The source pages are extreme long strips fitted into a two-pane spread. These captures accept selected-anchor
identity, RTL ordering, neighboring failure isolation, navigation and durable progress; they are not a readability
or animated-flight acceptance.

## Remaining boundary

Default replacement remains OPEN. This checkpoint does not cover the thumbnail flight frame sequence itself,
continuous-mode durable progress from a long-strip entry, chapter-boundary progress, or equivalent physical
writeback paths in NextE and Koma.
