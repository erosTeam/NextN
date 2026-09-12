# NextN optional shared-reader thumbnail progress — 2026-09-12

## Outcome

LIMITED accepted on phone 197. With explicit debug-only host progress permission, a real Detail thumbnail click wins over
an older stored progress value. A failed selected original does not publish or persist progress; the clicked page is
persisted only after explicit Retry displays that original. Ordinary Lab launches and the production Reader remain
unchanged.

## Acceptance contract

- The source is a real semantic Detail thumbnail, not a coordinate or direct page parameter.
- Index replaces the launch fallback with the clicked canonical zero-based source index after entry ownership succeeds.
- Thumbnail entry never restores over that clicked index from reading history.
- Loading and failure do not count as visible originals and therefore cannot write progress.
- A successful page-local Retry may write only after the selected original is displayed.
- The test snapshots all eight `reading_history` columns and restores the exact row or absence in `finally`; an
  independent cleanup phase must find no snapshot left after a successful run.

## Source and build checks

- Progress persistence, write-gate, observed-progress and initial-policy host tests: PASS.
- Signed `entry@ohosTest` build: 8 s 543 ms.
- Signed main HAP reused from the production-identical progress slice: 47,135,967 bytes,
  `0e1eb6bbb94ed748ebcf7b8dd27b194585763c104d82039abeb00979f3cb758e`.
- Signed native HAP: 43,776,887 bytes,
  `42f8f88c877cf21b48944488c72b37c772895b88cf0b80ff31508861729c9b73`.

## Device 197 evidence

Target `192.168.50.197:12345`, ALN-AL80, portrait 1260x2720.

1. The test recorded the exact original history state and seeded stored source index 7 (`P8`).
2. The selected Detail node was `reader-thumb-gallery-detail-1-page-2`, bounds `[764,1960][1081,2448]`.
3. The injected selected-original failure exposed `rkit-failure-page-3`, enabled `rkit-retry-page-3`, and visible
   `3 / 14`. After a one-second stability window, observed events remained empty and the durable index remained 7.
4. Retry replaced the failure with `rkit-part-2-whole`; visible chrome remained `3 / 14`. The only observed event was
   source index 2 and durable history then became 2, including after Reader close.
5. The test restored the exact original history state in `finally`. The independent cleanup test passed 1/1 and
   reported `cleanup snapshotAbsent=true`, proving there was no interrupted snapshot or temporary row left to repair.
6. The final whole capture is the system launcher. MUSIC is 3 and screen timeout override is 10000 ms. The lease was
   released.

Hypium result: 1 test, 1 pass, 0 failures, 0 errors in 28.882 seconds. Cleanup: 1 pass, 0 failures/errors.

Evidence root:

- Main run: `.hermes-artifacts/20260912-shared-thumbnail-progress-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/03-explicit-capability/`
- Exact cleanup/final state: `.hermes-artifacts/20260912-shared-thumbnail-progress-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/04-explicit-capability-cleanup/`

Key whole captures:

- `thumbnail-source.png`: actual Detail source and old `继续 P8` state.
- `thumbnail-failure.png`: P3 failure card before any progress write.
- `thumbnail-retried.png`: displayed P3 original after Retry and the only accepted progress event.
- `04-explicit-capability-cleanup/screen.jpeg`: restored launcher endpoint.

## Remaining boundary

This test intentionally forces single/LTR to make source identity unambiguous. The narrow full-height long-strip image
is not readability acceptance and does not replace the separately accepted continuous fit-width path. Remaining work
includes production opt-in entry plumbing, spread/RTL/vertical/continuous write semantics, cold thumbnail-entry
combinations, equivalent NextE/Koma progress adapters, and eventual default-reader replacement only after those paths
close without regression.
