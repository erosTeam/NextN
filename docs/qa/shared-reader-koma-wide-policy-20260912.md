# Shared reader Koma wide-page policy evidence — 2026-09-12

## Scope

This lane closes one replacement-parity gap only: Koma's optional shared reader must inherit the existing `reader.wideImageMode=split_wide_pages` preference when it creates its initial `ReaderDisplayPolicy`. It does not switch the production reader, migrate settings or claim support for `rotate_wide_pages`.

## Source and build gate

`KomaReaderInitialPolicy.resolve()` now maps `preferences.wideImageMode === 'split_wide_pages'` to `ReaderDisplayPolicy.splitWidePages=true`. The shared `ReaderDisplayMap` remains the sole owner of wide-page topology and LTR/RTL fragment order.

Koma's signed debug build passed in 8 s 376 ms. The installed candidate was 14,537,814 bytes with SHA256 `1e84923320f52bbedcd6d656414f7f1c9e6fc9dac409fa93e8dceedae199507f`.

## Device 103 evidence

All evidence is under `.hermes-artifacts/20260912-koma-wide-policy-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/`.

- The normal Koma Reading settings page first reported `宽图模式 / 保持单页`. The baseline preference snapshot contained `reader.wideImageMode=keep_single`.
- The normal settings menu was used to select `拆分宽页`; the selected preference snapshot contained `reader.wideImageMode=split_wide_pages`.
- Opening the existing independent QA comic directly at its 1600×800 P2 produced `rkit-part-1-left` plus actual `rkit-cropped-image-1-left`, each in `[0,480][1600,2080]`. The reader page label remained `2 / 3`.
- One forward LTR swipe produced `rkit-part-1-right` plus `rkit-cropped-image-1-right` in the same viewport and kept the source page label `2 / 3`. Whole screenshots show the yellow center marker continuing from the right edge of the left fragment to the left edge of the right fragment.
- Closing the optional reader and using the normal settings menu restored `reader.wideImageMode=keep_single`. Screen timeout returned to 10000 ms and the device lease was released. Device 237 was not used.

## Replacement gate

Accepted: Koma single-page LTR startup inherits `split_wide_pages`, both fragments are independently reachable, and restoration is complete for the changed preference.

Still open: `rotate_wide_pages` has no shared-reader policy/rendering equivalent yet; RTL startup inheritance must be repeated against the host preference rather than an in-reader debug toggle; cropped/split Image interpolation needs native Inspector evidence; production-reader replacement remains disabled.
