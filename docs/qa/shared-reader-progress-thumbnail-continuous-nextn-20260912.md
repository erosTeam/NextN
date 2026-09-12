# NextN optional shared-reader thumbnail/continuous progress — 2026-09-12

## Outcome

LIMITED accepted on phone 197. A real Detail-page P3 thumbnail enters the optional shared Reader in continuous
long-strip mode at full viewport width, actual scrolling advances durable progress only when P4 becomes the current
original, and close/reopen restores P4. The shared Reader remains debug-only and does not replace the production
Reader or migrate settings.

## Device 197 acceptance

Target `192.168.50.197:12345`, ALN-AL80, portrait 1260x2720. Matching signed candidates were installed with
replace-only install:

- main HAP: 47,141,576 bytes,
  `557bc1b259105556584e2b276f195bf55f2856ada3fc637a467dc1239c42bb17`;
- ohosTest HAP: 43,836,440 bytes,
  `e5da5b3601ec4dd9a1cff43bce82daab8dda0b1b60f998e5f2f0497e3d47491f`.

The checked `ReaderProgressPersistenceThumbnailContinuousTrial` proved:

1. Exact eight-column history state was snapshot, durable P8 was seeded, and the real semantic Detail P3 thumbnail
   was clicked. `rkit-continuous-page-2` displayed at full viewport width, chrome showed `3 / 14`, and P3 replaced
   stale durable progress.
2. Repeated physical upward scrolls traversed the long P3 source. Progress did not advance merely because P4 was
   preloaded; it advanced when `rkit-continuous-page-3` became the current visible original, with chrome `4 / 14`
   and durable index 3.
3. After close, a new explicitly write-enabled continuous session reopened directly on visible P4 at `4 / 14`.
   The strict event sequence was `[2,3,3]`, covering thumbnail entry, physical continuous advance, and new-session
   restore. Hypium reported 1 run, 1 pass, 0 failures, and 0 errors in 83.476 seconds.
4. The initial, advanced and reopened whole-screen captures were inspected; all three contain full-width long-strip
   artwork rather than the old width-constrained pager crop or a black compositor frame.
5. The test restored the exact original history in `finally`; independent cleanup passed with
   `snapshotAbsent=true`. The device returned to the launcher in portrait with MUSIC volume 3 and timeout override
   10000 ms, and the lease was released.

Evidence:

- `.hermes-artifacts/20260912-shared-progress-thumbnail-continuous-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-native/run-metadata.json`
- `01-native/initial.png`
- `01-native/next.png`
- `01-native/reopen.png`
- `02-cleanup/run-metadata.json`
- `02-cleanup/screen.jpeg`

## Remaining boundary

Default replacement remains OPEN. This checkpoint does not cover failure/retry while crossing a continuous page
boundary, thumbnail flight motion, chapter-boundary progress, or equivalent physical writeback paths in NextE and
Koma.
