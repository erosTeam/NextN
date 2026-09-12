# Shared reader observed progress - NextN - 2026-09-12

## Outcome

LIMITED accepted. The optional NextN shared reader now exposes its ready,
native-visible original page as a zero-based NextN page index. This slice is
read-only: it does not call the history repository and does not change the
existing reader or its persisted progress.

Replacement remains OPEN. Progress writeback, cold restoration, continuous and
spread semantics, RTL combinations, failure/cancellation behavior, and a default
reader switch are outside this checkpoint.

## Source contract

- `ReaderSurface.onObserved` is mapped only when the anchor belongs to the
  current numeric NH gallery and current unit.
- The page key and source index must be valid for the current page count.
- Repeated fragments or repeated observations of the same original page are
  deduplicated; changing work resets the dedupe boundary.
- The Lab bridge publishes only to an in-process test probe. It contains no
  `HistoryRepository` or `saveProgress` call.

Host checks passed:

- `node scripts/test_reader_observed_progress_runtime.mjs`
- `node scripts/test_reader_initial_policy_runtime.mjs`
- `node scripts/test_reader_tap_zone_handoff_runtime.mjs` (1404 cases)
- signed main HAP: 47,111,309 bytes,
  SHA-256 `88eaad05c2860f49612c69256f242fecbfa34e7e8e2a0a9bfb4d8306161b4e8f`
- signed native-test HAP: 43,709,612 bytes,
  SHA-256 `5fb1379a241b773100b82fbb2ab38cef6e663319c05559d99ae0c2fd04751dd0`

## Device 197 evidence

Target: `192.168.50.197:12345`.

The project-owned protocol installed the matching main/native candidates with
data retention, then ran `ReaderObservedProgressTrial` against actual gallery
`678049` in explicit single-page LTR shared-reader mode.

- Hypium: 1 run, 1 pass, 0 failures, 0 errors.
- Observed original-page sequence: `[2,3,2]` for P3 -> P4 -> P3.
- The pre-existing `reading_history` row was byte-equivalent before navigation,
  after the round trip, and after closing the optional reader.
- No additional event arrived after close.
- Layouts matched the visible originals and counters:
  `rkit-part-2-whole` / `3 / 14`, then `rkit-part-3-whole` / `4 / 14`, then
  `rkit-part-2-whole` / `3 / 14`.
- Exit returned to `nextn-root-navigation`; final cleanup returned to launcher.
- Portrait, music volume 3, and the original 10000 ms screen timeout were
  restored; the device lease was released.

Artifacts:

- `.hermes-artifacts/20260912-shared-observed-progress-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-native/initial.png`
- `.hermes-artifacts/20260912-shared-observed-progress-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-native/next.png`
- `.hermes-artifacts/20260912-shared-observed-progress-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-native/return.png`
- `.hermes-artifacts/20260912-shared-observed-progress-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-native/exit.png`
- `.hermes-artifacts/20260912-shared-observed-progress-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/03-cleanup/screen.jpeg`

The P3/P4 source images are extreme long strips and appear as narrow contained
images in the explicit paged-single test layout. This run accepts event identity
and history invariance only; it is not long-image readability or whole-reader
visual acceptance.
