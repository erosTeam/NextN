# Shared Reader complete-download split-spread reload — NextN / 2026-09-14

Status: **LIMITED PASS / replacement OPEN**. The optional shared Reader now
has repeated production-route evidence that each page of a complete local
split spread can be reloaded independently even when its immutable `file://`
URI does not change. The default Reader remains legacy and no download file or
business record was replaced.

## Candidate and contract

- NextN source identity before the test-only checkpoint:
  `93cfec8f5c74b4c9d3118ad00775cf61e17d3675`; reader-kit identity:
  `5e5cb4c`.
- Signed main HAP SHA-256:
  `acc42bea99732a4e7bea3c9e21d15c12bf0f17f22e5749df6f2b6d404e8683b0`.
- Signed ohosTest HAP SHA-256:
  `884be493640c3bdf591a522cb144060e3684a383b6cf31af98c21eef51fcd977`.
- Source/build gates passed before device execution: `git diff --check`,
  `node scripts/test_reader_contract.mjs`,
  `node scripts/test_reader_data_source_runtime.mjs`, and signed
  `entry@ohosTest` assembly.
- The test uses the normal Downloads route and the newest existing complete
  task with at least four pages. It snapshots the exact queue, all eight
  history columns and the raw/live mode, double-page and spread settings. It
  temporarily selects RTL paged + double page + split spread through the
  production presentation service and restores every captured value in both
  success and failure cleanup paths. It also restores the process-local legacy
  backend.

## Device 103 evidence

- Checked protocol:
  `docs/device-protocols/shared-reader-production-download-spread-reload-103.json`.
- Evidence roots:
  `.hvigor/outputs/shared-reader-production-download-spread-reload-103/run01/`
  and `run02/`.
- Run 01: Hypium `1` test, `0` failures, `0` errors, `1` pass in
  `50.640s`.
- Run 02: Hypium `1` test, `0` failures, `0` errors, `1` pass in
  `49.416s`.
- Both runs used gallery `661990`, `47` local pages and visible source indices
  `38,39`. Semantic captures show one `rkit-native-pager`, two split parts at
  `[800,105][1600,2560]` and `[0,105][800,2560]`, two Reader page images and no
  Reader `LoadingProgress` or failure node.
- Reloading source `38` changed only its image request generation; reloading
  source `39` then changed only its generation. The same two source identities,
  page label `39 / 47`, bounds and decoded images remained present after each
  reload. All initial/first/second/return screenshots were inspected in both
  runs.
- Each run returned to `nextn-download-queue-root` with no
  `rkit-reading-surface`. Logs explicitly report
  `localReloads=2 queueUnchanged=true historyRestored=true settingsRestored=true`.
  The protocol restored the temporary display timeout and force-stopped the
  test process after evidence collection.

## Remaining boundary

This closes only independent same-URI reload for both visible pages of a
complete local split spread on device 103. Deleted/corrupt local files, cache
eviction, rotation/fold while reloading, NextE/Koma consumption and default
replacement remain OPEN under the main replacement ledger.
