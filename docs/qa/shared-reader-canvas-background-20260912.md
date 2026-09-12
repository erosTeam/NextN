# Shared reader host canvas background acceptance — 2026-09-12

## Outcome

The optional shared reader now accepts a host-owned canvas background and foreground palette instead of hard-coding a black surface. NextN, NextE, and Koma map their existing reader-background preference into that palette. This is an additive debug-path change only; no production reader was replaced and no preference was migrated.

## Source and build evidence

- reader-kit commit: `110803c feat(reader): expose host canvas palette`
- reader-kit regression tests: `node --test tests/reader-surface-canvas.test.cjs tests/reader-image-interpolation-ui.test.cjs` — 2 passed, 0 failed.
- NextN signed build: 47,080,572 bytes, SHA-256 `c1f5388ef023dd95890ce7a4ad0a58f69383feda597f8f00df0f54854dbe27f1`.
- NextE signed build: 62,719,141 bytes, SHA-256 `dcec140e8008d17814cf67b02b54053a2e6a710734615a73e6f7dce445095ecd`.
- Koma candidate used for device acceptance: 14,535,823 bytes, SHA-256 `7884522cd5bc7969a549730d92ad7d07168206d1ca3546a7d779576d924151b1`.

The host mappings preserve each app's existing palette and include black, gray, white, and automatic light/dark behavior. ReaderSurface retains black/white defaults for hosts that do not opt in.

## Device acceptance

Device: `103` (`192.168.50.103:12345`, MLR-AL00), portrait `1600 × 2560`.

1. The original Koma reading-background setting was black. It was temporarily changed to white through the normal settings menu.
2. Before this change, the optional reader retained a black canvas even though the saved preference was `reader.backgroundMode=white`.
3. After installing the candidate with data retention, the same local QA page reported `rkit-reading-surface` bounds `[0,105][1600,2560]` and `backgroundColor=#FFFFFFFF` while the saved preference remained white.
4. With reader chrome hidden, the full area around the `1600 × 800` page was visibly white and the persistent `2 / 3` page label remained legible.
5. The original `reader.backgroundMode=black`, left-to-right direction, keep-single wide-page mode, and 10,000 ms system timeout were restored. The device lease was released.

Evidence root:

`/Users/honjow/git/NextN/.hermes-artifacts/20260912-koma-reader-canvas-background-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/`

- `01-menu/screen.jpeg`: original host menu and black selection.
- `02-baseline-white/screen.jpeg`: pre-change shared reader with a black canvas despite the white preference.
- `03-candidate-white/screen.jpeg`: candidate with white canvas and visible chrome.
- `04-candidate-hidden/screen.jpeg`: candidate with white canvas and hidden chrome.
- `06-restore-final/preferences.restored`: restored black preference.

## Acceptance boundary

Accepted on Koma/device-103 for the white-host setting and restoration path. NextN and NextE have source and signed-build evidence for the same additive interface, but this record does not claim same-page device acceptance for their black/gray/white/auto combinations.
