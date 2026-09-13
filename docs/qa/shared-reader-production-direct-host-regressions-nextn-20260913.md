# Shared Reader direct-host regression checkpoint — NextN / 2026-09-13

Status: **LIMITED PASS / replacement OPEN**. The current optional shared body
passes ordinary Detail entry, a phone failure/retry path, a tablet long-page
shared-versus-legacy comparator, and pending-preview cancellation followed by a
fresh opt-in. The default backend is not changed.

## Candidate identity

- Signed main HAP SHA-256:
  `ac7bc57d462b8187a9cc8eb08616cd946d7ea990771e7c1463c55be45779de92`.
- Accepted ordinary-entry, failure/retry and tablet comparator runs used signed
  ohosTest HAP SHA-256:
  `ee64f9c55c7c23f78286d24e5f2728462b816620f5862d8376ff1acf99be56b3`.
- After `ohpm install --all` refreshed generated dependency links to
  `third_party/reader-kit`, a cold signed main build and a cold
  `entry@ohosTest` build both passed. The cold signed main HAP SHA-256 is
  `43442739e762dd0bc063d6d89074f1345023fc66b0c16c81854eb461559a091c`.
- The accepted pending-preview cancellation run used signed ohosTest HAP
  SHA-256 `63d2d671092420aef03f0ee7d5cc969037c3273b4f8229a0e4f869cd2ca5241a`.
- The shared Reader remains selected only by the existing optional backend
  selector. Every accepted run restores history, settings where applicable,
  process state and the display timeout.

## Accepted device evidence

### Device 103 — ordinary Detail Read and rollback

- Exact protocol: retained as `protocol-manifest.json` under the local evidence
  root below.
- Evidence root:
  `.hermes-artifacts/20260913-shared-production-backend-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/02-direct-host-normal-entry/`.
- Hypium: `Tests run: 1, Failure: 0, Error: 0, Pass: 1`; duration
  `59.184s`.
- The real Detail Read action opened the shared body on page 1. A slider seek
  moved to page 8 and persisted progress. Close returned to the same Detail.
  Selecting legacy then reopened page 8 and closed to the same Detail. The exact
  prior history row and backend selection were restored.

### Device 197 — warmed production failure and exact retry

- Exact protocol: retained as `protocol-manifest.json` under the local evidence
  root below.
- Evidence root:
  `.hermes-artifacts/20260913-shared-production-failure-recovery-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/04-direct-host/`.
- Hypium: `Tests run: 1, Failure: 0, Error: 0, Pass: 1`; duration
  `26.092s`.
- The host resolved and warmed the real production page, injected one native
  decode failure, and displayed the shared recovery card over the retained
  opening context. Retry called the same NextN provider with `forceReload=true`,
  recovered page 1, closed to Detail and restored the exact prior history row.
  This is a deterministic decode/cache recovery test, not a claim that a natural
  transport outage was reproduced.

### Device 103 — extreme long page shared-versus-legacy comparator

- Exact protocol: retained as `protocol-manifest.json` under the local evidence
  root below.
- Evidence root:
  `.hermes-artifacts/20260913-shared-production-thumbnail-wide-direct-host-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/06-legacy-comparator/`.
- Hypium: `Tests run: 1, Failure: 0, Error: 0, Pass: 1`; duration
  `55.816s`.
- The same real P3 Detail thumbnail opened first through the direct shared body
  and then through the legacy body. Both rendered the same whole long page as a
  fully contained narrow strip and returned to identical source bounds.
- This is parity with the frozen paged-mode contract. Paged mode owns one
  viewport and uses whole-page `Contain`; continuous mode owns fit-width vertical
  flow. The previously repaired regression was fixed-height clipping after
  width-derived sizing, not the absence of per-page embedded vertical scrolling.
  No third long-page behavior is introduced by this checkpoint.

### Device 197 — pending-preview cancellation and fresh opt-in

- Exact protocol: retained as `protocol-manifest.json` under the local evidence
  root below.
- Evidence root:
  `.hermes-artifacts/20260913-shared-production-entry-cancel-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/26-focused-regex/`.
- Hypium: `Tests run: 1, Failure: 0, Error: 0, Pass: 1`; duration
  `62.701s`.
- The real Detail P1 preview was acquired before Back. Click-to-Back was
  `409ms`; the same epoch reported `accepted=true`, `delayedPreview=true`,
  `discarded=true`, `navigationChanged=false`, and `handoff=false`.
- Immediate return preserved the exact source bounds. The next six seconds
  remained on Detail with no shared or legacy Reader. A fresh Want created a
  new Detail instance (`detail-2` after `detail-1`), whose real P1 thumbnail
  completed the shared image handoff and then closed back to that exact page.
- All six captures were inspected: source, immediate return, no-late-open,
  fresh source, shared Reader, and fresh close. The harness now follows the
  dynamic semantic instance instead of retaining stale `List` or component
  handles; it does not use coordinate fallback.

## Remaining replacement gates

- Keep replacement status OPEN for the broader parity ledger, including the
  remaining continuous/paged settings and actions, offline/download behavior,
  rotation/fold adaptations, and Koma chapter handoff. These accepted slices do
  not authorize changing the default backend.
