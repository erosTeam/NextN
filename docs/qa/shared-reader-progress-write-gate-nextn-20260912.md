# Shared reader progress write gate - NextN - 2026-09-12

## Outcome

LIMITED accepted. The optional NextN shared-reader observation path now crosses
a host-owned write lifecycle gate before reaching its in-process probe. The
gate invokes the writer immediately, tracks outstanding writes, rejects stale
sessions and post-seal writes, ignores an older failure after a newer position,
and permits retry of only the latest failed position.

The active writer is still the non-persistent test probe. This checkpoint does
not enable `HistoryRepository` writes, restore persisted progress, replace the
production reader, or change any reader setting.

## Compatibility contract

NextN's production `HistoryRepository.saveProgress` publishes the live position
before its awaited RDB mutation, and its repository serializes durable writes.
The gate therefore calls its injected writer immediately rather than deferring
all progress until exit. This preserves the live Detail-page behavior required
by `REJ-READER-006` while adding a future close/flush boundary.

The injected writer owns durable serialization. The gate owns only:

- work/session epoch validation;
- repeated-page suppression;
- pending operation tracking and flush;
- latest-position failure visibility and retry;
- rejection after seal.

## Host evidence

- `node scripts/test_reader_progress_write_gate_runtime.mjs`: pass for immediate
  invocation, duplicate/stale rejection, older-vs-latest failure ordering,
  latest retry, seal and flush.
- `node scripts/test_reader_observed_progress_runtime.mjs`: pass.
- `node scripts/test_reader_initial_policy_runtime.mjs`: pass.
- `node scripts/test_reader_tap_zone_handoff_runtime.mjs`: 1404 cases pass.
- signed main build: 10.411 s; 47,128,411 bytes; SHA-256
  `c037c6e4b267bea8c6a512fda651c6c673ca8e15aaf9c1e2eaacce9c33067303`.
- signed native-test build: 8.299 s; 43,722,653 bytes; SHA-256
  `9e51a2bd028a2bdb2787e59b322419dfd0756885d3120750e37c8ac969614580`.

## Device 197 evidence

Target `192.168.50.197:12345`; lease
`20260912-102713-1eea461c` was acquired, used by project-owned protocols, and
released after restoration.

- Matching main/native HAPs were installed with `-r`.
- `ReaderObservedProgressTrial`: 1 run, 1 pass, 0 failures, 0 errors.
- Actual visible-original sequence remained exactly `[2,3,2]` for P3 -> P4 ->
  P3 after inserting the write gate.
- The existing `reading_history` row remained unchanged before/after navigation
  and after exit; no durable writer was enabled.
- Host logs contain exactly page 2, page 3, page 2.
- Initial, next, return and exit screenshots were individually inspected. P3
  and P4 are distinct originals, the counter moves 3/14 -> 4/14 -> 3/14, and
  exit returns to ordinary NextN Browse.
- Final cleanup returned to the launcher and restored portrait, music volume 3,
  and `OverrideTimeout=10000ms`.

Artifacts:

- `.hermes-artifacts/20260912-shared-progress-write-gate-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-native/initial.png`
- `.hermes-artifacts/20260912-shared-progress-write-gate-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-native/next.png`
- `.hermes-artifacts/20260912-shared-progress-write-gate-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-native/return.png`
- `.hermes-artifacts/20260912-shared-progress-write-gate-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-native/exit.png`
- `.hermes-artifacts/20260912-shared-progress-write-gate-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/03-cleanup/screen.jpeg`

## Remaining boundary

Actual progress writeback and cold restoration remain OPEN. The next candidate
must use an explicit debug-only opt-in, snapshot and restore the exact existing
history row, prove live publication before exit, flush durable state at close,
and cold-open at the saved original page. It must not make the shared reader the
default.

The selected P3/P4 source pages are extreme long strips. In this forced
paged-single test they remain fully contained but visually narrow. This run is
not long-image readability or whole-reader visual acceptance.
