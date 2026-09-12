# Koma shared-reader automatic advance acceptance — 2026-09-12

## Outcome

Koma's optional shared reader now exposes the existing automatic-advance control and consumes the host's saved `reader.autoPageSeconds` value. The controller remains chapter-local: it stops on the last display item and does not invoke Koma chapter switching.

This is an additive optional-reader connection only. The production reader, default route, preferences, progress, library records, and chapter orchestration were not replaced or migrated.

## Source and build evidence

- Koma passes `autoReadAvailable: true` and `autoReadSeconds: this.readerMode.autoPageSeconds` to `ReaderSurface`.
- The existing shared controller already gates timers on a fully displayed original, current surface activity, input lock, touch, open menus, seek preview, share/save/information work, and entry-transition layout. It stops at the final display item and on close.
- Current Koma signed candidate built successfully: 14,547,917 bytes, SHA-256 `5d37dcfce549e039d85e4f83faf9d4615f865bf9f16e9f5eca23b698a46c7d2d`.
- Existing reader-kit automatic-advance method test remains part of `tests/reader-surface-input.test.cjs`; no core behavior was changed in this slice.

## Device acceptance

Device: `103` (`192.168.50.103:12345`, MLR-AL00), portrait `1600 × 2560`.

The retained normal setting was read from Koma preferences as `reader.autoPageSeconds=3.000000`. The existing independent three-page local QA unit was opened at P1 through the optional shared-reader entry.

Observed sequence:

1. Before activation, the visible clock control `rkit-auto-read` was enabled and the page label was `1 / 3`.
2. After tapping the clock, P1 remained visible before the three-second interval and the clock glyph used Koma's accent color.
3. After 3.4 seconds, the same surface showed the actual blue P2 image and semantic page label `2 / 3`; the clock remained accent-colored.
4. The controller then reached the actual green P3 image and `3 / 3`.
5. Two later captures separated by another complete interval both remained `3 / 3`; the clock returned to its inactive color. No next-chapter request, toast, or replacement unit appeared.
6. The temporary screen timeout was restored to 10,000 ms and the device lease was released.

Evidence root:

`/Users/honjow/git/NextN/.hermes-artifacts/20260912-koma-shared-auto-read-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/`

- `01-open`: retained preference and available control on P1.
- `02a-active/screen.jpeg`: active clock and actual red P1 before the interval.
- `03a-p2/screen.jpeg` and `layout.json`: actual blue P2 and semantic `2 / 3` after one interval.
- `04-last`: actual green P3.
- `05-stopped`: still P3 after another full interval.

## Acceptance boundary

Accepted for Koma/device-103, single-page left-to-right, the existing local three-page unit, a three-second interval, and chapter-local last-page stop. Background/foreground pause, menu/touch cancellation, other page modes, and live multi-chapter handoff are not newly claimed by this device run; their shared core gates and prior named tests are not substitutes for new Koma device evidence.
