# NextN shared Reader entry-capture boundary — 2026-09-12

## Scope

This checkpoint extracts the thumbnail snapshot work from `Index` into a
NextN-owned host helper. The gallery still supplies the live component identity
and owns its source page. `reader-kit` receives only the captured `PixelMap`, its
current rectangle, and the existing departure authorization callback.

The shared Reader remains optional. Normal production thumbnail entry and the
legacy Reader/transition are unchanged by this checkpoint.

## Source boundary

- `NextNReaderEntryPreviewCapture` owns current component measurement, stable
  before/after geometry validation, snapshot capture, snapshot-aspect mapping,
  and rejected/cancelled `PixelMap` release.
- Its capture input is the scalar snapshot component id rather than a gallery,
  trial, NH, or reader-kit model. This keeps the helper reusable by the later
  production entry without importing feature-specific state.
- `Index` retains navigation epoch, foreground, safe-mode, ownership and close
  authorization. No entry geometry is cached for Reader exit.
- No status-bar ordering, close-target measurement, target eligibility,
  visibility gate, proxy dimensions, or radius ownership changed.

## Build evidence

- `git diff --check`: pass.
- Signed main build: pass in 11.900 s; SHA-256
  `7461773f09c7185852dccf70e436848d4af2ee4fd65a61d00f15b07d4217aeda`.
- Signed `entry@ohosTest` build: pass in 9.180 s; SHA-256
  `14da6336c163c3b213a8926df6cb2346605a9e255c1e205f67fadcb34c379a45`.

## Device evidence

Final checked protocol:
`docs/device-protocols/shared-reader-entry-capture-boundary-197.json`.

On device 197 (`ALN-AL80`, portrait 1260×2720), the final exact-hash run passed
1/1 in 9.983 s:

1. the current Detail P1 thumbnail was found through the retained Detail owner;
2. its live component was captured by the NextN host and handed to the shared
   Reader;
3. P1 completed the preview-to-original handoff;
4. shared Reader close returned to the same source component identity;
5. cleanup force-stopped NextN, restored the display timeout to 10000 ms, and
   released the device lease.

Evidence root:
`.hermes-artifacts/20260912-shared-entry-capture-boundary-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/05-final/`.

Two earlier runs are retained as rejected harness diagnostics. The first used
`Driver.dumpLayout`, unavailable on this 197 runtime. The second proved the
delayed snapshot cancellation/discard facts but later hit a stale UI Test List
handle after pushing the same Detail again. Neither is counted as acceptance.

## Remaining replacement gap

Production thumbnail clicks still select the legacy Reader. The next source
action is a separate optional production relay that stages the current Detail
seed before shared navigation, consumes this host capture boundary, and leaves
the legacy route as fallback. It must then prove Detail and full-thumbnail-page
entry, single-page-to-spread expansion, cancellation/close lifecycle, current
source return, and no default migration before replacement readiness changes.
