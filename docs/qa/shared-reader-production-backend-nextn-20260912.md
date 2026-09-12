# Shared Reader Production Backend Trial — NextN — 2026-09-12

## Outcome

LIMITED PASS. The optional shared Reader body can now run inside NextN's existing
production Reader destination for an ordinary Detail `Read` entry. The legacy
Reader remains the default and the explicit rollback path was exercised on both
the 197 phone and 103 tablet.

This does not accept default replacement. Thumbnail-origin entries remain on the
legacy path. Local/downloaded source selection, Detail prefetch handoff and the
real Downloads-root entry have since passed the follow-up checks recorded below.

## Boundary

- `Index.readerDestination` continues to own the existing overlay destination,
  presentation lifecycle, close path, window state and status-bar restoration.
- A process-local debug selector chooses only the embedded Reader body. Release
  capture forces the legacy selection, and no preference or backup schema is
  added.
- Normal Detail `Read` entries may select the shared body. Explicit-page and
  thumbnail-transition entries remain legacy so the frozen transition is not
  silently replaced.
- `NextNProductionReaderRequest` is a neutral host request rather than a debug
  `ReaderLabRequest`. Progress policy accepts scalar capabilities instead of
  importing the host request type.

## Source and build evidence

- Runtime checks: backend selector, initial policy, progress persistence,
  observed progress, write gate, 1,404 tap-zone comparisons and the 17/17 trial
  host checks passed.
- Signed main HAP: `50989795d6bca5edea1badb2fb77f4e31f492bf7c56e84e2ddce670ec37f3351`
  (10.731 s).
- Signed native-test HAP:
  `2896cbb79c47edef90bcd098ca6ff200de3ed2273513f16ec6d78a0219559be4`
  (9.936 s).
- The first 197 test attempt failed before product interaction because API 23
  does not expose `Driver.dumpLayout`. The harness was changed to use the
  supported `uitest dumpLayout` shell command; the exact history snapshot and
  legacy selector were restored by the test cleanup. This is retained as a
  harness failure, not reported as a Reader defect.

## Device evidence

### 197 phone — ALN-AL80 — 1260 x 2720 portrait

- Hypium: 1 pass / 0 failures / 46.230 s.
- Actual gallery `678049`, production history database and `odd_left` column.
- Shared body opened at source page 0, slider navigation reported source page 6,
  close returned to Detail with `Continue P7`, and explicit legacy rollback
  reopened at P7.
- Summary log:
  `sharedInitial=0 sharedChanged=6 sharedClosed=true legacyReopened=true legacyClosed=true historyRestored=true`.
- Shared and legacy whole-page captures were inspected. The current single-page
  mode shows the same contained long strip in both bodies; this is functional
  entry evidence, not full visual parity across modes.
- Cleanup restored the exact eight-column history record, selected legacy,
  force-stopped NextN, returned to Home and released the lease.

Evidence root:
`.hermes-artifacts/20260912-shared-production-backend-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/03-normal-entry-retry`

### 103 tablet — MLR-AL00 — 1600 x 2560 portrait

- Foreground gate identified `bundleName=com.erosteam.nextn` and
  `nextn-root-navigation`; Koma was not opened or mutated.
- Hypium: 1 pass / 0 failures / 61.938 s.
- Shared body opened at source page 0, slider navigation reported source page 7,
  close returned to Detail with `Continue P8`, and explicit legacy rollback
  reopened at P8.
- Summary log:
  `sharedInitial=0 sharedChanged=7 sharedClosed=true legacyReopened=true legacyClosed=true historyRestored=true`.
- The wide Detail layout, shared initial/changed/closed states and legacy
  reopened/closed states were all inspected. No overlap or viewport clipping was
  visible in these captured states.
- Shared layouts exposed `reader-overlay-navigation` and
  `rkit-reading-surface` at `[0,105][1600,2560]`; the legacy reopen exposed
  `reader-overlay-navigation` and `legacy-reader-surface` at
  `[0,0][1600,2560]`. This difference remains a visual-parity item rather than
  being hidden by the functional pass.
- Cleanup restored the exact history record and legacy selection, force-stopped
  NextN, returned to Home, left Koma untouched and released the lease.

Evidence root:
`.hermes-artifacts/20260912-shared-production-backend-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/02-normal-entry`

## Replacement status

Accepted in this slice:

- optional production navigation-shell integration;
- normal Detail entry to shared body;
- host-owned progress write and same-page legacy rollback;
- phone/tablet lifecycle and cleanup;
- production Downloads-root completed-task entry using verified local files;
- legacy remains the default and can be selected without migration.

Still open before default replacement:

- thumbnail-origin transition into shared Reader;
- visual parity for system-bar/chrome bounds and remaining modes;
- complete settings/action/failure/offline matrix;
- NextE and Koma production-shell cutovers under the same neutral contracts.

The next implementation slice is the data-source capability boundary: the host
chooses cached/local, prefetched or network page material, while reader-kit owns
only generic page presentation, navigation and retry signals.

## Follow-up: host data-source boundary

The first replacement blocker was implemented after the production-shell pass.
`NextNReaderDataSource` now keeps source choice outside reader-kit and outside
the shared UI:

- production detail order is complete verified download, then the one-shot
  route-scoped Detail seed, then NH network;
- every original or thumbnail asset checks the verified downloaded page before
  using a remote thumbnail or private Reader cache;
- the debug/Lab source remains network-only, so production cache behavior is
  not smuggled into failure probes or fixtures;
- the production request carries only a route epoch and a production-source
  capability marker. The overlay state remains the owner of consuming the
  short-lived Detail seed.

Runtime policy checks pass for selection order, one-shot seed consumption,
cancellation, page bounds and local-page precedence. Matching signed builds:

- main `386b2fb59487870a51a0d1f3077add5c7a64cbe8c4ef424abf5437461b1dbb82`
  (8.562 s final rebuild);
- native `de8b992318269d14d659db4e3c1e7f3c3e965400d22335664e347150c4ffbd23`
  (8.695 s for the final download-source test).

197 production Detail route passed 1/1 in 45.503 s with
`detail_source=route_seed`; the existing source0→6 progress, close, legacy P7
rollback and exact history restoration all remained true. This proves the
retained Detail snapshot avoids a duplicate detail request.

197 also had an existing verified complete 46-page download. The direct
production-source trial passed 1/1 in 1.344 s with
`detail_source=download` and `sample=complete pages=46 local=true`; page zero's
URI resolved to an accessible local file. No task was created, deleted, paused
or resumed. The first attempt failed in 2 ms before source work because the test
used an ApplicationContext where the RDB requires EntryAbility context. The
test was corrected to acquire the live EntryAbility context; the rejected run
is retained as a harness failure.

Evidence roots:

- `.hermes-artifacts/20260912-shared-production-data-source-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-route-seed`
- `.hermes-artifacts/20260912-shared-production-data-source-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/03-complete-download`
  (rejected context attempt)
- `.hermes-artifacts/20260912-shared-production-data-source-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/04-complete-download-context-retry`

The device ended on Home with the ordinary 10-second timeout, NextN
force-stopped and both leases released. This accepts source selection and real
local-file reachability.

## Follow-up: real Downloads-root entry

The production Downloads entry has now passed on 197 using the existing
completed task for gallery `556817`:

- the test entered the real root Downloads tab and clicked the completed row's
  Reader surface, rather than opening a Lab or direct-source fixture;
- the host data source logged `detail_source=download`;
- the shared body exposed `46 / 46`, rendered a ready local image and exposed no
  `legacy-reader-surface`;
- closing returned to the retained Downloads root at the same list position;
- the complete serialized queue snapshot was byte-for-byte equivalent before
  and after the Reader handoff;
- the selected gallery's eight history columns were restored exactly, the
  process-local selector was reset to legacy, NextN was force-stopped, the
  ordinary 10-second timeout and Home were restored, and the lease was released.

Hypium passed 1/1 in 25.575 s. The independent idempotent cleanup test also
passed 1/1 in 2 ms, confirming no interrupted history snapshot needed recovery.
Matching artifacts:

- main `177fdbb3b0a64d57df3f48e8ad7c442e1d9121ce04b6d0412bba346b72b1a6dc`
  (10.808 s);
- native `4d496aa520de486efa4ea829dfe18c9a2708c4aec04e04dcbe1fab043e3521ff`
  (8.905 s final rebuild).

The inspected layout records the Downloads root at `[0,124][1260,2720]`, the
clicked row at `[358,429][1196,787]`, and the shared production surface at
`[0,124][1260,2720]`. Before/return screenshots are visually equivalent in the
captured viewport; the Reader screenshot shows the ready final local page and
complete chrome without overlap or clipping.

Evidence roots:

- `.hermes-artifacts/20260912-shared-production-download-entry-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-entry`
- `.hermes-artifacts/20260912-shared-production-download-entry-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-cleanup`

This closes the complete-download production-entry gap only. Partial downloads,
network fallback, offline thumbnail-rail aspect handling, failure/retry,
thumbnail-origin transition and default replacement remain open.

## Follow-up: completed-download local share

The completed-download entry now also keeps current-page share source selection
inside the NextN host adapter. The shared Reader emits the generic current-page
share action; `NextNReaderLabAdapter` first asks the production data source for
the verified local page and only falls back to the existing NH cache/network
path when no complete downloaded page exists. No download-specific path or NH
URL construction was added to reader-kit.

On 197 the real Downloads-root flow passed 1/1 in 41.431 s:

- gallery `556817` opened through its existing complete 46-page task and logged
  `detail_source=download`;
- page `46 / 46` rendered from the local file, and sharing logged
  `NextNReaderShare source=download` before the system share sheet appeared;
- the system sheet showed the current page preview; it was cancelled without a
  recipient or delivery, then the shared Reader recovered on the same
  `46 / 46` page with its action enabled;
- closing returned to Downloads, the serialized queue stayed byte-identical,
  and the selected gallery's eight history columns were restored exactly.

Matching signed artifacts:

- main `a30be0c2bfa46624a3f066323b855cce9faf1ff82e56f3249cfd653dac52ca57`
  (9.647 s);
- native `37d34d4052a86788b42b7f44a1ab68a78a69e89fe43ba35e08f23ac572087bb3`
  (8.808 s).

The independent cleanup test passed 1/1 in 3 ms. NextN was force-stopped,
Home and the ordinary 10-second timeout were restored, and the lease was
released. The whole shared-page, system-sheet, recovered-page and Downloads
captures were inspected; the page remains stable across cancellation and no
Reader chrome overlap or clipping is visible in these captured states.

Evidence roots:

- `.hermes-artifacts/20260912-shared-production-download-entry-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/03-local-share`
- `.hermes-artifacts/20260912-shared-production-download-entry-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/04-local-share-cleanup`

This closes local current-page sharing for a verified complete download only.
Cache/network fallback sharing, partial downloads, offline thumbnail-rail aspect
handling, failure/retry, thumbnail-origin transition and default replacement
remain open.

## Follow-up: production network thumbnail rail and cached image share

The production network path now has a dedicated device trial covering the two
NH-specific boundaries that must remain outside the shared Reader core:

- NextN supplies independent NH thumbnail assets and their decoded dimensions;
  reader-kit only renders the generic bounded thumbnail rail. The first two
  visible slots measured `0.549,0.549`, rather than inheriting the extremely
  tall original-page ratio, and the selected source page stayed at zero.
- NextN classifies cached or downloaded share files with an image UTD derived
  from their original extension. The shared Reader still emits only a generic
  current-page share intent and owns no NH URL, cache or system-share typing.

On 197 the accepted rerun passed 1/1 in 41.924 s for gallery `678049`:

- `detail_source=route_seed` opened the optional shared production body at
  `1 / 14`;
- the inspected rail showed the independent cropped NH previews at ordinary
  bounded proportions with page one still selected;
- sharing logged `NextNReaderShare source=cache`, and the system sheet showed
  the actual current long-image preview instead of a generic unknown-file icon;
- cancelling the sheet recovered the same `1 / 14` page and enabled share
  action; closing returned to the exact Detail page;
- all eight history columns were restored exactly.

The immediately preceding generic-`FILE` run passed its functional assertions
but displayed an unknown-file icon in the share card. It is retained as a
rejected visual diagnostic under `01-network-actions` and is not counted as
acceptance. The accepted image-typed artifacts are:

- main `556f17cc3d3a539aa25b17551cc1199be8c547567120573fe2d8598e59c0cf9d`
  (11.163 s);
- native `470f786f01fe4f5e27df054a09e4ed6ca5e9aec1db011baca639b15bc09788ee`
  (9.966 s).

Evidence roots:

- `.hermes-artifacts/20260912-shared-production-network-actions-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/03-image-typed`
- `.hermes-artifacts/20260912-shared-production-network-actions-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/04-cleanup-after-image-typed`

The independent cleanup passed 1/1 in 2 ms. NextN was force-stopped, Home and
the ordinary 10-second timeout were restored, and the lease was released. This
closes production network thumbnail geometry and cached current-page sharing
for the captured state. Partial downloads, failure/retry through the production
source, thumbnail-origin transition and default replacement remain open.
