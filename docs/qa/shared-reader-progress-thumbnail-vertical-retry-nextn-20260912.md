# NextN optional shared-reader thumbnail/vertical/retry progress — 2026-09-12

## Outcome

LIMITED accepted on phone 197. A real Detail-page thumbnail can enter the optional shared Reader at its selected
source page, switch to vertical paging without duplicating progress, withhold durable progress while the next
original is failed, write only after Retry displays that original, and restore the retried page after close/reopen.
The shared Reader remains debug-only and does not replace the production Reader or migrate settings.

## Device 197 acceptance

Target `192.168.50.197:12345`, ALN-AL80, portrait 1260x2720. Matching signed candidates were installed with
replace-only install:

- main HAP: 47,141,576 bytes,
  `557bc1b259105556584e2b276f195bf55f2856ada3fc637a467dc1239c42bb17`;
- ohosTest HAP: 43,816,492 bytes,
  `904547d43eebeee4e431d7b0a4446db53ca305586a7cfc76ddd673398848baa7`.

The checked `ReaderProgressPersistenceThumbnailVerticalRetryTrial` proved:

1. Exact eight-column history state was snapshot, durable P8 was seeded, and the real semantic Detail thumbnail for
   P3 was clicked. The Reader displayed `rkit-part-2-whole`, published index 2, persisted index 2, and showed
   `3 / 14`, so the explicit thumbnail anchor overrode stale durable progress.
2. Switching to vertical paging retained the P3 source anchor without an extra progress callback. A physical upward
   page turn selected P4 but its injected original failure showed `rkit-failure-page-4` and `rkit-retry-page-4`.
   During failure the event list remained `[2]` and durable history remained index 2.
3. Retry displayed `rkit-part-3-whole`, then and only then published and persisted index 3 with `4 / 14`.
4. After close, a new explicitly write-enabled session restored `rkit-part-3-whole` at `4 / 14`. A render-stability
   gate was added after the first run exposed that semantic image readiness could precede the captured compositor
   frame; the accepted rerun visually contains the restored original instead of a black frame.
5. The strict final event sequence was `[2,3,3]`, covering thumbnail entry, successful retry, and new-session
   restore. Hypium reported 1 run, 1 pass, 0 failures, and 0 errors in 49.922 seconds.
6. The test restored the exact original history in `finally`; independent cleanup passed with
   `snapshotAbsent=true`. The device returned to the launcher in portrait with timeout override 10000 ms, and the
   lease was released.

Accepted evidence:

- `.hermes-artifacts/20260912-shared-progress-thumbnail-vertical-retry-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/03-native-render-stable/run-metadata.json`
- `03-native-render-stable/selected.png`
- `03-native-render-stable/failure.png`
- `03-native-render-stable/retried.png`
- `03-native-render-stable/reopen.png`
- `04-cleanup/run-metadata.json`
- `04-cleanup/screen.jpeg`

The rejected first capture remains under `01-native`: its semantic assertions passed, but the reopen screenshot was
still black, so it was not accepted as visual evidence.

## Remaining boundary

Default replacement remains OPEN. This checkpoint does not cover thumbnail entry into RTL spreads, automatic
continuous mode after a long-strip thumbnail entry, chapter-boundary progress, or equivalent physical writeback
paths in NextE and Koma.
