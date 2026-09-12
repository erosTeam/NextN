# Koma shared-reader current-page save acceptance — 2026-09-12

## Outcome

Koma's optional shared reader now connects the existing reader-kit system image-save host. The shared chrome derives the target from the current source-page anchor; Koma supplies the already displayed local file asset. The system presentation owns an independent per-operation copy and releases it after the dialog closes.

This is additive optional-reader wiring only. The production Koma save implementation, default reader, progress, library, downloads, and media library were not changed. The acceptance run cancelled the system dialog and created no photo-library asset.

## Source and build evidence

- Koma creates `ReaderSystemImageSaveHost` with its current `UIAbilityContext` and passes it to `ReaderSurface` as `imageSave`.
- No network downloader is supplied because the optional Koma adapter deliberately accepts only local/downloaded chapter pages.
- The shared save host captures local file descriptors before yielding, copies each target to an operation-owned cache directory, decodes the actual MIME type, requests the system creation dialog, and defers cleanup until presentation completion.
- Current Koma signed candidate built successfully: 14,547,736 bytes, SHA-256 `11de35c2306fa7138cdc6f1e3399bcf1065c1eeeb22f813d6303e16ff4ff2014`.

## Device acceptance

Device: `103` (`192.168.50.103:12345`, MLR-AL00), portrait `1600 × 2560`.

1. The candidate was installed with data retention and the existing independent local QA unit was opened at the actual blue P2.
2. Shared chrome exposed enabled action `rkit-save-image` at `[38,2352][143,2457]`; the semantic page label remained `2 / 3`.
3. Activating it opened the HarmonyOS system dialog “允许“Koma”保存 1 张图片？” with a correctly rendered P2 preview. While the dialog was open the underlying save action was disabled, preventing a duplicate operation.
4. The system dialog's deny/cancel action was selected. The same reader surface, actual P2 image, page label `2 / 3`, and enabled save action returned without navigation or reader closure.
5. The temporary screen timeout was restored to 10,000 ms and the device lease was released.

Evidence root:

`/Users/honjow/git/NextN/.hermes-artifacts/20260912-koma-shared-save-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/`

- `01-open`: P2 and enabled save action.
- `02-dialog/screen.jpeg`: system permission/save dialog with the real P2 preview.
- `02-dialog/layout.json`: dialog text and disabled underlying save action.
- `03-cancel`: same P2 and re-enabled save action after cancellation.

## Acceptance boundary

Accepted for Koma/device-103, one local P2 item, opening and cancelling the system save dialog. This run intentionally does not claim a completed media-library write, multi-page spread save, remote-only source fallback, permission denial persistence, or background/close cancellation.
