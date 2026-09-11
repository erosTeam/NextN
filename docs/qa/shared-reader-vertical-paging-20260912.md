# Shared reader vertical paging checkpoint — 2026-09-12

Status: named paths accepted; overall replacement OPEN. Default readers, saved settings and progress writeback remain unchanged. Devices 197 and 103 only; no 237 operations.

## Evidence and acceptance

- Shared candidate: paging axis defaults horizontal; copied policy preserves it; effective axis retires paged topology without changing the canonical source/fragment anchor. Continuous layout ignores axis for topology. Native vertical paging stays top-to-bottom even with RTL policy. 51 actual core-method tests pass; all three host main builds and N/E native builds pass.
- NextN 197: main95525/native15279, native 1 pass/0 failures, 40.569 seconds. Root reviewed original page2→page3→page2, pinch/pan, landscape page2, horizontal page3 and close captures. PID53091 scale1.807, pan y -15.39→-337.67, then fit1.000. Original orientation12 restored.
- NextE 197: main8384/native18566, native 1 pass/0 failures, 44.584 seconds. Root reviewed all nine original endpoints including whole menu and close to Non-H Gallery. PID54483 scale1.807, pan y -15.39→-76.02, then fit1.000; page2/46 retained while zoomed and rotated. Horizontal mode reaches page3. Original orientation12 and timeout10000 restored; device lease released.
- Koma 103: main65354, existing independent Chapter2 fixture. Root reviewed whole menu, actual blue page3/red page2, double-tap2x and pan, landscape2560x1600 page2, portrait1600x2560 page2, horizontal page3 and final shelf. PID14328 scale2.000, pan y -8.42→-257.06; subsequent observed double-tap cycle reaches native1.336 then fit1.000. Final MUSIC9 and timeout10000 restored; library/session hashes equal baseline, lease released.

Original evidence remains under `.hermes-artifacts/20260912-vertical-paging-197/` and `.hermes-artifacts/20260912-vertical-paging-koma-103/`. Exact package identities and checked protocol snapshots are retained there. This document records root adjudication, not merely delegated test status.

## Exclusions

- Initial NextN native60001 run02 failed its first 46%-viewport swipe at speed700; later steps did not execute. Preserve the failure. Native15279 increased only the test trajectory to62% at the same speed (plus optional sample-unit parameter); product unchanged. Success does not identify a unique platform threshold or prove every gesture trajectory.
- Old remote exception artifacts received during successful runs are excluded. Original image pixel comparison disproved an apparent black-body tool-preview omission; no product blackout repair was made.
- Koma103 real two-finger pinch remains OPEN: the checked typed device runner lacks that operation. Double-tap zoom is a separately accepted path, not a substitute. No runner bypass was used.
- No extreme-image, RTL-on-device vertical gesture, custom tap-zone, saved-mode handoff or comprehensive old/new parity acceptance is implied. Koma fixture is900x1300. Orientation checks establish source-page retention, not retention of arbitrary zoom/pan through rotation.

## Next unverified work

1. Review and checkpoint the exact vertical candidate and native regression slice without staging unrelated WIP.
2. Compare and implement optional SPLIT equal-pane spread geometry, preserving JOINED default, crop-aware image bounds, terminal singleton behavior and canonical source pairing. SPLIT layout is not `splitWidePages` image fragmentation.
3. Gate initial read-only old-settings handoff on representable modes and successful restoration before first session open/transition target publication. Never silently downgrade unsupported settings.
4. Keep missing real-device paths in the replacement gate; do not enable the shared reader by default until the complete capability matrix is closed.
