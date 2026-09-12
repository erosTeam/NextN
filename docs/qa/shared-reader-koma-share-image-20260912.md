# Koma shared-reader current-page share acceptance — 2026-09-12

## Outcome

Koma's optional shared reader now exposes current-page image sharing. The shared surface continues to own current source-page identity, request cancellation, busy state, and presentation lifecycle. A Koma host adapter resolves that identity to a local page, copies it into an operation-owned cache file, and constructs the HarmonyOS image share record.

This is additive optional-reader wiring only. No production reader route, library/progress/download data, or existing production share implementation was changed. The acceptance run dismissed the share sheet without selecting a recipient.

## Source and build evidence

- `KomaReaderLabAdapter.imageShareSource` accepts only a prepared unit's local image page and derives the title from the captured unit and source index.
- `KomaReaderLabImageShareHost` opens the source before yielding, creates an independent cache copy, detects its MIME type, supplies an image UTD and file URI, and releases the copy after the system sheet closes or preparation fails.
- `ReaderSystemSharePresentation` remains the system presentation owner and completes only on the sheet's dismiss event; Koma does not treat sheet appearance as a completed send.
- Current Koma signed candidate built successfully: 14,553,219 bytes, SHA-256 `d5a8a14625698e91f601624ef5d35ea25bf18d4d44e3f8839a82e2b61f0a52bd`.

## Device acceptance

Device: `103` (`192.168.50.103:12345`, MLR-AL00), portrait `1600 × 2560`.

1. The candidate was installed with data retention and the existing independent local QA unit opened on actual blue P2.
2. Shared chrome exposed enabled `rkit-share-image` at `[1268,118][1373,223]`; the semantic label was `2 / 3`.
3. Activating it opened the HarmonyOS sheet “分享 1 项”. The sheet reported a 20.48 KB image and displayed the correct P2 preview with `QA PAGE 2`, yellow center mark, and `1600 × 800` label. The underlying share action was disabled while the sheet was active.
4. The sheet was dismissed through its close action without choosing a recipient. The same actual P2 image, `2 / 3` label, and enabled share action returned; there was no navigation or reader closure.
5. The temporary screen timeout was restored to 10,000 ms and the device lease was released.

Evidence root:

`/Users/honjow/git/NextN/.hermes-artifacts/20260912-koma-shared-share-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/`

- `01-open`: P2 and enabled current-image share action.
- `02-sheet/screen.jpeg`: system share sheet with the actual P2 preview.
- `02-sheet/layout.json`: sheet title and disabled underlying share action.
- `03-cancel`: same P2 and re-enabled share action after dismissal.

## Acceptance boundary

Accepted for Koma/device-103, one local P2 item, opening and dismissing the system share sheet. This does not claim that a recipient received the item, multi-page spread sharing, remote-only source fallback, or background/reader-close cancellation.
