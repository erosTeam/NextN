# NextN optional shared-reader cross-mode progress — 2026-09-12

## Outcome

LIMITED accepted on phone 197. The optional, explicitly write-enabled shared Reader now publishes and persists
canonical zero-based NH source pages across RTL spread navigation and a close/reopen handoff into continuous
long-image mode. This does not enable the shared Reader by default, migrate settings, or replace the production
Reader.

## Shared correction

The native pager owns selection for the whole spread, while its two original-image leaves decode independently.
`ReaderPagedViewport` now publishes the selected snapshot's anchor original after the displayed snapshot has been
adopted. Publication is deferred one UI turn and fenced by selection and navigation revisions, preventing the
recursive state refresh observed with a synchronous callback. The existing session still enforces request, crop,
selection, and duplicate-event fences.

The focused reader-kit observation and paged-session tests pass 38/38. The matching signed NextN candidates are:

- main HAP: 47,141,576 bytes,
  `557bc1b259105556584e2b276f195bf55f2856ada3fc637a467dc1239c42bb17`;
- ohosTest HAP: 43,795,963 bytes,
  `697084ef162d7f743916617bc24b2368508f333253d308cd1fc7c1b9e550e244`.

## Device 197 acceptance

Target `192.168.50.197:12345`, ALN-AL80, portrait 1260x2720. The checked protocol installed both matching HAPs
with replace-only install and ran `ReaderProgressPersistenceCrossModeTrial` against actual gallery 678049.

1. The test snapshot the exact original eight-column history row or absence, seeded source index 2, and launched
   explicit RTL spread mode.
2. The first spread displayed source indices 2 and 3 with `3 / 14`; the anchor event and durable index were 2.
3. One physical RTL turn displayed source indices 4 and 5 with `5 / 14`; the anchor event and durable index were 4.
4. After closing, continuous mode reopened on source index 4 with `5 / 14`, emitted index 4, and retained durable
   index 4.
5. Physical continuous scrolling reached source index 5 with `6 / 14`; event and durable index both became 5.
6. The exact event sequence was `[2,4,4,5]`. Hypium reported 1 run, 1 pass, 0 failures, and 0 errors in 91.565
   seconds.
7. The test restored the exact original history state in `finally`. The independent cleanup test passed and found
   no residual snapshot. The device returned to the launcher in portrait with MUSIC volume 3 and timeout override
   10000 ms; its lease was released.

Accepted evidence:

- metadata and logs:
  `.hermes-artifacts/20260912-shared-progress-cross-mode-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/07-cross-mode-contract/run-metadata.json`;
- RTL spread P3/P4 and P5/P6:
  `07-cross-mode-contract/cross-spread-initial.png`, `07-cross-mode-contract/cross-spread-next.png`;
- continuous restore P5 and scroll to P6:
  `07-cross-mode-contract/cross-continuous-initial.png`, `07-cross-mode-contract/cross-continuous-next.png`;
- independent cleanup and final launcher:
  `08-cross-mode-contract-cleanup/run-metadata.json`, `08-cross-mode-contract-cleanup/screen.jpeg`.

## Rejected intermediate evidence

- `01-native` was correctly rejected because both RTL spread originals were visibly displayed but the selected
  spread emitted no progress event. This established the shared product defect.
- `03-selected-viewport` was correctly rejected after a synchronous selected-viewport callback reached P5 but
  caused a recursive refresh and transient loss of the pager semantic subtree.
- `05-deferred-selected-viewport` proved the deferred callback fixed the spread sequence `2 -> 4`; its later error
  was test-only because the continuous page was correctly visible at `5 / 14` while the test still searched for a
  paged `rkit-part-*` owner. The final test uses the continuous row owner without weakening image-ready, event, or
  durable-history assertions.

None of those runs is counted as acceptance. Each retained its diagnostics and was followed by independent exact
history cleanup before the next candidate.

## Remaining boundary

Default replacement remains OPEN. This checkpoint does not cover vertical paged write semantics, spread
thumbnail-entry precedence, failure/retry after a mode handoff, chapter-boundary progress, or equivalent physical
writeback paths in NextE and Koma.
