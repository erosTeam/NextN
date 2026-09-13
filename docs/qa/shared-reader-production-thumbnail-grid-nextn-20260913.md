# Shared Reader production thumbnail grids — NextN — 2026-09-13

## Outcome

LIMITED PASS / replacement OPEN. The optional production shared-reader route
now accepts neutral live sources from both the full-thumbnail page and the wide
Detail preview grid. The selected page is preserved independently from saved
history, while the existing legacy route remains the default and fallback.

This slice also corrects NH thumbnail presentation: grid tiles use the decoded
thumbnail asset's own dimensions with `Contain` inside a bounded portrait frame
instead of stretching a cropped NH thumbnail to the unrelated full-page aspect.

## Decoupled boundary

- `GalleryVirtualPageThumbnail` owns the rendered tile and emits its existing
  neutral `ReaderTrialEntrySource` together with the page index.
- `GalleryThumbnailGridContent` and the Gallery pages only relay the source;
  they do not choose a backend, capture pixels or navigate to a reader.
- `Index` owns the optional backend decision and reuses the production capture,
  route, cancellation and disposal lifecycle established for the compact rail.
- The shared reader consumes the neutral host request and captured preview. It
  has no Gallery, NH navigation or wide/compact layout dependency.
- If the shared host declines the source, the existing legacy coordinator still
  receives the same click. The default selector is still `legacy`.

No status-bar ordering, target eligibility, movement requirement, cached exit
geometry, proxy radius or legacy reader implementation was changed.

## Build and source evidence

- `node scripts/test_gallery_reader_transition_contract.mjs`: pass.
- `git diff --check`: pass.
- Signed main HAP: pass in 12.773 s; SHA-256
  `4cd978851d02f77ca1d8bbecc11166edc2666011d78eb23c9fb6c304a31e1e0f`.
- Signed native-test HAP: pass in 9.210 s; SHA-256
  `2d488c794320731442a9c77e6831bb690bbb5b3f4cb9637fe32c31a485456a27`.

## Device 197 — full-thumbnail page

The exact final protocol is retained as `protocol-manifest.json` under the
local evidence root below.

On 197 (`ALN-AL80`, portrait 1260 x 2720), the matching-hash protocol passed
1/1 in 29.242 s:

1. snapshot the exact history state and seed saved progress to P7;
2. enter the real `View all` thumbnail page and click its live P3 tile at
   `[887,344][1177,871]`;
3. require the shared surface `[0,124][1260,2720]` and `3 / 14`, with neither
   the seeded P7 nor a legacy/debug reader accepted;
4. close to the same full-thumbnail page/source, restore exact history, reset
   the selector to `legacy`, force-stop NextN and restore timeout 10000 ms.

Summary log:
`thumbnailGridShared=true clicked=2 persistedBefore=6 sourceRestored=true debugTrialAbsent=true historyRestored=true`.

The source/shared/closed screenshots were inspected. The source shows stable
three-column frames whose cropped NH contents retain their own aspect; the
shared screenshot contains the selected long image and `3 / 14`; the close
capture returns to the same grid viewport without a stale transition preview.

Evidence root:
`.hermes-artifacts/20260912-shared-production-thumbnail-grid-entry-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-final/`.

## Device 103 — wide Detail preview grid

The exact final protocol is retained as `protocol-manifest.json` under the
local evidence root below.

On 103 (`MLR-AL00`), the test retained the device's original portrait setting,
temporarily rotated into the actual 2560 x 1600 wide layout, then passed 1/1 in
37.033 s:

1. prove the real three-pane Browse / Detail / preview-grid parent and its
   preview pane `[1661,105][2560,1600]`;
2. click its live P3 tile `[1736,909][2054,1486]` rather than a test-only entry;
3. require shared surface `[0,105][2560,1600]` and `3 / 14`, excluding seeded
   P7, legacy and debug surfaces;
4. close to the same wide Detail pane/source, restore portrait, exact history,
   `legacy`, app stop state and timeout 10000 ms.

Summary log:
`thumbnailWideShared=true clicked=2 persistedBefore=6 sourceRestored=true debugTrialAbsent=true historyRestored=true`.

All three final screenshots were inspected. The source capture proves the real
wide parent rather than a resized compact page; the shared capture shows P3;
the close capture returns to the same three-pane layout and retained P3 state.

Evidence root:
`.hermes-artifacts/20260912-shared-production-thumbnail-wide-entry-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/03-landscape/`.

Two earlier 103 attempts remain rejected as acceptance: one stopped before page
interaction on a transient top-ability lookup, and one correctly revealed that
portrait 1600 x 2560 uses the compact Detail rail rather than the wide grid.
The final test now discovers that responsive boundary by observing the real
layout after temporary rotation instead of assuming tablet class implies wide.

## Remaining replacement work

- publish the selected page's real destination rect for spread mode so a single
  thumbnail expands into its actual side of the pair and the neighbor appears
  separately, without coupling Gallery to spread layout rules;
- validate capture cancellation and unavailable-preview fallback on production
  routes;
- close remaining action, offline/partial-download, failure and retry coverage;
- complete the remaining host/mode/viewport matrix before any default switch.
