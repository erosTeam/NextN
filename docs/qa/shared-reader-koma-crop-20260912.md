# Shared reader Koma border-crop checkpoint — 2026-09-12

## Outcome

LIMITED accepted; overall replacement remains OPEN.

The optional Koma shared-reader path now supplies file-backed originals to the shared crop contract. The detector and the sampled-file provider live in `reader-kit`; Koma only maps its existing `trimPageMarginsEnabled` preference into the shared session and supplies each local page URI. No production-reader entry, default, stored preference, progress, chapter, library, or reader-session write path was replaced.

This checkpoint covers local/downloaded Koma pages only. Remote source pages that are not represented by a readable local file remain unsupported by this adapter, and therefore remain OPEN for replacement parity.

## Implementation evidence

- `ReaderImageCropDetector` recognizes conservative white, black, and transparent outer frames from RGBA samples. It keeps one safety sample line, refuses an edge that reaches the 35% cap, requires at least 25% of each axis to remain, and tolerates no more than 1% non-background pixels on a removable line.
- `ReaderFileCropSource` decodes at most a 256-pixel long edge in a task-pool worker, releases `PixelMap` and `ImageSource`, shares in-flight work, and keeps a bounded 256-entry identity/path LRU.
- Crop bounds remain an asset presentation property. Enabling crop does not change page grouping, wide-page splitting, current-page identity, thumbnail geometry, source metadata, or decode state.
- `node --test tests/*.test.cjs`: 308/308 passed. The run includes detector safety, crop topology, late-completion invalidation, file-source threading/release/cache contracts, and the existing shared-reader regression suite.

## Build evidence

- NextN signed debug HAP: 47,098,042 bytes, SHA-256 `565f47bf0f7197e1834f2741af1ad167c9ab74c55a46b81d4a01a598e6733b68`; signed build succeeded.
- NextE signed debug HAP: 62,740,530 bytes, SHA-256 `4570ff07f15092d4947ebd660a83fb74b71834148895a8b5bec9c34831ecd741`; signed build succeeded.
- Koma signed debug HAP used on device 103: 14,581,951 bytes, SHA-256 `7fbf97d0831997e5635f0e559c6ff1e47c28674216cd2df51a9558b43eff69cf`; build succeeded.

Build success proves host compatibility, not device acceptance.

## Device 103 evidence

Target: `192.168.50.103:12345`, MLR-AL00, portrait 1600x2560. The Koma app was installed with retained data. Validation used the optional reader only.

An independent two-page CBZ was added through Koma's normal import picker. Each 1060x1460 page contains a real 80-pixel white outer frame around 900x1300 colored content. The source archive is 44,549 bytes, SHA-256 `9f86ee522b0ecc1ff16468b449475cec159dbea55b08e08a946cf705de71a990`.

- Crop OFF: page 1/2 rendered at `[0,178][1600,2382]`; the white outer frame remained visible.
- Crop ON: page 1/2 rendered at `[0,129][1600,2431]` through `rkit-cropped-image-0-whole`; the outer frame disappeared and the colored content enlarged. Internal artwork/grid lines remained.
- Crop OFF again: the uncropped `[0,178][1600,2382]` branch and white outer frame returned.
- A separate existing QA page had white internal lines but colored pixels at the true outside edge. Enabling crop did not create a cropped-image branch, providing a concrete false-positive check.
- The runtime toggle was session-local. Preference SHA-256 before, enabled, and final was identical: `fd66722b3a91982b09b0827058c445f66b94cce0a881a31953c2270ea3b79015`.
- Reader-session SHA-256 after import and after final exit was identical: `f0fdbd8fb6f7e315c450b57562380208553eee3c338d87a14adc63f42e1c9cce`.
- Final state was the ordinary Koma shelf, not the optional reader. The screen-off override was restored to 10000 ms and the device lease was released.

Private library-store contents were captured only to establish the normal import and final state; they are not reproduced here.

## Visual evidence

- Baseline OFF: `.hermes-artifacts/20260912-koma-shared-crop-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/08-fixture-baseline/screen.jpeg`
- Enabled: `.hermes-artifacts/20260912-koma-shared-crop-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/09-fixture-enabled/screen.jpeg`
- Restored OFF: `.hermes-artifacts/20260912-koma-shared-crop-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/10-fixture-restored/screen.jpeg`
- Final ordinary shelf: `.hermes-artifacts/20260912-koma-shared-crop-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/11-final-exit/screen.jpeg`

## Remaining replacement gates

- Remote/non-file Koma page crop source and its failure/retry behavior.
- Crop interaction with Koma chapter switching, cold reopen, spread/wide-page combinations, and entry transition on both phone and tablet.
- Cross-host device acceptance for the shared detector in NextN and NextE; their successful builds are not substitutes for runtime evidence.
- Full default-reader replacement, settings migration, and deletion of existing readers remain explicitly out of scope and OPEN.
