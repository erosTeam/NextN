# Shared Reader Replacement Work Order

This is the only live execution queue for replacing the NextN, NextE, and Koma
readers with `reader-kit`. The architecture document preserves design and prior
evidence. Per-app QA ledgers preserve durable counterexamples and accepted
boundaries. Neither may create a second queue.

## Outcome

Ship one shared reader whose core interaction and UI are reused by all three
apps while each host retains ownership of catalogs, cache/download services,
settings, progress, actions, navigation, and Koma chapter orchestration.

Until Package 5 is accepted, every production default remains the legacy reader
and every shared route remains optional and reversible. No package migrates or
deletes user data.

## Execution contract

1. Exactly one package is `ACTIVE`; all others are `QUEUED` or `DONE`.
2. A package starts with a current-source owner map and ends with a complete
   user path. Individual controls, callbacks, tests, screenshots, builds, and
   devices are evidence inside the package, not milestones.
3. Implement the coherent source candidate first. Then run focused state tests,
   the complete `reader-kit` suite when shared code changed, and one matching
   build of every consumer. Do not rebuild between adjacent assertions.
4. Device coverage follows risk rather than multiplication: use 197 for the
   primary phone/runtime path and 103 for tablet, rotation, responsive layout,
   or one selected cross-check. A changed shared visual/layout owner requires
   both shapes; a non-layout host adapter does not automatically require both.
5. One ignored artifact directory and one complete protocol manifest belong to
   each package/device run. Git receives no run JSON and no paragraph per run.
6. Update the table below in place. A counterexample reopens its package; it
   does not create a new phase name. Commit only a coherent package candidate or
   accepted package conclusion.

## Replacement packages

| Package | Complete user path and ownership boundary | Release evidence | Status |
| --- | --- | --- | --- |
| 1. Resource lifecycle and recovery | Open real content; load visible and adjacent originals; switch/reload the exact visible source; keep unaffected panes; fail and retry one source; retire stale work on navigation, background, close, and fresh reopen. `reader-kit` owns request/slot presentation generations; hosts own URL/file/cache/download and source scope. | Shared state suite; affected-host tests; all three consumers build if shared code changes. Primary runtime on 197 for NextE and NextN; 103 only for spread/reflow-sensitive coverage. Existing legacy routes remain usable afterward. | DONE |
| 2. Host state and action parity | Enter from normal host state; inherit and change applicable layout/direction/spread/crop/interpolation/auto-read/keep-screen/tap/volume settings; preserve progress; execute every supported image/host action without inventing generic business behavior. | Per-host old-to-shared capability map has no silent omission; persistence cold-start path and legacy return pass; one phone run per host plus 103 only for responsive state. | **ACTIVE** |
| 3. Entry, chrome, thumbnails, and return | Detail, all-thumbnails, and reader-rail entry use the correct source identity and thumbnail geometry; single/spread/continuous/long-image UI and failure material remain legible; rotation/window changes keep anchors; close returns to the current source position and restores system UI. | Same-state full-page review on 197 and 103 for changed responsive/transition paths; NH partial thumbnails and EH sprites use their own host contracts; no known visual counterexample. | QUEUED |
| 4. Koma chapter orchestration | Open a real multi-chapter title; explicit previous/next chapter preparation, success, failure, cancellation, rapid A-B-C selection, last-chapter semantics, per-chapter progress/read state, local/remote/provider scope, and return all remain host-owned around the shared session. | Focused orchestrator tests, Koma build, 197 phone path, 103 tablet rotation/chapter path, unchanged unrelated library/download data, and legacy Koma reader fallback. | QUEUED |
| 5. Controlled production replacement | Each app can select the shared host at the normal reader entry without debug Wants, while a single explicit fallback restores its legacy reader. Cold start, repeated entry, upgrade, and rollback preserve settings/progress/data. | One pinned `reader-kit` revision consumed by all hosts; per-app full route matrix accepted on the selected release candidate; fallback verified before any app changes its default. Default selection remains a separate explicit release decision. | QUEUED |

## Package 1 completion — 2026-09-14

Current owner map:

- `reader-kit` owns slot/request/presentation generations, stale-result fences,
  retained-frame replacement, released assets, and session teardown on surface
  disappearance. It never invents a host URL, cache key, or source variant.
- NextN owns NH remote/local/download selection, immutable reload siblings,
  cache replacement, and presentation leases. Its transport cancellation is
  consumer-only; shared generations prevent retired results from presenting.
- NextE owns EH `/s/?nl=` source selection, per-gallery file cache replacement,
  and refreshed reload-key persistence. Its transport cancellation is likewise
  consumer-only; the adapter persists a refreshed source only after the request
  remains current.
- Fresh reopen is a new host adapter plus a new shared session. Background and
  close retire shared presentation state; hosts remain responsible for any
  longer-lived cache or download work they deliberately retain.

Accepted implementation and source evidence:

- `reader-kit` has stable page/source identities, independent adjacent slots,
  cancellation fences, retained-frame handoff, and host-owned asset providers.
- NextN has bounded device evidence for complete-download same-URI reload in
  single, continuous, and split-spread layouts.
- NextE has source switching and the same-URI reload candidate integrated in its
  optional host. Current-source comparison found that the optional adapter had
  been redownloading the selected CDN URL without invoking EH source switching;
  it now forwards manual reload into `ImageResolveService.resolve(..., true)`
  and saves the refreshed source only after its cancellation fence.
- Shared revision `1d1f515` exposes the reload-only More-menu path while
  retaining the same-URI replacement fix from `5e5cb4c`. All 359 reader-kit
  tests pass.
- NextE commits `81c0bdfa` and `733a5c2f` add the real-body failure/retry,
  exact single/spread source reload, background/explicit close, fresh-reopen
  chain and API-25-compatible evidence capture. Its 24 focused reader/host
  tests, signed main HAP, and signed `entry@ohosTest` HAP pass.
- This NextN work-order commit advances `third_party/reader-kit` to `1d1f515`
  and repairs two runtime fixtures to consume the tracked submodule and current
  enhancement providers. Reader contract, host-action, initial-policy, and
  original-probe suites pass; the complete debug HAP consumer build passes.
  The isolated worktree has no local signing profile, so this consumer result
  is a compile/package result rather than a new signed-device build.
- Koma consumes sibling reader-kit `1d1f515`; its shared preference bridge and
  complete debug HAP consumer build pass without staging or changing its broad
  unrelated main-branch worktree.

Accepted device evidence:

- NextN's existing 103 production-download runs retain complete local content
  through two same-URI reloads in single and continuous modes, and reload the
  two split-spread sources independently while preserving the partner. Queue,
  history, temporary settings, and legacy backend are restored afterward; see
  `docs/qa/nextn-active-acceptance.md` and
  `docs/qa/shared-reader-production-download-spread-reload-nextn-20260914.md`.
- NextE 103 passed the consolidated real-host lifecycle at
  `.hvigor/outputs/shared-reader-package1/device103__MLR-AL00/not-applicable/portrait-1600x2560/18-consolidated-lifecycle`:
  Hypium 1/1; body failure/retry; exact single reload; one-side spread reload
  with the partner request unchanged; background close; explicit close; and
  two fresh reopens. All ten full-screen captures were inspected.
- NextE 197 passed the same chain at
  `.hvigor/outputs/shared-reader-package1/device197__ALN-AL80/not-applicable/portrait-1260x2720/22-phone-crosscheck-final`:
  the protocol validator and internal Hypium both pass 1/1, five terminal
  captures were inspected, and the screen timeout was restored to 10 seconds.
  One preserved earlier run reached a genuine transient spread-source load
  failure; the unchanged HAP then completed the chain twice, once with internal
  Hypium 1/1 and once with the full protocol validator passing.

Boundary retained: these runs do not claim deterministic reproduction of every
natural network timeout, deleted/corrupt local file, cache eviction, or download
queue stall. Those host cache/prefetch policies remain Package 2 inputs. All
three production defaults remain legacy and every shared entry remains optional
and reversible.

## Current Package 2 delta

The first Package 2 omission is implemented without enlarging the render tree.
All three legacy readers persist `preloadPages` as a bounded numeric depth, while
the old shared path only enabled its immediate native render neighbor. Shared
revision `46de8c5` now keeps that render-neighbor bound unchanged and separately
schedules future visual destinations through `ReaderPreloadHost`: complete
spreads contribute both sources, continuous mode starts after the visible range,
split fragments deduplicate their source, and navigation, policy, range, depth,
unit and close changes cancel retired cache demand. Failure is diagnostic only
and cannot demote the visible session.

Hosts continue to own all cache policy. NextN warms the existing remote private
cache and skips fixture/downloaded pages; NextE resolves its existing default
source and warms `ImagePipelineService`; Koma calls its existing remote source
cache and skips local pages. No shared cache, eviction rule, download task,
persistence key or production route was added. Core tests pass 363/363; focused
host tests pass in NextN, NextE 7/7 and Koma; current NextE signed main/native,
NextN complete debug and Koma complete debug consumers build. NextN's isolated
worktree has no signing profile, so its result is not a signed-device claim.

On 103, NextE `dc5413ae` with reader-kit `46de8c5` passed the existing complete
failure/retry/reload/spread/background/close/reopen chain 1/1 in 48.389 seconds.
The actual host logged successful future cache warms for sources 2, 3 and 4;
the retried single page, finished spread and final host return captures were
inspected. Evidence is under
`.hvigor/outputs/shared-reader-package2/device103__MLR-AL00/not-applicable/portrait-1600x2560/01-nexte-preload-lifecycle/run`.
The protocol restored the 10-second timeout and released its lease. This accepts
the NextE adapter path.

Koma commit `d0abcfda` repairs the tracked clean-build module graph by declaring
the two local reader-kit modules without committing its machine-local signing
profile. A detached clean worktree at that commit and reader-kit `46de8c5`
produced the signed HAP with SHA-256
`cd37b65a5a93d145ba73f10c6f7c6c023ba838b984fdff35badeb11f95a01f46`.
On 197, the normal shared Koma reader opened an existing four-page remote
MangaDex unit with persisted `preloadPages=2`. The host logged the bounded
shared request `sources=1,2`, cache hits for both future HTTPS sources, and
`[KomaReaderPreload] ... result=ready` for each. The visible first page and
reader chrome were inspected at
`.hvigor/outputs/shared-reader-package2/device197__ALN-AL80/not-applicable/portrait-1260x2720/08-koma-remote-preload-call/run`.
After returning to the bookshelf, `reader-sessions.v1.json` remained
`32b2533f0346f3f996b9aba8b0d622a706b4286a8403cf8bebc30c2da89884cd`
and `library-store.v1.json` remained
`a997dba1315adba11d236307a66084c0dde19236a6f4a93062f7cd19725f015c`;
the final capture is under the adjacent `09-koma-return-host/run` artifact.
The protocol restored the 10-second timeout and the 197 lease was released.
This accepts the Koma cache-warm adapter path. NextN device runtime and the rest
of Package 2 remain open.

The next capability-map omission was Koma's persisted `pageGapMode`: the legacy
reader renders compact, normal, and wide spacing, while the optional shared host
previously read the preference without applying it. Shared revision `f114c10`
adds a host-neutral numeric `pageGap`, clamps it to `0..96vp`, and applies the
same geometry to continuous-list spacing and separated spread slots without
owning any host enum or persistence key. Koma commit `b9cff3ba` maps its existing
compact/normal/wide values to `2/8/18vp`; NextN `6ac368e6` and NextE `fbadff2b`
only advance the shared revision and retain zero as their unchanged default.
All 367 reader-kit tests and the Koma preference-bridge test pass. Matching
NextE signed, NextN debug, and Koma signed consumer builds pass; NextE's V1
inventory reports zero generated V1 artifacts. The clean Koma candidate was
built at `b9cff3ba` with reader-kit `f114c10`, SHA-256
`b76478a9a8b9a0a75948c3fbc4f15b2fb5e047ab85510166b7d8c9774cce9261`.

On 103, the optional continuous reader opened the controlled local chapter with
the inherited normal gap. The adjacent image bounds ended at physical pixel 472
and resumed at 491, a visible 19-pixel rendering of 8vp on that tablet. Evidence
is under
`.hvigor/outputs/shared-reader-package2-page-gap/device103__MLR-AL00/not-applicable/portrait-1600x2560/01-koma-continuous-gap/run`.
On 197, the same candidate opened the existing four-page remote MangaDex unit;
the first two image bounds ended at 1726 and resumed at 1752, a visible 26-pixel
rendering of 8vp on that phone. Evidence is under
`.hvigor/outputs/shared-reader-package2-page-gap/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-koma-continuous-gap/run`.
Both full-screen boundary captures were inspected. Their adjacent return runs
reached the existing bookshelf, restored the 10-second screen timeout, and kept
the reader-session and library-store hashes unchanged from each run's entry.
Both leases were released. This accepts inherited page-gap rendering in Koma's
optional shared reader; changing that preference from shared runtime UI and the
remaining Package 2 capability map remain open.

The next capability-map omission was Koma's persisted `rotateWidePages` policy.
Shared revisions `7761c16` and `cce3df6` add host-neutral wide-page
classification and clockwise rendering without coupling reader-kit to Koma's
preference enum or storage. Rotation uses original source metadata, is mutually
exclusive with split-page presentation, inverts the visual ratio, and preserves
crop/zoom/source-coordinate mapping in paged, spread, and continuous surfaces.
Because the host transition preview remains unrotated, the shared surface
deliberately cancels that mismatched preview instead of morphing between two
different orientations. The second revision only adds a strict optional Reader
Lab override so the policy can be exercised deterministically; an absent or
invalid Want parameter leaves every production entry unchanged.

Koma revisions `897c7bf7` and `041a4de0` map the existing preference into the
shared policy and add a packaged wide-page fixture. NextN revisions `a3e2c895`
and `a641549a`, and NextE revisions `bf25c7bf` and `e7aa2c4c`, only advance the
shared revision and keep their existing defaults. All 372 reader-kit tests and
the Koma preference-bridge test pass. Matching NextN complete debug, NextE
signed debug, and clean Koma signed debug consumers build; NextE's V1 inventory
reports zero live V1 decorators across 587 ArkTS files. The clean Koma candidate
at `041a4de0` with reader-kit `cce3df6` has SHA-256
`629d41a63bb11831c2444ed25fa9c1b1db8c03755013afd165099a557991ef73`.

On 197, the controlled 1920x1080 fixture rendered clockwise as a complete
1260x2240 blue-over-orange page in both single and continuous modes, and a
center tap hid the chrome. The inspected captures are
`.hvigor/outputs/shared-reader-package2-wide-rotation/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-koma-wide-rotation/run/single-screen.png`
and the unobscured continuous capture under adjacent run
`02-koma-continuous-rotation-hidden/run/screen.png`. On 103, the independent
1600x800 QA page rendered clockwise with its full outer border visible in
single mode; continuous mode showed its full width, and an upward swipe reached
the page's lower boundary followed by the next unrotated page. Those inspected
captures are under
`.hvigor/outputs/shared-reader-package2-wide-rotation/device103__MLR-AL00/not-applicable/portrait-1600x2560/01-koma-wide-rotation/run`.
Both protocol validators pass, both readers returned to the normal bookshelf,
the reader-session and library-store hashes remained unchanged, both screen
timeouts were restored to 10 seconds, and both leases were released. This
accepts inherited wide-page rotation in Koma's optional shared reader; changing
the preference from shared runtime UI and the remaining Package 2 capability
map remain open.

The subsequent `imageFitMode` review found no renderer behavior to migrate.
Koma had already removed that preference from the supported reader contract in
`748a519d` after the RDR-002 device finding; reintroducing it would create a
setting with no accepted legacy semantic and risk recreating fixed-viewport
long-image clipping. It is therefore compatibility-only/non-applicable for the
replacement map, not a deferred shared-reader feature.

Koma commit `ce627f4c` then reuses its host-owned settings sheet from the
optional shared route instead of duplicating persistence or application enums
inside reader-kit. The host maps the existing layout, direction, animation,
tap-zone preset/inversion, background, page number, fullscreen, keep-awake,
auto-read interval, preload depth, volume-key and page-gap preferences into
host-neutral shared inputs. The same signed candidate with SHA-256
`56b31b4559b9834391d69c10b6691e9ad08e0ea8f02c55c0e97775688c070855`
passed the phone setting-change/cold-reopen/restore path on 197 and the complete
responsive upper/lower sheet on 103. Both devices returned to the normal host,
restored the 10-second timeout and preserved their reader-session and library
hashes. Evidence is under
`.hvigor/outputs/shared-reader-package2-host-settings/device197__ALN-AL80/not-applicable/portrait-1260x2720`
and
`.hvigor/outputs/shared-reader-package2-host-settings/device103__MLR-AL00/not-applicable/portrait-1600x2560`.

The settings comparison also exposed a visible legacy behavior omitted by the
shared route: changing a tap-zone preset closes settings and presents the
resolved colored regions once, with reader chrome hidden and the first tap
reserved for dismissal. Shared revision `a6396e6` now owns that host-neutral
presentation, labels, input freeze and one-shot revision fence; hosts continue
to own preset semantics, normalized region geometry and persistence. Koma
commit `69a20f13` maps its existing geometry and only increments the preview
revision when the preset or inversion actually changes. The full reader-kit
suite and Koma preference-bridge test pass. Matching NextN debug, NextE signed
debug and clean Koma signed debug consumers build; NextE's V1 inventory remains
zero across 587 ArkTS files. The exact clean Koma HAP for `69a20f13` plus
reader-kit `a6396e6` has SHA-256
`7541ea95117c6948a4e355cf91f4c9dffe514f3482e25737f432fc18fd52183f`.

On 197, changing the observed `right_left` plus horizontal inversion to
`l_shaped` produced the correctly inverted five-region full-screen preview;
chrome was absent, one center tap dismissed the preview, and restoring
`right_left` produced the expected inverted three-region preview. On 103, the
same path over an existing two-page local chapter started at `1 / 2` and still
showed `1 / 2` after the dismissal tap, proving that dismissal did not also
turn the page. Both complete previews and their post-dismissal frames were
inspected, original tap settings were restored, reader-session/library hashes
were unchanged, logs contained no reader exception, normal hosts and 10-second
timeouts were restored, and both leases were released. Evidence is under
`.hvigor/outputs/shared-reader-tap-preview/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-preview-acceptance/run`
and
`.hvigor/outputs/shared-reader-tap-preview/device103__MLR-AL00/not-applicable/portrait-1600x2560/01-preview-page-invariance/run`.

The next source/device comparison found that Koma's shared settings exposed the
existing default `fullscreen=true` while its optional host constructed a trial
window with status-visibility control disabled. The legacy reader hides the
status area whenever chrome is hidden, so this was a real silent omission, not
a new shared feature. Koma commit `b2465627` now keeps that preference semantic
in the host: hidden chrome applies the host fullscreen value, and showing chrome
first restores the status area and waits for the safe-area layout to settle
before painting controls. reader-kit remains unchanged at `a6396e6` and only
provides the already shared window-operation sequencing and layout fence.

The focused Koma preference contract and complete Koma debug consumer build
pass. A detached clean worktree at `b2465627` plus reader-kit `a6396e6`
produced signed HAP SHA-256
`cdd59194bdfff4ea80c4b399b9a5cf4d0a35b528b030b47b329a2cebf2492b6b`.
On 197, the reader root changed from `[0,124][1260,2720]` with chrome/status to
`[0,0][1260,2720]` without either, then returned to the original safe area and
complete chrome. On 103 the corresponding roots were
`[0,105][1600,2560]`, `[0,0][1600,2560]`, and
`[0,105][1600,2560]`; the real two-page chapter remained at `1 / 2`.
All four hidden/reshown captures were inspected. Both devices preserved their
reader-session/library hashes, returned to the normal host, restored the
10-second timeout and released their leases. Evidence is under
`.hvigor/outputs/shared-reader-fullscreen-status/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-hide-show-restore/run`
and
`.hvigor/outputs/shared-reader-fullscreen-status/device103__MLR-AL00/not-applicable/portrait-1600x2560/01-hide-show-restore/run`.

## Single next action

Resume the Package 2 old-to-shared capability map after the accepted Koma host
settings, one-shot tap-zone preview and fullscreen status-bar lifecycle.
Compare the remaining legacy/shared chrome actions and host-owned navigation
surfaces in current source, then implement only the first actual omission with
its owner explicit; do not add compatibility-only settings or duplicate host
business behavior in reader-kit. Retain the exact
NextN boundary: its isolated branch cannot produce a signed matching package
without copying credentials or changing tracked signing state, so no mismatched
HAP may be installed merely to claim the remaining preload adapter runtime.
Implement and close the next coherent missing
capability through shared state, host adapters, focused tests, matching consumer
builds, and only the device shapes justified by its risk. Do not change any
production default or persistence key.

## Package completion record

Update one row here when a package closes: shared revision, host commits,
focused suite result, consumer build result, selected device/artifact roots,
observed user path, preserved fallback, and explicit untested/non-applicable
branches. Do not paste command transcripts or create a second status log.
