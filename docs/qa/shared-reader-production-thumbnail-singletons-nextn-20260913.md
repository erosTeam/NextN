# Shared Reader production thumbnail singleton entry — NextN / device 197

Status: **LIMITED PASS**. This closes repeated cover/tail singleton entry for the optional shared backend. It does not switch the default backend or claim whole-reader replacement readiness.

## Contract under test

- Source: the real full-thumbnail Grid for NH gallery `678049` on device 197 (`ALN-AL80`, `1260x2720`, portrait).
- Temporary policy: horizontal RTL, split spread, `EVEN_LEFT`, first page alone.
- Sequence in one native test process: open P1, hold preview, deliver original, close to the exact Grid position; scroll to P14, repeat the same lifecycle, and close again.
- Required topology: both P1 and P14 are one centered whole-page part. Neither endpoint may invent a neighbour page.
- Isolation: snapshot and restore the exact History row, four reader-setting keys, legacy backend selection, process state and display timeout.

## Implementation boundary

- Gallery supplies only the live source geometry, gallery detail seed and selected page index.
- `reader-kit` owns pairing, singleton topology, content rectangles, preview/original replacement and page state.
- NextN's entry shell owns backend selection, capture admission, full-window visibility, system Back/status-bar coordination and route lifecycle.
- The shared backend now mounts its shared Reader body directly. HDS remains only the legacy navigation adapter; it is no longer a hidden runtime dependency of the shared body.
- Every shared route has a fresh route epoch, and the host clears the prior route's closing state synchronously before the child's `aboutToAppear` can observe it.

## Rejected evidence and cause

- Runs `22-final` and `23-final` showed that new stacks, new host nodes and unique HDS destination names still left the second Reader absent. Mutating an HDS path list was not proof that the native destination body mounted.
- Runs `24-final` and `25-final` mounted the direct host but the second body stayed an empty Column. The child's `aboutToAppear` ran before the container's `onAppear` and observed the prior session's `hostClosing=true`, so initialization correctly cancelled itself.
- These failed runs are diagnostic evidence only and are not included in acceptance.

## Accepted evidence

- Signed main HAP SHA-256: `ac7bc57d462b8187a9cc8eb08616cd946d7ea990771e7c1463c55be45779de92`.
- Signed ohosTest HAP SHA-256: `abdb73453f853b89fd2ff0c26d1d75e94d7f7c185f81c03dacd9e9088b08f50e`.
- Exact protocol: retained as `protocol-manifest.json` under the local evidence
  root below.
- Final artifacts: `.hermes-artifacts/20260913-shared-production-thumbnail-singletons-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/26-final/`.
- Hypium: `Tests run: 1, Failure: 0, Error: 0, Pass: 1`; duration `77.139s`.
- Runtime summary: `coverCentered=true`, `tailCentered=true`, `onePartEach=true`, `deliveredBoth=true`, `sourceRestoredBoth=true`, `historyRestored=true`, `settingsRestored=true`.
- P1 waiting/settled: only `rkit-part-0-whole`, bounds `[524,124][736,2720]`, page label `1 / 14`.
- P14 waiting/settled: only `rkit-part-13-whole`, bounds `[532,124][728,2720]`, page label `14 / 14`.
- Waiting states contain `rkit-entry-preview-image`; settled states contain `rkit-entry-image-0-1-1` and no preview/loading/failure node.
- P1 source and closed bounds match exactly at `[485,344][775,871]`; P14 source and closed bounds match exactly at `[485,1934][775,2461]`.
- Logs show two distinct full initializations and entry lifecycles: source indices `0` and `13`, each progressing `moving → waiting → revealing → finished`.

## Remaining replacement gates

- Keep the backend optional/default-legacy until the remaining production-entry matrix is closed: ordinary Detail Read, repeated non-thumbnail entry, failure/retry and capture fallback/cancel through the direct host.
- Cross-check the direct host on the 103 tablet, including adaptive layout and rotation.
- Continue closing the broader legacy parity ledger: continuous/paged modes, actions, settings, progress, offline/download paths and Koma chapter handoff. Passing this endpoint topology does not imply those unrelated capabilities.
