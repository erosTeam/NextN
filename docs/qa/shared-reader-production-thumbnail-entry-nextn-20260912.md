# Shared Reader production compact-thumbnail entry — NextN — 2026-09-12

## Outcome

LIMITED PASS / replacement OPEN. When the process-local backend selector is
`shared`, a real compact thumbnail on Gallery Detail can now enter the shared
Reader at the exact selected page. The legacy thumbnail route remains the
fallback and the default selector remains `legacy`.

This slice does not accept default replacement. The full-thumbnail page, the
single-page-to-spread visual expansion and the remaining production entry
matrix are still open.

## Decoupled boundary

- Gallery owns the live compact-thumbnail component and offers a neutral
  `ReaderTrialEntrySource`. It does not select a Reader backend or navigate.
- `Index` owns backend selection, source capture, route-scoped Detail seed,
  navigation, cancellation and captured-preview disposal.
- The shared Reader receives only the host request, captured preview and neutral
  entry-transition lifecycle. It does not import Gallery or NH navigation.
- Explicit initial-page intent is now independent from thumbnail animation:
  `restoreSavedProgress=false` preserves the clicked page while
  `thumbnailEntry=false` preserves production features such as crop.
- When the shared host declines or cannot capture a valid live source, the
  existing legacy coordinator remains the unchanged fallback.

No status-bar recovery, close-target lookup, target eligibility, proxy radius
or cached exit geometry was changed.

## Build evidence

- `git diff --check`: pass.
- Signed main HAP: pass in 13.214 s; SHA-256
  `5aaa0178aa4b477812e89f6a5c0653eda8c773903f068fd3310b8c7a4eb7e539`.
- Signed native-test HAP: pass in 9.222 s; SHA-256
  `4a9cdd95d236ab7e0fd793702cfa322971f113664220df34d6f2b26c85fe065b`.

## Device evidence

Final protocol:
`docs/device-protocols/shared-reader-production-thumbnail-entry-197.json`.

On device 197 (`ALN-AL80`, portrait 1260 x 2720), the matching-hash protocol
passed 1/1 in 27.184 s:

1. the test snapshotted all existing history fields and seeded P7;
2. the real Detail compact rail scrolled to and clicked its live P3 component;
3. the production shell claimed the source and opened the shared Reader at P3,
   rather than restoring P7 or opening the legacy/debug Reader;
4. the entry preview and pending source were released after settlement;
5. the production settings menu still exposed `rkit-crop-toggle`;
6. close returned to the same source id and exact bounds
   `[764,1960][1081,2448]`, while Detail progress became `Continue P3`;
7. the exact history snapshot was restored, the backend was returned to
   `legacy`, NextN was force-stopped and the display timeout returned to 10000
   ms.

Summary log:
`thumbnailShared=true clicked=2 persistedBefore=6 cropAvailable=true sourceRestored=true debugTrialAbsent=true historyRestored=true`.

The source, shared Reader and returned Detail screenshots were all inspected.
The shared capture shows `3 / 14`, the selected long image and the production
settings/crop menu; no legacy surface, debug navigation, stale preview or
failure overlay was present.

Evidence root:
`.hermes-artifacts/20260912-shared-production-thumbnail-entry-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-diagnostic/`.

An earlier run is retained under `01-final` and rejected as acceptance. It
opened the legacy Reader because the test process had not yet proved the
process-local backend state. The final harness now asserts the selector before
click and records whether the production shell claimed the offered source.

## Remaining replacement work

- connect the full-thumbnail page through the same neutral source contract
  without mixing its existing dirty work into this slice;
- define and validate the single-thumbnail-to-spread expansion so the selected
  page does not abruptly become an unexplained pair;
- exercise cancellation during capture/movement and unavailable-preview
  fallback on real production routes;
- repeat the production entry and return contract on tablet 103;
- complete the remaining actions, offline/partial-download and failure matrix
  before considering a default switch.
