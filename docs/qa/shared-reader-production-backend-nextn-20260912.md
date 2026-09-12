# Shared Reader Production Backend Trial — NextN — 2026-09-12

## Outcome

LIMITED PASS. The optional shared Reader body can now run inside NextN's existing
production Reader destination for an ordinary Detail `Read` entry. The legacy
Reader remains the default and the explicit rollback path was exercised on both
the 197 phone and 103 tablet.

This does not accept default replacement. Thumbnail-origin entries remain on the
legacy path, and local/downloaded source selection plus Detail prefetch handoff
remain open.

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
- legacy remains the default and can be selected without migration.

Still open before default replacement:

- Downloads-tab UI entry through the now host-owned local/download source;
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
local-file reachability, not the Downloads-tab-to-shared-body visual/runtime
entry; that remains the next physical path.
