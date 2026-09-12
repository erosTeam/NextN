# Shared Reader production thumbnail to RTL spread — NextN — 2026-09-13

## Outcome

LIMITED PASS / replacement OPEN. The real full-thumbnail P3 production source
now enters the optional shared Reader at P3's actual right-hand side in an RTL
split spread. P4 is revealed independently on the left; the selected thumbnail
is not stretched across the pair and does not abruptly turn into two pages.

The legacy Reader remains the default and fallback. This result does not
authorize a default switch.

## Decoupled boundary

- Gallery owns the live source tile and emits only the existing neutral source
  plus page index. It contains no RTL, pairing, spread or transition geometry.
- The NextN host owns source capture, optional backend selection, navigation,
  cancellation and final source return.
- `reader-kit` resolves the spread, publishes the selected image's actual
  content rectangle, moves the preview to that rectangle, and reveals the
  neighbor independently.
- Entry-transition facts end when the host clears the completed transition;
  the Reader session continues to own reading anchor and displayed assets.
  The acceptance probe verifies those as separate lifecycles.
- Expanding the one-shot original hold probe to production entry is
  observation-only. With no matching armed probe it changes no load behavior.

No Gallery-specific model entered the shared core. No status-bar ordering,
target eligibility, movement requirement, cached exit geometry, proxy radius,
legacy Reader implementation or persistent default changed.

## Build evidence

- `git diff --check`: pass.
- Signed main HAP: pass in 10.997 s; SHA-256
  `5bd013251dc33cd9e82b17b2695d6c120867b544c4dbb242db20b11875b24b9a`.
- Signed `entry@ohosTest` HAP: pass in 9.134 s; SHA-256
  `0aa2a571f6d8952035d01bcb0b2f0329a6264f3e5ff5c4bd9320bcd1271aca41`.

The existing `scripts/test_reader_trial_entry_host_runtime.mjs` run is not
claimed as a full pass: its unrelated same-frame fallback case expected one
measurement and observed zero. The matching signed builds and named device
test below are the evidence for this slice.

## Device 197 evidence

Final protocol:
`docs/device-protocols/shared-reader-production-thumbnail-spread-entry-197.json`.

On 197 (`ALN-AL80`, portrait 1260 x 2720), the matching-hash protocol completed
at 2026-09-13 00:34:42 +08:00. Hypium passed 1/1 in 34.465 s:

1. snapshot exact history and the four affected reader setting rows;
2. temporarily select `PAGED_RTL`, double-page, `SPLIT`, `ODD_LEFT` and open the
   real full-thumbnail page;
3. capture the P3 source, click its live tile and hold only P3's production
   original while shared Reader resolves the spread;
4. require P3's selected part `[630,124][1260,2720]` on the right, P4's
   independent part `[0,124][630,2720]` on the left, and the moving P3 preview
   `[843,1174][1047,1545]` centered inside the selected side;
5. release P3 and require `3 / 14`, two displayed originals, no transition
   preview, spinner or failure layer;
6. close to the exact source bounds and restore history, all four settings and
   the `legacy` selector before force-stop and timeout restoration.

Lifecycle log: `moving -> waiting -> revealing -> finished`. Final summary:
`thumbnailSpreadShared=true clicked=2 savedBefore=6 heldWaiting=true
selectedRight=true neighborLeft=true delivered=true sourceRestored=true
historyRestored=true settingsRestored=true`.

The source, held transition, settled spread and returned grid screenshots were
all inspected. In the held frame P4 is already visible on the left while only
the selected P3 thumbnail occupies the right. In the settled frame P4 and P3
are distinct full-height images at `[216,124][414,2720]` and
`[843,124][1048,2720]`; the preview node is absent. The returned grid matches
the source viewport.

Evidence root:
`.hermes-artifacts/20260913-shared-production-thumbnail-spread-entry-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/03-final/`.

Two earlier runs are retained but rejected as acceptance. The first treated the
host-cleared completed `entryId` as sticky. The second still treated completed
transition-only `phase/decodedReady` facts as session state. Both observed the
real `finished` product transition, but neither completed settled/return
assertions and neither is counted.

## Remaining replacement work

- validate the same production path for joined spreads, cover/tail singleton
  boundaries, the opposite selected side and `EVEN_LEFT` pairing;
- validate capture-unavailable, back/cancel, selected-original failure and
  neighbor failure/retry without stranding the host overlay;
- close production action, partial-download/offline, rotation and responsive
  host matrices across 197 and 103;
- keep legacy default/fallback until the replacement ledger has no critical
  functional gap and the named-device regression matrix passes.
