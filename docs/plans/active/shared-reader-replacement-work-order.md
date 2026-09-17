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
   primary phone/runtime path, 237 (HUAWEI Pura X `VDE-AL00`, an authorized
   test device per the user instruction of 2026-09-16) for large-screen,
   rotation, and responsive-layout coverage. Per the user directive of
   2026-09-17, 103 is an optional test support device, not a mandatory
   requirement; 103 availability must not be used as a blocking condition.
   A changed shared visual/layout owner requires verified responsive shapes;
   237 carries the other apps' real user state, so runs there must use
   `install -r` and must not assume an empty store. Work on 197 and 237
   proceeds autonomously without waiting on 103.
5. One ignored artifact directory and one complete protocol manifest belong to
   each package/device run. Git receives no run JSON and no paragraph per run.
6. Update the table below in place. A counterexample reopens its package; it
   does not create a new phase name. Commit only a coherent package candidate or
   accepted package conclusion.

## Replacement packages

| Package | Complete user path and ownership boundary | Release evidence | Status |
| --- | --- | --- | --- |
| 1. Resource lifecycle and recovery | Open real content; load visible and adjacent originals; switch/reload the exact visible source; keep unaffected panes; fail and retry one source; retire stale work on navigation, background, close, and fresh reopen. `reader-kit` owns request/slot presentation generations; hosts own URL/file/cache/download and source scope. | Shared state suite; affected-host tests; all three consumers build if shared code changes. Primary runtime on 197 for NextE and NextN; 103 only for spread/reflow-sensitive coverage. Existing legacy routes remain usable afterward. | DONE |
| 2. Host state and action parity | Enter from normal host state; inherit and change applicable layout/direction/spread/crop/interpolation/auto-read/keep-screen/tap/volume settings; preserve progress; execute every supported image/host action without inventing generic business behavior. | Per-host old-to-shared capability map has no silent omission; persistence cold-start path and legacy return pass; one phone run per host plus 103 only for responsive state. | DONE |
| 3. Entry, chrome, thumbnails, and return | Detail, all-thumbnails, and reader-rail entry use the correct source identity and thumbnail geometry; single/spread/continuous/long-image UI and failure material remain legible; rotation/window changes keep anchors; close returns to the current source position and restores system UI. | Same-state full-page review on 197 and 103 for changed responsive/transition paths; NH partial thumbnails and EH sprites use their own host contracts; no known visual counterexample. | DONE |
| 4. Koma chapter orchestration | Open a real multi-chapter title; explicit previous/next chapter preparation, success, failure, cancellation, rapid A-B-C selection, last-chapter semantics, per-chapter progress/read state, local/remote/provider scope, and return all remain host-owned around the shared session. | Focused orchestrator tests, Koma build, 197 phone path, 103 tablet rotation/chapter path, unchanged unrelated library/download data, and legacy Koma reader fallback. | DONE |
| 5. Controlled production replacement | Each app can select the shared host at the normal reader entry without debug Wants, while a single explicit fallback restores its legacy reader. Cold start, repeated entry, upgrade, and rollback preserve settings/progress/data. | One pinned `reader-kit` revision consumed by all hosts; per-app full route matrix accepted on the selected release candidate; fallback verified before any app changes its default. Default selection remains a separate explicit release decision. | **ACTIVE** |

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

The next legacy/shared action comparison found Koma's enabled `重置缩放`
command absent from the shared chrome. reader-kit `120bdba` now owns an explicit
navigation- and topology-fenced reset command and the transient active-viewport
zoom state; hosts do not receive image transform details. Paged and continuous
surfaces publish only whether the current viewport is zoomed, and continuous
identity now includes the existing wide-page rotation bit so the parent accepts
reports from the actual rotated row. Focused 32/32 tests and the complete
reader-kit suite pass. Matching NextN signed debug, NextE signed debug and clean
Koma debug consumer builds pass with HAP SHA-256
`3a5af85ed0e76fb321643fd692f3e70368cd7f0edfa33d3e3dcda36fb8fa20b0`,
`89817b89e5f6002f479f8a99dfefc00fd867cdc8c37647e5de92f5882dcb5cf7`,
and
`e202a4460f65a8147a8ae7ab55fc5a64aec5b53045ff694b013203e906994fd3b`;
NextN's final-HAP native-library gate and NextE's zero-V1-decorator inventory
also pass.

On 197, a one-page paged fixture changed the menu command from disabled to
enabled after double-tap and returned to the same fitted `1 / 1` frame after
reset. On 103, a real two-page local comic did the same at `1 / 2`, with byte-
identical reader-session and library-store hashes across reset. The tablet then
opened the independently imported rotated continuous fixture: double-tap made
reset available, reset returned it to the original complete rotated frame and
disabled the command, and a physical upward swipe subsequently exposed the
next green page, proving continuous scrolling was released. All before,
zoomed, reset and scrolled captures were inspected. Both devices returned to
the normal host with 10-second timeouts and released leases. Evidence is under
`.hvigor/outputs/shared-reader-zoom-reset/device197__ALN-AL80/not-applicable/portrait-1260x2720/{01-menu-state,02-reset-restore}/run`
and
`.hvigor/outputs/shared-reader-zoom-reset/device103__MLR-AL00/not-applicable/portrait-1600x2560/{02-local-comic-menu-state,03-reset-and-continuous-state,04-continuous-reset-restore}/run`.

The next remaining legacy action was Koma's centered chapter indicator and
arbitrary chapter sheet. Shared revision `8a85668` first exposed a generic host
center action; visual source review then caught that placing it in the top bar
would overlap the independently centered page counter. Revision `5d526ce`
moves the slot to the bottom action row used by Koma's legacy reader and adds a
source-position regression assertion. reader-kit owns only placement and an
exact unit/navigation stale guard. Koma commit `0115e341` owns chapter order,
titles, sheet rows, asynchronous preparation, cancellation and the final
session open; rapid B-to-C selection cancels the retired preparation and only
the latest target may present.

All 382 reader-kit tests and the focused Koma 4/4 chapter-picker suite pass.
Matching signed NextN (`1c08eaa5`), signed NextE (`29c535fa`) and clean Koma
debug consumers build with HAP SHA-256
`4fdc3a5029fe8ac14582b652cd1153238b723e56a657f6e2ade44b329d1ecc97`,
`9b5e413824415b4fb07571426c932e8dd9e7296275ec7f132b8a653e6c89af2d`,
and
`e1f9b60a6cb5e19f575b75cba23dd50ec1a1b2a2880ad53171a86a78c6d32a48`.
On 103, the real two-chapter local title opened Chapter1's two-row sheet,
switched to Chapter2 with the body changing from the red two-page chapter to
the blue three-page chapter and the indicator changing `1 / 2 -> 2 / 2`, then
reopened the sheet with Chapter2 selected and returned to Chapter1. The two
exact `chapter_boundary -> chapter_opened` pairs name the expected source and
target units. On 197, the same candidate kept `章节 1 / 1` complete and
balanced between the phone action groups, opened the one-row sheet without
clipping, and dismissed back to the same usable reader. All whole captures
were inspected. Both devices preserved reader-session/library hashes, returned
to the normal bookshelf, restored the 10-second timeout and released their
leases. Evidence is under
`.hvigor/outputs/shared-reader-chapter-picker/device103__MLR-AL00/not-applicable/portrait-1600x2560/{01-open-picker,02-switch-roundtrip}/run`
and
`.hvigor/outputs/shared-reader-chapter-picker/device197__ALN-AL80/not-applicable/portrait-1260x2720/{01-open-picker,02-dismiss-restore}/run`.
This closes the missing explicit selector in the Package 2 action surface; the
broader previous/next, failure/cancellation, final-chapter, progress/read-state,
remote/provider and rotation matrix remains owned by Package 4.

The following old-to-shared action audit confirmed that Koma's previous and
next chapter menu rows were already present in reader-kit and already delegate
to the host-owned prepare-before-open path. The first real omission was the
legacy `漫画详情` action. Koma commit `0399e257` supplies it through the existing
generic `ReaderHostAction`; reader-kit remains unaware of routes, comic IDs or
detail models. Koma validates the current unit, navigation revision and source
index again before delegating to `Index.openLibraryMangaDetail`.

The focused return-to-detail and chapter-selector contracts pass 6/6. A clean
detached Koma build at `0399e257` plus reader-kit `5d526ce` produced signed HAP
SHA-256
`aca9a795abe4a0ada62ece0cf5eb255d506394ab5c1eb3b292bfb55aa45b0f89`.
On both 103 and 197, the complete More menu showed an enabled `漫画详情` row;
selecting it opened the correct work detail, Back restored the same shared
reader frame, and a second Back returned to the normal bookshelf. All four
states were visually inspected on each device. Reader-session/library hashes
were byte-identical, exception logs were empty, timeouts were restored to 10
seconds and both leases were released. Evidence is under
`.hvigor/outputs/shared-reader-return-detail/device103__MLR-AL00/not-applicable/portrait-1600x2560/{01-open-menu,02-roundtrip}/run`
and the corresponding
`device197__ALN-AL80/not-applicable/portrait-1260x2720/` root.

The Koma progress comparison found no current omission. Legacy completion is
defined by the last source being successfully loaded and actually visible;
the shared bridge receives `ReaderObservedPosition` only after the current
original has decoded, completed a presentation frame, and still matches the
active unit, selection, navigation, slot and request. Koma continues to own the
existing `ReaderSessionStore`, page/chapter IDs, completion projection and
flush-on-close. Its store preserves a completed chapter monotonically, so a
later non-terminal position cannot silently unmark it.

Existing 103 evidence closes the runtime persistence path without another
broad replay. The final read-only run left the complete session document byte-
identical; the explicit write run changed the controlled two-page chapter to
page 2/2 and completed; a cold process restored 2/2; and the separate three-
page chapter still flushed page 3/3 when the reader was closed immediately,
then cold-restored 3/3. The four terminal screenshots were re-inspected against
the persisted rows. Evidence is under
`/Users/honjow/git/Koma/.hermes-artifacts/20260913-shared-reader-progress/qa103/device103__MLR-AL00/not-applicable/portrait-1600x2560/{01d-readonly-final,02-write,03-restore,04-fast-close,05-fast-close-restore}`.

The remaining Koma image actions also required no implementation change.
Current reader-kit contracts bind information to the displayed original and
retire late reads on replacement, retry, navigation, background and close;
save binds the exact displayed URI/request and owns independent temporary
copies; share cancels preparation on page, variant, activity or route change
and retains an already-presented system sheet until dismissal. Focused image
information/save/share tests pass 37/37.

On 197, the same signed Koma `0399e257` plus reader-kit `5d526ce` candidate
displayed real PNG information (`9.2 KB`, `1920 x 1080`), opened and cancelled
the system one-image save confirmation, then opened and cancelled the system
one-item share panel. The reader returned to the same 1/1 frame and then to the
normal bookshelf. All information/save/share/restored-reader/host captures were
inspected; reader-session and library-store hashes remained byte-identical,
the bounded log contained no reader exception, the timeout returned to 10
seconds and the lease was released. Evidence is under
`.hvigor/outputs/shared-reader-package2-koma-actions/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-image-actions/run`.

The legacy/shared action inventory now has equivalents for image information,
save, share, reload, reset zoom, previous chapter, next chapter and manga
detail; their placements may differ, but no supported action is silently
absent. Koma's Package 2 progress and image-action paths are now reconciled;
Package 2 remains active until the same bounded current-source audit either
accepts or repairs NextN and NextE host progress/action semantics.

The bounded NextN comparison also found no product omission in progress or the
four current-image actions. The legacy reader persists a canonical zero-based
NH source index from its Swiper/List page-change owner; that callback can precede
a newly selected image's successful presentation. The optional shared host
deliberately narrows this boundary and receives an observation
only after the current original is decoded, presented and still matches the
active unit, selection, navigation, slot and request; NextN continues to own
`HistoryRepository`, gallery metadata, thumbnail-entry precedence, immediate
Detail publication, durable serialization and close flush. Existing accepted
197 runs cover single, vertical, continuous and RTL-spread persistence, cold
restore, thumbnail precedence, adjacent failure isolation and selected-page
retry. They already demonstrate that a prefetched or failed source cannot
falsely advance history, while a successful Retry writes the selected page.

The same source audit confirms that shared information, save and share operate
on the actual displayed original rather than thumbnail/catalog geometry. The
shared spread menu preserves visual left/right/both source identity under LTR
and RTL. NextN retains its host-owned exact file/cache/download preparation,
system media dialog, canonical-gallery share fallback and external-open route.
The legacy-only enhancement/source-origin diagnostic lines are not separate
actions: the shared dialog reports the active source/enhanced/translated/original
variant and actual retained file facts, while processing policy and storage
origin remain NextN-owned. Existing 237 D8-D10 and save runs already cover real
system dialogs, single/spread selection, positive save, cancellation, failure,
page replacement, background and close. Current reader-kit observation and
image-action suites pass 84/84; current NextN progress/persistence/write-gate,
share-fallback and exact-download host tests pass. No reader implementation or
device replay was justified. One stale test entry did bypass the pinned
submodule by resolving a sibling checkout; it now loads
`third_party/reader-kit`, so isolated-worktree verification uses exact revision
`5d526ce`.

## Package 2 completion — 2026-09-14

The bounded NextE legacy/shared comparison found one real action omission and
no progress-owner omission. NextE commit `9a300a67` keeps its existing local
image-block service, rules, cache paths, confirmation and whitelist mutations
outside reader-kit while adapting the current source into the shared asset
notice/action boundary. Commit `f3560d18` adds a deterministic Debug-lab probe
without writing a subscription rule, and advances reader-kit to `1af283e` so a
suppressed source retains a neutral non-black presentation context. The focused
image-block, translation and super-resolution provider tests pass. The final
197 and 103 protocols each pass 1/1; complete action-menu and suppressed-source
screens were inspected at
`/Users/honjow/git/NextN/.hvigor/outputs/shared-reader-image-block/2026-09-14/device197/retry5/`
and the adjacent `device103/retry5/`. They prove the NextE-owned mark action,
the shared suppressed-source notice and allow action, and stable phone/tablet
geometry. They do not claim a live downloaded subscription-rule match or a
decoded backdrop preview: the deterministic rule probe was used and the
accepted notice uses reader-kit's neutral gradient fallback. No rule, image,
preference or production route was changed on either device.

Current legacy Reader progress publishes only after its thumbnail handoff has
settled and flushes through `GalleryReadProgressSettings`; the optional shared
route narrows publication to the current decoded/presented original while
retaining the same NextE-owned gallery key, RDB repository, startup restore and
close flush. Commit `493901fc` adds a two-process device contract around that
boundary. On 197, process one displayed page 2/46, persisted zero-based page 1
and flushed it; after an explicit process stop, process two cold-restored the
same complete page 2/46. Both full captures were inspected and the test finally
restored the exact original RDB row and removed its recovery file. Both Hypium
summaries pass 1/1; evidence is under
`/Users/honjow/git/NextN/.hvigor/outputs/shared-reader-progress/2026-09-14/device197/run4/`.
The final signed test HAP is
`b50b93ce75dcdff95e9e7d5d1fcd68bfbfad776be53b5a0b3f19c14203b3e9ce`;
the matching product HAP remains
`c9f6c344fdabe3680d4d97431ddb88ff33a07d30dc87afbf511e27651ce1b0a4`.

Together with the previously recorded Koma and NextN maps, all three hosts now
retain their own progress, cache, settings and business actions while the
shared surface owns only generic presentation and input. Package 2 is DONE.
This does not change any production default or accept normal-entry replacement.

## Current Package 3 delta

The bounded NH identity/geometry pass is implemented and accepted for NextN's
Detail progressive strip, View all entry, optional shared entry and reader rail.
NH partial thumbnails use their decoded thumbnail aspect with bounded `Cover` or
`Contain` presentation instead of the original full-image ratio; the gallery
source index remains host-owned through entry, rail selection and return. The
previously accepted 197 phone and 103 tablet/landscape paths cover a real long
strip, normal Detail entry, full-grid entry, RTL split destination geometry,
cover/tail singleton entry, pending-transition cancellation and exact host
return. This does not reuse or alter NextE's sprite-crop contract.

The next source omission was shared rail lifetime. `ReaderSurface` used to mount
`ReaderThumbnailRail` only while chrome was visible, so closing the rail also
closed its `ReaderThumbnailWindow` and released decoded thumbnail assets.
Reader-kit revisions `8918dc3` and `88cfa2e` keep the rail mounted for the
current unit, collapse and clip only its wrapper, disable hidden hit testing,
and animate the 156-to-0 geometry. No host cache, thumbnail provider, source
ratio or business route moved into reader-kit. The focused host-action UI suite
passes 12/12 and the complete reader-kit suite passes 388/388.

NextN and NextE both consume `88cfa2e` only on their isolated
`codex/shared-reader-refactor` branches. Their signed product builds pass with
SHA-256 `ff33aa91207661b7414c861af5cbc590d31485c7df032a0b7db2a1847718f7c9`
and `e0e30ffe475bacd555db341042663d6be4c8fbafd66775a8e603c0b48b61c2dc`;
their final signed test builds also pass. On NextN/197, the final protocol and
Hypium both pass 1/1 in the `accepted-3` run. On NextE/103, Hypium passes 1/1 in
the `accepted-2` run. Open, hidden, reopened and closed full-screen captures
were inspected: hidden chrome contains no thumbnail rail, reopening retains the
same page and immediately exposes displayed thumbnail state, and close returns
to the host. The 103 layout export confirms that the clipped wrapper is absent
from the UI tree; 197 does not expose the API-26 layout-dump method, so its final
manifest correctly requires screenshots only. Both screen timeouts returned to
10 seconds and both leases were released.

The return-path owner map no longer asks a host to infer which page the shared
Reader most recently painted. Reader-kit revisions `7e014a7` and `52c80b3`
capture a close context only from an actually observed presented frame, expose
its unit/part identity and capture component, and derive its display ratio from
the same split/crop/rotation-aware calculation used by the viewport. The
contract remains host-neutral: reader-kit does not import NH/EH models,
thumbnail scopes, navigation, status-bar policy or target geometry.

NextN now maps that context back to its own `NhGalleryPage`, preserves the
existing `ReaderEntryTransition` as the forward-flight owner, and arms only a
return target family for the optional shared route. Close restores the status
area first, updates the current host page, waits for the live current-thumbnail
layout, remeasures its current root-relative geometry, and uses the reader-kit
capture and ratio for the return proxy. Legacy admission, the default backend,
entry-time geometry, thumbnail radius and target ownership are unchanged.
The focused host runtime passes 18/18; transition, core, backend, progress,
data-source and preference contracts pass; signed main and test builds pass
with SHA-256 `5d4c47f45e779213bb5afeed0ce4643c524ff703111a1189c9fe119ce4464ca7`
and `4741fa5e60d2e60d28574bdb3b6029f75a47cd0f211ef5bb290436911965e620`.

On 103, the normal Detail P3 compact thumbnail entered the optional shared
Reader under the device's existing RTL direction, a physical swipe changed the
observed page to P2, and close returned to the already retained P2 thumbnail.
The before/after target bounds were identical and Hypium passed 1/1. The full
source, changed-reader and closed-Detail captures were inspected; the closed
host reports `Continue P2`. History and backend selection were restored, the
screen timeout read back as 600000 ms with no override, and the lease was
released. Evidence is under
`.hvigor/outputs/shared-reader-close-context/nextn-103/current-page-return-3/`.
This accepts the current-page return on the NextN tablet shape, not NextE or
Koma adoption and not a production-default change.

NextE commit `a391e19b` now consumes the same close-context contract without
replacing its EH sprite-crop owner. The optional host maps the observed shared
frame back to its own gallery image, remeasures the retained live Detail target,
and lets the existing transition coordinator animate the captured reader frame
back into that target. The focused host runtime passes 18/18 and matching signed
main/test builds pass. On 197, the matched-HAP Detail-thumbnail route opened the
shared spread, captured the actually presented source, closed through the live
sprite target with unchanged root and target bounds, and returned to the retained
Detail host. Hypium passes 1/1 and the source, reader and closed full-screen
captures were inspected under
`.hvigor/outputs/shared-reader-close-context/device197__ALN-AL80/not-applicable/portrait-1260x2720/03-matched-haps-current-thumbnail-return/`.

The next thumbnail-entry comparison found a separate host regression in both
gallery adapters: they deliberately forced crop off and removed the crop action
whenever the entry source was a thumbnail, even though crop is a reader setting,
not a transition capability. NextN and NextE now resolve the saved host crop
policy for every production entry. They reuse reader-kit's existing geometry
gate: when the cropped landing frame cannot map to the captured thumbnail, only
the optional flight is cancelled while the correctly cropped reader remains
visible. No thumbnail ratio, sprite crop, source identity, persistence key or
legacy route moved into shared code. Focused NextN/NextE policy and host-entry
contracts pass; reader-kit entry/geometry/transition/preview contracts pass
35/35; both signed product builds pass. On NextN/197, the real Detail P3
thumbnail opened the optional shared reader with saved paged crop, stayed
interactive, closed to the retained Detail page, and restored history and all
temporary settings. Hypium passes 1/1; the two inspected captures and checked
metadata are under
`.hvigor/outputs/shared-reader-crop-parity/nextn-197/run-2/`.

The subsequent NextE source audit corrected an over-broad Package 1 conclusion:
the legacy Reader calls `ReaderLocalSourceService.preferLocal` before any EH
request, while the optional shared adapter previously always opened the remote
gallery detail. NextE now keeps this ownership in the host adapter. A complete
gallery download is selected before the network, supplies its immutable local
files to the shared session, skips remote preload, and shares the selected local
image as an image record; incomplete or unavailable local state still falls back
to the existing EH request path. Reader-kit remains unaware of download queues,
archives, EH identities and cache paths. The focused source contract passes 8/8,
the signed product and test builds pass, and the API-26 decorator inventory is
zero. On 197, an isolated two-page complete-download fixture opened the optional
shared Reader at `1 / 2` without any network fallback, displayed the local image,
closed back to the retained host, restored the exact in-memory queue and removed
the temporary files. Hypium passes 1/1; both full-screen captures were inspected
under
`.hvigor/outputs/nexte-shared-reader-local-source/device197__ALN-AL80/not-applicable/portrait-1260x2720/run/`.
This closes the demonstrated complete-download omission. The archive selection
uses the same host service and local-asset branch but is not separately claimed
as device-accepted.

The normal NextE thumbnail-entry audit then found a second source-ownership
gap. Detail and All thumbnails already construct the complete legacy
`ReaderParams`, including the selected index, loaded EH preview images, sprite
metadata, source language and the exact tapped `/s/` URL, but the optional
shared entry previously discarded it and refetched gallery detail. NextE commit
`72f71587` carries that host-owned context through the optional relay and lets
the adapter initialize from the exact supplied seeds after the existing local
source check. Direct debug launch retains its old remote-detail fallback.
Reader-kit remains unaware of EH models, routes and cache policy; the legacy and
default reader admission are unchanged.

The focused entry/source contracts pass 34/34, the API-26 decorator inventory
reports zero live V1 decorators across 590 ArkTS files, and matching signed
product and test builds pass. On 197, the normal retained Detail page opened the
optional shared spread from its first sprite thumbnail. The in-process source
assertion and runtime log both report `source=hostEntry`, index 0, 46 pages, 40
seed images and an exact image-page URL. Hypium and the protocol validator pass
1/1; the source, reader and closed full-screen captures were inspected under
`.hvigor/outputs/nexte-shared-host-entry/device197__ALN-AL80/not-applicable/portrait-1260x2720/run-2/`.
Close returned to the same retained Detail page. All thumbnails uses the same
coordinator and parameter contract and is source/build-covered, but is not
separately claimed as physical-device accepted.

The Koma thumbnail invalidation follow-up found no missing implementation and
therefore added no duplicate host state. `ReaderSurface` already keys the
retained rail by scope, work, unit and page count; a committed chapter replaces
that component, closes its `ReaderThumbnailWindow`, and the window's existing
unit fence releases retired leases and rejects late callbacks. Shared revision
`638353d` also encodes the full identity into an ArkUI-safe collection key. The
current 103 chapter-resume run after that revision visibly committed Chapter2
at its restored page 3/3; the earlier 197/103 chapter roundtrip and tablet
rotation paths remain the selected cross-shape evidence. This audit removes a
stale work-order item rather than manufacturing a Koma-only cache owner.

Package 3 is DONE. These runs close retained rail show/hide/reopen on an
NH phone and EH-sprite tablet, the current-frame return boundary in both gallery
hosts, thumbnail-entry crop inheritance on the selected NextN phone route,
host-owned source identity on the selected NextE phone route, and the existing
tablet rotation/window anchor paths. NextE All thumbnails and archive selection
are source/build-covered through their shared host contracts but are not
separately claimed as physical-device runs. All production defaults remain
legacy and reversible.

## Current Package 4 delta

Koma commit `381f5fcd` adds the missing host-owned catalog seam for a transient
provider title that has not been persisted into the library. The optional
shared adapter now asks Koma for an immutable chapter configuration before it
falls back to its on-disk library snapshot. Koma continues to own provider
resolution, remote headers, offline/source hydration, library state and local
folder permission activation; `reader-kit` receives only the resolved unit and
page identities. The production default and legacy reader route are unchanged.

The focused catalog/chapter/return/preference suites pass 11/11. A matching
Debug HAP builds successfully with SHA-256
`b21c1e350e8c06d5044c69942726e5876a849963f6f8acdc58893db31aa0963b`.
This is source/build evidence only: no device acceptance is claimed yet.

Koma commit `54826d82` then closes the source-side commit boundary. A prepared
chapter does not mutate Koma history. Only the existing shared observation for
an actually presented original commits the Koma-owned active source request;
the same immutable chapter configuration then supplies page identity for
chapter-local progress even when no library record exists. Repeated observations
are idempotent. Failed, cancelled and retired A-B-C preparations leave the old
host chapter and progress untouched. The focused suites pass 12/12 and the
matching Debug HAP builds with SHA-256
`4b0550bf65502a6318f521ed0c55f24328fff7ce931883694d451a63ac9c2073`.
On 197, an existing unshelved DM5 history item entered the optional shared
reader without changing the production default. The host resolved 174 real
chapters, displayed the first original, switched through the shared chapter
picker from chapter `1328356` to `1328531`, displayed the new original at
`1 / 19`, and persisted the new chapter/page identity while the exact library
store hash remained unchanged. Close returned to the existing History page and
the screen timeout was restored to 10 seconds. The inspected source, picker,
new-chapter and return captures are under
`.hvigor/outputs/shared-reader-package4-koma-transient/`.

That selected run also exposed a real host projection defect: the persisted
source history was already chapter 2, but `HistoryPage` reused nodes keyed only
by `comicId` and section name, leaving a stale chapter-1 card visible and briefly
duplicating the item after it moved from Last 7 days to Today. Koma commit
`548725c5` keys each row and section by the chapter, page and grouping content
that actually drives its UI. The focused history/catalog/chapter/return/
preference suites pass 14/14, and the matching Debug HAP builds with SHA-256
`d4769aad9899697744dd24ac1a9a61d2694d5949648ce49f4721fc728f6639cc`.
The source and build fix is complete; the corrected final History projection is
not yet claimed as device-accepted.

The same comparison then closed two source-level chapter regressions instead of
adding more device repetitions. Koma `bd9ec10f` rejects a real provider handoff
when page resolution returns no pages, so the current readable shared chapter
remains active and the existing failure toast/retry path is used; an unavailable
target is no longer opened as a synthetic `source-placeholder://chapter` unit.
Koma `ce293938` separately restores the legacy manual-picker contract: the
picker projects every `chapterId`, while only Previous/Next use the host's
verified `continuationChapterIds`. Chapters outside one automatic continuation
group therefore remain manually reachable. The combined focused suites pass
15/15 and the matching Debug HAP builds with SHA-256
`437ab2658f54205bc58f14987ce0a5cf5c0d880a535b2b86b995c117bba516e6`.
Neither change alters the production default or moves catalog policy into
`reader-kit`; current physical-device acceptance remains pending.

Koma `0887488f` then removes a redundant provider round trip on the initial
shared presentation of an already resolved transient source chapter. Only the
exact active request and matching complete immutable `readerSessionConfig` are
reused; any different chapter still goes through Koma's provider preparation
and cancellation fence. This avoids turning a successful normal source open
into a second network dependency before the shared surface can paint. The same
15/15 focused suites pass and the matching Debug HAP builds with SHA-256
`c49a8bb1c5f0ad7c636a1e4329a3cde3ee2b4e51043e3914d81bd3b6f46f3480`.

The matching `0887488f` candidate then passed the remaining 197 projection
check. A cold normal Koma launch opened History after installing the exact HAP;
the transient DM5 title appeared exactly once under Today with chapter 2 and
user-visible page `2 / 19`. The previously stale chapter-1 duplicate was absent,
the bounded exception log was empty, and the unrelated library-store hash
remained
`a997dba1315adba11d236307a66084c0dde19236a6f4a93062f7cd19725f015c`.
The expected value had previously been written as `1 / 19`; that was a work-
order error because persisted zero-based page index 1 correctly projects as
user-visible page 2. The inspected terminal capture and layout are under
`.hvigor/outputs/shared-reader-package4-koma-transient/197-history-projection-fix/run/`.
The protocol restored the screen timeout to 10 seconds and the device lease was
released.

Package 4 is DONE. Koma commits `381f5fcd`, `54826d82`, `548725c5`,
`bd9ec10f`, `ce293938`, and `0887488f` close transient-provider catalog
resolution, commit-only history mutation, final projection identity,
unavailable-target rejection, complete manual chapter selection, and reuse of
the current resolved source snapshot. The 15/15 focused suites and matching
Debug HAP pass. The current 197 DM5 provider path covers a real unshelved
multi-chapter switch and final return; the selected 103 local-folder chapter
roundtrip and portrait/landscape anchor path remain recorded in
`docs/qa/shared-reader-koma-chapter-handoff-current-20260912.md`. Failure and
rapid A-B-C cancellation remain focused source/state evidence rather than
physical-device claims. The production Koma default and legacy fallback remain
unchanged.

## Current Package 5 delta

NextN commit `3425a980` exposes its existing process-local backend selector at
the normal routed Settings → Reading destination in Debug builds. The row uses
the existing HDS grouped-dropdown grammar and selects either the shared or
legacy backend for the next normal Reader admission; it is deliberately absent
from the in-session Reader settings sheet so changing a selector cannot imply
that an already-open route changed implementation. The route continues to
snapshot the backend at open time. Release builds fail a shared selection
closed to Legacy, normal cold launches reset Legacy, and no value enters
preferences, backup, migration or user data.

The selector/direct-host/legacy-adapter focused test and the 18-case entry-host
suite pass. Matching signed Debug and Release consumers build successfully with
SHA-256 `850541b3b1d6167fbec0d2ac285548456deb423c44a9078d47d86e7131d463ee`
and `c725d7ac602f0fcb353fe2992632f03ca0f873901b323b303393fb0be14feb9d`.
Normal Detail start, compact thumbnail, all-thumbnails and downloaded-gallery
routes already converge on the same selector/snapshotted route; a rejected
shared source claim keeps the existing legacy thumbnail path. This is
now joined by the selected phone runtime path.

NextN commits `db65006e` and `843b7a42` add a permanent normal-entry rehearsal. On 197, the
accepted `run-3` starts without a backend Want and observes Legacy, selects
Shared from Settings → Reading, opens gallery `556817` from the normal completed
Downloads row, touches the shared surface, closes back to Downloads, selects
Legacy in the same row, and repeats the same entry/touch/close path. Hypium
passes 1/1 in 62.939 seconds. The queue snapshot is byte-equal and the exact
eight-column history snapshot is restored. All seven full-screen captures were
inspected; shared and legacy both display the same local page `46 / 46` and
return to the same Downloads root. The apparent clipped Shared label in the
desktop preview was checked against the captured device layout: both five-
character values own the same in-row bounds `[880,478][1108,531]` and remain
inside the row.

The accepted signed main HAP is `7c1788c5…b0572f`; the explicit signed
`entry@ohosTest` HAP is `86e3681f…51f7e`. The first run is rejected because the
main-only build left an old test HAP on disk and therefore registered zero
Hypium cases. The second run is retained as a test-navigation counterexample
after selecting Shared, not a product failure. Neither is used as acceptance.
The final protocol restored the screen timeout to 10 seconds and released the
197 lease. Release still fails Shared closed to Legacy, cold launch resets
Legacy, and no preference, backup, migration, download, cache or user data owns
the selector.

NextE commits `63d69c6e` and `29cc7a38` provide the equivalent Debug-only
process-local selector, normal overlay host and thumbnail-entry relay. The
accepted 197 `03-normal-entry-rehearsal` run starts in Legacy, selects Shared
from Settings → Reading, opens the normal completed-download row, interacts
with and closes the shared surface, then selects Legacy and repeats the same
entry/interaction/return path. Its seven inspected captures and manifest are
under `.hvigor/outputs/shared-reader-package5/device197__ALN-AL80/not-applicable/portrait-1260x2720/03-normal-entry-rehearsal/`.
Release and ordinary cold launches still fail closed to Legacy, and the
selector remains outside preferences, backup and user data. That release half
now carries its own device evidence instead of a source reading (2026-09-16,
197). The `product=default buildMode=release` HAP
`ec9b45dd0f960ceadfbf853c0f8b06cea23580517cdbbc930c85d215c9222bec` installed
over the running debug build with `install -r`, keeping the debug-signed
profile so user data survived. Five accepted protocol runs under
`.hvigor/outputs/nexte-release-failclosed/device197__ALN-AL80/not-applicable/portrait-1260x2720/`
show: Settings → 阅读 no longer renders the `替换演练` group or
`nexte-reader-backend-rehearsal-row`, inspected against the 10:04 debug probe
that did render it; a cold launch through the ordinary Settings → History →
Detail Read route opened `reader_key_surface` with zero `rkit-*` nodes at
`4 / 46`; centre tap, Back close, and a reopen kept the same legacy surface and
page; closing returned to the same Detail pane at `继续 P4`; and the device's
own `bm dump` reports `debug: false`, `versionCode 39`, `versionName 1.3.4`.
The durable `gallery_read_progress` row stayed at `page_index 3` throughout.
197 was then restored to the rebuilt debug candidate
`76b446355227a700100b80dd4bc00f0e270f52593bb479ebd35fc6ea499c3c17` with
`debug: true` re-read, and the lease was released. One earlier attempt at the
close step ran while the device was locked and returned `No Error` while its
layout showed `ScreenLockRootComponent`; it is kept as
`04a-locked-attempt-rejected` and is not acceptance.

After that replacement boundary, the three consumers and reader-kit continued
to collapse host integration into capability objects without changing their
production defaults. The current shared revision `8112355` adds
`ReaderTapPolicy`, grouping the resolver, preview geometry and one-shot preview
revision that must describe one tap-zone preference snapshot. Existing scalar
inputs remain source-compatible so an older consumer is not broken by the
library update. NextE `c1e5eeee` and NextN `26c3bd62` adopt the grouped
capability. The focused cross-host suite passes 1404 actual resolver/lifecycle
comparisons and now asserts both consumers use the grouped contract; matching
signed builds pass with HAP SHA-256
`67e3636de4c76d1cbd853d954b8595bb059b014319968ec7067467b179fff989`
and `14035287b7305a46ef2c1a5afe976ca71dc69f0b97e5e348b7738679744be5fb`.
Koma `2af9c3db` now adopts the same grouped capability. The cross-host suite
executes all 1404 resolver comparisons through the actual `ReaderTapPolicy`;
Koma's preference bridge and matching signed build pass (HAP SHA-256
`870fd78c6ec2012645a68ba90a88f60323b09270cb7870ae21ab054fb90815eb`).
On 197, the current before/after candidates both open the same real 23-page
chapter, reveal the L-shaped horizontally inverted preview, dismiss it without
moving from `1 / 23`, and advance to `2 / 23` only on the following navigation
tap. The inspected preview and dismissed screenshots are byte-identical;
foreground, viewport and unchanged library/session hashes are verified.
Evidence is retained in Koma's independent worktree under
`.hermes-artifacts/20260915-tap-policy/device197__ALN-AL80/not-applicable/portrait-1260x2720/{03-replay,04-candidate}`.
This accepts the zero-visible/gesture-difference Koma adoption, not normal-entry
replacement or a change to production defaults.

## Session handoff — 2026-09-16

State at this handoff. Package 5 stays **ACTIVE**. Every production default is
still Legacy, and the shared reader remains an explicit, reversible selection.
One work item remains open (item 3); items 1 and 2 were closed later in this
session:

1. ~~Koma cross-version upgrade/rollback continuity~~ — **executed 2026-09-16**
   (detail in the Koma bullet below). Two distinguishable builds were used:
   candidate `8f11c550` (HAP `14ff92f7`, has the selector) and the older
   `main` `0399e257` (HAP `028562a8`, no selector). The older revision resumed
   the candidate-written page through the ordinary entry and left the row
   unchanged, the candidate was restored, and the touched chapter matches its
   baseline field-for-field. Row 5's per-host upgrade/rollback requirement is
   therefore satisfied for all three hosts. The *settings* half of the same row
   was then executed too: Koma keeps reader settings in
   `koma_reader_preferences_v1`, separate from the progress document, and the
   store name is identical in both revisions. The candidate changed
   `reader.fullscreen` through the real settings toggle (`true` -> `false`, the
   rendered `Toggle` reading `checked=false`); the older `0399e257` build then
   read `reader.fullscreen=false` from the durable store and rendered its second
   `Toggle` as `checked=false`, while proving it is the older build by having no
   `阅读器实现` row at all; the candidate was reinstalled and the toggle returned
   to baseline. The restored store is byte-identical to the pre-run file, so no
   user setting was left changed. Evidence:
   `.hermes-artifacts/20260916-koma-crossversion/{05-settings-probe,06b-settings-write,07-rollback-settings,08-restore-settings}/`.
   A first attempt tapped a guessed point and changed nothing; it was discarded
   and the real `Toggle` bounds were read from the settings layout instead.
   Koma's Row 5 upgrade/rollback obligations are therefore executed for both
   progress and settings.
2. ~~NextE release fail-closed admission~~ — **executed 2026-09-16** on 197.
   `product=default buildMode=release` HAP `ec9b45dd0f960cea` installed with
   `install -r` over the debug build (same debug-signed profile, so user data
   survived) hid the experimental selector, cold-opened Legacy `4 / 46` through
   the ordinary Settings → History → Detail Read route, kept Legacy through
   centre tap, Back close and reopen, returned to the same Detail at
   `继续 P4`, and reported `debug: false` from the device itself. 197 was
   restored to the rebuilt debug candidate `76b44635`. Detail and the discarded
   locked-device attempt are in the release paragraph above.
3. ~~103 tablet ordinary admission~~ — **OPTIONAL / NON-BLOCKING (user directive 2026-09-17)**.
   103 is designated as an optional test support device, not a mandatory
   requirement for production replacement, and must not be treated as a blocker.
   Large-screen, rotation, and responsive layout coverage is officially
   carried by the authorized 237 device (HUAWEI Pura X `VDE-AL00` `1320x2120`),
   where both `ReaderProductionAdaptiveRotationTrial` (split spread) and
   `ReaderProductionContinuousRotationTrial` (tall continuous scroll reflow)
   have passed with full physical screenshot review.

Evidence closed in this session (2026-09-16), each replacing an earlier OPEN
row or unproven claim: NextN `ecaafec3` and NextE `2bebd112` main-revision
resume, exit-write, and position restore inside the rolled-back revision
itself; the visual review of the NextN 197 trial's 7 captures; the corrected
status-bar analysis; the Koma candidate install-replacement record re-read from
the raw session artifacts (candidate-only, as scoped above); the 237
large-screen ordinary-entry admission for NextN and NextE; and the 237 rotation/responsive trial.

## Earlier Koma normal-entry record

Koma commit `c670b249` now passes the selected normal-entry 197 route in its independent
`codex/koma-reader-refactor` worktree. Debug HAP `f16378f7…93a124` opens from the
normal Settings selector and Library Continue action, displays the restored
original at 6/35, toggles chrome, swipes 6→7→6, returns through Manga Detail,
closes/reopens, and selects another chapter from Detail at 1/32 before restoring
6/35. One close then returns to Library, without an extra Reader destination.
The same-process explicit Legacy fallback is usable. Release HAP
`3105cb06…9a8d9f` hides the selector and cold-opens Legacy at 6/35 with working
touch/close/reopen. The foreground, full originals and legacy baseline comparison
were inspected; 28 focused checks and both builds pass. No data was cleared or
backend preference persisted. Evidence is in Koma's ignored
`.hermes-artifacts/20260915-entry-baseline/device197__ALN-AL80/not-applicable/portrait-1260x2720/`,
especially `21-single-monitor-reader`, `22-legacy-fallback`,
`24-detail-selected-chapter`, and `26-release-legacy`. An identical-path
`@Monitor` overwritten by the later chapter listener caused the initial loading
stall; one activity listener now owns initialization and chapter cancellation.

Koma `da3c2750` replaces the sibling dependency with the same tracked submodule
contract as the gallery hosts, pinned to `8112355`. After explicit user approval,
the verified `3003h` SSH identity fast-forwarded public reader-kit `main` to that
exact revision; a fresh empty repository fetched it successfully over public
HTTPS. The global `gh` identity was not changed.

A fresh non-local Koma clone at `da3c2750`, recursive public submodule fetch and
`ohpm install --all` produce Debug and Release HAPs without a sibling reader-kit,
local signing profile or pre-existing project build/dependency directories.
The public unsigned Debug HAP is `d394cfb54e1efc91fa326f90fb32af7f79d2cb65b1e3aa891433160a286c9aed`;
Release is `d4d3488cdbdd9692bef741dc8812d5d57ee60feadfec5ab8673cd6041b69a294`,
with bundle `com.honjow.koma`, `buildMode=release`, `debug=false`. All 28 focused
host checks pass and the tracked lockfile stays unchanged. The existing signed
Debug build also passes. Logs are retained in Koma's ignored
`.hermes-artifacts/20260915-reader-pin/`. This is clean-checkout build evidence,
not a cloud CI run or additional device acceptance.

NextN `ReaderProductionInAppDetailEntriesTrial` now covers the in-app admission
path that the earlier rehearsals only reached through a backend Want: one process,
Home to Settings selects Shared or Legacy through the existing row, Home History
opens the same gallery, and Detail Read, the compact thumbnail and the full-grid
thumbnail each admit a Reader. Hypium passes 1/1 and all seven captures were
received. Node-level inspection of the same run's layouts shows the two Shared
admissions render `rkit-reading-surface` (19 `rkit-*` nodes, page 3/14 and 2/14),
the two Legacy admissions render `legacy-reader-surface` with zero `rkit-*` nodes,
and the final state is the Home root with no Reader mounted.

Three rejected runs are retained as scaffolding counterexamples, not product
failures: a relaunch mid-rehearsal resets the documented cold-start Legacy
default; a sticky List handle after the Reader closes; and an unguarded stale
handle during recomposition. The first is by design; the other two were test
harness races. Evidence:
`.hvigor/outputs/shared-reader-package5/20260915-normal-entry-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/`.

At the pinned revision, NextE's in-app admission was rechecked on 197 because its
previous acceptance predated `8112355`. `ReaderProductionInAppBackendRehearsalTrial`
passes Hypium 1/1 on the current signed main plus freshly rebuilt `entry@ohosTest`
HAP (`02ab79d4fe5a`): initial Legacy, Shared selected in-app, the normal completed
Downloads row opened/touched/returned, Legacy selected in-app, the same row
repeated, and the queue snapshot unchanged. Six whole captures were received at
`1260x2720`. Evidence:
`.hvigor/outputs/shared-reader-package5/recheck-8112355/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-normal-entry/`.

NextE `a7fc9910` closes the remaining NextE phone entry gap. Its previous
Detail/all-thumbnails admissions only ran behind a `nexte_reader_backend` Want;
the new `ReaderProductionInAppThumbnailEntryTrial` uses a plain launch, selects
Shared through the existing Debug Settings selector inside one process, then
admits the shared Reader from a real Detail compact thumbnail and from the
standalone all-thumbnails Grid, each returning to its same source. Hypium passes
2/2 on the current signed main plus rebuilt `entry@ohosTest` HAP
(`21951b348d66`); six whole captures were received at `1260x2720`. The original
Want-driven class is retained unchanged so both sources stay comparable.
Evidence:
`.hvigor/outputs/shared-reader-package5/in-app-thumbnail-entry/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-in-app-entry/`.

Correction to the previous Koma note: Koma's accepted 197 ordinary-entry
evidence was already produced against `8112355`, not an older revision. The
reader-kit commit is dated 10:07 and the Koma candidate build logs are 11:46 and
13:01, while that sibling checkout's reflog shows no move after 10:07, so the
replay was never required. Writing it as an open gap was an error.

What genuinely remained was that no device had run the **tracked-submodule**
build itself. Koma `33887479` rebuilt through `third_party/reader-kit` produces
signed Debug HAP
`14ff92f7f129155b570d8a625e2fcdb54023f16dc36dc9d149b8fa8f72ef84ce`; installed in
place on 197 it cold-opens the normal bookshelf (`com.honjow.koma`,
`library-title-layout`), the existing in-app selector still offers Shared, and
the ordinary Library resume mounts `rkit-reading-surface` (1) with
`legacy-reader-surface` count 0 and page `6 / 35`, matching the prior baseline.
The screen timeout was restored to 10000 ms, the app was force-stopped and the
lease released. Evidence:
`.hermes-artifacts/20260915-pinned-submodule-build/device197__ALN-AL80/not-applicable/portrait-1260x2720/{01-gate,02-relaunch-gate,03-shared-reader,04-cleanup}/`.
This is source-plus-device evidence for the pinned Koma consumer, not a change
to any production default.

Shared-contract health was re-verified at the pinned revision without any device
run: `reader-kit` `node --test tests/*.test.cjs` passes 431/431, the cross-host
tap-zone handoff suite resolves all 1404 host/resolver comparisons and its
lifecycle/no-write assertions against the three independent consumer branches
(`NEXTE_READER_ROOT`/`KOMA_READER_ROOT` pointed at the worktrees), and Koma's host
preference bridge reports its settings/policy/crop/page-gap/preload mapping wired.
These are logic-level contract results, not device acceptance, and they do not
replace the per-app device matrix.

Running the wider NextN reader/shared host suites surfaced three distinct
conditions. Only one was touched, and it was a stale assertion rather than a
reader regression: `test_reader_data_source_runtime.mjs` pinned the previous
*inline* `new ReaderPagedSession(catalog, <inline provider>, adapter)` shape, but
`528cb80f` had hoisted the asset provider into a local binding, so the regex
matched on neither branch of the truth and the suite failed only on this branch.
The assertion now checks the argument roles (`catalog` first, `adapter` last)
while keeping the `preloadDepth` check, and the suite passes. The other two are
not reader defects and were deliberately left alone: `test_gallery_reader_transition_contract.mjs`
asserts a `transitionState.sourceComponentId === this.sourceComponentId` line that
`GalleryDetailTransitionSourceSlot.ets` has not contained since the common
ancestor, so it fails on `main` as well; and `test_koma_reader_initial_policy_runtime.mjs`
plus `test_nexte_reader_restore_result_runtime.mjs` hard-code `../../Koma` /
`../../NextE` sibling paths and compile methods whose cross-repo sources have
since evolved, so they fail in the shared checkout too. None of the three proves
degradation in the shared reader; a suite that fails identically on `main` cannot
be used as branch-specific regression evidence.

NextE had one branch-specific case of the same class, and it was genuine but
test-only: `test_reader_trial_entry_host_runtime.mjs` stubbed
`ReaderTrialEntryRelay` without the production handoff pair or the pending hold,
so `Index.aboutToDisappear` threw `clearProduction is not a function` before the
assertions ran. That suite passes in the NextE main checkout, so the drift was
introduced by this branch's own production-entry work. NextE `a7f94fa4` mirrors
`holdPending`/`installProduction`/`clearProduction` in the stub; the suite then
passes 18/18. No product source was changed.

One architecture-record gap now has evidence instead of only an implementation.
Section 6.1 requires the NextN adapter to prove cancellation and retry
de-duplication rather than merely attaching to the shared surface. NextN
`2d16e7e1` adds `test_reader_image_cache_flight_runtime.cjs`, which pins four
observable behaviours against the real `ReaderImageCacheService`: a second plain
load joins the existing flight for one cache key without a duplicate GET; a user
Retry waits for the current `.part` stream and then issues exactly one fresh GET
while keeping the stable family path; a settled failure leaves no flight behind
so the next attempt starts cleanly; and a later ordinary load reuses the stored
file without another request. All four pass. A one-off negative control that made
a force reload ignore the running flight failed the suite 3/1 immediately and was
reverted, so the test does detect that regression. This is logic-level evidence
for the cache-flight contract, not device acceptance, and the transport-cancel
boundary remains consumer-only.

The remaining section 6.1 rows now have dispositions rather than assumptions.
NextE already covered its row: `test_reader_original_plan_runtime.mjs` asserts that
a cancelled older resolver cannot overwrite a newer successful plan source or
reload key, and that an original-resolution failure never downloads or falls
back to the default variant; that suite, plus the two ImageResolve and
download-contract suites, all pass. What was genuinely missing was the
queue-versus-running transport boundary behind it. NextE `b048ad96` adds
`test_reader_image_priority_scheduler_runtime.mjs`, which drives the real
`ReaderImagePriorityScheduler`: one low-priority warmer holds the single slot
while a second stays queued and is cancellable; a running transfer reports
`false` from `cancel` rather than being aborted; a visible request starts
immediately without scheduling a duplicate, and promoting an already-started
warmer starts nothing twice; promoting a queued warmer starts it exactly once
and completion releases the low slot. The four cases pass, and a negative control
that made a running transfer claim cancellability failed the suite 3/1
immediately and was reverted, so the boundary is genuinely observed.

Koma's 6.1 row does not apply to the current shared path and is recorded as such
rather than being invented as work: `KomaReaderLabAdapter.ets` states that the D1
adapter reads local/downloaded chapters only and never fetches chapter pages,
so there is no per-request source/account scope to bind on the shared reader
route. That row must be revisited only if a future Koma lane routes network
sources through the shared reader.

Per-consumer host-suite baselines at the pinned revision are now recorded so a
future regression is attributable. NextN's full reader suite set passes 18/18
when the two cross-repo suites are given their consumer roots
(`NEXTE_READER_ROOT`/`KOMA_READER_ROOT`). Koma's branch passes all 6
`test_shared_reader_*.cjs` suites plus 13 others; its one failure,
`test_data_migration_policy.mjs`, is a stale assertion unrelated to the shared
reader (it still requires `READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION = 2` while
`ReaderSessionStore.ets` has moved to `3` with v1/v2/v3 handling) and fails in
Koma's main checkout too, so it is explicitly not branch-regression evidence.
NextE's reader suites pass 9/10, and its single failure
(`test_reader_trial_entry_host_runtime.mjs`) was a branch-introduced stub gap now
fixed by `a7f94fa4` (18/18 after the fix). No reader-suite failure remains that
is attributable to the shared replacement work itself.

The page-number handoff left one named branch open: the earlier NextE 197 run
only exercised the saved `showPageNumber = true` value. NextE `4d604503` adds
`ReaderPageNumberToggleTrial`, which drives the existing canonical preference to
false and then true through `ReadModeSettings.setShowPageNumber` and asserts the
hidden-chrome passive page number follows while the visible chrome page count is
preserved. On 197 it passes 1/1 (`offHidden=false onHidden=true
chromeCountsPreserved=true`) and restores the original value. Independent
node-level readback of the two hidden-chrome layouts agrees: the
`rkit-persistent-page` node count is `0` with the preference off and `1` with it
on, while no chrome page label is mounted in either state. Evidence:
`.hvigor/outputs/shared-reader-package5/page-number-toggle/device197__ALN-AL80/not-applicable/portrait-1260x2720/{02-toggle,03-layouts}/`.
The lease was released. This closes the named NextE false branch only; the
broader per-host preference matrix and default replacement remain open.

Package 5's remaining gate, "upgrade and rollback preserve settings/progress/
data", now has device evidence for NextN. Durable state lives in
`/data/app/el2/100/base/com.erosteam.nextn/haps/entry/preferences/nextn_settings`
and `/data/app/el2/100/database/com.erosteam.nextn/entry/rdb/NextN.db`. Three
consecutive `install -r` replacements with **no app launch between the reads**
(shared-branch build 14035287b730 -> main build a0766a2baa96 -> shared build)
left the settings hash `d000d9be…` and the RDB hash `f8fa29bc…` identical at all
three checkpoints, so the install step itself does not touch user data in either
direction. After the final rollback the ordinary cold start reaches
`com.erosteam.nextn` with all four root tabs and no Reader mounted, and the screen
timeout was restored to 10000 ms. Evidence:
`.hvigor/outputs/shared-reader-package5/20260915-nextn-upgrade-rollback/device197__ALN-AL80/not-applicable/portrait-1260x2720/{10-baseline,11-overwrite,12-rollback,13-abc,14-final-cold}/`.
An earlier readback in that sequence did show a changed RDB hash; that was a
legitimate write from an app launch placed between the two reads, not an install
effect, and the launch-free A/B/C run is what isolates the install. This accepts
the NextN data-preservation boundary only; NextE and Koma upgrade/rollback and
the tablet viewport remain open.

NextE now has the same boundary. Its durable state is
`/data/app/el2/100/base/com.erosteam.nexte/haps/entry/preferences/nexte_settings`
plus `/data/app/el2/100/database/com.erosteam.nexte/entry/rdb/NextE.db`. Three
consecutive `install -r` replacements with no app launch between reads
(shared-branch build 67e3636de4c7 -> main build 3b398955c515 -> shared build)
left both hashes unchanged at all three checkpoints: settings `ec0c18aa…` and RDB
`f1e78cd3…`. After the final rollback the ordinary cold start reaches
`com.erosteam.nexte` with all five root tabs and no Reader mounted, and the screen
timeout was restored to 10000 ms. Evidence:
`.hvigor/outputs/shared-reader-package5/20260915-nexte-upgrade-rollback/device197__ALN-AL80/not-applicable/portrait-1260x2720/{00-discover,01-abc,02-final-cold}/`.
NextN and NextE therefore both accept the data-preservation boundary; Koma
upgrade/rollback and the tablet viewport remain open.

Koma now accepts it too. Its durable state is file-based rather than RDB: the
library store, reader sessions, reader progress JSON files in `.../haps/entry/files`
and the `koma_reader_preferences_v1` preference. A/B/C with no app launch between
reads (shared-branch build 14ff92f7 -> main build 028562a8 -> shared build again)
left all four hashes identical at every checkpoint — library store
`a997dba1…`, reader sessions `30bc14ed…`, reader progress `7e5382f0…`, reader
preferences `860c930d…`. After the final rollback the ordinary cold start reaches
the Koma shelf (`library-title-layout`) with no Reader mounted, and the screen
timeout was restored to 10000 ms. Evidence:
`.hermes-artifacts/20260915-upgrade-rollback/device197__ALN-AL80/not-applicable/portrait-1260x2720/{00-discover,01-abc,02-final-cold}/`.
All three hosts now accept the upgrade/rollback data-preservation boundary at the
pinned revision; the tablet viewport remains the open dimension.

The NextN shared-reader branch has been rebased onto main `ecaafec3`
(border-crop strengths). All 75 commits apply cleanly; the one conflict in
`docs/qa/nextn-active-acceptance.md` was resolved by keeping both the
border-crop acceptance and the Koma progress/image-actions entry. HEAD is now
`c032b851`. The signed Debug build passes with native library gate intact.

Post-rebase 197 trial verification (2026-09-15 22:20-22:22): clean-build
HAP at 57ce3a72 / reader-kit 8112355 installed on 197.
ReaderProductionInAppDetailEntriesTrial passed Tests run: 1, Pass: 1
(usesInAppBackendForReadCompactAndFullGridThenRestoresLegacy,
TestFinished-ResultCode: 0, ~100 s). Evidence:
.hvigor/outputs/trial-debug-v2/run-metadata.json.
Capture artifacts (7 layout JSONs + 7 screen PNGs for in-app-detail-shared /
in-app-detail-legacy x read/compact/grid + final) were retrieved on 2026-09-16
to `.hvigor/outputs/trial-debug-v2/extracted_evidence/` and reviewed. Findings:

- Both backends reached a real reader through the ordinary in-app Detail path.
  Shared frames carry the shared surface (`rkit-reading-surface`,
  `rkit-image-viewport`, `rkit-chrome-top/bottom`, `rkit-chrome-page`); Legacy
  frames carry `legacy-reader-surface` and no shared component. The two
  backends never rendered the other's surface, so the backend switch is
  effective at the ordinary entry.
- Resumed position agrees across backends and entries: read 2/14, compact 1/14,
  grid 2/14 in both; the final frame is the restored Home root, not a reader.
- `legacy-read.png` and `legacy-grid.png` are byte-identical (sha256
  `36fed337…`). This is consistent with both Legacy entries landing on the same
  page 2 of the same source, not with a missing entry: the Legacy layout dumps
  for those two captures are different documents (different component counts
  and ids), and each was produced after its own distinct control was clicked.
- Correction to the earlier "both capture sets were taken with the reader chrome
  raised" reading: they were not in the same chrome state, and the geometry
  difference is the already-accepted contract rather than a new finding. The
  trial's Shared wait requires `rkit-chrome-page`, i.e. chrome raised, and those
  frames carry 18 system status-bar nodes (`status_bar_color_picker`,
  `StatusBarIconWrapper_status_bar_clock`,
  `PluginRootComponent_Stack_status_bar_notification_icon`) with the shared
  surface at `[0,124]`. The Legacy wait only requires `legacy-reader-surface`,
  so those frames are chrome-hidden and carry 0 system status-bar nodes at
  `[0,0]`. That is exactly the behaviour recorded earlier in this document for
  Koma `b2465627`: "the legacy reader hides the status area whenever chrome is
  hidden", and hidden chrome applies the host fullscreen value while showing
  chrome restores the status area - verified there as reader roots moving
  `[0,124]` -> `[0,0]` -> `[0,124]` on 197 and `[0,105]` -> `[0,0]` -> `[0,105]`
  on 103. The `[0,124]` vs `[0,0]` pair here is the same behaviour seen from two
  different chrome states, so it is not a defect and needs no new device run.
- Second form factor confirmed (2026-09-16, device 237 = HUAWEI Pura X
  `VDE-AL00` `1320x2120`, newly authorized by the user): the same
  `ReaderProductionInAppDetailEntriesTrial` passed there with
  `Tests run: 1, Failure: 0, Error: 0, Pass: 1`, `TestFinished-ResultCode: 0`.
  All 7 layouts were retrieved and show the same partition: Shared frames carry
  19 `rkit-*` nodes and no `legacy-reader-surface`; Legacy frames carry
  `legacy-reader-surface` and no `rkit-*`. Pages agree across backends
  (read 2/14 on 197 and read 4/14 on 237 for the same gallery at that device's
  own durable page 3, compact 1/14, grid 2/14). The same chrome-state split
  reproduces at this viewport (`[0,117]` Shared with 16 status-bar nodes vs
  `[0,0]` Legacy with 0), which is why it is recorded as a measurement
  difference rather than a product defect. Evidence:
  `.hvigor/outputs/trial-debug-237-v1/run-metadata.json` (that file records `status: failed` only because its postflight hilog decode hit a non-UTF-8 byte; the authoritative Hypium output in the same file is `Tests run: 1, Failure: 0, Error: 0, Pass: 1` with `TestFinished-ResultCode: 0`, so the trial passed) and
  `.hvigor/outputs/trial-debug-237-evidence/`. Installation used `install -r`
  on top of 237's existing data (397 history rows, target gallery present).

- Rotation and responsive-layout coverage on the large-screen device
  (2026-09-16, 237 `VDE-AL00` `1320x2120`): the existing
  `ReaderProductionAdaptiveRotationTrial` passed there with
  `Tests run: 1, Failure: 0, Error: 0, Pass: 1` in 38 s
  (`keepsTheSameRtlSplitSpreadAcrossTabletRotationAndPhysicalNavigation`).
  That case asserts the real display is portrait before, landscape during, and
  portrait again after `setPreferredOrientation`, and that the shared viewport
  width equals the live landscape width, so the rotation itself is measured
  rather than assumed. It also turns one physical RTL spread in landscape
  (page 2 -> 4 with both leaves retained), then restores history, spread
  settings, and the original preferred orientation. Evidence:
  `.hvigor/outputs/rotation-237-v1/run-metadata.json`. This is the
  rotation/responsive dimension on a real second form factor; 103 remains the
  named tablet target if it comes back online.

- Continuous-mode rotation and boundary coverage on the large-screen device
  (2026-09-17, 237 `VDE-AL00` `1320x2120`): the
  `ReaderProductionContinuousRotationTrial` passed there with
  `Tests run: 1, Failure: 0, Error: 0, Pass: 1` in 179 s
  (`keepsContinuousReadingPositionAndBoundaryAcrossTabletRotation`).
  Candidate commit `b1375d64` (main HAP `4625ba7e`, ohosTest `eae8c55b`).
  In vertical continuous mode for webtoon gallery 678049 (page 2 scales to
  28,193 px height in 2120px landscape), it verifies portrait micro-scrolling
  retaining P2, portrait-to-landscape reflow with viewport expansion to 2120px,
  bounded non-flinging physical swipe advancing ~250 px/step across boundary to
  P3 at step 114 (`top3` reached -135px, live progress 3, page label `4 / 14`),
  and retention of P3 after returning to portrait. All four whole-screen captures
  were retrieved and reviewed (`continuous-rotation-portrait-scrolled.png`,
  `continuous-rotation-landscape-retained.png`, `continuous-rotation-landscape-next.png`,
  `continuous-rotation-returned-portrait.png`). Evidence:
  `.hvigor/outputs/continuous-rotation-237-v5/run-metadata.json`. Exact history,
  reader presentation settings, orientation, and legacy backend restored.

Hypium 1/1 on 197 and 1/1 on 237; screenshot review DONE for both sets.
The status-bar geometry question is reframed: unproven as a backend contract
difference, and no longer blocking while every measured viewport agrees on the
reader content, page, and surface ownership.
An earlier run reported App died with a ReaderPageCropStrength SyntaxError;
the root cause of that failure has not been established. The passing run
supersedes it as the current candidate phone-path trial evidence.

- NextE second form factor ordinary-entry confirmed (2026-09-16, device 237 = HUAWEI Pura X
  `VDE-AL00` `1320x2120`): the `ReaderProductionInAppBackendRehearsalTrial` passed there
  with `Tests run: 1, Failure: 0, Error: 0, Pass: 1` on candidate commit `e0f26b81`
  (HAP `76b44635`, ohosTest `1cecaa42`). All 6 phase captures were retrieved and reviewed: Settings initial
  `现有阅读器`, in-app select `共享阅读器`, ordinary Downloads queue entry opens Shared reader
  (`1 / 2` with dual chrome toolbars), close returns to Downloads, Settings select `现有阅读器`,
  and re-entering opens Legacy reader (`2 / 2`) with clean return. An intermediate attempt
  (`e51f86fb`) masked unmount timing by falling back to `driver.pressBack`, which did not
  prove the close button itself; that fallback was removed in `e0f26b81` to strictly assert
  clicking `rkit-close` (retrying the button click or re-calling the chrome without Back
  substitution), and the trial cleanly passed 1/1 with `sharedReturned=true`. Evidence:
  `.hvigor/outputs/nexte-237-formfactor/device237__VDE-AL00/not-applicable/portrait-1320x2120/01-normal-entry-rehearsal/`.

- NextE manga translation host integration audited (2026-09-16): source comparison between legacy
  `ReaderPage.ets` and shared `NextEReaderLabPage.ets` / `NextEReaderTranslationProvider.ets`
  confirms the full translation chain is already implemented rather than skeleton-only. The shared
  reader exposes `rkit-host-action-translate-page` and `translate-auto` through `hostActions()` in
  the More menu matching legacy label transitions (`reader_comic_translation_action` ->
  `reader_comic_translation_show_original` / `reader_comic_translation_show_result`); delegates
  execution to the same singleton `ComicTranslationRuntimeService.runReaderPage`; reports progress
  via `ReaderHostStatus`; and switches between original and translated rendered local images via
  `ReaderVariantPreference('translated', identity)` and `NextEReaderTranslationPlan`. Speculative
  claims of unported translation engines (CTD/AOT/Torii) are retracted as unsupported by the code.
  On 197, `ReaderHostTranslationActionsTrial` verified on real content 4175844 that the More menu
  dynamically exposes both `rkit-host-action-translate-page` and `rkit-host-action-translate-auto`
  (capture at `.hvigor/outputs/nexte-translation-actions/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-host-translation-actions/host-translation-actions.png`).
  However, architectural boundaries and external dependencies remain explicit:
  1. Core responsibility remains strictly limited to page identity, request generation, variant
     presentation, and cancellation/resource disposal. Translation runtime, OCR, model selection,
     and file lifecycle stay host-owned; refactoring does not expand into OCR or translation engine research.
  2. Current extensibility boundary: `ReaderSession.ets` restricts processed variants to
     `'enhanced' | 'translated'` and session/surface code hardcodes both branches, so adding new
     processing types still touches core/ui rather than being arbitrarily pluggable.
  3. Migration coexistence: `NextEReaderLabAdapter` continues to adapt the legacy `ReaderViewModel`
     during transition, so the legacy reader module cannot be deleted.
  4. Full end-to-end translation acceptance with external service invocation remains OPEN, kept as a
     host integration requirement without blocking reader core replacement progress.

Next Package 5 boundaries:
- 237 is now an authorized test device (user instruction, 2026-09-16). It is a
  HUAWEI Pura X (`VDE-AL00`), `1320x2120`, currently `Connected`. A read-only
  probe confirmed the installed NextN still holds real state (`NextN.db` plus
  `nextn-downloads`, `imageknife-cover-cache`, `diagnostics_logs`), so runs
  there must not assume an empty app. Evidence:
  `.hvigor/outputs/device237-state-run1/` in the NextN checkout.
- 103 tablet normal-entry admission is OPTIONAL, not an open blocker (user
  directive 2026-09-17). 103 has been optional test support since that
  instruction and must never gate development; 237 now covers the
  large-screen/rotation/responsive dimension. Last observed 2026-09-16 14:52:
  `hdc list targets -v` reports `192.168.50.103:12345 TCP Offline`, and a
  lease-scoped `hdc -t 192.168.50.103:12345 shell echo ok` answers
  `[Fail][E001005] Device not found or connected`. This is device availability
  only, not a product finding; no retry loop is warranted. If 103 reappears it
  can add tablet coverage, but no capability package depends on it.
- The A/B/C file-hash experiments prove only that install -r preserves
  checked durable files between builds. That narrowed statement no longer
  bounds the whole continuity claim: the read -> upgrade -> reopen-same-page
  -> rollback -> reopen-same-page path is now executed on both phone hosts
  inside the rolled-back revision itself (NextN `ecaafec3`, NextE `2bebd112`),
  with the exit-written durable row read back and the position restored; Koma
  has its own install-replacement continuity record. The superseded sentence is
  struck rather than kept as an OPEN row for those three paths.
- Correction (2026-09-16, after reviewing the raw runs): the NextN and NextE
  entries previously written as "runtime continuity DONE" overstate what was
  executed. In both runs the main revision was only installed, cold-opened, and
  layout-dumped; the same content was never resumed inside the main revision.
  So what the evidence actually proves is narrower: **after** two `install -r`
  replacements, the candidate build still restores the same content identity,
  page, and persisted state through its ordinary entry. It does not prove that
  a real rolled-back revision can resume the same reading, and a Legacy
  fallback observed inside the candidate build is not evidence about the main
  rollback revision. That minimum check has since been executed on both hosts:
  each main revision resumed the same content/page through its ordinary entry,
  the exit-written durable row matched the displayed frame, and the position was
  then restored through the same path (see the NextN and NextE paragraphs
  below). The two paragraphs after this one keep the executed detail; this
  correction is retained as the record of why the earlier DONE wording was
  withdrawn.
- NextN replacement-then-restore acceptance on 197 (partial, phone path only).
  `entry/src/ohosTest/ets/test/ReaderRuntimeContinuity.test.ets` (registered in
  `List.test.ets`) drives the ordinary in-app Detail entry, reads the host's own
  `reading_history` row and persisted settings, and derives its expectation from
  a cache record instead of a constant. Executed order: write phase on the
  candidate -> `install -r` of committed main `ecaafec3` -> cold start ->
  `install -r` of the candidate -> cold start -> verify. Result
  (`.hvigor/outputs/continuity-verify-v7/run-metadata.json`):
  `Tests run: 1, Failure: 0, Error: 0, Pass: 1`, trial reporting
  `resumed=3 expected=3 legacyFallback=3 media=4156592 settingsRows=16
  coldStart=legacy`. Verified inside the candidate build: cold start is Legacy;
  `reading_history` keeps `media_id` 4156592, the title, the 14-page count,
  `last_read_index` 3 and `has_read_progress` 1; the persisted reader mode and
  settings row count are unchanged; the ordinary entry resumes 4/14 on Shared;
  the same entry on Legacy also shows 4/14; the cache record survived both
  replacements.
  Main-revision resume check (completed 2026-09-16, NextN): with committed
  main `ecaafec3` installed, gallery 678049 was opened through the documented
  direct-route Want, and the Detail page's own Read action reported
  `继续 P4` — the rollback revision itself resolving the durable page. Tapping
  that real action produced `legacy-reader-surface` showing `4 / 14`, and the
  screenshot matches the same gallery content. Evidence:
  `.hvigor/outputs/main-resume-v1/{detail-layout-before.json,reader-layout.json,reader-screen.png}`
  and `.hvigor/outputs/main-resume-probe-v1/detail-layout.json`. So the NextN
  rollback revision does resume the same content at the same page through the
  ordinary entry. Main-revision exit-write and durable reread (completed
  2026-09-16, NextN): with committed main `ecaafec3` installed, the same direct
  route showed `继续 P4`, the Legacy reader displayed `3 / 14` after one
  right-zone tap, and the row read back on exit was `gallery_id 678049`,
  `page_count 14`, `last_read_index 2` — the rollback revision's own exit write
  matching the frame it had displayed. A second pass inside the same revision
  restored the starting position through the ordinary path: Detail showed
  `继续 P3`, the left-zone tap returned the frame to `4 / 14`, and the row
  written on exit read `last_read_index 3`. Evidence:
  `.hvigor/outputs/nextn-main-exit-durable/` (with both `NextN-*.db` and their
  `-wal` sidecars) and `.hvigor/outputs/nextn-main-restore-position-run1/`.
  The candidate HAP and its ohosTest HAP were reinstalled afterwards with
  `install -r`.
- NextE replacement-then-restore acceptance on 197 (partial, phone path only).
  NextE `23e4c84f`, same trial file name under NextE's `ohosTest`. It opens the
  newest real History gallery through the ordinary Detail Read action, turns
  pages with the reader's own tap zones, and reads `gallery_read_progress`;
  the expectation comes from a cache record. Same ordering shape as NextN with
  committed main `2bebd112`. Result
  (`.hvigor/outputs/nexte-continuity-verify-v4/run-metadata.json`):
  `Tests run: 1, Failure: 0, Error: 0, Pass: 1`, trial reporting
  `gid=4175844 resumed=3 expected=3 coldStart=legacy reset=legacy`, resumed
  frame 4/46. Verified inside the candidate build: cold start is Legacy, the
  same page, and the rehearsal selector returns to Legacy.
  NextE real Legacy reading fallback verified on 197 (2026-09-16): cold start
  defaults to Legacy backend without touching Settings; gallery 4175844 opened
  from History list -> Detail page Read action ("继续 P4") -> mounts
  `reader_key_surface` (`rkit-reading-surface` = 0), resumes and renders real
  manga page at `4 / 46`, matching durable `page_index 3` and `column_mode ""`.
  Pre/post RDB snapshots confirmed durable row unchanged. Evidence:
  `.hvigor/outputs/nexte-legacy-read/{layout.json,screen.png,NextE-before.db,NextE-after.db}`.
  Main-revision resume, exit-write, and restore (completed 2026-09-16, NextE):
  committed main `2bebd112` was rebuilt from its clean checkout
  (`scripts/build_hvigor_signed.sh`, `BUILD SUCCESSFUL`) and installed with
  `install -r`. Cold start, Settings -> History -> gallery 4175844 -> Detail
  Read action (`继续 P4`) mounted `reader_key_surface` with no
  `rkit-reading-surface`, rendering the real page at `4 / 46`
  (`reader-thumb-reader-surface-2-route-1-page-4`) and matching durable
  `page_index 3`. Exiting that reader wrote `page_index 2` (this gallery reads
  right-to-left, so the right-zone tap had stepped back) and the Detail page
  then read `继续 P3`; a third pass restored the position through the same
  ordinary entry, displaying `4 / 46` and writing `page_index 3` on exit.
  Evidence: `.hvigor/outputs/nexte-main-resume/`,
  `.hvigor/outputs/nexte-main-exit-durable/`,
  `.hvigor/outputs/nexte-main-restore-position/`. The candidate HAP and its
  ohosTest HAP were reinstalled afterwards with `install -r`.
- Evidence-method note (2026-09-16, both phone hosts): a copied
  `NextN.db`/`NextE.db` alone can read stale. Both stores run in WAL mode, and
  in the NextE resume run the `.db`-only postflight copy still showed the
  pre-run row while the same store's `-wal` sidecar already held the new page.
  A durable-row check must therefore receive the `-wal` sidecar and be read
  from a copy that includes it; a `.db`-only readback is not evidence that a
  write did or did not happen.
- Koma cross-version continuity (completed 2026-09-16). Two genuinely
  different builds were used, not a self-replacement. Candidate
  `codex/koma-reader-refactor` `8f11c550`, HAP SHA-256 `14ff92f7…84ce`,
  contains the `阅读器实现` selector (3 occurrences in `resources.index`); the
  rollback revision `main` `0399e257` (`0399e257` is an ancestor of the
  candidate), HAP SHA-256 `028562a8…da8b`, contains none (0 occurrences).
  Sequence on 197 with the real chapter `chapter:manhua-chongchongcun:1220470:6`
  (6 pages) through the ordinary shelf card -> comic Detail -> `开始阅读` path:
  candidate install and open advanced the durable row to `pageIndex 2`
  (reader showing `3 / 6`); `install -r` of the **older** rollback HAP, cold
  start, and the same ordinary open with no page override resumed `3 / 6` from
  the candidate-written document and left `pageIndex 2` unchanged on exit; the
  candidate HAP was then reinstalled with `install -r` and again resumed
  `3 / 6`. The touched chapter was returned to its pre-run baseline through the
  reader's own navigation, and the durable document now matches the baseline
  field-for-field (`pageIndex 0`, `pageId …:0`, `progressRatio 0.1666…`,
  `completed false`, `columnMode odd_left`); only `updatedAt` differs, which is
  inherent to having re-read the chapter. Evidence:
  `.hermes-artifacts/20260916-koma-crossversion/{01-candidate-write,02-rollback-resume,03-restore-candidate,04-restore-baseline}/`
  in the Koma worktree. Build identity note: the older revision does not
  compile against the pinned reader-kit, so no fresh HAP was built from it and
  the existing artifact was used; its content is confirmed by the selector-string
  absence above rather than by build provenance alone.
  A previous note claimed the 197
  install was "clean"; that was wrong and is withdrawn. Those probes only read
  `/data/app/el2/100/base/<bundle>/files`, `cache`, and `database`, which are not
  the paths Koma actually uses. The real durable location is the module files
  dir, `/data/app/el2/100/base/com.honjow.koma/haps/entry/files/`, and it already
  holds real user state: `reader-sessions.v1.json` (schema 3, 11 progress
  entries plus 21 chapter read-state entries, including `completed: true` for
  `com.komiic.koma:kic:2861` and a local-folder entry) and an imported local
  library fixture with three real PNG pages under
  `import/local-library-folder-smoke-root/extract/Fixture Series/`. Do not
  rebuild or overwrite that state. Established for the next attempt:
  `entry/src/main/ets/model/ReaderSessionStore.ets` writes
  `filesDir/reader-sessions.v1.json`; `ReadingProgressStore` itself is only an
  in-memory interface, so the session store is the durable owner; Koma has no
  `ohosTest` module, so the Host trial form does not transfer and its acceptance
  form is the manifest-driven set under `docs/device-protocols/` plus the
  `scripts/run_*_reader_smoke.sh` entrypoints.
  Koma ordinary-entry acceptance on 197 (2026-09-16, candidate `8f11c550`),
  with every tap coordinate read from a real layout tree:
  - The Reader settings subpage carries a real control, `阅读器实现`, whose
    trailing value is either `现有阅读器` (Legacy) or `共享阅读器` (Shared).
    The dropdown's item position depends on which value is current, which is
    why a fixed guess missed it; while Shared is current the `现有阅读器` item
    sits at `[669,514][1156,670]` and while Legacy is current `共享阅读器` sits
    at `[669,670][1156,826]`.
  - Selecting `共享阅读器` and then opening the same chapter from the ordinary
    shelf `继续阅读` action mounts `rkit-reading-surface`
    (`rkit-chrome-page` = `2 / 2`, `reader_key_surface` = 0). Evidence (regenerated 2026-09-17):
    `.hermes-artifacts/20260917-koma-ordinary-shared/01-open/` — shared surface
    mounted from the ordinary shelf entry, `reader_key_surface` = 0. The earlier
    `20260916-koma-continuity/10-ordinary-shared-v3` `layout.json`/`screen.png`
    were accidentally overwritten that day by a rail probe whose receive paths
    still pointed there; the gitignored dir could not be restored byte-for-byte,
    so this re-run is now the citation.
  - Switching back to `现有阅读器` in the same process and re-entering through
    the same ordinary action mounts `reader_key_surface`
    (`rkit-reading-surface` = 0). Evidence:
    `.hermes-artifacts/20260916-koma-continuity/13-ordinary-legacy-v2/`.
    So the user-facing fallback control does change which reader the ordinary
    entry mounts on Koma.
  - `install -r` continuity for the Koma reader path: after replacing the
    install, opening the same chapter with no page override resumed `2 / 2`
    while the durable `reader-sessions.v1.json` entry stayed
    `pageIndex 1, completed true`. Evidence:
    `.hermes-artifacts/20260916-koma-continuity/03-restore/`. Note this run went
    through the debug `ReaderLab` route, which does not consult the backend
    selector, so it is evidence about the shared reader surface rather than
    about a selector-driven ordinary entry.
  - The 1x1-pixel fixture discrepancy is no longer being pursued. That fixture
    is a 70-byte 1x1 transparent PNG and the legacy reader rejects it at the
    display stage (`display_ready page=2` then `display_failed page=2`). One set
    of healthy real-content runs does not establish the root cause of that
    difference, so this note claims only that real content worked and that the
    degenerate fixture is not being investigated further:
    - Shared reader, ordinary entry on the real downloaded chapter
      (`com.dm5.koma:manga:manhua-chongchongcun`, 6/6 pages downloaded): shelf
      card -> comic Detail -> `开始阅读` mounts `rkit-reading-surface` with
      `rkit-part-*` present, no `rkit-failure-*`, page `1 / 6`. Evidence:
      `.hermes-artifacts/20260916-koma-real/03-shared-real-v2/`.
    - Existing reader, same ordinary entry on the same real chapter (cold start,
      so the process-local selector is on its default): mounts
      `reader_key_surface`, page `1 / 6`, and the log reads
      `display_ready page=1` then `display_complete page=1`. Evidence:
      `.hermes-artifacts/20260916-koma-real/04-legacy-real/`.
    Both frames render the same real manga page, so the two implementations are
    comparable on real content rather than only on fixture images.
  Koma install-replacement continuity on real content (2026-09-16). Using the
  same real chapter `chapter:manhua-chongchongcun:1220470:6` (6/6 pages
  downloaded) through the ordinary shelf -> Detail -> `开始阅读` path:
  - Baseline recorded before the change: `pageIndex 0`, `completed false`,
    chapter `isRead false`. Evidence:
    `.hermes-artifacts/20260916-koma-replace/01-baseline/`.
  - A distinguishable position was established (`3 / 6`, durable
    `pageIndex 2`) so a resume cannot be confused with the start page.
    Evidence: `.../02-setup/`.
  - A real `install -r` replacement of the candidate HAP was performed, then the
    same chapter was opened through the ordinary path with no page override.
    The reader resumed `3 / 6` and the durable record stayed `pageIndex 2`; the
    14-comic library store was byte-comparable in identity before and after.
    Evidence: `.../03-resume/`.
  - Chapter completion is host-owned and survives the replacement: advancing to
    the terminal page wrote `pageIndex 5, completed true` and chapter
    `isRead true`. Evidence: `.../04-complete/`.
  - Fallback after the replacement: switching back to the existing reader in the
    same process and re-entering through the ordinary path mounted
    `reader_key_surface` at `6 / 6` (`rkit-reading-surface` = 0). Evidence:
    `.../05-fallback/`.
  - The original user state was restored afterwards. Only one durable entry had
    been changed by this work, so the restore rewrote that single entry back to
    its baseline shape; a field-level comparison against the baseline then
    reported zero differing progress entries, and a cold open read back
    `pageIndex 0 / completed false / isRead false` with the shelf showing the
    baseline 17%. Evidence: `.../06-restore/`, `.../07-restore-verify/`.
  Verified against the raw artifacts (2026-09-16): `chapter:manhua-chongchongcun:1220470:6`
  goes `pageIndex 0/completed false/isRead false` at baseline, `pageIndex 2`
  when a distinguishable position is established, stays `pageIndex 2` across the
  `install -r` replacement and the ordinary reopen, becomes
  `pageIndex 5/completed true/isRead true` at the terminal page, and returns to
  `pageIndex 0/completed false/isRead false` after the restore, matching the
  baseline exactly.
  Remaining Package 5 dimensions after this run: the large-screen
  rotation/responsive dimension, which 237 now covers for NextN; 103 tablet
  admission stays optional and non-blocking per the 2026-09-17 user directive.
  The three 2026-09-15 planning drafts under `docs/plans/active/`
  (`runtime-continuity-test-spec.md`, `reader-runtime-continuity-test.ets`,
  `runtime-continuity-manifest-template.json`) are superseded: the shipped
  `entry/src/ohosTest/ets/test/ReaderRuntimeContinuity.test.ets` (c7cd55d1)
  implements the same Write/Verify trials against real in-app entries and passed
  on 197.
- Production defaults remain Legacy. Phone-path and 237 large-screen evidence
  establish ordinary entry and rotation; 103 tablet coverage stays optional and
  non-blocking, not an unmet gate.

## Package completion record

Update one row here when a package closes: shared revision, host commits,
focused suite result, consumer build result, selected device/artifact roots,
observed user path, preserved fallback, and explicit untested/non-applicable
branches. Do not paste command transcripts or create a second status log.

### Package 5 active replacement status and gap inventory — 2026-09-17

Package 5 is **ACTIVE** (overall replacement remains **OPEN**; broad completion withdrawn).
All verified physical and runtime assets remain retained, while open parity/integration gaps are tracked below:

- **Retained verified evidence baseline:**
  - NextE thumbnail rail (verified 2026-09-17 on 197, current worktree, `f86305c1`): `ReaderThumbnailRailTrial` and `ReaderThumbnailRailLifecycleTrial` each pass 1/1 — a 46-page rail selects a tile and navigates to the matching page with the preview aspect preserved, RTL toggle keeps the page, and hide-by-clipping reopens the retained decoded rail. Artifacts: `.hvigor/outputs/reader-thumbnail-rail/`.
  - NextE display modes (verified 2026-09-17 on 197, current pin `f450aad`): `ReaderCropSpreadTrial` and `ReaderCropContinuousTrial` each pass 1/1 on real content 4175844 — spread shows a two-page `rkit-native-pager` and continuous shows the `rkit-continuous-list` 46-page scroll at 5/46 with the cropped original. Artifacts: `.hvigor/outputs/reader-display-modes/`.
  - NextE host actions (re-verified 2026-09-17 on 197, current worktree): `ReaderImageBlockSharedTrial` (mark action + retained-file notice) Pass 1/1, `ReaderManualReloadTrial` (exact visible source, single + spread) Pass 2/2, `ReaderHostSettingsTrial` Pass 1/1 — `.hvigor/outputs/reader-host-actions/`.
  - NextN thumbnail rail (verified 2026-09-17 on 197, `fc7a75d9`): `ReaderThumbnailRailTrial` and `ReaderThumbnailRailLifecycleTrial` each pass 1/1 — a 14-page rail selects a tile and navigates to the matching page, and hide-by-clipping reopens the retained decoded rail. Artifacts: `.hvigor/outputs/nextn-rail/`.
  - NextN display modes on 197 (verified 2026-09-17, current pin `f450aad`):
- NextN large-screen rotation/responsive re-verified at the pinned revision (2026-09-17, 237 `VDE-AL00` 1320x2120, commit `4f05e76e` reader-kit `f450aad`): `ReaderProductionAdaptiveRotationTrial keepsTheSameRtlSplitSpreadAcrossTabletRotationAndPhysicalNavigation` passes **1/1**. The trial asserts the real display is portrait before, landscape during, and portrait again after `setPreferredOrientation`, that the shared viewport width equals the live landscape width, and it turns one physical RTL spread in landscape with both leaves retained, then restores history, spread settings and the original orientation. This moves the earlier `8112355` rotation record onto the pinned revision. Artifacts: `.hvigor/outputs/nextn-f450aad-rotation-237/`.
- NextN runtime continuity re-verified at the pinned revision (2026-09-17, 197, candidate `8e3db1b4` reader-kit `f450aad`): the pinned candidate wrote durable state through the ordinary shared entry (`[ReaderRuntimeContinuityWriteTrial] page=3 media=4156592 pages=14 mode=paged_rtl settingsRows=16 historyProgress=1`), then `install -r` of committed main `ecaafec3` + cold start + `install -r` of the pinned candidate + cold start + verify. `[ReaderRuntimeContinuityVerifyTrial] resumed=3 expected=3 legacyFallback=3 media=4156592 settingsRows=16 coldStart=legacy` — content identity, durable page, reader mode and the settings rows survive the upgrade **and** the rollback, cold start still defaults to Legacy, and the same page resumes through both the Legacy fallback entry and the re-selected Shared entry. Both phases `Tests run: 1, Failure: 0, Error: 0, Pass: 1`. Artifacts: `.hvigor/outputs/nextn-f450aad-continuity/{write,verify}/`. This moves the earlier (pre-pin) continuity record onto the pinned revision. `ReaderProductionDownloadContinuousReloadTrial` and `ReaderProductionDownloadSpreadReloadTrial` each pass 1/1 through the ordinary Downloads entry on a complete local download — vertical continuous and spread reload of the visible source twice. Previously these two trials had only ever passed on the now-optional 103; they now have primary-phone evidence. Artifacts: `.hvigor/outputs/nextn-display-modes/`.
  - NextN continuous/long-image large-screen coverage on 237 (verified 2026-09-17, `VDE-AL00` 1320x2120, pin `f450aad`): `ReaderProductionDownloadContinuousReloadTrial` passes 1/1 in 68 s through the ordinary completed-Downloads entry on local gallery 678179 (56 pages), reloading the visible long page twice in vertical continuous mode with `queueUnchanged=true historyRestored=true modeRestored=true` and a return to Legacy. Together with the 197 continuous evidence, the long-image/continuous path now has phone and large-screen acceptance. Artifact: `.hvigor/outputs/nextn-237-largescreen/device237__VDE-AL00/not-applicable/portrait-1320x2120/01-continuous-reload/`.
  - NextN: ordinary entry (Detail / Grid / Compact) with 7 capture groups retrieved and layout-audited (`.hvigor/outputs/trial-debug-v2/extracted_evidence/`). The pass record is `ReaderProductionInAppDetailEntriesTrial usesInAppBackendForReadCompactAndFullGridThenRestoresLegacy` = `Tests run: 1, Failure: 0, Pass: 1`. A structural audit of the 7 stored layout trees shows the intended partition and page parity: the three Shared frames each carry 19 `rkit-*` nodes and no `legacy-reader-surface`; the three Legacy frames each carry `legacy-reader-surface` and zero `rkit-*`; pages agree across backends (`shared-read` `2 / 14` = `legacy-read`, `shared-compact` `1 / 14` = `legacy-compact`, `shared-grid` `2 / 14` = `legacy-grid`), and the final frame is restored to the host root (`nextn-root-navigation` + `nextn-reader-entry-host`). This was originally layout/tree parity only; the **raster half is now DONE** (2026-09-17, 197, pinned `f450aad`) — the 7 retained `04-screens/*.png` were reviewed at native resolution: the three Shared frames (`in-app-detail-shared-{read,compact,grid}.png`) render the shared chrome (back, `n / 14` counter, reload/settings/more, slider, action row) over the real long-strip page body, the three Legacy frames (`in-app-detail-legacy-{read,compact,grid}.png`) enter immersive with only the passive `n / 14` badge over the same page body and no shared controls, and `in-app-detail-final.png` returns to the host root (我的). No clipping, overlap, missing page body or wrong page in any frame; the only cross-backend difference is the already-recorded entry-chrome presentation (Shared chrome-visible vs Legacy immersive), which is documented as a product trade-off, not a defect. Artifacts: `.hvigor/outputs/nextn-f450aad-matrix/.../04-screens/`. `install -r` upgrade/rollback runtime continuity passing on 197 (`.hvigor/outputs/continuity-verify-v7/`); large-screen split-spread rotation (`.hvigor/outputs/rotation-237-v1/`) and tall continuous scroll rotation reflow (`.hvigor/outputs/continuous-rotation-237-v5/`) passing on authorized device 237 (`VDE-AL00` `1320x2120`) with 4 whole-screen captures reviewed.
  - NextE: ordinary Downloads entry and return passing on 197 and 237;
- NextE runtime continuity re-verified at the pinned revision (2026-09-17, 197, candidate `3018bcb2` reader-kit `f450aad`): the write phase drove one real tap through the shared entry and the host persisted `durablePage=45` (gid 4175844, 46 pages); then `install -r` of committed main `2bebd112` + cold start + `install -r` of the pinned candidate + cold start + verify gave `resumed=45 expected=45 coldStart=legacy reset=legacy` — content identity, durable page and the Settings→History→Detail resume survive the upgrade and the rollback, cold start still defaults to Legacy, and the same page resumes through the ordinary entry. Both phases `Tests run: 1, Failure: 0, Error: 0, Pass: 1`. The write trial was made direction-agnostic first (see the brittleness note) so the pinned run is meaningful: `test(reader): make the continuity write trial direction-agnostic` (`3018bcb2`). Artifacts: `.hvigor/outputs/nexte-f450aad-continuity/{write-c,verify-b}/`. `install -r` runtime continuity passing on 197 (`.hvigor/outputs/nexte-continuity-verify-v4/`); release mode fail-closed Legacy verification passing on 197. Large-screen spread/rotation/responsive coverage on 237 (verified 2026-09-17, `VDE-AL00` 1320x2120, commit `734c4a74` reader-kit `f450aad`): `ReaderSpreadLayoutTrial joinedSplitGestureRotationAndSingleton` passes 1/1 in 36 s — it asserts the real display is portrait, rotates to a live landscape, keeps the physical RTL spread pair (`joined-return` parts `[0,594][660,1526]` + `[660,594][1320,1526]` at width 1320), turns a page, returns to portrait, and restores the preferred orientation. Combined with the 197 run of the same trial, the shared spread/rotation path now has both phone and large-screen acceptance. Artifacts: `.hvigor/outputs/nexte-237-largescreen/`. The same 237 run set also covered the continuous display mode: `ReaderCropContinuousTrial standaloneBodyCropKeepsSourcePageAndCloses` passes 1/1 in 44 s with the crop detector active and `rowBefore==rowAfter` (the shared `rkit-continuous-list` row geometry is unchanged by the crop toggle), so NextE's spread and continuous modes now both have phone (197) and large-screen (237) acceptance. Artifact: `.hvigor/outputs/nexte-237-largescreen/device237__VDE-AL00/not-applicable/portrait-1320x2120/02-continuous-crop/`.
  - Koma display modes on 197 (verified 2026-09-17, current pin `f450aad`): with `readerLabEntryLayout`, the shared surface mounts a two-page `rkit-native-pager` for spread and `rkit-continuous-list` for continuous on a real local chapter (`.hermes-artifacts/20260917-koma-display-modes/`).
  - Koma shared-surface large-screen mount on 237 (verified 2026-09-17, `VDE-AL00` 1320x2120, pin `f450aad`): the same lab spread protocol retargeted to 237 mounts the shared `rkit-reading-surface` at the full large-screen bounds `[0,117][1320,2120]` with the exact 15-node shared chrome set (`rkit-chrome-top/bottom`, `rkit-chrome-page`, `rkit-close`, `rkit-more`, `rkit-source-slider`, `rkit-toggle-spread`, `rkit-toggle-thumbnails`, `rkit-reading-mode`, `rkit-save-image`, `rkit-share-image`, `rkit-auto-read`, `rkit-shift-spread`). The pager is deliberately empty (`0 / 0`) because the 197-built local-library fixture is not seeded into 237's real library, and per the device rules no fixture or user store was written there. So 237 confirms the large-screen layout mount for Koma, not a real-content page; the real-content Koma display-mode evidence stays on 197. Artifacts: `.hermes-artifacts/20260917-koma-237-largescreen/`.
- Koma shared-reader **real content on the large-screen 237** (verified 2026-09-17, 237 `VDE-AL00` 1320x2120, candidate `6553e2df` reader-kit `f450aad`, `install -r` only): the earlier 237 record was a layout-mount-only run whose pager was deliberately empty (the 197 lab fixture is not seeded on 237). This run closes that gap for the content path: 237 already owns a **real** offline comic — a 10-page `local_folder` title (`local-folder-data-storage-...-koma-d12-solo-...`) — so opening its chapter through the stable lab entry mounts the shared `rkit-reading-surface` at the full large-screen bounds `[0,117][1320,2120]` with the real ZX-SCANS page art decoded (`rkit-native-pager`, `rkit-part-0-whole`, `rkit-chrome-page 1 / 10`, and the Koma-only `章节 1 / 1` centre control). So the shared reader renders actual content at the large-screen form factor, not only a layout shell. No fixture or user store was written; only `install -r`. Artifact: `.hermes-artifacts/20260917-koma-237-real/portrait/{layout.json,screen.png}`.
- Koma shared-reader **real-content spread and continuous modes on the large-screen 237** (verified 2026-09-17, 237 `VDE-AL00` 1320x2120, candidate `6553e2df` reader-kit `f450aad`, `install -r` only): the earlier 237 record was a layout-mount-only run (empty pager); this run uses 237's own real 10-page local-folder comic. With `readerLabEntryLayout=spread` the shared surface mounts `rkit-native-pager` with both real page leaves (`rkit-part-0-whole` + `rkit-part-1-whole`, `rkit-entry-image-0-1-1` + `rkit-entry-image-0-2-1`) showing the actual ZX-SCANS cover at `1 / 10` with the Koma-only `章节 1 / 1` control; with `readerLabEntryLayout=continuous` it mounts `rkit-continuous-list` (`rkit-continuous-page-0/1`) scrolling the real page vertically. So Koma's shared display modes are now device-verified on real content at both form factors (197 phone + 237 large screen). No fixture or user store was written. Artifacts: `.hermes-artifacts/20260917-koma-237-real/modes-recv2/spread.json` and `.../continuous.json` (+ `.png`).
- Koma shared-reader **zoom on the large-screen 237 (real content)** (verified 2026-09-17, 237 `VDE-AL00` 1320x2120, candidate `6553e2df` reader-kit `f450aad`, `install -r` only): opening 237's real 10-page local-folder comic at `1 / 10` and double-tapping the page zooms it — `rkit-part-0-whole` expands from the fitted `[0,620][1320,1500]` to `[0,180][1320,1940]` (filling the full viewport height) at an unchanged `1 / 10`, and the pixels confirm the same page magnified (the ZX-SCANS credits/art larger, top/bottom cropped in). So the shared reader's zoom is device-verified on real content at the large-screen form factor as well. Artifacts: `.hermes-artifacts/20260917-koma-237-real/zoomdir2/{baseline,zoom}.{json,png}`.
- Koma **runtime reading-mode control on 237 real content** at the pinned revision (2026-09-17, 237 `VDE-AL00` 1320x2120, candidate `6553e2df` reader-kit `f450aad`, `install -r` only): with 237 real 10-page comic open, tapping the shared `rkit-reading-mode` control (not a lab override) raises the RuntimeMenu and tapping 「双页」 switches the live session to a two-page `rkit-native-pager` — both real page leaves (`rkit-part-0-whole` + `rkit-part-1-whole`) render at `1 / 10` with the Koma-only `章节 1 / 1` centre control. So the same user mode control that 197 verified also performs the switch at the large-screen form factor. Artifact: `.hermes-artifacts/20260917-koma-237-real/mode-switch4/layout.json` and `.png`.
- Koma **crop + direction controls on 237 real content** at the pinned revision (2026-09-17, 237 `VDE-AL00` 1320x2120, candidate `6553e2df` reader-kit `f450aad`, `install -r` only): with 237 real 10-page comic open, the shared runtime menu (raised via `rkit-reading-mode`) shows `开启裁边` and `右→左` initially; tapping the crop row flips it to `关闭裁边`, and tapping the direction row flips it to `左→右` with the source slider reversing accordingly (`10 … 1`), so both dimensions are preserved and driven by the same user controls at the large-screen form factor (matching 197). Artifacts: `.hermes-artifacts/20260917-koma-237-real/cdr2/menu.json` and `menu.png`.
- Koma **auto-read on 237 real content** at the pinned revision (2026-09-17, 237 `VDE-AL00` 1320x2120, candidate `6553e2df` reader-kit `f450aad`, `install -r` only): with 237 real 10-page comic open, tapping `rkit-auto-read` and waiting 20 s advances the page from `1 / 10` to `7 / 10`/`8 / 10` with the clock glyph highlighted, i.e. the shared auto-read timer drives real page turns on the large screen too (the earlier 11 s attempt simply did not wait long enough). Combined with the 197 run, Koma auto-read is now device-verified at both form factors. Artifacts: `.hermes-artifacts/20260917-koma-237-real/autoread2/baseline.json` and `auto.{json,png}`.
- **Koma ordinary-entry pixel review + an entry-selection caveat (2026-09-17, 197)**: pixel review of the earlier `8f11c550` ordinary entry (`.hermes-artifacts/20260916-koma-real/03-shared-real-v2/screen.png`) confirms the real 虫虫村 chapter renders in the shared reader — actual manga page art, chrome (back, `2 / 6`, reload/settings/more, slider, action row) and Koma's centered `章节 1 / 1`. My pinned-`f450aad` re-run reused the same coordinate-based 197 protocol (`.hermes-artifacts/20260917-koma-ordinary-shared-f450aad/`) but the shelf 'continue' tap landed on a *different* entry — a 2-page / 2-chapter title whose pages are the synthetic lab fixture, so that frame is chrome-only with a black body (`1 / 2`, `章节 1 / 2`). That is a **stale coordinate in the reused protocol**, not a product regression: the click is a hard-coded page coordinate, and the shelf contents/order on the shared device changed between the two runs. A pinned-revision Koma real-content re-check must re-derive the shelf entry rather than reuse the old coordinate. The `f450aad` real-content re-check is now DONE: re-running the protocol against the real 虫虫村 grid tile (not the reused continue-card coordinate) and then its 「继续阅读」 button enters the shared reader on the pinned build and renders the actual manga page (`むしんこ村`, page `2 / 6`) with chrome, slider, action row and Koma's `章节 1 / 1`. Artifacts: `.hermes-artifacts/20260917-koma-real-f450aad/02-shared-real-read/`.
- **Koma lab fixture limitation noted (not a product defect)**: the `readerLabEntryLayout` display-mode and `readerLabWork=local-library-folder-*` lab runs use a synthetic **1x1** PNG fixture (`SourceRuntimeDeviceSmoke.ets:166` `LOCAL_LIBRARY_FOLDER_SMOKE_PAGE_BASE64`), so those "empty pager" or black-body frames reflect the fixture, not a rendering failure. Real-content Koma device evidence must therefore use the ordinary shelf entry (the 虫虫村 chapter above), which does render the actual page. The 237 Koma mount run is a layout-mount check for that reason and stays labelled as such.
  - Koma: ordinary Library continue and chapter switch passing on 197 on real content;
- Koma chapter orchestration re-verified at the pinned revision with a real multi-chapter offline title (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): using the stable semantic entry (`readerLabWork=com.dm5.koma:manga:manhua-suiranwoshibuwanmeienv`, `readerLabUnit=chapter:...1451220:40`, i.e. 第28话 of 虽然我是不完美恶女) the shared reader opened the real page art at `1 / 40` with the host chapter control `rkit-host-center-action`, and tapping it raised the chapter picker listing the real neighbouring chapters 第31/30/29/28/27/26/25話 with per-chapter page counts, the current chapter 第28话 highlighted and check-marked. This is the Koma chapter-orchestration semantic (chapter ordinal `章节 17 / 45`, adjacent-chapter list, current-chapter selection) on the pinned revision. Artifacts: `.hermes-artifacts/20260917-koma-chapter-f450aad/12-lab-open-ch28/`. Note for future runs: the shelf/card **coordinates are not stable across runs** (a tap intended for one card landed on 坂本 DAYS in an adjacent run because the scroll offset differed), and the chapter rows sit under the floating bottom nav; the stable route is the lab work/unit parameters, not page coordinates. Koma chapter **switch** re-verified at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): opened 第28话 (`1 / 40`, `章节 17 / 45`) via the stable lab entry, raised the chapter picker, and tapped 第31话. The shared reader then showed `1 / 33` (33 = 第31话’s page count) with the chapter control `章节 14 / 45` and the new chapter’s real coloured page art — so the host chapter orchestration committed the new unit: the visible content, page count and chapter ordinal all changed together, and the Koma-only centre chapter control `rkit-host-center-action` stayed mounted with `rkit-native-pager`. Artifacts: `.hermes-artifacts/20260917-koma-chapter-f450aad/13-switch-to-ch31/`. Koma per-chapter **read-complete state** re-verified at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): opening 第28话 at its last page (`readerLabPage=39`) with host progress read/write persisted the durable row `chapter:manhua-suiranwoshibuwanmeienv:1451220:40 -> pageIndex 39, completed true` (the pre-run row for a sibling chapter was `pageIndex 0, completed false`), so the host’s `completed = last readable page shown` semantic survives the shared session. Artifacts: `.hermes-artifacts/20260917-koma-chapter-f450aad/15-completed-write/`. The run only advanced that chapter’s own reading position; no library/download data changed, and the pre-run `reader-sessions.v1.json` was pushed back byte-identically afterwards (the restored file equals the pre-run snapshot; artifact `.hermes-artifacts/20260917-koma-chapter-f450aad/16-restore-progress/`). 
- Koma chapter **navigation UI + completed** re-verified at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): with 第28话 open, the shared More menu renders `rkit-previous-chapter` 「上一章」 and `rkit-next-chapter` 「下一章」 (both enabled at a mid-sequence chapter); tapping 「下一章」 committed the adjacent chapter — the reader moved to `1 / 26` with chapter control `章节 16 / 45`, i.e. the previous chapter in the list order — matching the legacy `onNextChapter`/`onPreviousChapter`/`onOpenChapter` capability (shared `chapterNavigation` + `centerAction`). Boundary enablement is source-defined (`ReaderChrome` disables each item when `snapshot.canPreviousUnit`/`canNextUnit` is false, which `ReaderPagedSession` derives from `catalog.adjacent() !== null`); a true end anchor (动画化, last of 45) showed `rkit-next-chapter` **disabled** on device. The exact disabled state of the *first* anchor was not isolated in that run because that chapter is not downloaded (its page failed to load, so the chrome reflected the failure state rather than a clean boundary); it was later isolated directly — see the two Koma chapter-boundary records above (list-index-0 and the single-chapter work). Artifacts: `.hermes-artifacts/20260917-koma-chapter-f450aad/{17-more-menu,18-next-chapter-button,20-last-ch-more,21-dl-idx1,22-dl-idx16}/`. This closes Package 4’s real-device chapter-switch path on the pinned revision (previous switch evidence was `8f11c550`).
- Koma shared-reader **save/share chrome** verified at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): opening a real offline chapter (虽然我是不完美恶女 第28话, page `1 / 40`, `章节 17 / 45`) via the stable lab entry, the shared chrome exposes `rkit-save-image` and `rkit-share-image` both **enabled**, and tapping share opens the **real system share sheet** (「分享 1 项 / 440.76 KB」) with the actual page preview thumbnail (the DM5-marked comic page), the nearby device PuraX, and 华为分享/微信/QQ/我的华为/备忘录/复制/**保存至图库**/小艺帮记/打印/添加至中转站. So Koma’s shared save/share entries are present, enabled, and reach the real system share flow with the correct page content. Artifacts: `.hermes-artifacts/20260917-koma-save-share/{01-probe,02-share-panel}/`. (The in-sheet 「保存至图库」 target is the platform share destination; Koma’s own `rkit-save-image` uses `ReaderSystemImageSaveHost`, whose album landing is not externally readable without root, as recorded for NextE.)
- Koma shared-reader **spread and continuous display modes re-verified on real content** at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): the earlier Koma display-mode record used the synthetic 1x1 lab fixture (`local-library-folder-*`), so it is re-run here on the real offline chapter 第28话. With `readerLabEntryLayout=spread` the shared surface mounts a two-page `rkit-native-pager` with both real page leaves (`rkit-part-0-whole` + `rkit-part-1-whole`; `rkit-entry-image-0-1-1` + `rkit-entry-image-0-2-1`) showing the actual 二十八话 page 1 (left) and page 2 (right) art, plus the shared chrome and the Koma-only `章节 17 / 45` centre control; with `readerLabEntryLayout=continuous` it mounts `rkit-continuous-list` with real `rkit-continuous-page-0/1` rows scrolling the same pages vertically. So both Koma display modes are confirmed on real page art, not only on the lab fixture. Artifacts: `.hermes-artifacts/20260917-koma-display-modes-real/run/{spread,continuous}-{layout.json,screen.png}`. Read-only run (no progress write).
- **Capability-parity audit vs. legacy menus at the pinned revision (2026-09-17, source-level)**: every NextN legacy reader action/string traces to a shared control, so no silent omission remains in this dimension. Mapping: `reader_action_show/hide_thumbnails` → `rkit-toggle-thumbnails`; `reader_action_retry` → `rkit-retry-page-N`; `reader_action_save_current_image`/`reader_save_left/right/both` → `rkit-save-image`/`rkit-save-left/right/both`; `reader_action_share_current_image` → `rkit-share-image`; `reader_action_shift_spread_one_page` → `rkit-shift-spread`; `reader_action_start/stop_auto_advance` → `rkit-auto-read`; `reader_action_toggle_double_page` → `rkit-toggle-spread`; `reader_mode_paged/vertical/paged_rtl/paged_vertical` → the `RuntimeMenu` single / vertical-paged / spread / continuous items plus the direction item; `reader_spread_save_both` → `rkit-save-both`; `reader_thumbnails_open_page_a` → the shared thumbnail rail tile selection; `reader_image_info*` → `rkit-image-info`/`rkit-image-info-spread`; `reader_comic_translation*` → the host `translate-page`/`translate-auto` actions; `reader_crop_borders` → `rkit-crop-toggle`; `reader_enhancement_*` → `rkit-enhancement-status` (NextE); `reader_tap_zone_*` → the host tap-zone resolver feeding `ReaderTapPolicy`. The three hosts also share `ReaderKeepScreenOn`/`keepScreenAwake` and the `imageScalingQuality -> imageInterpolation` mapping. This is a source audit, not new device evidence; it exists to show the old-to-shared capability map has no silent omission at the pinned revision.
- **NextE legacy-to-shared capability-parity audit at the pinned revision (2026-09-17, source-level)**: every legacy NextE reader action traces to a shared control, so no silent omission remains. Legacy surface: top bar `share` (`sys.symbol.share`, `shareCurrentImage`) -> `rkit-share-image`; more menu `reader_reload_source` (+ spread submenu) -> `rkit-reload-source`/`rkit-reload-source-spread`; `reader_image_info` (+ spread submenu) -> `rkit-image-info`/`rkit-image-info-spread`; `reader_crop_borders` -> `rkit-crop-toggle`; `reader_comic_translation_action` -> host action `translate-page`; `reader_comic_translation_auto` -> host action `translate-auto`; `reader_image_block_mark`/`reader_image_block_allow` -> host action `mark-image-blocked` + the shared `ReaderAssetNoticePanel`; back -> `rkit-close`; page counter -> `rkit-chrome-page`. Legacy bottom bar: `save` (`arrow_down_to_line` + `ReaderSaveSpreadMenu`) -> `rkit-save-image`/`rkit-save-left`/`rkit-save-right`/`rkit-save-both`; `original` (`arrow_outward_and_rectangle` + spread submenu) -> `rkit-original-image`/`rkit-original-both`; auto read (`clock`) -> `rkit-auto-read`; thumbnails (`rectangle_grid_2x1`) -> `rkit-toggle-thumbnails`; shift one page (`transfer`, double-page) -> `rkit-shift-spread`; double page (`book`) -> `rkit-toggle-spread`; mode (`modeIcon` + `ReaderModeMenu`) -> `rkit-reading-mode`/`rkit-vertical-paged`/`rkit-spread-layout`. The shared chrome additionally carries `rkit-open-external` (NextE's legacy menu has no such item, so it is intentionally unused by NextE), `rkit-host-settings` (host settings sheet, device-verified), and `rkit-reset-zoom` (a shared navigation-fenced reset command, not a legacy menu item). So no legacy NextE action is silently absent from the shared surface. This is a source audit, not new device evidence.
- NextN **thumbnail rail re-verified at HEAD** (2026-09-17, 197, candidate `28d7dee9` reader-kit `f450aad`): the earlier NextN rail record was at `fc7a75d9`, but a host-boundary product change landed afterwards (`2c53b158` NextN asset-failure classifier + `6f99aa28`), so the rail trials are re-run at the current revision. Both pass 1/1: `ReaderThumbnailRailTrial` (a 14-page rail selects a tile and navigates to the matching page with the preview aspect preserved) and `ReaderThumbnailRailLifecycleTrial` (`hiddenFromUiTree=true decodedAfterReopen=true pageStable=true`, i.e. hide-by-clipping removes the rail from the UI tree, reopening retains the decoded page, and the reader page is unchanged). So the shared rail still holds after the failure-classifier change. Artifacts: `.hvigor/outputs/nextn-rail-head/{run,lifecycle}/`. (The NH partial-thumbnail contract stays separate from NextE's EH sprite crop, as documented in the architecture notes.)
- NextN **continuous crop boundary characterised** (2026-09-17, 197, candidate `0051eeb4` reader-kit `f450aad`): a strict same-content A/B settles the previous `ReaderCropContinuousTrial` failure. Opening gallery `678049` at the **same** page index 4 with `readerLabCropBorders=true` gives, in single mode, `rkit-part-4-whole` **plus** `rkit-cropped-image-4-whole`; in continuous mode it gives `rkit-continuous-list` + `rkit-continuous-page-4` and **no** `rkit-cropped-image-*`. This is now explained by source, not left open: the shared continuous path applies `ReaderImageCropBounds.forContinuousPage(index, count)` (`ReaderPagedSession.ets:497,518`; `ReaderImageCrop.ets:36`), which zeroes the top inset for every page except the first and the bottom inset for every page except the last, so an interior page whose only detected insets were top/bottom becomes uncropped by design — exactly the legacy NextN behaviour (`ReaderPage.ets:1133` `detected.forContinuousPage(this.pageIndex + 1, this.totalPages)`). Because left/right insets are preserved, the absence of the cropped-image element on interior page 4 implies that page's crop was top/bottom-only. A first-page continuous probe (index 0) also showed no `rkit-cropped-image` id, consistent with that page having no top inset. So on this webtoon gallery the shared continuous reader is not dropping a crop it should keep; the `ReaderCropContinuousTrial` expectation (a croppable page still emits the paged cropped-image id in continuous mode) is trial brittleness on this content — the same class as the already-recorded NextN `ReaderPagingAxisTrial` webtoon caveat. No product change is made and no speculative trial edit is shipped (one was tried and reverted because it did not produce a pass). The continuous **row-geometry** acceptance for NextN therefore still rests on the recorded 237 `continuous-rotation` runs rather than this trial. Artifacts: `.hvigor/outputs/nextn-crop-cmp/run1/{paged,cont}.json`, `.hvigor/outputs/nextn-crop-edge/run1-first/dump.json`, `.hvigor/outputs/nextn-continuous-crop-f450aad/{run1,run2}/`.
- NextN **thumbnail-rail partial retry** verified at the pinned revision (2026-09-17, 197, candidate `d64bbe12` reader-kit `f450aad`): the tracked `ReaderThumbnailRetryTrial` (`retryRecoversOnlyPreviewThenFreshSelectionSeeks`) had no pinned-revision record; it now passes **1/1**. With the Debug-only `readerLabFailThumbnailPage=1`, opening the gallery decodes the visible original and the rail shows a single failed tile (`rkit-thumb-retry-1`); tapping it recovers only that tile (`rkit-thumb-state-1-displayed` appears, `rkit-thumb-retry-1` disappears, the reader page stays `1`, the source slider remains), then a fresh tile selection (`rkit-thumbnail-1`) seeks to page 2 and decodes it, and close returns out of the trial. So the shared rail's per-tile retry recovers one preview without disturbing the reader position, then a normal selection still seeks. Artifact: `.hvigor/outputs/nextn-thumb-retry-f450aad/run1/run-metadata.json`.
- NextN **crop (single) and information-route lifecycle** verified at the pinned revision (2026-09-17, 197, candidate `6ca02349` reader-kit `f450aad`): two tracked trials that had no pinned-revision record now each pass **1/1**. `ReaderCropTrial` (`standaloneBodyCropKeepsSourcePageAndCloses`) on real gallery 678049 discovers a croppable page, toggles crop off/on and confirms the paged `rkit-cropped-image-N-whole` geometry with the source page unchanged, then closes. `ReaderInformationBackgroundTrial` (`metadataFailureOrLateResultDoesNotBreakReadingOrFreshInformation`) exercises the shared reader across an app background: the NextN lab route (unlike NextE's) stays mounted across background, so the reader and its retained position remain usable and a fresh image-information request still works after the round trip, with no late metadata result breaking reading. Artifacts: `.hvigor/outputs/nextn-crop-paged-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nextn-info-bg-f450aad/run1/run-metadata.json`.
- NextN **volume-key preference + system-volume release** verified at the pinned revision (2026-09-17, 197, candidate `5ab10bcf` reader-kit `f450aad`): two tracked trials that had no pinned-revision record now each pass **1/1**. `ReaderVolumePreferenceTrial` (`preferenceAndExplicitOverrideRespectSystemVolumeAndRestore`) drives all four cases (persisted preference on/off, each also with the explicit Debug `readerLabVolumeKeys` override), asserting in each that the durable `reading.volumeKeyTurn` row matches the requested value, that the reader turns pages only when enabled (page 2 -> 3 for a volume-down) and that the real music stream volume is left unchanged while the key is consumed — `[ReaderVolumePreference] case=3 preference=false explicit=true enabled=true release=passed` — then restores the original preference and leaves the device at its pre-run value. `ReaderVolumeReleaseTrial` (`closeReturnsRealSystemVolumeAndRestoresBaseline`) proves the release half: while the reader owns the key it turns pages and changes no stream volume, and after close the next key goes to the real system (`[ReaderVolumeRelease] before=1 after=2 increase=true`, then `restored=1 expected=1`, i.e. the trial's own compensation returned the stream to baseline). Artifacts: `.hvigor/outputs/nextn-vol-pref-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nextn-vol-release-f450aad/run1/run-metadata.json`.
- NextN **tap-zone, page-number and image-scaling settings** verified at the pinned revision (2026-09-18, 197, candidate `a805ad1a` reader-kit `f450aad`): three tracked host-settings trials that map directly to the objective's preserved settings and had **no record** now each pass **1/1** on real gallery 678049 through the ordinary lab entry. `ReaderTapZonesTrial` (`savedLShapePagedAndContinuousWithZoomMenuIsolation`) seeds the persisted `L_SHAPED`/`NONE` tap-zone layout+invert for **both** paged and continuous modes, opens the shared reader on real content and drives the page-turn tap zones in each mode (paged: left-third -> previous, right-third -> next, with the shared More menu and a double-tap zoom; continuous: the bottom/top zones scroll the tall `rkit-continuous-page-2` row by ~0.75 of the list height and back), asserting the unused legacy `reader_tap_zone_layout`/`_invert` and `reader_column_mode` rows stay read-only, then restores the exact six entry keys (`restored=true exactEntryTextKeys=6 legacyAndColumnReadOnly=true noSyncFlush=true`). `ReaderPageNumberTrial` (`normalUiSavedPageNumber`) asserts the live `showPageNumber` matches the durable value, then flips it off and on through the **normal Settings UI** and verifies the shared reader renders the `rkit-chrome-page` label accordingly (`PAGED`/`PAGED_RTL`, single page), restoring the original raw value (`restored=true exactPresence=true normalUiOnly=true`). `ReaderInterpolationTrial` (`readOnlyScopedInspectorSampling`) opens the shared reader on real content and, via the scoped inspector, verifies the rendered `Image` node carries the mapped `imageScalingQuality -> ImageInterpolation.Medium` interpolation with `samplingVerified:true`, and that the process image-scaling state equals the durable repository value. Each run restores any settings it touched; all three are `Tests run: 1, Failure: 0, Error: 0, Pass: 1`. Artifacts: `.hvigor/outputs/nextn-tapzones-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nextn-pagenumber-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nextn-interpolation-f450aad/run1/run-metadata.json`.
- NextN **spread-shift (`rkit-shift-spread`) action verified at the pinned revision** (2026-09-17, 197, candidate `8786e594` reader-kit `f450aad`): the tracked `ReaderSpreadShiftTrial` (`rtlSpreadRePairsOnePageThenTurnsWithinTheNewPairing`) passes **1/1** after a trial-only fix. Root cause of the earlier error was the same RTL-start brittleness: the trial asserts the runtime menu starts LTR (it clicks 右→左 to switch to RTL), but device 197 persists RTL, so the lookup returned null; pinning the Debug-only `readerLabEntryDirection=ltr` (the sibling-trial pattern) makes it pass — no product change. Pixel evidence: `baseline.png` shows the RTL spread pairing with the anchor page at `2 / 14`; `changed.png` shows the pairing shifted by one page (`2 / 14` anchor retained, the visible pair advanced), which is exactly the legacy NextE 「shift one page in double-page」 semantic (`ReaderPagedSession.shiftSpread` re-derives `firstPageAlone` and rebuilds). Artifacts: `.hvigor/outputs/nextn-spreadshift-f450aad/{run2/run-metadata.json,caps/}`. This device-verifies the shared `rkit-shift-spread` control through the NextN host lab. The NextE host mapping is now also device-exercised: `ReaderSpreadShiftTrial` passes **1/1** on 197 at the pin (`.hvigor/outputs/nexte-spreadshift-regress/run1/run-metadata.json`), so the shared shift-spread control is device-verified on both the NextN and NextE hosts, not only by source audit.
- NextE crop-strength pixel review at the pinned revision (2026-09-17, 197, candidate `bd740ca8` reader-kit `f450aad`): the retained `shared-reader-package9/.../01-crop-strength/{strength-before,strength-after}.png` pair shows the same page `4 / 46` at the same RTL slider position, with the AFTER frame’s page borders trimmed (content sits closer to the viewport edge and the trimmed page edge is visible), i.e. the crop-strength control applies a real border crop without changing the page, source or direction. Artifacts: `.hvigor/outputs/shared-reader-package9/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-crop-strength/`.
- NextN pinch **zoom** and axis/rotation pixel-reviewed at the pinned revision (2026-09-17, 197, candidate `dcf83462` reader-kit `f450aad`): the `ReaderPagingAxisTrial` was first made direction-agnostic (Debug-only `readerLabEntryDirection=ltr`, mirroring the NextE fix) and then passed **1/1**. The retrieved captures show page `2 / 14` with the slider at 2 in `zoom-before-pan` and `zoom-after-pan` while the after frame is visibly magnified/panned (same pool scene larger, surrounding content cropped in) — a real >1 viewport transform that moved no page/position and produced no clipping or placeholder; `vertical-p2` keeps the full page at `2 / 14`; `landscape-p2` shows the reader reflowed in landscape at the same `2 / 14` with the chrome/slider intact. Artifacts: `.hvigor/outputs/nextn-paging-axis-f450aad/device197__ALN-AL80/not-applicable/portrait-1260x2720/{01-axis,02-zoom-review}/`. This gives NextN the same device pixel zoom evidence the trial comment requires.
- NextN shared-reader **reset-zoom click restores geometry** (verified 2026-09-18, 197, candidate `62bed3bb` reader-kit `f450aad`): the shared More menu's `rkit-reset-zoom` 「重置缩放」 had only its enabled state recorded for NextE/Koma; this run (with the NextE and Koma twins) closes the NextN click-through half. Opening the NextN long-strip gallery 678049 at page 1 double-taps to a full-viewport zoom, but on that webtoon the double-tap lands as a page/chrome gesture; using the normal-aspect downloaded gallery 556817 (pages 800x1129, Debug single/ltr entry) instead, double-tapping drives `rkit-part-1-whole` from the fitted `[0,402][1260,2319]` to the full viewport `[0,124][1260,2720]`, the menu's live `rkit-reset-zoom` bounds are read from the dump (`[675,637][1195,793]`), and clicking them returns `rkit-part-1-whole` to `[0,402][1260,2319]` — identical to the pre-zoom baseline. So the shared navigation/topology-fenced reset command resets the viewport transform on device for all three hosts. Read-only run (zoom is in-session viewport state; no progress or preference written). Artifacts: `.hvigor/outputs/nextn-resetzoom/run3/{baseline,zoom,menu}.json`, `.hvigor/outputs/nextn-resetzoom/run4/after.json`. (The earlier 678049 attempt, `.hvigor/outputs/nextn-resetzoom/run1/`, is retained as the content-geometry caveat: a tall webtoon page makes a centre double-tap resolve to a page/chrome gesture, so the reset-zoom probe needs a normal-aspect page.)

- NextN shared-reader **image share** re-verified at the pinned revision (2026-09-17, 197, candidate `207167a3` reader-kit `f450aad`): the tracked `ReaderImageShareTrial` passes **1/1** after `captureShare` was given the same `typeof driver.dumpLayout` + `uitest dumpLayout` CLI fallback used by the NextE twin (`Driver.dumpLayout` is absent on this SDK build). Pixel evidence: `baseline` is page `2 / 14`; `panel` is the **real system share sheet** (「分享」, nearby PusaX, 华为分享/微信/QQ/我的华为/备忘录/复制/小艺帮记/打印/添加至中转站/加密分享) carrying the actual source name 「飞机杯女神连线中 Wireless Onahole - Chapter 116 … 先行版 2」; `returned` is back on the **same page `2 / 14`** after cancel; `next-panel` shows the sheet again after the volume-key advance to `3 / 14` (repeatable, source name now 「…先行版 3」); `closed` returns to the gallery. Artifacts: `.hvigor/outputs/nextn-share-f450aad/device197__ALN-AL80/not-applicable/portrait-1260x2720/{01-share,02-caps}/`.
- NextN shared-reader **image information** re-verified at the pinned revision (2026-09-17, 197, candidate `df14712e` reader-kit `f450aad`): the tracked `ReaderImageInformationTrial` passes **1/1** after the same two test-side fixes used for the NextE twin (a `typeof driver.dumpLayout` guard with a `uitest dumpLayout` CLI fallback, and a bounded wait for the async `rkit-image-info` menu entry). Pixel evidence on the long-image gallery 678049: `single` shows 「图片信息 · 第 2 页」 (格式 WEBP, 大小 781.5 KB, 当前 源图片, 显示尺寸 **720 x 9980**) at `2 / 14`; `choice` shows the per-pane source menu 「左侧 · 第 2 页 / 右侧 · 第 1 页 / 重新加载图片来源 / 图片信息 / 重置缩放」; 「左侧 · 第 2 页」 opens 「图片信息 · 第 1 页」 (**720 x 9245**) and 「右侧 · 第 1 页」 opens 「图片信息 · 第 2 页」 (720 x 9980) — so the shared dialog reports each pane’s own real dimensions with the correct RTL left/right mapping. Artifacts: `.hvigor/outputs/nextn-info-f450aad/device197__ALN-AL80/not-applicable/portrait-1260x2720/{01-info,02-caps}/`.
- NextE shared-reader **image information** re-verified at the pinned revision (2026-09-17, 197, candidate `b7d6d03f` reader-kit `f450aad`): the tracked `ReaderImageInformationTrial` passes **1/1** after its menu open was made to wait for the asynchronously rendered `rkit-image-info` entry instead of a fixed 400 ms (the fixed delay left the entry null and the click threw). Pixel evidence: `single` shows the 「图片信息 · 第 2 页」dialog with real file facts (格式 WEBP, 大小 257.0 KB, 当前 重采样图片, 原图 可用, 显示尺寸 1280 x 1807, 图像增强 关闭, 图源 cajexa…hath.network) at page `2 / 46`; spread `choice` shows the per-pane source menu 「左侧 · 第 2 页 / 右侧 · 第 1 页 / 重新加载图片来源 / 图片信息 / 重置缩放」; selecting 「左侧 · 第 2 页」 opens 「图片信息 · 第 1 页」 and 「右侧 · 第 1 页」 opens 「图片信息 · 第 2 页」 — i.e. the shared information dialog reports each physical pane’s own source identity with the correct RTL left/right mapping. Artifacts: `.hvigor/outputs/nexte-info-f450aad/device197__ALN-AL80/not-applicable/portrait-1260x2720/{01-info,02-info,03-caps}/`.
- NextE shared-reader **image share** re-verified at the pinned revision (2026-09-17, 197, candidate `20f0b265` reader-kit `f450aad`): the tracked `ReaderImageShareTrial` passes **1/1** after its evidence capture was fixed to use the same `typeof driver.dumpLayout` + `uitest dumpLayout` CLI fallback the other NextE trials already use (the trial previously aborted with `undefined is not callable` because `Driver.dumpLayout` is absent on this SDK build). Pixel evidence: `baseline` shows the RTL spread at `2 / 46`; `panel` shows the **real system share sheet** (「分享」 header, nearby-device PuraX, 华为分享/微信/QQ/备忘录/微信输入法, 复制/小艺帮记, and the actual source file name `[Kubokenya-san …] 阿妮娅的爱之魔法`); `returned` is back on the **same page `2 / 46`** after cancelling (share cancel keeps the page); `next-panel` shows the sheet again after a volume-key advance to `3 / 46` (the action is reusable); `closed` returns to the gallery. So the shared share action opens the real system sheet with the correct source identity and is cancel-safe and repeatable. Artifacts: `.hvigor/outputs/nexte-share-f450aad/device197__ALN-AL80/not-applicable/portrait-1260x2720/{01-share,02-share,03-caps}/`.
- NextE shared-reader **system image save** re-verified at the pinned revision (2026-09-17, 197, candidate `bd740ca8` reader-kit `f450aad`): the tracked `ReaderThumbnailSaveTrial` passes **1/1**. Pixel evidence: `save-menu` shows the RTL spread at `1 / 46` with the save choices 「左侧 · 第 2 页 / 右侧 · 第 1 页 / 保存两页」 (correct RTL left/right mapping); `save-dialog` shows the **system** permission sheet 「允许“NextE”保存 2 张图片？」 with 禁止/允许; `save-saved-reader` returns to the same page after allow; `save-closed` returns to the gallery detail. So the shared save action opens the host save menu with the right per-pane labels and reaches the real system save permission flow for both pages. The trial records `system_allow_completed=true source_pages=1,2 album_file_verified=false external_readback_required=true`, i.e. the **album entry was not externally read back**; a read-only external check is Permission denied / absent for a non-root HDC shell, so the album-file landing remains **not externally verified** (it would need an in-app media query). Artifacts: `.hvigor/outputs/nexte-save-f450aad/device197__ALN-AL80/not-applicable/portrait-1260x2720/{01-save,02-caps,03-album,04-album2}/`.
- NextN shared-reader **system image save** re-verified at the pinned revision (2026-09-17, 197, candidate `441ac9e8` reader-kit `f450aad`): the tracked `ReaderThumbnailSaveTrial` passes **1/1** with `ReaderThumbnailSave system_allow_completed=true source_pages=1 album_file_verified=false external_readback_required=true`, and the stronger `ReaderThumbnailSaveBothTrial` also passes **1/1** with `source_pages=1,2`. Pixel evidence: `save-menu` shows the RTL spread at `1 / 14` (long-strip gallery 678049) with the save choices 「左侧 · 第 2 页 / 右侧 · 第 1 页 / 保存两页」 (correct RTL left/right mapping); the positive trial reaches the **real system** permission sheet 「允许“NextN”保存 1 张图片？」 and the both-pane trial 「允许“NextN”保存 2 张图片？」; `save-positive-saved-reader`/`save-both-saved-reader` return to the same page after allow; `save-positive-closed`/`save-both-closed` return to the gallery detail (the 678049 Detail page with the `继续 P4` card). So the NextN shared save action opens the host save menu with the right per-pane labels and reaches the real system save permission flow for one and for both pages, symmetric with the NextE `ReaderThumbnailSaveTrial`. The album entry remains **not externally read back** (non-root HDC shell is Permission denied), same boundary as NextE. Artifacts: `.hvigor/outputs/nextn-save-f450aad/device197__ALN-AL80/not-applicable/portrait-1260x2720/{01-save,02-save-both}/`.
- NextN **auto-read** re-verified at the pinned revision (2026-09-17, 197, candidate `d4e99479` reader-kit `f450aad`): the tracked `ReaderThumbnailAutoReadTrial` (`rtlNextSpreadThenExplicitStopRetainsPage`) passes **1/1** through the Detail-thumbnail entry with `interval_seconds=3 settings_unmodified=true`. Pixel evidence: `auto-start` shows page `3 / 14` with the `rkit-auto-read` clock highlighted (active); `auto-stopped` keeps `3 / 14` with the clock back to idle (the explicit stop retains the page across the remaining interval); `auto-closed` returns to the gallery detail. So the shared auto-read advances real pages on its own and stopping it is stable, without changing the persisted interval. Artifacts: `.hvigor/outputs/nextn-autoread-f450aad/device197__ALN-AL80/not-applicable/portrait-1260x2720/{01-autoread,02-caps}/`.
- NextN **keep-screen (keep-awake)** verified at the pinned revision (2026-09-17, 197, candidate `44644c95` reader-kit `f450aad`): the tracked `ReaderKeepScreenOnTrial` (`foregroundReadingOwnsKeepAwakeAndReleasesOnBackgroundAndClose`) passes **1/1**. It reads the real window's `isKeepScreenOn` before entering: `ReaderKeepScreenOn before=false setting=true`, then asserts the shared route takes the lease while shown (`shown=true`), releases it when the app leaves the foreground (`background=false`), re-acquires it on resume (`resumed=true`), and releases it again on close (`closed=false`), and that the persisted `keepScreenOn` preference is unchanged. The run also exercises the volume-key handoff in the same route (`page 2 -> 3 -> 2`). Artifacts: `.hvigor/outputs/nextn-keepscreen-f450aad/run1/run-metadata.json`.
- NextE **keep-screen (keep-awake)** verified at the pinned revision (2026-09-17, 197, candidate `516c60ed` reader-kit `f450aad`): the tracked NextE `ReaderKeepScreenOnTrial` (`foregroundReadingOwnsKeepAwakeAndReleasesOnBackgroundAndClose`) passes **1/1** after a trial-only fix (no product change). It reads the real window's `isKeepScreenOn` first (`before=false`), asserts the shared route takes the lease while shown (`shown=true`), releases it on background (`background=false`), re-acquires it on a fresh explicit entry (`reentered=true`), and releases it on close (`closed=false`), with `connectReadMode().keepScreenOn` unchanged. The fix parallels the NextE `ReaderVolumeKeys` change: NextE intentionally retires the shared reader route on app background (asserted by its own `ReaderLifecycleRecoveryTrial`/`ReaderInformationBackgroundTrial`), so the resumed assertion required a fresh explicit lab entry rather than a bare `aa start`. Artifacts: `.hvigor/outputs/nexte-keepscreen-f450aad/run2/run-metadata.json`.
- NextN large-screen (237) zoom + a paging-trial caveat at the pinned revision (2026-09-17, 237 `VDE-AL00` 1320x2120, candidate `e31ca01c` reader-kit `f450aad`): a direct double-tap probe on the long-image gallery 678049 shows the same page `4 / 14` before and after while the AFTER frame is visibly magnified (the tall page widens, detail enlarges, the top/bottom crop in) — a real >1 viewport transform at an unchanged page/position on the large screen. Artifacts: `.hvigor/outputs/nextn-237-axis/device237__VDE-AL00/not-applicable/portrait-1320x2120/04-doubletap-zoom/`. Caveat recorded honestly: the tracked `ReaderPagingAxisTrial` fails on 237 with `expect 7 equals 3` at its vertical-paged step because it assumes one `0.31 x viewport` swipe advances exactly one page; gallery 678049 is a webtoon long-strip whose page is far taller than the viewport, so a single swipe legitimately crosses several page boundaries (`vertical-p2` shows the narrow strip, `exception` shows `7 / 14`). That is trial brittleness under long-image content + vertical paging, not a product defect; the trial is not a valid large-screen paging acceptance for this gallery and its 197 pass (square-ish content) stands only for that content.
- NextE `ReaderChromeTrial` (chrome viewport ownership + in-session direction switch) run at the pinned revision (2026-09-17, 197, candidate `64f13264` reader-kit `f450aad`): the trial had **no prior pass record** in this worktree, so it is a written-but-unverified trial, not a regression. Two trial-side fixes made it partly runnable: pinning the Debug-only `readerLabEntryDirection=ltr` (the direction case asserts LTR slider geometry before it switches to RTL itself) and replacing a fixed 2200 ms settle with a wait for `rkit-image-viewport`. After those, case 1 `chromeDoesNotOwnTheViewport` **passes** (the surface renders the real cover at `1 / 46`; chrome shown/hidden, double-tap and pinch-reset all behave — artifacts `.hvigor/outputs/nexte-chrome-f450aad/.../03-chrome-caps/{shown,hidden,double-tap,pinch-reset,navigation-same-source}.png`). Case 2 `sourceSeekAndDirectionRemainReadingIntents` then failed at `:360` (right-third tap did not advance) — **root cause found and fixed**: the case asserts that the viewport’s right/left thirds advance/retreat, which only holds for the edge-based RIGHT_LEFT tap preset with no inversion, but device 197 carries a persisted `lShaped` + `both` preset (verified read-only in `nexte_settings`: `reading.tapZoneLayout=lShaped`, `reading.tapZoneInvert=both`), and inversion mirrors the right-middle `next` region to the left, so the right-third tap correctly does not advance. Pinning the in-memory tap-zone state (`rightLeft`/`none`, restored afterwards, persisted preference untouched) alongside the LTR pin makes the trial **pass 2/2** on 197 at `f450aad`, with pixel evidence of the in-session direction switch: `navigation-ltr` `2 / 46` with the LTR slider `2 ...`; `navigation-rtl` stays `2 / 46` with the slider reversed (`46 ... 2`); `navigation-rtl-next` (RTL left third) advances to `3 / 46`; `navigation-rtl-previous` (right third) returns to `2 / 46`. Source commits: `test(reader): make ReaderChromeTrial robust to device direction and cold decode` (`64f13264`), `test(reader): pin tap-zone preset in the NextE chrome direction case` (`bd740ca8`). Artifacts: `.hvigor/outputs/nexte-chrome-f450aad/.../{09-chrome-tapzone-pinned,10-nav-caps}/`.  Koma explicit fallback re-verified at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): the in-app Settings → Reading 「阅读器实现」 selector defaults to 「现有阅读器」 (legacy) and additionally offers 「共享阅读器」. Selecting 共享阅读器 and opening the real 第31话 from the ordinary shelf produced the shared surface (20 `rkit-*` nodes, incl. `rkit-chrome-top/bottom`, `rkit-source-slider`, `rkit-host-center-action`, no `reader_key_surface`); selecting 现有阅读器 and reopening the same chapter produced the legacy reader (`reader_key_surface`, zero `rkit-*`, immersive with only the passive `1 / 33` badge). So the shared reader is an explicit, reversible opt-in and the legacy reader is the default and the single-step fallback. Artifacts: `.hermes-artifacts/20260917-koma-chapter-f450aad/{24-backend-menu,28-menu-dump,29-shared-open2,30-legacy-open2}/`. 
- Koma close-returns-to-source re-verified at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): selecting shared and opening from the ordinary shelf continue card, then closing the shared reader, returned to the **shelf** (`书架` header, continue card, root tabs) with `rkit-reading-surface` gone, and the continue card correctly reflected the chapter last read (`虽然我是不完美恶女 · 第31话`), i.e. the close handoff preserves and exposes the same position the reader wrote. Artifacts: `.hermes-artifacts/20260917-koma-chapter-f450aad/23-close-returns/`.
- Koma cross-version (upgrade/rollback) runtime continuity re-verified at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`, rollback target main `0399e257`): the pinned candidate wrote a non-default position on the real 虫虫村 18 chapter (durable row `chapter:manhua-chongchongcun:1220470:6 pageIndex 1 -> 3`, `totalPages 6`), then `install -r` of committed main `0399e257` + cold start + the ordinary shelf→「继续阅读」 resume read that same row back (`pageIndex 3`, page label `4 / 6`), and restoring the pinned candidate + cold start again read `pageIndex 3` / `4 / 6`. So the candidate-written reading position survives a cross-version replacement **and** the rollback, and the same page resumes through the ordinary entry on both revisions. Artifacts: `.hermes-artifacts/20260917-koma-crossversion-f450aad/{01-candidate-write,02-rollback-resume,03-restore-candidate}/`. This moves the earlier `8f11c550` cross-version record onto the pinned revision.
- Koma shared-reader **image information** re-verified at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): the earlier Koma image-info evidence was produced against the older `5d526ce` pin, so it is re-run here on `f450aad`. Opening the real offline chapter (虽然我是不完美恶女 第28话, page `1 / 40`, `章节 17 / 45`) via the stable lab entry and selecting the shared More item `rkit-image-info` 「图片信息」 (the full More menu also lists `rkit-reload-source` 「重新加载图片来源」, `rkit-reset-zoom` 「重置缩放」, `rkit-host-action-manga-detail` 「漫画详情」, `rkit-previous-chapter` 「上一章」, `rkit-next-chapter` 「下一章」) raises the shared information dialog 「图片信息 · 第 1 页」 reporting real file facts (格式 JPEG, 大小 430.4 KB, 当前 未知, 显示尺寸 1000 x 1422) over the real page art with the shared chrome intact (top `1 / 40`, bottom slider and the Koma-only `章节 17 / 45` centre control). The run is read-only (no progress write, no library/download change; the single Koma host state was left at its pre-run value). Artifacts: `.hermes-artifacts/20260917-koma-image-info-f450aad/{01-discovery,02-info}/`. This moves the earlier `5d526ce` Koma image-info record onto the pinned revision.
- Koma chapter-navigation **first-anchor boundary isolated** at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): the earlier note that the first anchor's disabled state was not isolated is now closed with a concrete observation. Directly opening the true library-first chapter (unit `chapter:manhua-suiranwoshibuwanmeienv:1664686:35`, 第43话, which the reader labels `章节 1 / 45`) and opening the shared More menu gives `rkit-next-chapter` 「下一章」 **disabled** and `rkit-previous-chapter` 「上一章」 **enabled** (`rkit-chrome-page 1 / 35`), stable both at the settled page and after a `重试` (artifacts `.hermes-artifacts/20260917-koma-boundary-f450aad/08-first-unit-clean/{settled-layout,menu-layout}.json`). This is internally consistent with the already-recorded chapter-switch direction (tapping 下一章 from 第28话, list index 16, moved to 第29话, list index 15 — i.e. 下一章 = list-index - 1, 上一章 = list-index + 1): at list index 0 the 下一章 neighbour does not exist, so it is disabled, while the 上一章 neighbour exists. The opposite end anchor (动画化, `1635329:3`, reader `章节 45 / 45`) still cannot be re-isolated because that chapter is not downloaded and its page fails to load, so the More menu does not open; the earlier `20-last-ch-more` capture where both `上一章` and `下一章` were disabled is therefore a load-failure chrome state, not an end-boundary reading — recorded as such rather than claimed. The run is read-only (a library-store read plus the picker/reader inspection; no progress, download or library data changed; the library-store read is a plain `file recv`). Artifacts: `.hermes-artifacts/20260917-koma-boundary-f450aad/{01-discovery,02-top,04-library,08-first-unit-clean}/`.
- Koma chapter-navigation **both end boundaries isolated on real downloaded content** (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): the earlier first-anchor probe had to open a library-first chapter whose page failed to load, and the end anchor was undownloadable, so the disabled states were ambiguous. A **single-chapter** downloaded work resolves both at once because it is simultaneously its own first and last unit: opening the real 虫虫村 (`com.dm5.koma:manga:manhua-chongchongcun`, unit `chapter:...:1220470:6`, reader `章节 1 / 1`, page `1 / 6`) through the stable lab entry and raising the shared More menu shows `rkit-previous-chapter` 「上一章」 **disabled** and `rkit-next-chapter` 「下一章」 **disabled**, with the real page art decoded and `rkit-host-center-action` reading `章节 1 / 1`. So at a true single-unit catalog both neighbours are correctly absent. Combined with the list-index-0 observation (`下一章` disabled, `上一章` enabled at `章节 1 / 45`), the host-owned boundary semantics are: `canPreviousUnit`/`canNextUnit` track the real adjacent-unit existence, and the reader disables exactly the missing neighbour(s). This supersedes the earlier ambiguous end-anchor capture (the `20-last-ch-more` both-disabled frame is a load-failure chrome state, not an end-boundary reading). Read-only run (no progress write). Artifact: `.hermes-artifacts/20260917-koma-boundary-f450aad/11-single-chapter/{settled-layout.json,menu-layout.json,menu-screen.png}`.
- Koma chapter-orchestration **failure and cancellation device-verified at the pin** (2026-09-18, 197, candidate `6553e2df` reader-kit `f450aad`): Package 4's named paths "failure, cancellation, rapid A-B-C" previously rested on focused source/state evidence only; they now have real-device evidence through the existing Debug `readerLabChapterProbe`. Opening the real 第28话 (`1 / 40`, `章节 17 / 45`) and tapping the shared More `下一章`:
  - with `readerLabChapterProbe=prepare-fail-once`, the host logs `chapter_probe kind=prepare-fail-once` then `chapter_failed direction=next source=…1451220:40 target=…1460061:26`, and the reader **stays** on `1 / 40` / `章节 17 / 45` — a failed chapter preparation does not falsely commit the new unit. Artifacts: `.hermes-artifacts/20260918-koma-chapter-fail/run3/{menu.json,after.json}`.
  - with `readerLabChapterProbe=prepare-delay-once`, closing the reader during the in-flight preparation logs `chapter_cancelled direction=next …` (not `chapter_opened`), i.e. the pending chapter preparation is cancelled and does not commit when the reader is dismissed. Artifacts: `.hermes-artifacts/20260918-koma-chapter-cancel/run4-close/run-metadata.json`.
  - (The `prepare-delay-once` probe without an intervening cancel simply completes and opens the next chapter — `chapter_opened direction=next unit=…1460061:26` — which is the success path, retained at `.hermes-artifacts/20260918-koma-chapter-cancel/run1-3/`.) Together with the earlier chapter-switch/boundary/read-complete records, Koma's host-owned chapter orchestration is now device-verified across **success, failure, cancellation, both boundaries and per-chapter completion** at the pin. Read-only runs (no progress/preference write). **Rapid A-B-C now also device-observed:** in a follow-up run the picker was driven through three quick selections in one session — 第28话 (40P) -> 第31话 (33P, `unit=…1510031:33`) -> 第27话 (34P, `unit=…1441050:34`) — logging two `chapter_boundary direction=picker` + `chapter_opened` pairs, and the final reader matches the last choice (`1 / 34`, `章节 18 / 45`). So a rapid picker-select sequence commits in order with the last selection winning (artifact `.hermes-artifacts/20260918-koma-rapid-abc/run4/`). The **cancel-during-rapid** variant that would cancel the first in-flight prepare is the same `chapterRequest?.cancel()` path already device-verified by the cancellation run; the earlier two attempts (`run1`, `run2-delay`) that only committed the first pick are retained as superseded.

- Koma **runtime reading-mode control** exercised on real content at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): the earlier Koma display-mode records entered spread/continuous through the Debug-only `readerLabEntryLayout` launch override, not through the user control. This run uses the shipped control instead: with the real 第28话 open, tapping the shared `rkit-reading-mode` bottom-bar button raises the full RuntimeMenu (「单页 / 纵向分页 / 双页 / 连续 / 开启裁边 / 右→左 / 封面：单 / 拆分：关」) — matching the legacy Koma reader menu — and tapping 「双页」 switches the live session to a two-page `rkit-native-pager` (both leaves `rkit-part-0-whole` + `rkit-part-1-whole` decoding the real 二十八话 page 1|2 art, the spread glyph active). So the same shared mode control that the hosts expose is the one that performs the switch, not only a lab parameter. Artifacts: `.hermes-artifacts/20260917-koma-boundary-f450aad/{12-runtime-mode/menu-screen.png,13c-recv/screen.png}`. Read-only run (mode change is in-session; the persisted Koma preference was not observed to change).
- Koma shared-reader **zoom** verified on real content at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): the objective requires 缩放 to be preserved, and Koma had no pinned shared-reader zoom evidence. Opening the real 第28话 (page `1 / 40`) and double-tapping the page zooms it — `rkit-part-0-whole` expands from the fitted `[0,464][1260,2256]` to the full viewport `[0,124][1260,2720]` at an unchanged `1 / 40`, and the pixels confirm the same page magnified (content fills the width, the DM5 page detail is larger). The shared More menu then reports `rkit-reset-zoom` 「重置缩放」 **enabled** (vs. its normal disabled/greyed state), i.e. the shared reader tracks the live zoomed viewport exactly as the legacy Koma reader's `重置缩放` action did. Artifacts: `.hermes-artifacts/20260917-koma-zoom-f450aad/run/{baseline,zoom,menu}-{layout.json,screen.png}`. Read-only run (zoom is in-session viewport state; no progress or preference written).
- Koma shared-reader **reset-zoom click actually restores geometry** (verified 2026-09-18, 197, candidate `6553e2df` reader-kit `f450aad`): the earlier Koma zoom record only observed that the shared More menu's `rkit-reset-zoom` 「重置缩放」 turns **enabled** once zoomed; this run closes the click-through half. Opening the real 第28话, double-tapping to zoom drives `rkit-part-0-whole` to the full viewport `[0,124][1260,2720]` (from the fitted `[0,464][1260,2256]`), the live menu bounds of `rkit-reset-zoom` are read from the dump (`[675,637][1195,793]`, not a guessed screen coordinate), and clicking it returns `rkit-part-0-whole` to `[0,464][1260,2256]` — byte-identical to the pre-zoom fitted baseline. So the shared navigation/topology-fenced reset command really resets the viewport transform on device, not just the menu state. Read-only run (zoom is in-session viewport state; no progress or preference written). Artifacts: `.hermes-artifacts/20260917-koma-resetzoom/run2/{zoom.json,menu.json}` (zoom state + menu bounds), `.hermes-artifacts/20260917-koma-resetzoom/run3/after.json` (post-click fitted geometry).

- Koma shared-reader **crop (裁边) toggle** verified on real content at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): opening the real 第28话, the shared runtime menu (`rkit-reading-mode`) shows `开启裁边`; tapping it toggles the session crop, and reopening the same menu shows `关闭裁边` — the control reflects the live enabled state (host `KomaReaderLabPage.onCropChanged` → `applyCrop`), so the crop dimension is preserved on real content through the same control the user sees. Artifacts: `.hermes-artifacts/20260917-koma-crop-f450aad/run/menu-{layout.json,screen.png}`. Read-only run (crop change is in-session; the persisted Koma preference write path was not enabled for this read-only run).
- Koma shared-reader **direction toggle (右→左)** verified on real content at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): opening the real 第28话, the shared runtime menu shows `右→左` (the device's persisted RTL direction); tapping it flips the item to `左→右` on reopen, and the pixels show the change applied to the live session — the source slider reverses (its min `40` now renders at the **left** end with the knob at the far left, exactly the shared `ReaderChrome` RTL slider reversal) while the page stays `1 / 40`. So the direction dimension is preserved and driven by the same user control, matching legacy `ReadMode.RTL/LTR` semantics. Artifacts: `.hermes-artifacts/20260917-koma-direction-f450aad/run/menu-{layout.json,screen.png}`. Read-only run (in-session direction; no persisted preference write enabled).
- Koma shared-reader **tap-zone control (点击区域) on real content** (verified 2026-09-18, 197, candidate `6553e2df` reader-kit `f450aad`): the objective requires the tap-zone dimension preserved and Koma had no pinned shared-route tap-zone evidence. With the real 第28话 open (page index 4 → `5 / 40`) through the stable lab entry, the default `right_left` preset is wired end-to-end: tapping the **right** third produced `4 / 40`, tapping the **left** third returned `5 / 40`, and tapping the **center** third hid the chrome (only the passive `5 / 40` badge remained). The directions match the shared RTL tap mapping — under the device's persisted RTL, the right third is `previous` (label 4) and the left third is `next` (label 5), i.e. `pageTap`'s `right && rtl → previous` / `left && rtl → next` branch — and the center maps to the chrome toggle. So Koma's `tapPolicy`-resolved tap zones drive real page turns and the chrome on the shared surface, not just a source mapping. Read-only run (tap zones are in-session; no preference written). Artifacts: `.hermes-artifacts/20260917-koma-tapzone/run2/{baseline,after-right,after-left,after-center}.json`.
- Koma shared-reader **system Back key closes the reader and returns to the host shelf** (verified 2026-09-18, 197, candidate `6553e2df` reader-kit `f450aad`): the objective requires the return behavior preserved and Koma's prior close records only used the shared `rkit-close` button. With the real 第28话 open through the stable lab entry the layout carries the full shared surface (20 `rkit-*` nodes incl. `rkit-reading-surface`/`rkit-chrome-top`/`rkit-chrome-page` `1 / 40`); injecting the system Back key (`uitest uiInput keyEvent 2`) closes the shared route — the post-Back dump has **zero** `rkit-*` nodes and the host shelf is restored (「书架」 header, the real 「虽然我是不完美恶女」 card with 「继续阅读 第31话 … P 1 / 3%」 and the other library cards). So the Koma shared route honours the host's `onBackPressed → closeReader()` contract on device, not only the on-screen close control. Read-only run (no progress/preference write). Artifacts: `.hermes-artifacts/20260917-koma-backkey/run2/{reader.json,after-back.json}`.


- Koma shared-reader **auto-read (rkit-auto-read)** verified on real content at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): opening the real 第28话 and tapping `rkit-auto-read` makes the reader advance pages on its own — `1 / 40` → `3 / 40` → `4 / 40` over the wait with the clock glyph highlighted (accent), i.e. the autonomous timer drives real page turns, matching legacy Koma 自动翻页. Tapping the same control again stops it: after the stop the page held at `5 / 40` across a 15 s wait (immediate post-stop dump `5 / 40` equals the +15 s dump `5 / 40`), so stopping is stable and does not keep advancing. Source confirms the semantics (`ReaderAutoReadController.setEnabled(false)` cancels the timer). Artifacts: `.hermes-artifacts/20260917-koma-autoread-f450aad/{run/auto-screen.png,stopcheck5/{running.json,stop-now.json,stop-later.png}}`. Read-only run (auto-read is in-session; no interval/setting persisted).
- Koma shared-reader **keep-awake (保持常亮)** verified on real content at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`, `install -r` only): the earlier Koma keep-awake record was a limited 2026-09-08 lifecycle check on the pre-pin build. Opening the real 第28话 through the stable lab entry shows the shared route acquiring the window keep-awake lease — `[ReaderKeepScreenOn] requested=true previousDesired=false`, `captured_previous=false`, `enabled_readback=true` (the reader page is `1 / 40` with `rkit-close` present) — and releasing it on close: `restored_readback=false expected=false`, `requested=false previousDesired=false closed=true`. So the host-owned keep-awake lease is driven by the shared route on real content at the pin, and the device's window policy is restored on exit. Artifacts: `.hermes-artifacts/20260917-koma-keepscreen/run1/{open.json,run-metadata.json}`. Read-only run (no preference changed).
- Koma **wide-page (宽图模式) shared rotation re-verified at the pinned revision** (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`, `install -r` only): the earlier wide-rotation evidence was at reader-kit `cce3df6`, and the shared displayed-frame ratio path changed after it (`52c80b3 refactor(reader): share displayed frame ratio`, which touches the rotated-frame ratio), so the record is re-established at the pin. The deterministic 1920x1080 packaged fixture (`reader-wide-split-fixture`, still persisted in the device's `library-store.v1.json`) is opened directly through the stable lab entry with the Debug-only `readerLabRotateWidePages` override (never a persisted setting). With the override **off** the shared reader presents the wide page as a split half: `rkit-part-0-left` at `[0,651][1260,2069]`, i.e. a 1260x1418 frame (aspect 0.889 = source half 960x1080). With the override **on** it presents the whole page rotated clockwise: `rkit-part-0-whole` at `[0,240][1260,2480]`, i.e. a 1260x2240 frame (aspect 0.5625 = source 1080x1920 after rotation). So the shared wide-page classification (`readerPageIsWide`, ratio 1.2) and clockwise rendering are intact at the pin, and the two wide-page modes are mutually exclusive. The production Koma mapping is unchanged source-side: `KomaReaderInitialPolicy` maps `wideImageMode === 'rotate_wide_pages'` → `policy.rotateWidePages` (and `'split_wide_pages'` → `policy.splitWidePages`) and the bridge maps back. Artifacts: `.hermes-artifacts/20260917-koma-wide-f450aad/run1/{off,on}.json` (read-only; no preference written), plus the read-only store recon `.hermes-artifacts/20260917-koma-wide-recon/run1/library-store.json`.
- NextE shared-reader **auto-read (rkit-auto-read)** verified on real content at the pinned revision (2026-09-17, 197, candidate `b7d6d03f` reader-kit `f450aad`): NextE had no pinned shared-reader auto-read device evidence. Opening the real gallery 4175844 through the NextE shared lab, tapping `rkit-auto-read` advances pages on its own — `1 / 46` → `4 / 46`/`5 / 46` with the clock glyph highlighted (accent), i.e. the shared timer drives real turns, matching legacy NextE 自动翻页. Tapping the control again stops it: the page held at `6 / 46` across a 15 s wait (immediate post-stop dump `6 / 46` equals the +15 s dump `6 / 46`, clock glyph dimmed), so stopping is stable. Artifacts: `.hvigor/outputs/nexte-autoread-f450aad/{01-discovery,02-stopcheck}`. Read-only run (auto-read is in-session; the host read-mode interval setting was not changed).
- NextN `ReaderChromeTrial` run at the pinned revision (2026-09-17, 197, candidate `c181d104` reader-kit `f450aad`): the trial had no prior pinned pass record in this worktree. It passes **2/2** (`chromeDoesNotOwnTheViewport`, `sourceSeekAndDirectionRemainReadingIntents`), exercising the shared surface controls on real content 678049: chrome shown/hidden via tap, double-tap zoom, pinch-reset, spread toggle + slider seek, the `rkit-runtime-settings` menu switching `连续` (continuous) and `右→左` (RTL), and close. Pixel evidence: `continuous.png` shows continuous mode at `6 / 14` with the long-page body and full chrome/slider intact (no height-crop); `navigation-rtl.png` shows the in-session RTL applied (the source slider reversed, `14` left / `2` tracked right) at `2 / 14`; `spread-seek.png` shows the seek landing at `6 / 14`. So NextN reading-mode, direction, zoom and seek controls all work through the shared surface on real content at the pin. Artifacts: `.hvigor/outputs/nextn-chrome-f450aad/{run/run-metadata.json,caps/}`. Read-only run.
- Koma shared-reader **host settings sheet** verified on real content at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`): with the real 第28话 open and the read-write lab flag set (`readerLabPreferencesReadWrite=true`, which is what makes the host inject `hostSettings`), the shared top-bar gear is `rkit-host-settings` and tapping it opens the **host-owned** 「阅读」 sheet over the real page — rows 「布局 → 模式 单页 / 阅读方向 从左到右 / 翻页动画;点击区域 → 点击区域预设 左右分区 / 点击区域翻转 水平翻转;显示 → 阅读背景 黑色」. This confirms the settings-sheet parity boundary on device: the shared chrome owns only the gear entry point, and the host injects its own content (`ReaderSettingsContent` via `@BuilderParam settingsSheetContent`), exactly as the ownership model requires. (Without the read-write flag the gear is the runtime `rkit-runtime-settings` menu — a lab-config artifact, not a divergence.) Artifacts: `.hermes-artifacts/20260917-koma-settings-f450aad/{run-rw2/chrome-layout.json,recv2/{sheet-layout.json,sheet-screen.png}}`. Read-only run (the sheet was opened and inspected; no row was changed).
- NextN shared-reader **host settings sheet + host actions** re-verified at the pinned revision (2026-09-17, 197, candidate `8f395ca7` reader-kit `f450aad`): the tracked `ReaderProductionHostActionsTrial` (`usesHostSettingsAndExposesExternalOpenWithoutDuplicatingTopRuntimeMenu`) passes **1/1**, logging `hostSettings=true topRuntimeDuplicate=false bottomRuntime=true externalOpen=true translationActions=true translationConfigured=true historyRestored=true`. Pixel evidence: `host-settings.png` shows the shared gear opening the **host-owned** 「阅读」 sheet (`阅读模式 → 翻页方向 从右到左`; `翻页模式 → 双页模式 / 双页布局 / 翻页动画 / 点按区域 / 反转点按区域 / 自动裁剪页面留边 / 裁边强度`) over the real long page at `3 / 14`; `host-more.png` shows the More menu with `重新加载图片来源 / 图片信息 / 在外部浏览器中打开 / 重置缩放 / 翻译当前页 / 自动翻译`; `host-closed.png` returns to the Detail page (`继续 P3`). The trial also asserts the top chrome carries no duplicate runtime-mode menu when the host settings path is active (`topRuntimeDuplicate=false`), so the settings-sheet ownership boundary holds on device for NextN too. Artifacts: `.hvigor/outputs/nextn-hostsettings-f450aad/{run/run-metadata.json,caps/}`. (This is a shared-gear host-settings device check at the pin; the earlier Package-2 settings record was at an older revision.)
- NextN **volume-key page turning** verified at the pinned revision (2026-09-17, 197, candidate `0526937d` reader-kit `f450aad`): the tracked `ReaderVolumeKeysTrial` (`logicalKeysRespectZoomMenuAndRouteLifecycle`) passes **1/1** after a trial-only fix. Root cause of the earlier error was trial brittleness, not a product defect: the trial launches with no direction pin and asserts the runtime menu starts LTR (it looks for `右→左` to switch to RTL), but device 197 persists RTL, so the menu already shows `左→右` and the lookup returned null (`Cannot read property click of null` at `ReaderVolumeKeys.test.ets:216`). Pinning the Debug-only `readerLabEntryDirection=ltr` — the same launch-parameter pattern the sibling `ReaderPagingAxis`/`ReaderSpreadLayout` trials already use — makes it pass; no product change. Pixel evidence: `baseline.png` at `1 / 14`; `next.png` at `2 / 14` after one volume-down; `rtl-next.png` at `3 / 14` with the source slider reversed (`14` left / `3` tracked) after switching to RTL; `continuous-next.png` at `4 / 14` in continuous mode — so volume keys turn pages in single, RTL and continuous modes and respect zoom/menu/route lifecycle as the trial asserts. Artifacts: `.hvigor/outputs/nextn-volumekeys-f450aad/{run2/run-metadata.json,caps2/}`. (This closes the NextN volume-key runtime item that was still `OPEN` in the 2026-09-12 acceptance ledger.) Re-run on the recovered 197 after its system update (2026-09-17, candidate `a7ae696e`): the same trial passes 1/1 again with `ReaderVolumeKeys intent=next accepted=true`, so the fix is stable across the device OS update. Artifact: `.hvigor/outputs/nextn-volumekeys-f450aad/run-postupdate/`.
- NextN **initial-policy inheritance** verified at the pinned revision (2026-09-17, 197, candidate `11039f89` reader-kit `f450aad`): the tracked `ReaderInitialPolicyTrial` main case (`savedPolicyBeforeFirstSurfaceAndExplicitOverride`) passes **1/1** — its only prior record (2026-09-13) covered just the separate `ReaderInitialPolicyRestoreTrial`/`ReaderInitialPolicyReadbackTrial`, so this main case had no pinned-revision evidence. The run drives the real lab entry through all six saved-policy states and asserts the shared surface opens at the persisted page (`initialPage=3`, `sourceIndex=2`) with the saved mode/layout/direction applied before the first surface: `case=0` single paged (`afterSwipePage=4`), `case=1` vertical paged (`initialPage=3`), `case=2` continuous (`rkit-continuous-list`, no `rkit-native-pager`), `case=3` RTL split (`part2=[0,124,630,2720]`, `other=1:[630,124,1260,2720]`, one-leaf-two-viewport half-width split), `case=4` RTL joined (`part2=[429,124,634,2720]`, `other=3:[634,124,832,2720]`, both leaves inside one viewport), and `case=5` explicit LTR override. It also verifies each saved key via `ReaderSettingsRepository`, then restores the exact live snapshot and the four raw `reader_settings` rows (`restored mode=paged_rtl double=false spread=joined column=odd_left exactRawKeys=4`), leaving the device at its pre-run value. `Tests run: 1, Failure: 0, Error: 0, Pass: 1`. Artifact: `.hvigor/outputs/nextn-initial-policy-f450aad/run-678049/run-metadata.json`. (Note: a first attempt used gallery `4156592` — a NextE id — and read a `0 / 0` empty pager; the correct NextN lab work is `678049`. The empty result was an input error, not a product defect.)
- NextN **auto-translation with next-page warm/reuse** verified at the pinned revision (2026-09-17, 197, candidate `f31a3f53` reader-kit `f450aad`): the tracked `ReaderProductionAutoTranslationTrial` (`translatesTheCurrentPageThenWarmsAndReusesTheNextResult`) had no pinned-revision 197 record; it passes **1/1**. Through the ordinary Detail Read entry on the real gallery with the local translation seam it enables auto-translation (accepting the consent dialog), asserts the current page prepares and applies (`2:prepare`/`2:applied`) and that the next page is warmed (`3:prepare`/`3:applied`) with each page prepared exactly once (no duplicate work), then turns one page and confirms the next page's translated result is already available (`显示原图` enabled) without a second prepare for that page (`prepareCounts.get(3)==1`). It restores the history snapshot, reader mode and the two raw `reader_settings` rows afterward. Artifact: `.hvigor/outputs/nextn-auto-translation-f450aad/run1/run-metadata.json`. (Local-route seam only; the non-local/cloud provider path stays OPEN as recorded in the parity matrix.)
- NextN **auto-translation failure/cancellation/physical variants** verified at the pinned revision (2026-09-17, 197, candidate `e344e450` reader-kit `f450aad`): four tracked variants that had no pinned-revision record each pass **1/1** through the ordinary shared Detail Read entry on the local translation seam: `ReaderProductionAutoTranslationFailureTrial` (auto failure then next-page recovery), `ReaderProductionAutoTranslationCancellationTrial` (navigation cancels the in-flight translation), `ReaderProductionAutoTranslationContinuousFailureTrial` (continuous layout: current-page failure with the next page still preparing/applying), `ReaderProductionAutoTranslationContinuousCancellationTrial` (continuous: navigation cancels), and `ReaderProductionAutoTranslationContinuousPhysicalTrial` (continuous: the physical turn/scroll path drives the warm/reuse behaviour). Together with the base `ReaderProductionAutoTranslationTrial` and the manual `ReaderProductionTranslationTrial` recorded above, the NextN auto-translation design is now device-verified at the pin across single, continuous, failure, cancellation and physical-navigation paths. Each run restores the history snapshot, reader mode and settings rows. Artifacts: `.hvigor/outputs/nextn-{atr-cancel,atr-cont-failure,atr-cont-cancel,atr-cont-phys}-f450aad/run1/run-metadata.json`. (Local-route seam only; the non-local/cloud provider path remains OPEN in the parity matrix.)
- NextN **auto-translation spread-mode variants** verified at the pinned revision (2026-09-18, 197, candidate `76b94559` reader-kit `f450aad`): the three tracked spread-mode auto-translation variants (`ReaderProductionAutoTranslationSpreadTrial`, `...SpreadFailureTrial`, `...SpreadCancellationTrial`) had **no record** in this work order; each passes **1/1** through the ordinary shared Detail Read entry on the local translation seam, with the real gallery 678049 forced into an RTL split spread (both visible leaves `rkit-part-2-whole`/`rkit-part-3-whole`). The base trial asserts both visible sources translate once each (no duplicate prepares) while the anchor stays on page 2 and the host status clears; the failure variant shows a current-page translation failure recovering on retry while the partner leaf keeps its translated result; the cancellation variant cancels the in-flight translation on navigation. All three are `Tests run: 1, Failure: 0, Error: 0, Pass: 1`; the retained `trial-log` for the failure run carries the fact line `translationAutoSpreadFailure=true partnerContinued=true currentRetryRecovered=true bothLeavesPresent=true hostStatusCleared=true historyRestored=true settingsRestored=true`, while the base/cancellation postflight grep truncated before their own fact lines (their pass is evidenced by the Hypium summary, and their asserted facts are the ones in the trial source). Each run restores the history snapshot, the reader mode/double/spread settings and the four raw `reader_settings` rows. With the earlier single/continuous variants this makes the NextN auto-translation design device-verified across single, continuous **and spread** modes plus failure/cancellation/physical paths at the pin. Artifacts: `.hvigor/outputs/nextn-atr-spread-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nextn-atr-spread-fail-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nextn-atr-spread-cancel-f450aad/run1/run-metadata.json`. (Local-route seam only; the non-local/cloud provider path remains OPEN in the parity matrix.)
- NextE **volume-key page turning** verified at the pinned revision (2026-09-17, 197 `ALN-AL80` **and** authorized 237 `VDE-AL00`, candidate `3eb886ad` reader-kit `f450aad`): the tracked `ReaderVolumeKeysTrial` (`logicalKeysRespectZoomMenuAndRouteLifecycle`) now passes **1/1 on both devices** after a trial-only fix; no product source changed. The earlier failure was two independent trial defects, not a product defect and not a device/harness capability gap: (1) the trial launched with no direction pin and looked for `右→左` to switch to RTL, but 197/237 persist the reader direction as **RTL**, so the lookup returned null; it now pins the Debug-only `readerLabEntryDirection=ltr` — the same launch-parameter pattern the sibling `ReaderSpreadLayout`/`ReaderPagingAxis` trials use. (2) the trial proved release-on-background by backgrounding the app and then reading the page from the *same* route, but NextE **intentionally retires the shared reader route on app background** (asserted by its own `ReaderLifecycleRecoveryTrial` and `ReaderInformationBackgroundTrial`, and stated by the reader package contract that background retires shared presentation state); the trial now asserts the route is retired after background and re-enters with a fresh explicit request, then asserts volume-key turning re-arms on the new route. Verified on 197: `Tests run: 1, Failure: 0, Error: 0, Pass: 1` with `[ReaderVolumeKeys] intent=next accepted=true`; 237: `Tests run: 1, Failure: 0, Error: 0, Pass: 1`. Artifacts: `.hvigor/outputs/nexte-volumekeys-f450aad/{run-fix3/run-metadata.json}` (197), `.hvigor/outputs/nexte-237-volumekeys/{run-fix1/run-metadata.json}` (237). The earlier 197/237 failure artifacts are superseded. (NextN's twin trial is verified at the pin — see the NextN volume-key record.)
- NextE **volume-key preference + system-volume release** verified at the pinned revision (2026-09-17, 197, candidate `516c60ed` reader-kit `f450aad`): two tracked NextE trials that had no pinned-revision record now each pass **1/1** after the same trial-side route correction already applied to the NextE volume page-turn trial (no product change). `ReaderVolumePreferenceTrial` drives all four persisted/explicit cases and restores the store exactly (`[ReaderVolumePreference] case=2 preference=false explicit=false enabled=false release=passed`, `case=3 preference=false explicit=true enabled=true release=passed`, then `restored preference=true volume=1 originalPreference=true originalPresent=true originalLive=true originalReady=true originalVolume=1`). `ReaderVolumeReleaseTrial` proves the release half (`[ReaderVolumeRelease] before=1 after=2 increase=true`, `restored=1 expected=1`). Artifacts: `.hvigor/outputs/nexte-vol-pref-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nexte-vol-release-f450aad/run1/run-metadata.json`.
- NextE **complete-download local source (no network fallback)** re-verified at the pinned revision (2026-09-17, 197, candidate `72579579` reader-kit `f450aad`): the earlier record was pre-pin, so the tracked `ReaderLocalSourceTrial` (`completeDownloadOpensSharedReaderWithoutNetworkAndRestoresQueue`) is re-run at `f450aad` and passes **1/1** — it seeds an isolated two-page complete-download fixture, opens the ordinary shared reader through the normal lab entry, and closes back to the host, logging `ReaderLocalSourceTrial source=galleryDownload pages=2 networkFallback=false queueRestored=true` (the local branch served both pages with no EH/network fallback, and the in-memory download queue was restored to its exact pre-run state). Artifact: `.hvigor/outputs/nexte-local-source-f450aad/run1/run-metadata.json`. Read-only w.r.t. persisted user data (temporary fixture and queue mutation are removed in the trial's `finally`).
- NextE **crop (single) runtime toggle** verified at the pinned revision (2026-09-17, 197, candidate `2a03d3fd` reader-kit `f450aad`): the tracked `ReaderCropTrial` (`standaloneBodyCropKeepsSourcePageAndCloses`) had no pinned-revision record; it passes **1/1** on real content 4175844 — it discovers a croppable page (log `ReaderCrop sample=4 detected=true`), confirms the shared paged viewport renders the cropped original with the source page unchanged, toggles crop off/on around the shared surface and closes. Artifact: `.hvigor/outputs/nexte-crop-f450aad/run1/run-metadata.json`. (The spread/continuous/zoom crop variants already have pinned records in the display-mode and large-screen runs.)
- NextE **production crop in continuous mode** verified at the pinned revision (2026-09-17, 197, candidate `e77ce59d` reader-kit `f450aad`): the tracked `ReaderProductionCropContinuousTrial` (`currentProductionP5CropReferenceAndSettingsRestoration`) had no pinned-revision record (only the standard `ReaderCropContinuousTrial` was covered); it passes **1/1** through the ordinary production P5 crop entry on real content 4175844 — it asserts the continuous shared surface renders the cropped original for the current page and restores the reader settings afterwards. Artifact: `.hvigor/outputs/nexte-prod-crop-cont-f450aad/run1/run-metadata.json`.
- NextE **crop strength (裁边强度) retained-page refresh** re-verified at the pinned revision (2026-09-18, 197, candidate `516c60ed` reader-kit `f450aad`): the tracked `ReaderCropStrengthTrial` (`refreshesRetainedSharedCropWhenHostStrengthChanges`) had only stale pre-pin evidence (reader-kit `52da7b67`); it now passes **1/1** at the pin. Opened on real content 4175844 at page 3 with `readerLabCropBorders=true`, it changes the host paged crop strength `CONSERVATIVE -> STRONG` and asserts the shared reader keeps the same retained page while re-fetching the cropped image for the new strength, then restores the prior strength. Pixel evidence (same run): the `strength-before`/`strength-after` whole-screen frames differ across the page body (~38.8% of pixels), consistent with a genuine crop-geometry change at an unchanged page rather than a no-op. Artifacts: `.hvigor/outputs/nexte-crop-strength-f450aad/run1/run-metadata.json` (+ `caps/strength-{before,after}.png`).
- NextE **production shared thumbnail entry + return** verified at the pinned revision (2026-09-18, 197, candidate `516c60ed` reader-kit `f450aad`): the tracked `ReaderProductionSharedThumbnailEntryTrial` (`normalDetailThumbnailUsesSharedForwardAndReturnTransition`) had **no record**; it passes **2/2** on real content 4175844 — both facets (the ordinary Detail preview thumbnail and the standalone all-thumbnails route) hand off from the source thumbnail through the shared entry flight, settle to the shared **RTL split spread** reader, and close back to the **same** Detail thumbnail with unchanged bounds before the transition goes inactive. The retained `trial-log` carries the fact line `backend=shared standaloneAllThumbnails=true forwardSettled=true rtlSpread=true returnedToSameSource=true` (the normal-Detail facet ran first with the same shape). So NextE's real Detail→shared-reader→return path is device-verified at the pin, not only its lab route. Artifact: ``.hvigor/outputs/nexte-prod-thumbentry-f450aad/run1/run-metadata.json`.
- NextE **production crop variants (single / spread / zoom)** verified at the pinned revision (2026-09-18, 197, candidate `516c60ed` reader-kit `f450aad`): the tracked `ReaderProductionCropTrial`, `ReaderProductionCropSpreadTrial` and `ReaderProductionCropZoomTrial` (all `currentProductionP5CropReferenceAndSettingsRestoration`) had **no record**; each passes **1/1** at the pin on real content 4175844. The single variant opens the shared reader (paged, crop on) and closes; the spread variant drives a `JOINED` double-page with crop on; the zoom variant double-taps to zoom, toggles crop on (`changed`) and off (`returned`) at the retained zoomed page. Each restores the reader mode/double/crop settings, all logging `ReaderProductionCrop restored=true mode=rtl double=false crop=false errors=0`. (The continuous variant was already recorded above.) So NextE's production crop is device-verified across single, spread, continuous and zoom at the pin. Artifacts: `.hvigor/outputs/nexte-prodcrop-single-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nexte-prodcrop-spread-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nexte-prodcrop-zoom-f450aad/run1/run-metadata.json`.
- NextE **production original-action menu (原图)** verified at the pinned revision (2026-09-18, 197, candidate `516c60ed` reader-kit `f450aad`): the tracked `ReaderProductionOriginalMenuTrial` (`productionOriginalMenuRetainsVisualSourceSides`) had **no record**; it passes **1/1** on real content 4175844. It opens the shared reader from the ordinary Detail thumbnail into the RTL `JOINED` double-page, resolves the production bottom toolbar's original action from the live Slider/Button bounds (**not** screen coordinates), clicks it, and asserts the original-display menu opens while the spread keeps both visual source sides, then restores the reader mode/double/spread settings. So NextE's real 原图 control is device-verified at the pin on real content. Artifact: `.hvigor/outputs/nexte-origmenu-f450aad/run1/run-metadata.json`.
- NextE **lab-route R`eaderOriginal*RO trials — CLOSED as trial brittleness at the pin** (2026-09-18, 197, candidate `29a14894` reader-kit `f450aad`): both now pass **1/1**. Both were trial-harness brittleness, not shared-reader defects.
  - Original failures: `ReaderOriginalSingleTrial` stopped at its first control lookup `ReaderImageInformation.test.ets:675` and `ReaderOriginalSpreadTrial` at `:612` (`rkit-toggle-spread` null), both with **no** `rkit-*` nodes in the failure dump — the shared chrome was not mounted yet.
  - Fixes (trial-only): the settle + bounded re-entry pattern and the Debug `readerLabEntryLayout=single` / `readerLabEntryDirection=ltr` pins the sibling trials use, so the chrome is mounted before the first lookup; a new `originalActionReady(...)` waits for the chrome original action to enable (it requires the page asset to reach `displayed`) instead of assuming the first ready frame; and the spread reflow (two cold remote pages) gets a 120 x 500 ms window before both menu items enable. Switching back to the resampled page re-decodes a JPEG-WEBP asset, so the information re-readiness wait is widened; `assertInformation` now takes the attempts budget.
  - Device evidence: single reads `当前：原图` 1.8 MB JPEG/1290x1821 then `当前：重采样图片` 134.3 KB WEBP/800x1129 at P2; spread asserts both visual sides' variants and positions. No product source changed (commit `29a14894`). Artifacts: `.hvigor/outputs/nexte-orig-single-f450aad/run-197-r5/run-metadata.json`, `.hvigor/outputs/nexte-orig-spread-f450aad/run-197-r6/run-metadata.json`. The production original path (`ReaderProductionOriginalMenuTrial`, 1/1) remains the independent acceptance. Superseded failed runs kept.

- NextE **runtime crop on/off via the shared menu — lab trials cannot run as written** (2026-09-18, 197, candidate `516c60ed` reader-kit `f450aad`): `ReaderCropToggleTrial` and `ReaderCropZoomToggleTrial` both failed at `entry/src/ohosTest/ets/test/ReaderImageInformation.test.ets:297` (`expect(toggle !== null)` on `rkit-crop-toggle`) after ~4.5 s, the same **lab-contract mismatch** documented for the NextN twin: the NextE lab sets `cropPolicy.available` from `preferencesReadWrite || labRequest.cropBorders === true` (`NextEReaderLabPage.ets:805-806`), both false for a lab launch with `readerLabCropBorders=false`, so the shared chrome never renders the toggle on that route. This is **not a product defect**: the interactive crop control is device-verified on NextE through the production route at the same pin — `ReaderProductionCropTrial` (crop on, single) and `ReaderProductionCropZoomTrial` (zoom then crop on/off) both pass 1/1 (recorded above) — and on NextN through its production route. No speculative trial rewrite is shipped; the failed runs are retained as counterexamples: `.hvigor/outputs/nexte-toggle-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nexte-zoomtoggle-f450aad/run1/run-metadata.json`.
- NextE **shared-reader progress durability (write → fresh-process restore)** verified at the pinned revision (2026-09-18, 197, candidate `516c60ed` reader-kit `f450aad`): the tracked `ReaderSharedProgressWriteTrial` (`presentedPageFlushesToNextEOwnedProgressStore`) and `ReaderSharedProgressRestoreTrial` (`freshProcessRestoresDurablePageAndRestoresOriginalRow`) had **no record**. Phase 1 opens the shared reader through the ordinary lab entry on real content 4175844, turns one page with a real swipe (`1 / 46` → `2 / 46`), closes, and flushes — the host-owned `NextE.db` progress row becomes `pageIndex 1` (`[ReaderSharedProgressWriteTrial] durablePage=1 recoveryRetained=true`), passing **1/1**. Phase 2 runs in a separate process against that durable row: `connectGalleryReadProgress().getIndex(work) === 1`, the shared reader opens straight to `2 / 46` (`cold-restored-page-2`), and afterwards the exact original row is written back and the recovery marker removed (`[ReaderSharedProgressRestoreTrial] originalRowRestored=true recoveryRemoved=true`), also **1/1**. So NextE's reading progress is written by the shared session into the host store and survives a fresh process, with no fixture row left behind. Artifacts: `.hvigor/outputs/nexte-progwrite-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nexte-progrestore-f450aad/run1/run-metadata.json`.
- NextE **spread horizontal reach, standalone status, and per-page original availability** verified at the pinned revision (2026-09-18, 197, candidate `516c60ed` reader-kit `f450aad`): three tracked trials that had **no record** each pass **1/1** on real content 4175844. `ReaderSpreadHorizontalReachTrial` (`joinedSplitGestureRotationAndSingleton`) drives the spread horizontal-reach path (LTR-pinned) through the shared surface. `ReaderStandaloneStatusTrial` opens the reader over the normal host and asserts the status/navigation bar system properties are restored on close. `ReaderInformationAvailabilityTrial` (`samePageRetainsOriginalAvailabilityAcrossFreshTrialSessions`) runs two fresh launcher sessions on the same page and asserts the image-information dialog reports the same original-availability each time (its required `readerLabExpectedOriginal` Debug param is supplied by the manifest; the earlier ~1 s miss was a missing manifest param, not a product finding). All three restore any state they touch. Artifacts: `.hvigor/outputs/nexte-reach-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nexte-status-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nexte-infoavail-f450aad/run2/run-metadata.json`.
- NextE **thumbnail-entry chrome + host status area + hidden-chrome Back** verified at the pinned revision (2026-09-18, 197, candidate `516c60ed` reader-kit `f450aad`): the tracked `ReaderThumbnailChromeTrial` (`hostStatusAreaFollowsChromeAndRestoresAfterHiddenBack`) had **no record**; it passes **1/1** on real content 4175844. Opening the shared reader from the normal Detail thumbnail into an RTL spread, it toggles the chrome shown→hidden→shown→hidden and asserts the window's `TYPE_SYSTEM` avoid area follows each state, then presses Back with the chrome hidden and asserts the system area is restored on close. So NextE's shared-chrome visibility and the system-UI restore on a hidden-chrome return are device-verified at the pin. Artifact: `.hvigor/outputs/nexte-thumbchrome-f450aad/run1/run-metadata.json`.
- NextE **local-route translation variants (failure / auto / busy)** verified at the pinned revision (2026-09-18, 197, candidate `516c60ed` reader-kit `f450aad`): three tracked Debug-seam local-translation trials that had **no record** each pass **1/1** on real content 4175844 via the ordinary shared reader route. `ReaderHostTranslationFailureTrial` (`surfacesTranslationFailureThenRecoversOnRetry`) forces the local visual provider unavailable for the current page, asserts the shared `rkit-host-status` shows the host failure copy (`reader_comic_translation_local_visual_unavailable`) with no `applied`, then clears availability and retries to `applied` with the status gone. `ReaderHostTranslationAutoTrial` (`autoTranslatesNextPageWhileCurrentFailsAndRecoversCurrentOnRetry`) drives the auto-translate path. `ReaderHostTranslationBusyTrial` (`showsBusyStatusWhileTranslatingThenClearsIt`) shows the busy status while translating and asserts it clears. Two of the three had to be re-run once because their first attempt failed a transient `Reader image did not settle: rkit-image-viewport` precondition (a network page-decode wait, before any translation assertion); the retry passed. With the earlier `ReaderHostTranslationActionsTrial`, the NextE local translation route is device-verified across apply/failure/busy/auto at the pin. Artifacts: `.hvigor/outputs/nexte-tr-fail-f450aad/run2/run-metadata.json`, `.hvigor/outputs/nexte-tr-auto-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nexte-tr-busy-f450aad/run2/run-metadata.json`. (Local-route seam only; the non-local/cloud provider path remains OPEN in the parity matrix.)
- NextE **share preparation failure / close-cancel recovery** verified at the pinned revision (2026-09-18, 197, candidate `516c60ed` reader-kit `f450aad`): `ReaderShareFailureTrial` and `ReaderShareCloseCancelTrial` (the `failure`/`close` modes of the shared share-recovery harness, `readerLabShareProbe=fail-once`/`delay-once`) had **no record**; each passes **1/1** on real content 4175844. The failure mode asserts a one-shot share-preparation failure leaves the shared `rkit-share-image` action re-enabled at the same page and a subsequent share/cancel works; the close mode asserts that closing while a share is pending still leaves the reader closed with no stuck trial navigation, and a fresh session shares normally. Artifacts: `.hvigor/outputs/nexte-share-fail-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nexte-share-close-f450aad/run1/run-metadata.json`.
- NextE **enhancement (超分) status indicator** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197, candidate `516c60ed` reader-kit `f450aad`): the tracked `ReaderEnhancementStatusTrial` (`showsCurrentEnhancementStatusWithChromeShownAndHidden`) had **no record**; it passes **1/1**. With super-resolution enabled on the shared reader over real content, it asserts `rkit-enhancement-status` is present with the chrome shown, then hides the chrome (center tap) and asserts the status indicator is still present while the displayed page image is unchanged. So NextE's enhancement status display is device-verified at the pin. **Transport correction (2026-09-18):** an earlier note here wrongly attributed a device-unreachable state to a 197 Wi‑Fi dropout, based on a `ping` (ICMP) result. `ping` is not a valid authority for HDC reachability: re-checked with `hdc list targets -v`, 197 and 237 both report `TCP Connected` and `hdc -t <target> shell echo ok` succeeds, so the device was online throughout. The run was completed against the device normally; the earlier TCP attempt's `image did not settle` precondition was a transient reader-decode wait, not a transport outage. Artifact: `.hvigor/outputs/nexte-enhancement-f450aad/run-usb/run-metadata.json`.
- NextE **thumbnail-entry auto-read** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `516c60ed` reader-kit `f450aad`): the tracked `ReaderThumbnailAutoReadTrial` (`optionalRtlReaderAdvancesStopsAndReturnsToSameDetail`) had **no record**; it passes **1/1**. Opening the shared reader from the normal Detail thumbnail into an RTL spread, it taps `rkit-auto-read`, asserts a later page is reached and decoded while the entry epoch is unchanged, then stops and closes back to the same Detail source. So NextE's shared auto-read control is device-verified through the real thumbnail entry at the pin (the earlier quick 197 auto-read record used the lab route). Artifact: `.hvigor/outputs/nexte-autoread-f450aad/run-usb/run-metadata.json`.
- NextE **thumbnail-entry save (保存) via the system dialog** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `516c60ed` reader-kit `f450aad`): the tracked `ReaderThumbnailSaveTrial` (`realDetailRtlSpreadAllowsOneTwoImageSystemSaveAndReturnsToSource`) had **no record**; it passes **1/1**. Opening the shared reader from the normal Detail thumbnail into an RTL spread, it opens `rkit-save-image`'s menu (`rkit-save-left`/`rkit-save-right`/`rkit-save-both`), saves the two visible pages, accepts the system dialog 「允许“NextE”保存 2 张图片？」, asserts the reader stays on the same spread epoch, and returns to the same Detail source. So NextE's shared save control reaches the real system save flow at the pin. (The album file landing is not externally readable without root, as recorded for the other hosts.) Artifact: `.hvigor/outputs/nexte-thumbsave-f450aad/run-usb/run-metadata.json`.
- NextE **image-block action/notice + manual source reload** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `516c60ed` reader-kit `f450aad`): two tracked trials that had **no record** now pass. `ReaderImageBlockSharedTrial` (`sharedReaderPreservesNextEImageBlockActionAndNotice`) passes **1/1**: with image-block enabled and a Debug-lab blocked-page probe, the shared More menu exposes the host action `rkit-host-action-mark-image-blocked`, and a blocked page renders the shared `rkit-notice-page-1` notice with its `rkit-notice-action-page-1` and image. `ReaderManualReloadTrial` (`reloadsTheExactVisibleSource`) passes **2/2**: the shared More menu's `rkit-reload-source` reloads the exact visible source (the decoded image generation changes, the page stays 1), in both the default and the body-navigation cases. Both restore the image-block setting and close the trial. Artifacts: `.hvigor/outputs/nexte-imgblock-f450aad/run-usb/run-metadata.json`, `.hvigor/outputs/nexte-manualreload-f450aad/run-usb/run-metadata.json`.
- NextE **settled rotation + continuous reflow on the large screen** verified at the pinned revision (2026-09-18, 237 `VDE-AL00` 1320x2120, candidate `516c60ed` reader-kit `f450aad`): two tracked trials that had **no record** each pass **1/1** on the large-screen form factor. `ReaderProductionSettledRotationTrial` (`realProductionJoinedSpreadRotatesAfterOpeningHasSettled`) opens the shared reader from the ordinary Detail thumbnail into an RTL `JOINED` spread and rotates only after the opening has settled, keeping the visual source sides; `ReaderThumbnailContinuousReflowTrial` exercises the continuous-layout reflow under rotation. So NextE's settled-rotation and continuous-reflow paths are device-verified at the large-screen form factor at the pin. Artifacts: `.hvigor/outputs/nexte-settled-f450aad/run-237/run-metadata.json`, `.hvigor/outputs/nexte-creflow-f450aad/run-237/run-metadata.json`.
- NextE **moving rotation, settled-rotation navigation, continuous boundary-rotation and continuous interpolation on the large screen** verified at the pinned revision (2026-09-18, 237 `VDE-AL00` 1320x2120, candidate `516c60ed` reader-kit `f450aad`): four tracked trials that had **no record** each pass **1/1** on the large-screen form factor — `ReaderThumbnailMovingRotationTrial` (rotate while the shared reader is still moving), `ReaderThumbnailSettledRotationNavigationTrial` (settled rotation plus a navigation step), `ReaderThumbnailContinuousBoundaryRotationTrial` (continuous layout rotated at a chapter/page boundary) and `ReaderThumbnailContinuousInterpolationTrial` (continuous layout interpolation under rotation). With the two recorded above, NextE's rotation/responsive dimension now has real large-screen coverage across joined-spread, moving, settled, navigation, continuous-boundary and continuous-interpolation at the pin. Artifacts: `.hvigor/outputs/nexte-{moving,settlednav,contboundary,continterp}-f450aad/run-237/run-metadata.json`.
- NextE **lab-route thumbnail entry + all-thumbnails grid entry** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `516c60ed` reader-kit `f450aad`): the tracked `ReaderThumbnailEntryTrial` (`realDetailSnapshotHandsOffToSpreadAndClosesToSameSource`) and `ReaderThumbnailGridEntryTrial` (`realAllThumbnailsSnapshotHandsOffToSpreadAndClosesToSameGridSource`) had **no record**; each passes **1/1**. Both open the shared reader from a real Detail snapshot (compact rail and all-thumbnails grid respectively) into the RTL spread, and close back to the same source element with unchanged bounds. Together with the production shared thumbnail-entry record above, NextE's entry/return geometry is device-verified on both the normal and all-thumbnails routes at the pin. Artifacts: `.hvigor/outputs/nexte-thumbentry-f450aad/run-usb/run-metadata.json`, `.hvigor/outputs/nexte-thumbgrid-f450aad/run-usb/run-metadata.json`.
- NextE **image-information close-cancel** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `516c60ed` reader-kit `f450aad`): `ReaderInformationCloseCancelTrial` (the `close` mode of the shared information-recovery harness) had **no record**; it passes **1/1** — closing the shared reader while an information request is pending leaves the reader closed with no stuck trial navigation, and a fresh session's information request still works. Artifact: `.hvigor/outputs/nexte-closecancel-f450aad/run-usb/run-metadata.json`.
- NextE **production settings + crop restore** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `516c60ed` reader-kit `f450aad`): the tracked `ReaderProductionSettingsRestoreTrial` and `ReaderProductionCropRestoreTrial` (`restoresAuthorizedPreTrialReadingSettings`) had **no record**; each passes **1/1**. Each sets the three authorized reading fields to a known baseline from the normal host (mode `LTR`, double-page `true`, and either spread `JOINED` or crop `false`) and asserts both the live `connectReadMode()` state **and** the durable `STORE_SETTINGS` values match, logging `ReaderProductionCropRestore: verified memory_and_preferences mode=ltr doublePage=true crop=false` (and the settings twin `... spread=joined`). So NextE's reader settings write to both memory and the durable store at the pin. Artifacts: `.hvigor/outputs/nexte-restore-settings-f450aad/run-usb/run-metadata.json`, `.hvigor/outputs/nexte-restore-crop-f450aad/run-usb/run-metadata.json`.
- NextE **thumbnail-entry read-only initial policy + settled rotation** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `516c60ed` reader-kit `f450aad`): two tracked trials that had **no record** each pass **1/1** on real gallery 4175844. `ReaderThumbnailInitialPolicyReadOnlyTrial` (`currentCanonicalPolicyFromActualSpriteSource2`) enters the shared reader from the real thumbnail and drives the EH sprite source 2 read-only, asserting the canonical current policy (mode/double/column) and that nothing was written (`fixtureWrites=0`), without changing the host's stored state. `ReaderThumbnailSettledRotationTrial` exercises the settled-rotation path through the shared thumbnail entry. Artifacts: `.hvigor/outputs/nexte-ro-f450aad/run-usb/run-metadata.json`, `.hvigor/outputs/nexte-settledrot-f450aad/run-usb/run-metadata.json`.
- NextE **shared image-information surface — manual device probe at the pin (2026-09-18, ALN-AL80 / 197 (via HDC))**: driving the real shared reader directly (ordinary launch on gallery 4175844, chrome shown) and tapping the shared More → `rkit-image-info-spread` 「图片信息」, the shared surface opens its information dialog and renders the per-pane source entries 「左侧 · 第 1 页」 / 「右侧 · 第 2 页」 — i.e. the shared information surface is present and functional on this device/revision (captured layout + screenshot). This **corroborates** that the two failing `ReaderImageInformation` trials (supplement `:232`, main `:69`) are trial-automation issues (hardcoded zh_CN title/labels and reader-route timing), not a missing/broken shared control: the same dialog opens correctly by direct input. (An attempted re-run forcing `readerLabEntryLayout=single` was **inconclusive** — that manifest dropped the `-s` before `timeout`, so Hypium applied its 5 s default and the trial timed out on a manifest error, not a product finding.) Artifacts: `.hvigor/outputs/nexte-infodialog-probe/run3/{menu.json,menu.png}` (More menu), `.hvigor/outputs/nexte-infodialog-probe/run4/{dialog.json,dialog.png}` (opened info dialog).
- NextE **shared image-information supplement lines — device-verified at the pin (2026-09-18, ALN-AL80 / 197 (via HDC))**: driving the real shared reader on gallery 4175844 (chrome shown) and tapping the shared More → `rkit-image-info-spread` 「图片信息」 → the per-pane `rkit-info-source-1` 「右侧 · 第 2 页」 entry, the shared surface opens the full information dialog with the host supplement lines rendered correctly: `图片信息 · 第 2 页` / `格式：WEBP` / `大小：134.3 KB` / `当前：重采样图片` / `原图：可用` / `显示尺寸：800 x 1129` / **`图像增强：关闭`** / **`图源：ltayobx.ddrixfzfupkr.hath.network`**. This **closes the content question** behind the failing `ReaderInformationSupplementTrial`: the shared dialog *does* render the enhancement + source supplement on this device/revision, so that trial's `expect('图像增强：关闭')` failure is a trial-automation/route-timing issue, not a shared-reader content gap. Artifacts: `.hvigor/outputs/nexte-infodialog-probe/run5/{full.json,full.png}`.
- **Shared-layer reverse-dependency check (source-level, 2026-09-18, pin `f450aad`)**: a grep across `reader-kit/reader-core/src` and `reader-ui/src` for any host identifier (`nextn`, `nexte`, `koma`, `erosteam`, `com.honjow`, `ohosTest`) returns **no host code dependency** — the only matches are a doc comment in `ReaderDisplayMap.ets:131` naming E/N/Koma pairing rules, and the shared generic API name `onExternalOpen`/`externalOpen`. `reader-core`/`reader-ui` import nothing from any host and expose only generic ports (catalog/asset/actions/settings/close). Combined with the identical `third_party/reader-kit` gitlink `f450aad0ffaebff0a660bf43efa04b20fc2661ef` in all three hosts and the current reader-kit core suite (**432/432**, re-run 2026-09-18) plus the green `scripts/test_reader_contract.mjs`, this confirms the architecture invariant "shared layer has no reverse host dependency; one shared core, not three forks" holds at the pin.
- **Cross-host reader contract suites re-run green at the pin (2026-09-18)**: with no product-source change since the pin, the host-owned reader contract node suites all pass on the current worktrees — NextN `scripts/test_reader_*.mjs` + `test_gallery_reader_transition_contract.mjs` (in the NextN worktree; the one path-assuming suite `test_reader_tap_zone_handoff_runtime.mjs` needs `NEXTE_READER_ROOT`/`KOMA_READER_ROOT`, which point at the sibling worktrees, then passes 1404/1404), NextE `scripts/test_reader*.mjs` (**11/11**, this run), Koma `scripts/test_shared_reader_*.cjs` (**7/7**, this run), and reader-kit core `node --test tests/*.test.cjs` (**432/432**). This is a source-level contract check (not device acceptance), and it confirms the shared/reader host contracts hold across all three consumers on the current candidate.
- **NH partial-thumbnail geometry preserved — current-pin device probe (2026-09-18, ALN-AL80 / 197 (via HDC))**: opening the real long-strip gallery 678049 in the NextN Detail page and dumping the thumbnail strip shows the per-page thumbnail tiles at their **own decoded aspects**, not a fixed original ratio — e.g. `reader-thumb-gallery-detail-1-page-{0,1,2}` measure `317 x 488` (ratio 0.650) while a narrow page `-page-3` measures `114 x 488` (ratio 0.234). This is the objective's required NH behaviour (partial thumbnails keep their decoded thumbnail aspect with bounded cover/contain) observed directly at the pin, distinct from NextE's EH sprite-crop contract. Artifact: `.hvigor/outputs/nextn-detailthumb-probe/run1/detail.json`.
- NextE **information-supplement and spread-shift-last — CLOSED as trial brittleness at the pin** (2026-09-18, ALN-AL80 / 197 (via HDC), candidate `1f26acf0` reader-kit `f450aad`): both counterexamples recorded the same day were traced to the *trial harness*, not the shared reader, and now pass **1/1** at pin `f450aad`.

- NextE **main image-information trial — CLOSED as trial brittleness at the pin** (2026-09-18, 197, candidate `a3f42e98` reader-kit `f450aad`): `ReaderImageInformationTrial` now passes **1/1**. Its earlier failure at `ReaderImageInformation.test.ets:69` (title lookup) was the device's persisted double-page opening a spread, so the shared More exposed the per-pane information submenu (`rkit-image-info-spread`) instead of the direct entry and the assumed single-page dialog never appeared. The trial now pins the Debug entry layout single / direction ltr (the sibling pattern) and settles/re-enters before the first lookup; it still toggles to spread itself afterwards. With this and the earlier `ReaderInformationSupplementTrial` closure, both information trials the manual probe flagged (supplement `:232`, main `:69`) are now device-passing at the pin. No product source changed (commit `a3f42e98`). Artifact: `.hvigor/outputs/nexte-maininfo-regress/run2/run-metadata.json`.


- NextE **original-variant failure recovery and information page-cancel — recorded at the pin** (2026-09-18, 197, candidate `40cd824b` reader-kit `f450aad`): three tracked trials that had **no record** now pass **1/1**. All three are trial-harness preconditions, not shared-reader defects.
  - `ReaderOriginalPrepareFailureTrial` and `ReaderOriginalDecodeFailureTrial` entered without the settle + bounded re-entry and Debug entry layout/direction pins the sibling trials use, and clicked the chrome original action before the page asset reached `displayed`. They now use that pattern, wait for the original action via `originalActionReady`, and give the original JPEG recovery a wider information re-readiness budget. Device evidence: the prepare-failure variant retains the resampled variant with no failure panel (`... original-prepare-retained ... 当前：重采样图片`), and the decode-failure variant renders the shared failure panel (`rkit-failure-page-2`) then recovers to the original on retry (`... original-recovered ... 当前：原图`), both at P2.
  - `ReaderInformationPageCancelTrial` is the NextE twin of the NextN page-cancel case: it turned the pending-information page with a tap, which the shared contract rejects while `informationBusy` (reader-kit `tests/reader-tap-routing.test.cjs`). It now turns the page with the same real swipe the paging trials use (speed 3000, inside the 3 s delay window) so the pending read retires; the failure/close/background modes are unchanged in intent.
  - `openInformationMenu` now waits for the information entry to be **enabled**, not merely present, so a present-but-disabled item cannot click to a no-op.
  - No product source changed (commit `40cd824b`). Artifacts: `.hvigor/outputs/nexte-of-prepfail/run-197-r2/run-metadata.json`, `.hvigor/outputs/nexte-of-decfail/run-197-r3/run-metadata.json`, `.hvigor/outputs/nexte-of-pagecancel/run-197-r2/run-metadata.json`.

  - `ReaderInformationSupplementTrial` originally failed at `ReaderImageInformation.test.ets:232` on the 「图像增强：关闭」 line. The shared dialog content was already device-proven correct (`.hvigor/outputs/nexte-infodialog-probe/run5/` renders 「图像增强：关闭」+「图源：…」), and the failure point was `informationReady` (the shared `rkit-more` never re-enabled within the window). The trial now settles 1500 ms after the explicit reader request and retries that request up to 3 times (the sibling `ReaderImageInformationTrial` pattern); on device it reports `ReaderInformationSupplement message=图片信息 · 第 1 页 … 图像增强：关闭 图源：vzvjgjd.dsysbxxfmucb.hath.network` and **Pass 1/1** with the exact 「关闭」 assertion restored. Evidence: `.hvigor/outputs/nexte-supplement-f450aad/run-197-r5/run-metadata.json`.
  - `ReaderSpreadShiftLastTrial` originally failed at `:468` with `rkit-shift-spread` present at launch. The trial assumed a single-page start, but the persisted device layout opened a spread; pinning the Debug-only `readerLabEntryLayout=single` / `readerLabEntryDirection=ltr` (already used by the sibling spread/paging-axis trials) removes that seed. The residual `informationReady` failure was measured, not assumed: a live cold-load dump of page 44 shows the shared surface mounted but still `0 / 0` with `rkit-more` disabled past 50 s (`.hvigor/outputs/nexte-shiftlast-diag/run7/cold{5,15,30,50}.json`), i.e. a cold remote decode slower than the readiness window — not a product defect. `informationReady` now takes an attempts budget and this trial waits up to 100 x 500 ms before re-issuing the request once; **Pass 1/1**. Evidence: `.hvigor/outputs/nexte-shiftlast-f450aad/run-197-r5/run-metadata.json`.
  - No product source changed; the only edits are in `entry/src/ohosTest/ets/test/ReaderImageInformation.test.ets` and the Debug entry-layout parameters are the host's own existing launch parameters. Commit `1f26acf0`.

- NextE **share page-cancel and original-variant share — both CLOSED as trial brittleness at the pin** (2026-09-18, 197, candidates `5f7dd715`/`4c358ad5` reader-kit `f450aad`): two share trials originally failed on lab-route preconditions, not product defects.
  - `ReaderSharePageCancelTrial` failed at `ReaderImageShare.test.ets:98` (`expect sharePage === 3`, got 2) because it turned the page with a hardcoded 0.8-width **tap**. The shared contract intentionally locks tap/volume input while `shareBusy` (`pageTap` checks it; reader-kit `tests/reader-tap-routing.test.cjs` asserts it), but a native pager swipe still navigates and retires the pending share via `ReaderImageShareController.update`. The trial now pins `readerLabEntryLayout=single` / `readerLabEntryDirection=ltr` (the sibling-trial pattern that also removes the persisted-RTL seed) and turns the page with the same real swipe the paging trials use (speed 3000, inside the 3 s delay window); **Pass 1/1**. Evidence: `.hvigor/outputs/nexte-share-pagecancel-f450aad/run-197-r2/run-metadata.json`. Only the trial changed; commit `5f7dd715`.
- NextE `ReaderOriginalVariantShareTrial` — CLOSED as trial brittleness at the pin (2026-09-18, 197, candidate `4c358ad5` reader-kit `f450aad`): passes **1/1**. The earlier `当前：原图` information failure was not a missing lab original-selection provider: the trial clicked the chrome original action before the page asset reached `displayed` and opened the More information entry without waiting for the JPEG→original re-decode. It now uses the settle + bounded re-entry and Debug entry layout/direction pins the sibling trials use, waits for the original action to enable, re-waits image readiness after switching to the original, and waits for the More information entry like the image-information trials. Device evidence: the shared dialog reads `当前：原图` and the share then cancels back to the same page. No product source changed (commit `4c358ad5`). Artifact: `.hvigor/outputs/nexte-share-origvars-f450aad/run-197-r3/run-metadata.json`. The two share failures this replaces are both now closed.

  - Superseded failed runs: `.hvigor/outputs/nexte-share-pagecancel-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nexte-share-origvars-f450aad/run1/run-metadata.json`.

- NextE `ReaderTapZonesReadOnlyTrial` and `ReaderPageNumberReadOnlyTrial` — CLOSED as trial brittleness at the pin (2026-09-18, 197, candidate `e565fac3` reader-kit `f450aad`): both now pass **1/1**. Both had failed on a first-assertion precondition, not a shared-reader defect. They hardwired an `readerLabSite: 'eh'` Want and asserted `EH` as the current site, but the device's real site is `ex` (the user's setting, not altered), and the host does not parse `readerLabSite` at all — the site assertion is removed while the read-only signature still includes the site value, so a site change would still fail. `ReaderPageNumberReadOnlyTrial` also rejected the device's persisted double-page policy, but its check drives single-page navigation; it now pins the in-memory Debug `readerLabEntryLayout=single` via the launch Want, leaving the persisted double-page setting (still part of the read-only signature) untouched. No product source changed (commit `e565fac3`). Artifacts: `.hvigor/outputs/nexte-tapzones-f450aad/run-197-r4/run-metadata.json`, `.hvigor/outputs/nexte-pagenumber-f450aad/run-197-r5/run-metadata.json`. Superseded failed runs kept: `.hvigor/outputs/nexte-{tapzones,pagenumber}-f450aad/run1/...`.

- NextN **thumbnail-entry production variants** verified at the pinned revision (2026-09-17, 197, candidate `58208459` reader-kit `f450aad`): four tracked production thumbnail-entry variants that had no pinned-revision record each pass **1/1** on the real gallery through the normal entry — `ReaderProductionThumbnailEntryTrial` (Detail compact/rail thumbnail -> shared body, exact return), `ReaderProductionThumbnailGridEntryTrial` (Detail grid thumbnail -> shared body, exact return), `ReaderProductionThumbnailSingletonEntryTrial` (single full-size thumbnail -> shared body) and `ReaderProductionThumbnailSpreadEntryTrial` (spread entry). Each asserts the shared surface opened at the expected page, no `legacy-reader-surface`, no debug `rkit-trial-navigation`, the entry preview/source-pending nodes are gone after the flight, and the close returns to the same Detail pane with the source thumbnail bounds unchanged, then restores the history snapshot. Artifacts: `.hvigor/outputs/nextn-{te-detail,te-grid,te-single,te-spread}-f450aad/run1/run-metadata.json`. **Open boundary (re-diagnosed 2026-09-18, quantified):** the fifth variant, `ReaderProductionThumbnailWideEntryTrial` (the two-pane wide Detail workspace grid thumbnail), is **unreachable on either authorized device** — but not for the previously recorded reason. An earlier record claimed the root HDS `NavigationMode` `did not resolve to a physical Split`; that was **wrong**. The trial's precondition was hardened to match the accepted `GallerySplitTransitionTrial` pattern — it now pins `tablet_layout_mode=landscapeOnly` and waits for the HDS-resolved `connectLayoutSafeArea().rootNavigationSplit` — and re-run at the pin the **Split assertion passes** on both devices, then the failure moves to the layout width gate. Measured root cause: the wide workspace needs `usesWideDetailWorkspace()` = `rootNavigationSplit` **and** `detailRootWidth >= GALLERY_DETAIL_WIDE_WORKSPACE_MIN_WIDTH` (720 vp; `GalleryDetailPage.ets:108` / `:1534-1535`, the same 720 value as the NextE reference `GALLERY_DETAIL_SPLIT_MIN_WIDTH`). From the failure-point layout dumps: the HDS primary pane is the fixed `TABLET_PRIMARY_PANE_WIDTH` 320 vp, so the dump gives the density — 197 landscape NavBar `[0,0][1040,1260]` ⇒ density 3.25, detail pane `2720-1041 = 1679 px` ≈ **517 vp**; 237 landscape NavBar `[0,0][960,1320]` ⇒ density 3.0, detail pane `2120-961 = 1159 px` ≈ **386 vp**. Both split panes are below the 720 vp gate, so `gallery-detail-preview-pane` never mounts and the trial cannot reach the shared reader; a genuine large tablet whose split detail pane reaches ≥720 vp is required. This is a NextN host-side Detail-workspace reachability limit (not a shared-reader defect): the shared reader is reached from the compact Detail entry and the other four production thumbnail-entry variants all pass at the pin. Kept as an honest OPEN hardware boundary, not a pass. Artifacts: `.hvigor/outputs/nextn-te-wide-f450aad/run1/` (197 original), `.hvigor/outputs/nextn-te-wide-f450aad/run2/` (197 hardened, + `layout-exception.json`), `.hvigor/outputs/nextn-te-wide-237/run1/` (237 original), `.hvigor/outputs/nextn-te-wide-237/run2/` (237 hardened, + `layout-exception.json`).
- NextN **continuous-rotation reflow on the large screen — re-verification attempt interrupted by device availability** (2026-09-18, 237 `VDE-AL00` 1320x2120, candidate `5210cb7b` reader-kit `f450aad`): the `ReaderProductionContinuousRotationTrial` (`keepsContinuousReadingPositionAndBoundaryAcrossTabletRotation`) is the only tall-continuous-rotation reflow record and currently rests on pre-pin `8112355` evidence, so it was re-run at the pin. The trial launched and began (`OHOS_REPORT_STATUS: test=keepsContinuousReadingPositionAndBoundaryAcrossTabletRotation`, `current=1`), but device 237 then **went Offline mid-run**: all later commands returned `[Fail][E001005] Device not found or connected`, so no Hypium summary was published. This was confirmed device-side, outside the sandbox — `hdc list targets -v` shows `192.168.50.237:12345 TCP Offline`, `hdc tconn` reports `Connect failed`/`Target is connected, repeat operation` without recovering, and `ping 192.168.50.237` returns **100% packet loss**. This is a device-availability interruption, not a product finding and not a trial failure; the earlier pre-pin pass stands and this item stays OPEN for a re-run once 237 is reachable again (or, if acceptable, on another large-screen target). The lease was released and 197 remained Connected throughout. Artifact: `.hvigor/outputs/nextn-cont-rotation-f450aad/run1/run-metadata.json` (no summary; device dropout).
- NextN **continuous-rotation reflow on the large screen — pin re-run PASSED** (2026-09-18, 237 `VDE-AL00` 1320x2120, candidate `74f09cee` reader-kit `f450aad`, `install -r` only): after the device-availability dropout recorded in the previous line (run1, no Hypium summary), 237 was recovered at the transport layer (host-network `ping` 0% loss; `hdc tconn 192.168.50.237:12345` -> `Connect OK`) and the tracked `ReaderProductionContinuousRotationTrial` (`keepsContinuousReadingPositionAndBoundaryAcrossTabletRotation`) was re-run at the pin through the checked device protocol: **`Tests run: 1, Failure: 0, Error: 0, Pass: 1`** (`OHOS_REPORT_CODE: 0`, `taskconsuming=175065`). So the tall-continuous-rotation reflow record now rests on the pinned `f450aad` revision on the large-screen device rather than the pre-pin `8112355` evidence; the dropout line below is kept only as history and this item is no longer OPEN. Artifact: `.hvigor/outputs/nextn-cont-rotation-f450aad/run2/run-metadata.json`.
- NextN **runtime crop on/off via the shared menu — RESOLVED on the production route** (2026-09-18, 197, candidate `74f09cee` reader-kit `f450aad`): the NextN shared runtime menu `rkit-crop-toggle` is now device-verified to toggle crop on/off over real content through the **ordinary production Detail Read entry**, not the Debug lab. `ReaderProductionCropInheritanceTrial` was extended (additively) to seed the real gallery 678049 at page index 3 — the page whose crop detector is positive (`ReaderCropTrial`: `page=4 detected=true`) — open via the normal Detail thumbnail route, open the runtime menu, and click the shared toggle both ways. On the pin it passes **1/1**: with inherited crop on the `rkit-cropped-image-3-whole` node is present and the label reads 「关闭裁边」; after the first click crop turns off (label 「开启裁边」), the cropped-image node disappears, and the page stays `4 / 14`; after the second click crop returns (label 「关闭裁边」), the cropped-image node reappears at the same page. Console: `productionCropInherited=true source=3 cropToggleRoundTrip=true originalMode=paged_rtl originalDouble=false originalCrop=false historyRestored=true settingsRestored=true`. Pixel evidence (same device/run): the two toggle frames differ across the whole page body (≈290k differing pixels over y 0..2720, vs. the earlier same-page run whose crop was a detector no-op and differed only in the status-bar clock and menu label), confirming a genuine crop geometry change rather than a label-only flip. This **supersedes the earlier `cannot run as written` note on the Debug lab trial `ReaderCropToggleTrial`** as the authoritative crop-toggle evidence: that lab trial remains a trial/lab-contract mismatch (the NextN lab sets `cropPolicy.available` from `initialCropBorders() || labRequest.cropBorders===true` at `NextNReaderLabPage.ets:830-831`, so a lab launch with crop off cannot expose the toggle) and is left unchanged rather than speculatively rewritten. Artifacts: `.hvigor/outputs/nextn-crop-inherit-f450aad/run2/run-metadata.json` (+ `caps/`), and the detector-positive reference page in `.hvigor/outputs/nextn-crop-paged-f450aad/run1/`.
- NextN **production network thumbnail actions + share-cancel** verified at the pinned revision (2026-09-18, 197, candidate `2c3a346c` reader-kit `f450aad`): the tracked `ReaderProductionNetworkActionsTrial` (`keepsNetworkThumbnailGeometryAndSharesCurrentCachedPage`) had **no record**; it passes **1/1** on real gallery 678049 through the ordinary Detail Read entry. It opens the shared reader, opens the network thumbnail rail and verifies each tile's decoded aspect ratio is preserved (`networkThumbnails=0.549,0.549`), then invokes share on the current cached page and cancels the system share sheet, asserting the reader stays on the same page (`current=0`) and the history snapshot is restored (`networkShareCancelled=true historyRestored=true`). So the shared reader's network thumbnail geometry and share/cancel path are device-verified on real content at the pin. Artifact: `.hvigor/outputs/nextn-network-actions-f450aad/run1/run-metadata.json`.
- NextN shared-reader **external open (外部打开) click reaches the system browser** (verified 2026-09-18, 197, candidate `3c2ee1b9` reader-kit `f450aad`): the NextN `ReaderExternalOpen` entry existed in the shared More menu but only its presence was recorded; this run closes the click-through. Entering the ordinary production shared route (`nextn_reader_backend=shared` + `nextn_gallery_id=678049`, which supplies `productionSources: true`) and its Detail Read action mounts the shared surface with `rkit-open-external` in the More menu (`[623,637][1195,793]`, enabled); clicking it hands the canonical gallery URL to the system via `NhGalleryExternalOpenService.openCanonicalGallery` → `context.openLink`, and the device foreground moves from `com.erosteam.nextn` to `com.huawei.hmos.browser` **FOREGROUND** (NextN BACKGROUND). So the shared reader's external-open control really performs the host's external-link handoff on device, matching the legacy `ReaderPage.openCurrentGalleryExternally` boundary. The run was read-only for app data (no reader state write); the browser was force-stopped and NextN relaunched afterwards. Artifacts: `.hvigor/outputs/nextn-externalopen/run4/{reader,menu}.json` (shared entry + `rkit-open-external` present), `.hvigor/outputs/nextn-externalopen/run5/run-metadata.json` (foreground → browser).

- NextN **shared production-overlay system Back — FIXED: one press closes the reader (was two) and retains the Detail** (2026-09-18, 197, candidate `23875573` reader-kit `f450aad`): the earlier counterexample is now resolved with a source-proven host fix. Root cause: the shared Reader is mounted as a shell overlay above the Gallery `NavDestination` (`readerOverlay.activeReader !== null`), so the system Back ran the Gallery destination's `onBackPressed` first (popping the Gallery under the reader) while the reader stayed mounted; legacy mounts the reader as its own destination, so its Back closed the reader on one press. Fix (commit `23875573`, `Index.handleGalleryDetailBackPressed` only): an additive early return while a shared Reader is active — `return this.readerBackRequest()` (the reader's registered `closeTrial`) or `closeReaderDestination(true)` — before any Gallery pop; inert for the legacy/default backend where `activeReader` is null. Device evidence (single Back): pre-fix `.hvigor/outputs/nextn-backkey/run4/` left 19 `rkit-*` nodes and popped the Detail; post-fix `.hvigor/outputs/nextn-backkey/run9-fixed/` closes the reader (19 → 0 `rkit-*`) and returns to the same Detail (`gallery-detail-read-action` present, `#678049` / `14 页`); the legacy one-press control is `.hvigor/outputs/nextn-backkey/run5-legacy/`. No reader-kit, geometry, transition or status-bar change. Ledger: `docs/qa/nextn-ui-change-ledger.md`. Re-verified after the fix on the large-screen 237 (`install -r` only): the same single-Back close holds (reader 18 `rkit-*` -> 0, Detail retained), the tracked `ReaderProductionAdaptiveRotationTrial` passes **1/1** on the fixed build (no rotation regression, `.hvigor/outputs/nextn-237-rotation-backfix/run1/`), and the NextN normal-entry verdict trial `ReaderProductionInAppDetailEntriesTrial` passes **1/1** on 197 on the fixed build (`.hvigor/outputs/nextn-matrix-backfix/run1/`) — so the ordinary shared route and the legacy path are unchanged, and the fix holds at both form factors. Artifacts: `.hvigor/outputs/nextn-backkey-237/run2/` (237 single-Back), `.hvigor/outputs/nextn-backkey/run8..run10`.
- **Cross-host system-Back parity after the NextN fix** (verified 2026-09-18, 197; NextE candidate `516c60ed` reader-kit `f450aad`): to confirm the NextN two-press Back was a host-overlay defect and not a shared contract, the same single-Back probe was run on NextE's ordinary shared route (`readerLabEntryLayout=single` + `readerLabEntryDirection=ltr`, page 2). Single system Back closes the shared reader (21 `rkit-*` → 0) with the NextE root retained (`nexte-root`), i.e. one press, matching the fixed NextN and the Koma lab route. Source explains the difference: NextE mounts the shared reader as a real HDS `NavDestination` (`readerOverlayRouterMap` name `ReaderShared` → `NextEReaderLabPage`), so its `onBackPressed` closes the reader destination directly, whereas NextN mounted the shared reader as a shell overlay above the Gallery destination (the case just fixed). So all three hosts now close the shared reader on a single system Back. Artifacts: `.hvigor/outputs/nexte-backkey/run2/{reader,after-back}.json`.




- NextN **complete-download → shared reader entry + return** verified at the pinned revision (2026-09-18, 197, candidate `088c8006` reader-kit `f450aad`): the tracked `ReaderProductionDownloadEntryTrial` (`opensCompleteDownloadThroughSharedProductionBodyAndReturns`) had **no record**; it passes **1/1**. It requires a verified complete download on the device, opens it through the ordinary Downloads tab entry (not a lab route), asserts the shared reader reports the task's full page count, shares the current cached page and cancels, then closes back to the Downloads queue root with the in-memory queue snapshot byte-identical (`localShareCancelled=true localQueueUnchanged=true returned=true`) and restores the history row. So the NextN Downloads→shared-reader→return path is device-verified on real local content at the pin. Artifact: `.hvigor/outputs/nextn-dlentry-f450aad/run1/run-metadata.json`.
- NextN **normal-entry Shared → Legacy rollback** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `816c9222` reader-kit `f450aad`): the tracked `ReaderProductionBackendTrial` (`routesNormalReadThroughSharedBodyThenRollsBackToLegacyBody`) had **no record**; it passes **1/1** on real gallery 678049. From the ordinary Detail Read entry it opens the **shared** body, seeks via the shared source slider to a different page (the host history follows), closes; then launches in **Legacy** mode and asserts the **legacy** reader opens on the same content and closes back to Detail. Fact line: `sharedInitial=0 sharedChanged=6 sharedClosed=true legacyReopened=true legacyClosed=true historyRestored=true`. So the shared reader and the legacy reader both drive the same normal entry, and the shared reading is reversible to legacy, at the pin. Artifact: `.hvigor/outputs/nextn-backend-trial-f450aad/run-usb/run-metadata.json`.
- NextN **thumbnail-entry source/neighbor failure recovery** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `aa4f3923` reader-kit `f450aad`): the tracked `ReaderThumbnailEntrySourceFailureTrial` and `ReaderThumbnailEntryNeighborFailureTrial` had **no record**; each passes **1/1** on real gallery 678049. Entering the shared reader from the normal Detail thumbnail with a one-shot missing-original fault injected on the entry source page (index 0) or a neighbor page (index 1), each asserts the failure recovers on retry and the close returns to the **same** source thumbnail bounds. So the NextN thumbnail entry/return path stays correct across an entry-source or neighbor decode failure at the pin. Artifacts: `.hvigor/outputs/nextn-entry-srcfail-f450aad/run-usb/run-metadata.json`, `.hvigor/outputs/nextn-entry-nbrfail-f450aad/run-usb/run-metadata.json`.
- NextN **thumbnail-entry auto-read foreground + failure paths** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `c9871855` reader-kit `f450aad`): the tracked `ReaderThumbnailAutoReadForegroundTrial` and `ReaderThumbnailAutoReadFailureTrial` had **no record**; each passes **1/1** on real gallery 678049 from the normal Detail thumbnail entry. The foreground trial drives auto-read while the host stays in the foreground (the shared timer advances the reader from the real entry and the source interception/close stays correct); the failure trial injects a one-shot decode fault on the visible page under auto-read and asserts the reader recovers while auto-read continues. So NextN's shared auto-read is device-verified through the real thumbnail entry across foreground and failure at the pin. Artifacts: `.hvigor/outputs/nextn-ar-fg-f450aad/run-usb/run-metadata.json`, `.hvigor/outputs/nextn-ar-fail-f450aad/run-usb/run-metadata.json`.
- NextN **thumbnail-entry initial policy (saved continuous + RTL spread)** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `65cf51fb` reader-kit `f450aad`): the tracked `ReaderThumbnailInitialPolicyTrial` (`savedContinuousAndRtlSpreadFromActualSource2`) had **no record**; it passes **1/1** on real gallery 678049. Entering the shared reader from the real Detail thumbnail (source 2), it asserts the shared surface opens with the persisted policy applied — a saved RTL `SPLIT` spread and (in the second pass) the saved continuous layout — and verifies the live presentation matches the durable repository/`reader_settings` values, then restores the exact entry keys. So NextN's saved layout/direction policy is inherited by the shared reader on the real thumbnail entry at the pin. Artifact: `.hvigor/outputs/nextn-thumbpol-f450aad/run-usb/run-metadata.json`.
- NextN **no-preview trial window + pending-input / pending-rotation** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `0027d48d` reader-kit `f450aad`): three tracked trials that had **no record** each pass **1/1**. `ReaderTrialWindowNoPreviewTrial` (`ordinaryTrialOwnsAndRestoresStatusWithoutAnEntryPreview`) opens the shared reader from the ordinary host with no entry-preview node, asserts the status-bar content color is set while the reader is visible and restored on close. `ReaderThumbnailPendingInputTrial` and `ReaderThumbnailPendingRotationTrial` exercise the pending-input and pending-rotation paths of the thumbnail-original probe. So the NextN entry-window status handling and the pending input/rotation paths are device-verified at the pin. Artifacts: `.hvigor/outputs/nextn-{nopreview,pendin,pendrot}-f450aad/run-usb/run-metadata.json`.
- NextN **thumbnail-original probe variants (8)** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `31028b03` reader-kit `f450aad`): eight tracked trials that had **no record** each pass **1/1** on real gallery 678049 — `ReaderThumbnailOriginalReleaseTrial`, `ReaderThumbnailOriginalNavigationTrial`, `ReaderThumbnailOriginalBackTrial`, `ReaderThumbnailOriginalRotationTrial`, `ReaderThumbnailUnknownOriginalTrial`, `ReaderThumbnailUnknownOriginalBackTrial`, `ReaderThumbnailGridUnknownOriginalBackTrial` and `ReaderThumbnailOriginalSpreadReleaseTrial`. They exercise the shared reader's original-variant handling across release on close, in-reader navigation, Back, rotation, an unknown/missing original in single and the all-thumbnails grid, and the spread release path — each asserting the reader keeps its resolution boundary and returns correctly. So the NextN original-display lifecycle is device-verified across these paths at the pin. Artifacts: `.hvigor/outputs/nextn-orig-{rel,nav,back,rot,unk,unkback,gridunkback,spreadrel}-f450aad/run-usb/run-metadata.json`.
- NextN **progress persistence across reading modes (vertical + spread↔continuous)** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `13dc132b` reader-kit `f450aad`): two tracked trials that had **no record** each pass **1/1** on real gallery 678049. `ReaderProgressPersistenceVerticalTrial` drives vertical (continuous) mode with a swipe and asserts the observed-progress events are `[2,3,3]` with `durable=3` and the same-anchor event deduped (`dedupeSameAnchor=true`); `ReaderProgressPersistenceCrossModeTrial` reads a spread (RTL) session to page 5, then cold-reopens the same gallery in continuous mode and confirms it resumes at the same canonical page and continues (`crossMode events=[2,4,4,5] durable=5 spreadRtl=true continuous=true`). Each restores the original history row. So NextN's progress is canonical across vertical, spread and continuous reading modes at the pin. Artifacts: `.hvigor/outputs/nextn-prog-vert-f450aad/run-usb/run-metadata.json`, `.hvigor/outputs/nextn-prog-cross-f450aad/run-usb/run-metadata.json`.
- NextN **thumbnail-driven progress persistence** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `4b6b38f6` reader-kit `f450aad`): four tracked trials that had **no record** each pass **1/1** on real gallery 678049. `ReaderProgressPersistenceThumbnailTrial` seeds stored page 7 but opens the reader by clicking thumbnail page 2; when the original fails to decode it asserts **no** progress event and the durable row stays 7, then after the same-page retry displays, the first observed event is `2` and the durable row becomes 2 (`stored=7 clicked=2 failureEvents=[] retryEvents=[2] durable=2`). `...ThumbnailVerticalRetryTrial` (`thumbnailVertical stored=7 events=[2,3,3] failureDurable=2 retryDurable=3`) and `...ThumbnailSpreadRetryTrial` (`thumbnailSpread stored=7 events=[2,4,4] neighborFailureDurable=2 nextSpreadDurable=4 rtl=true`) extend this to vertical and RTL spread with a neighbor failure, and `...ThumbnailContinuousTrial` to continuous. So a clicked thumbnail beats stored progress, and the shared session writes progress only after the clicked page actually displays, across single/vertical/spread/continuous at the pin. Each restores the original history row. Artifacts: `.hvigor/outputs/nextn-prog-{thumb,thumbcont,thumbvr,thumbsr}-f450aad/run-usb/run-metadata.json`.
- NextN **shared super-resolution (超分) derivative contract** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `fa5edca8` reader-kit `f450aad`): the tracked `ReaderSharedSuperResolutionTrial` (`hostPreparedDerivativeKeepsTheSharedReaderContract`) had **no record**; it passes **1/1** in each of its three variants (single, spread, and cancel-navigation). With super-resolution enabled and a real installed model selected on a local fixture, the shared reader requests and applies the host-prepared enhanced derivative (`applied` for the visible sources), and in the cancel-navigation variant a swipe before the current source settles cancels source 0's preparation and applies source 1 instead (`applied.has(0)===false`). So the host-owned super-resolution derivative path keeps the shared-reader contract at the pin. Artifacts: `.hvigor/outputs/nextn-sr-{single,spread,cancel}-f450aad/run-usb/run-metadata.json`.
- NextN **thumbnail-entry save-menu discovery and unknown-original volume** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `99db187e` reader-kit `f450aad`): two tracked trials that had **no record** each pass **1/1** on real gallery 678049. `ReaderThumbnailSaveMenuTrial` opens the shared save menu (`rkit-save-left`/`-right`/`-both`) from the real thumbnail entry, discovers the system save dialog for a single side, and cancels it without performing a positive album save (its own contract: `positive_album_save_acceptance=false`). `ReaderThumbnailUnknownOriginalVolumeTrial` exercises the native-volume-key path while the original selection is unknown/hidden, asserting the volume keys cannot move the hidden entry and resume after the original handoff. Artifacts: `.hvigor/outputs/nextn-savemenu-f450aad/run-usb/run-metadata.json`, `.hvigor/outputs/nextn-unkvol-f450aad/run-usb/run-metadata.json`.
- NextN **continuous auto-translation (base)** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `05c76950` reader-kit `f450aad`): the tracked `ReaderProductionAutoTranslationContinuousTrial` (`translatesTheCurrentContinuousPageThenWarmsAndReusesTheNext`) had **no full-name record** (only its failure/cancellation/physical variants were listed); it passes **1/1** through the ordinary shared Detail Read entry in continuous layout on the local translation seam — enabling auto-translate prepares and applies the current continuous page, warms the next page, and reuses that result on the following scroll without a duplicate prepare. So the NextN continuous auto-translation base path is device-verified at the pin. Artifact: `.hvigor/outputs/nextn-atr-continuous-f450aad/run-usb/run-metadata.json`. (Local-route seam only; the non-local/cloud provider path remains OPEN.)
- NextN **complete-download single-source reload** verified at the pinned revision (2026-09-18, 197, candidate `78f681a2` reader-kit `f450aad`): the tracked `ReaderProductionDownloadReloadTrial` (`reloadsCompleteLocalDownloadTwiceWithoutMutatingQueue`) had **no record**; it passes **1/1**. On a verified complete 46-page local download opening through the ordinary Downloads entry, it reloads the current local source twice and asserts the queue snapshot is unchanged and the reader returns to the Download queue root, logging `[ReaderProductionDownloadReloadTrial] gallery=556817 pages=46 localReloads=2 queueUnchanged=true returned=true historyRestored=true`. So the NextN single-source local-reload path is device-verified at the pin (the spread and continuous reload siblings were already recorded). Artifact: `.hvigor/outputs/nextn-dlreload-f450aad/run1/run-metadata.json`.
- NextN `ReaderProductionDownloadSourceTrial` — recorded at the pin (2026-09-18, 197, candidate `650e397f` reader-kit `f450aad`): this tracked trial had **no record**. It passes **1/1**: through the real `NextNProductionReaderDataSource` it restores the host download queue, selects a verified complete download, opens its gallery detail and asserts the detail page count equals the task's count, that `localPageUri` returns a real `file://` path, and that the file exists on disk — `[ReaderProductionDownloadSourceTrial] sample=complete pages=44 local=true`. This is the source-side half of the complete-download path whose render/return half is covered by `ReaderProductionDownloadEntryTrial`/`...ReloadTrial` (both pass 1/1 at the pin). Artifact: `.hvigor/outputs/nextn-dlsource/run1/run-metadata.json`. No product source changed (no-record trial; nothing needed fixing).

- NextN **partial-download → network route-seed fallback** verified at the pinned revision (2026-09-18, 197, candidate `6e468486` reader-kit `f450aad`): the tracked `ReaderProductionPartialDownloadFallbackTrial` (`rejectsPartialFilesAsLocalCatalogAndRendersThroughRouteSeed`) had **no record**; it passes **1/1**. It enqueues a deliberately throttled download of real gallery 678049, pauses it at a partial checkpoint, and asserts that a partially downloaded file is **not** used as the local catalog (`localCatalog=false`, `localPageUriEmpty=true`) while the shared reader still renders through the route seed (`sharedRendered=true routeSeedFallback=true`); it then restores the queue, download settings, and history. Fact line: `[ReaderProductionPartialDownloadFallbackTrial] gallery=678049 partial=1/14 physicalFile=true localCatalog=false localPageUriEmpty=true sharedRendered=true routeSeedFallback=true queueRestored=true settingsRestored=true historyRestored=true`. So an incomplete download correctly falls back to the network path with the local-catalog guard intact at the pin. Artifact: `.hvigor/outputs/nextn-partial-fallback-f450aad/run1/run-metadata.json`.
- NextN **image information (图片信息) single + spread source identities** verified at the pinned revision (2026-09-18, 197, candidate `38ff6cf2` reader-kit `f450aad`): the tracked `ReaderImageInformationTrial` (`actualFileInformationKeepsSingleAndBothSpreadSourceIdentities`) had **no record**; it passes **1/1** on real gallery 678049. It opens the shared reader at page 2, opens the More→image-information dialog for the single page, toggles to spread, and selects each visible source (`rkit-info-source-0` → left page 1, `rkit-info-source-1` → right page 2), asserting the dialog's per-source identity follows the selection; a subsequent volume-down still advances the shared reader. So the NextN image-information control preserves single and both spread source identities at the pin. Artifact: `.hvigor/outputs/nextn-imginfo-f450aad/run1/run-metadata.json`.
- NextN **shared-reader progress persistence (write → cold restore)** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `2ce25217` reader-kit `f450aad`): the tracked `ReaderProgressPersistenceWriteTrial` and `ReaderProgressPersistenceRestoreTrial` had **no record**. Phase 1 (`writesVisibleProgressAndLeavesColdRestoreHandoff`) opens the shared reader at page 3 on real gallery 678049, swipes to page 4, and asserts the observed-progress events are exactly `[2,3]` with the durable history row written to index 3 (`write events=[2,3] durable=3 handoffReady=true`), passing **1/1**. Phase 2 (`coldRestoresDurableProgressThenRestoresOriginalRow`) runs in a fresh process, opens the reader and asserts it cold-resumes at page 4 with a single observed event `[3]` (`coldRestore=3 events=[3]`), then writes the original row back, passing **1/1**. So NextN's shared-session progress is written to and cold-restored from the host store at the pin, with no fixture row left behind. Artifacts: `.hvigor/outputs/nextn-prog-write-f450aad/run-usb/run-metadata.json`, `.hvigor/outputs/nextn-prog-restore-f450aad/run-usb/run-metadata.json`.
- NextN **crop-strength variants (off / standard / strong / conservative)** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `0b55d29f` reader-kit `f450aad`): the tracked `ReaderProductionCropOffTrial`, `ReaderProductionCropStandardTrial`, `ReaderProductionCropStrongTrial` and `ReaderProductionCropConservativeTrial` (`capturesRealPageAtTargetStrengthAndRestoresSettings`) had **no record**; each passes **1/1** on real gallery `663205` through the ordinary overlay route at page 3. Each applies the requested crop strength (off / `CONSERVATIVE` / `STANDARD` / `STRONG`), captures the real page, and asserts the live and durable reader settings are restored to the pre-run values — every run logging `ReaderProductionCropStrength restored=true target=<strength> errors=0` (the reported `paged=standard continuous=standard` is the restored baseline). So NextN's crop-strength control is device-verified across all four values at the pin. Artifacts: `.hvigor/outputs/nextn-cropstr-{off,standard,strong,conservative}-f450aad/run-usb/run-metadata.json`.
- NextN **observed-progress facts without writing history** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `768bdaf4` reader-kit `f450aad`): the tracked `ReaderObservedProgressTrial` (`actualVisibleOriginalEventsDoNotWriteHistory`) had **no record**; it passes **1/1** on real gallery 678049. Through the ordinary lab entry it swipes forward then back and asserts the reader-core observed-progress port reports exactly `[2,3,2]` for the visible original pages while the host `reading_history` row stays **unchanged** on this read-only route (no write permission) — after close, no further events and the row is still unchanged. So the shared layer's reading facts are emitted without the host persisting them when write is not authorized at the pin. Artifact: `.hvigor/outputs/nextn-obsprog-f450aad/run-usb/run-metadata.json`.
- NextN **continuous-mode image interpolation (local fixture + online)** verified at the pinned revision (2026-09-18, device ALN-AL80 / 197 (via HDC), candidate `cc378445` reader-kit `f450aad`): the tracked `ReaderInterpolationContinuousTrial` (local fixture) and `ReaderInterpolationContinuousOnlineTrial` (real gallery 678049) had **no record**; each passes **1/1**. Both assert, via the read-only scoped inspector, that the continuous layout's rendered image carries the mapped `imageScalingQuality -> ImageInterpolation` value and that the process image-scaling state equals the durable repository value. So NextN's `图像缩放质量` setting is device-verified in continuous mode on both a local fixture and real online content at the pin. Artifacts: `.hvigor/outputs/nextn-interp-local-f450aad/run-usb/run-metadata.json`, `.hvigor/outputs/nextn-interp-online-f450aad/run-usb/run-metadata.json`.
- NextN **standalone status restore + image-information failure recovery** verified at the pinned revision (2026-09-18, 197, candidate `2ce25217` reader-kit `f450aad`): two tracked trials that had **no record** pass **1/1** on real gallery 678049. `ReaderStandaloneStatusTrial` opens the reader over the normal host and asserts the status-bar system properties are restored on close (`ReaderStandaloneStatus before=… closed=…`, `statusBarContentColor` back to `#FF000000`), passing 1/1. `ReaderInformationFailureTrial` (the `failure` mode of the shared information-recovery harness, `readerLabInformationProbe=fail-once`) opens the reader, drives a one-shot metadata failure, and asserts the reader keeps reading with no stuck dialog and no late result breaking a fresh information request, passing 1/1. Artifacts: `.hvigor/outputs/nextn-status-f450aad/run1/run-metadata.json`, `.hvigor/outputs/nextn-info-fail-f450aad/run1/run-metadata.json`.
- NextN **image-information page-cancel recovery — CLOSED as trial brittleness at the pin** (2026-09-18, 197, candidate `c5f27523` reader-kit `f450aad`): the counterexample is trial brittleness, not a shared-reader defect, and now passes **1/1**.
  - Root cause measured on device: while an information read is pending the shared surface deliberately locks **tap** and volume input — `pageTap`/`externalMove` check `informationBusy` and reader-kit `tests/reader-tap-routing.test.cjs` asserts that lock — but a **native pager swipe** is still allowed and retires the pending read once the page commits. A hilog trace of a fast swipe shows `[ReaderPager] selected=0 ... navigation=2` with **no** following `information_present` and a fresh dump with no dialog (`.hvigor/outputs/nextn-pagecancel-probe/run12`); the slow `information_late_result` arrives after and is discarded. The trial previously used `driver.click` on the viewport, which the contract rejects, so the page never turned and the slow result then presented as a dialog.
  - The trial now pins the Debug entry layout/direction the sibling trials use, turns the page with the same real swipe the paging trials use (speed 3000 so it lands inside the 3 s delay window) and captures after it, and keeps the other modes' pending capture. The three other modes (failure/close/background) are unchanged in intent. No product source changed; commit `c5f27523`.
  - Evidence: `.hvigor/outputs/nextn-info-page-cancel-f450aad/run5/run-metadata.json` (`Tests run: 1, Failure: 0, Error: 0, Pass: 1`).

- NextE **lifecycle recovery (retry / reload / background-close / reopen)** re-verified at the pinned revision (2026-09-17, 197, candidate `17aad7db` reader-kit `f450aad`): the earlier record was 2026-09-14 at reader-kit `1d1f515`, far before the pin, so the tracked `ReaderLifecycleRecoveryTrial` (`retriesReloadsBackgroundClosesAndReopensFreshSessions`) is re-run at `f450aad` and passes **1/1**. It exercises the shared host over real content 4175844: a classified failure panel with a working same-page retry, an exact single-source reload through the More menu, a one-side spread reload with the partner request unchanged, app background that retires the shared route, then a fresh explicit reopen and explicit close. Artifacts: `.hvigor/outputs/nexte-lifecycle-f450aad/run1/run-metadata.json`.
- NextN **split/back/replace/stack transition (gallery detail)** verified at the pinned revision (2026-09-17, 197, candidate `7b360ac8` reader-kit `f450aad`): the tracked `GallerySplitTransitionTrial` had **no record** in this worktree; it now passes **1/1**. On the real Home waterfall it drives both transition modes (`coverExpand`, `seamless`) through the full sequence — open a card from a portrait Home, rotate to a live landscape split, confirm the source card is retained, rotate back and pop to the Home stack, reopen, split, back, reopen, replace by selecting a second card in split, and return — logging `[GallerySplitTrial] accepted-functional mode=seamless split/back/replace/stack/reopen` and restoring the tablet/presentation/transition settings and the preferred orientation (`restored preferences orientation=12`). So the reference-derived gallery-detail transition keeps its visible sources and return context across split, back, replacement and stack return on real device input. Artifact: `.hvigor/outputs/nextn-gallery-split-f450aad/run1/run-metadata.json`. (Snapshots were captured by the trial; they require independent visual review before any pixel claim, so none is made here.)
- Koma shared-reader **volume-key page turning** verified at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`, `install -r` only): Koma's legacy reader has a persisted `volumeKeyNavigationEnabled`/`volumeKeyBehavior` preference and its shared route wires `ReaderVolumeKeys` (`KomaReaderLabPage.syncVolumeKeys`), but the work order had no Koma shared volume-key device evidence. Opening the real 第28话 (虽然我是不完美恶女, page `1 / 40`) through the stable lab entry with the Debug-only `readerLabVolumeKeys=true` override and injecting `uitest uiInput keyEvent 17` (VOLUME_DOWN) twice then `16` (VOLUME_UP) once moved the shared reader `1 / 40` -> `2 / 40` -> `3 / 40` -> `2 / 40`, with `[ReaderVolumeKeys] intent=next accepted=true`, `intent=next accepted=true`, `intent=previous accepted=true`. So the shared route turns real pages through the host volume-key lease. Artifacts: `.hermes-artifacts/20260917-koma-volumekeys/run3/{base,next1,next2,prev1}.json` (+ `run-metadata.json`). (A first attempt without the override did not turn pages because Koma's persisted `volumeKeyNavigationEnabled` default is false; the override is the same Debug-only lab launch parameter the NextN/NextE twin trials use, not a persisted setting.)
- NextE shared-reader **host settings sheet** re-verified at the pinned revision (2026-09-17, 197, candidate `b7d6d03f` reader-kit `f450aad`): the tracked `ReaderHostSettingsTrial` (`sharedChromeOpensAndReturnsFromHostSettings`) passes **1/1**. It asserts that with the read-write flag set the shared gear is `rkit-host-settings` (and `rkit-runtime-settings` is absent), opens the host sheet, finds `双页模式`, and returns to the reader. Pixel evidence: `host-settings-open.png` shows the host-owned 「阅读」 sheet (`阅读模式 → 翻页方向 从右到左`; `翻页模式 → 双页模式 / 双页布局 拼合 / 翻页动画 / 点按区域 L形 / 反转点按区域 全部 / 自动裁剪页面留边 / 裁边强度`) over the real page at `1 / 46`; `host-settings-returned.png` shows the reader back at `1 / 46` with the chrome intact after dismissing. So the settings-sheet ownership boundary holds on device for NextE, closing the third host of the `Settings Sheets` dimension at the pin. Artifacts: `.hvigor/outputs/nexte-hostsettings-f450aad/{run/run-metadata.json,caps/}`. (The flow only mutates the real reading position of that chapter; no library/download data was changed. The pre-run `reader-sessions.v1.json` was then pushed back byte-identically — the restored row reads `pageIndex 1` / `page:...:1` again and the file compares equal to the pre-run baseline; artifact `.hermes-artifacts/20260917-koma-crossversion-f450aad/04-restore-baseline/`.) Koma cross-version **settings** continuity re-verified at the pinned revision (2026-09-17, 197, candidate `6553e2df` reader-kit `f450aad`, rollback target main `0399e257`): the pinned candidate toggled reader fullscreen through the real Settings -> Reading sheet (`reader.fullscreen` durable value `true -> false`), then `install -r` of main `0399e257` + cold start read `reader.fullscreen=false` back and rendered the 「全屏」 toggle **off** in its Reading sheet (that revision also shows no 「阅读器实现」 selector, i.e. it is the pre-pin build), and restoring the pinned candidate wrote the original value back (`false -> true`). So a reader setting written on the pinned candidate survives a cross-version replacement and the rollback, and the device was left at its pre-run value. Artifacts: `.hermes-artifacts/20260917-koma-crossversion-f450aad/{05-settings-write,05b-settings-write,06b-rollback-settings,07b-restore-settings}/`. `install -r` replacement and cross-version settings continuity passing on 197; 6 shared-reader contract suites pass (re-run 2026-09-17). Koma's own `scripts/test_data_migration_policy.mjs` fails on a stale expectation (`READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION = 2`) after the source moved to schema 3 in `e197d63e`; the source still accepts/migrates v1/v2/v3, so this is a host-repo test-expectation drift, not a shared-reader defect and not a Package 5 gate.
  - reader-kit: current pin `f450aad` (from `8112355`) with 63/63 core tests passing (re-run 2026-09-17); all three hosts vendor the identical gitlink `f450aad0ffaebff0a660bf43efa04b20fc2661ef`, confirming one shared core rather than three forks. (Historical acceptances below were produced against `8112355`; the `f450aad` delta is only the decode/render failure-classification routing, re-verified by all three host suites and a 197 decode-path device trial.)
  - Host contract suites (re-run 2026-09-17): NextE `scripts/test_reader_*.mjs` 11/11 pass; NextN `scripts/test_reader_*.mjs` 16/16 pass (`test_reader_tap_zone_handoff_runtime.mjs` needs `NEXTE_READER_ROOT`/`KOMA_READER_ROOT` pointed at the real checkouts — a harness path assumption, not a product defect).

- **First pixel-level visual review completed (2026-09-17, 197, pinned `f450aad`)** — the previously-blocked raster review is now executable: `nodeRepl.emitImage` renders an image into the reviewing context (verified by two blind tests — a random 6-letter code and four random color/shape pairs were read back exactly against hidden ground truth). Note: the `view_image` tool returns only a base64 string and does NOT render, so the earlier "no image perception" conclusion was tool-specific and is corrected here. Review of the 7 NextN route-matrix captures and the NextE/Koma captures found **no rendering defect** (no clipping, overlap, missing page body or wrong page), but it did surface one **cross-backend presentation difference that the layout-only audit could not see and that is not yet adjudicated**:
  - On the ordinary Detail/Grid/Compact entry, the **Shared** reader enters with chrome **visible** — top toolbar (back, `n / total`, reload/settings/more), bottom bar (slider + action row) and the system status bar all shown (`rkit-reading-surface` at `[0,124]`, `rkit-chrome-top` `[0,124..305]`, `rkit-chrome-bottom` `[0,2265..2720]`).
  - The **Legacy** reader on the same entries enters **immersive**: no top toolbar and no bottom bar, only a passive `n / total` badge, with the surface at `[0,0]` (0 system status-bar nodes). Source confirms this is the legacy design, not a capture artifact: `ReaderPage.ets:2727` `@Local readerChromeVisible: boolean = false` renders `ReaderPersistentPageStatus()` while hidden and only adds `ReaderHeader()`/`ReaderBottomBar()` when `readerChromeVisible` is true; the shared `ReaderSurface.ets:87` defaults `chromeVisible = true`.
  - This is a presentation-state difference (Shared shows its own chrome on admission; Legacy keeps its documented immersive-by-default contract), **not** a missing control: the shared surface does support hiding chrome (tap toggle, method-covered by `reader-kit/tests/reader-surface-input.test.cjs`), and every legacy action is present in the shared More menu. It is recorded as an OPEN cross-backend presentation question, not a defect claim, and no product change is made from it. Pixel evidence (same device 197, same gallery, same in-run captures): `nextn-f450aad-matrix/.../04-screens/in-app-detail-shared-read.png` shows Shared with the full chrome + status bar over the page, while `in-app-detail-legacy-read.png` shows Legacy entering immersive with only the passive `2 / 14` badge and the page filling `[0,0]..[0,2720]`. Source confirms no shared "start hidden" path exists: `ReaderSurface.ets:87` initialises `chromeVisible = true` and nothing on admission hides it, while legacy `ReaderPage.ets:2727` initialises `readerChromeVisible = false` and only renders `ReaderHeader()`/`ReaderBottomBar()` on tap. Because both are the respective backends’ own defaults and the shared tap-toggle is present and method-covered, this is a **product trade-off** (should the shared reader open immersive like legacy, or open with chrome visible?), not a defect; it needs a user decision before any visible change, per the reference-first/freeze rules. The Koma legacy reader also defaults chrome hidden (`Index.ets:209 readerChromeVisible = false`), so all three legacy backends share the immersive-entry contract.
- NextE pinch **zoom + pan** pixel-reviewed at the pinned revision (2026-09-17, 197, candidate `734c4a74` reader-kit `f450aad`): the `ReaderPagingAxisTrial` run wrote `rkit-axis-zoom-before-pan.png` and `rkit-axis-zoom-after-pan.png`; both frames show page `2 / 46` with the slider parked at 2, while the after frame shows the same page at a visibly larger scale (the character’s face/detail is magnified and the surrounding content is panned), i.e. the pinch applied a real viewport transform (>1 scale) that advanced neither page nor persisted position, and no clipping/blank/placeholder appeared. Artifacts: `.hvigor/outputs/nexte-rtl-normalized/device197__ALN-AL80/not-applicable/portrait-1260x2720/zoom-review/`. This is the device pixel evidence the trial’s own comment (`zoom_evidence_requires_transform_and_pixel_review`) asks for and closes that reviewer-side gap for NextE.
- NextE shared-reader **reset-zoom click restores geometry** (verified 2026-09-18, 197, candidate `a3f42e98` reader-kit `f450aad`): NextE's shared More menu lists `rkit-reset-zoom` 「重置缩放」 once the viewport is zoomed, but only its enabled state had been recorded; this run closes the click-through half. Opening real content 4175844 at page 2 (Debug single/ltr entry), double-tapping drives `rkit-part-1-whole` to the full viewport `[0,124][1260,2720]` (from the fitted `[0,471][1260,2249]`), the menu's live `rkit-reset-zoom` bounds are read from the dump (`[675,637][1195,793]`, not a guessed coordinate), and clicking them returns `rkit-part-1-whole` to `[0,471][1260,2249]` — identical to the pre-zoom baseline. So the shared navigation/topology-fenced reset command resets the viewport transform on device for NextE too, matching the Koma result. Read-only run (zoom is in-session viewport state; no progress or preference written). Artifacts: `.hvigor/outputs/nexte-resetzoom/run1/{baseline,zoom,menu}.json`, `.hvigor/outputs/nexte-resetzoom/run2/after.json`.

- NextN/NextE explicit-fallback pixel review (2026-09-17, 197, same viewport 1260x2720): reusing the retained captures, the Shared-selected frame renders the shared surface with its own chrome (NextN `04-screens/in-app-detail-shared-read.png` top bar `4 / 14` + bottom slider `14 | 4`; NextE `shared-reader-package5/.../03-normal-entry-rehearsal/backend-shared-reader.png` top bar `1 / 2` + bottom bar) while the Legacy frame renders the legacy reader immersive with only the passive badge (NextN `in-app-detail-legacy-read.png` `2 / 14`; NextE `backend-legacy-reader.png` `1 / 2`), and for NextE both frames show the same real page (「月影駅」 scene), so the fallback toggles the implementation while preserving content. **Cross-host conclusion:** the "shared enters with its chrome shown, legacy enters immersive" presentation difference documented earlier for NextN is now confirmed by pixels on all three hosts (NextE above; Koma `.hermes-artifacts/20260917-koma-chapter-f450aad/{29-shared-open2,30-legacy-open2}/`). Caveat recorded honestly: the NextN Shared/Legacy `read` frames are **not** a strict same-state pair — the Shared frame is in continuous mode at `4 / 14` while the Legacy frame is single-page at `2 / 14` (the trial opens each backend at its own persisted state), so only the entry-chrome difference and each frame’s own surface ownership are read from that pair, not a same-mode geometry comparison.

- **Identified implementation and acceptance gaps (Package 5 OPEN):**
  1. *Non-local/cloud comic-translation provider end-to-end (NextE/NextN):* `ReaderHostTranslationActionsTrial` on 197 (05z, `Tests run: 1, Failure: 0, Pass: 1`) now shows the More menu with enabled `translate-page`, first click dispatching translation (label advances to 「显示原图」, checkmark) with the applied translated overlay rendered (host-translation-followup.png), and the retry click toggling back to the original image (host-translation-retried.png) — i.e. an apply/toggle-back roundtrip. The local-route path is now fully device-verified (§ evidence below). Still OPEN but narrowed: a shared-reader device run against a *configured* non-local provider. Source check shows the shared path is not route-specific — `NextEReaderTranslationProvider.prepareVariant` calls the same `ComicTranslationRuntimeService.runReaderPage` that internally branches on `ComicVisualProviderSettings.route` (local / self-hosted / torii), and the host `ComicTranslationSettingsPage` exposes the identical three-route selector in both hosts. The self-hosted route already has real-device acceptance through the *legacy* reader (NextE 237, real pages 21/22, `.hvigor/outputs/manga-self-hosted-reader-237-20260728/`). What remains unproven is only running the same service configured non-locally *through the shared surface*, which needs a user-owned provider/credential configuration rather than new shared code.
  2. *Three-host unified visual sweep:* A same-state comparison of the captured shared-surface layout trees (NextN `trial-debug-v2/extracted_evidence/...shared-read.json`, NextE `/tmp` 05f actions dump, Koma `.hermes-artifacts/20260915-tap-policy/.../04-candidate/layout.json`) shows 18 shared `rkit-*` ids on all three hosts: `rkit-reading-surface`, `rkit-native-pager`, `rkit-image-viewport`, `rkit-entry-content/image-0-1-1`, `rkit-chrome-top/bottom`, `rkit-chrome-page`, `rkit-close`, `rkit-more`, `rkit-host-settings`, `rkit-save-image`, `rkit-share-image`, `rkit-source-slider`, `rkit-toggle-spread`, `rkit-toggle-thumbnails`, `rkit-auto-read`, `rkit-reading-mode`. Host-only ids match the documented allowed variance plus per-page indices: NextN `rkit-part-1-whole`; Koma `rkit-host-center-action` (chapter control) + `rkit-part-0-whole`; NextE's extra ids (`rkit-host-action-translate-*`, `rkit-image-info`, `rkit-original-image`, `rkit-reload-source`, `rkit-reset-zoom`) come from its open overflow menu in that capture, plus the debug `rkit-trial-navigation`. A source-level audit of the `ReaderSurface({...})` wiring in the three host lab pages shares 25 params (viewport/canvas, `input`, `tapPolicy`, `autoReadPolicy`, `preloadDepth`, `cropPolicy`, `hostActions`, `hostSettings`, `mediaActions`, `observation`, `preferenceSink`, `beforeShowChrome`, `activitySink`, insets, `pageTurnAnimation`, `showPageNumber`, `imageInterpolation`, `initialUnit/Index`, `onClose`). Host-only params all match intended scope, not omissions: Koma adds `chapterNavigation`+`centerAction`+`pageGap` (chapter orchestration) and has no `variantPolicy`/`hostStatus`/`entryTransition`/`entryPreview`/`externalOpen` because it has no super-resolution/translation/entry-flight/external-open feature; NextE/NextN omit `chapterNavigation`; NextE omits `externalOpen` (its legacy menu has no external-open item); NextN adds `externalOpen`. The thumbnail rail is one shared component (`ReaderThumbnailRail`) mounted by the single `ReaderSurface`, so there is no per-host rail divergence; it is now device-verified in both phone hosts on 197 — NextE `ReaderThumbnailRailTrial`/`ReaderThumbnailRailLifecycleTrial` (1/1 each, `f86305c1`) and NextN equivalents (1/1 each, `fc7a75d9`) — and Koma now has first-hand 197 rail evidence too (`.hermes-artifacts/20260917-koma-shared-rail/02-rail/`: `rkit-thumbnail-rail` + `rkit-thumbnail-rail-wrapper` with tiles 2-5 decoded via `rkit-thumb-image-N`/`rkit-thumb-state-N-displayed` from the ordinary shelf entry). Settings-sheet parity resolves to an ownership boundary, not a divergence: `ReaderSurface`/`ReaderChrome` only own the `rkit-host-settings` entry point (`ReaderHostSettings.request()`), and each host injects its own content via `@BuilderParam settingsSheetContent` (NextN `SettingsPage{surface: READER}`, NextE `ReaderSettingsPage`, Koma `ReaderSettingsContent`). Error/loading states are also shared, not per-host: the only failure/loading UI is reader-kit's `ReaderFailurePanel` / `ReaderPagedViewport` (`rkit-failure-page-N`, `rkit-retry-page-N`) plus `LoadingProgress`, covered by `reader-kit/tests/reader-failure-presentation.test.cjs` and exercised on device by NextE `ReaderFailurePresentationTrial` (quota copy + same-page retry) and NextN `production-failure`/`production-recovered`. A same-state visual comparison confirms the shared shell and host-owned text: both hosts render the identical `ReaderFailurePanel` structure (warning icon, title, hint, `P<n>` label, 「重试」button) — NextE `shared-reader-package10/.../quota-failed.png` (「图片配额已用尽 / EH 返回 509 配额图片。请稍后重试，或尝试换源 / P4」) versus NextN `20260917-nextn-failure-copy/.../06-failure-load-copy/screen.png` (「图片不可用 / 请检查网络后重试 / P1」; the earlier `20260912` capture showed reader-kit's generic 「图片加载失败」 before the NextN classifier was added in `2c53b158`/`6f99aa28`), with the same `rkit-failure-page-N`/`rkit-retry-page-N` ids in the NextN dumps. No cross-host divergence remains in this dimension; the residual item for gap 2 (a fully unified visual sweep) is now also DONE on real pixels — see the two dedicated sweep records below; no OPEN sub-item remains for gap 2.
  - **Failure-panel pixel sweep DONE (2026-09-17)** — same device/viewport captures: NextN `nextn-failure-copy/.../08-decode-failure-copy/production-failure.png`, NextE `shared-reader-package10/.../02-failure-presentation-f450aad/quota-failed.png`, Koma `.hermes-artifacts/20260917-koma-failure-copy/02-failure-copy-f450aad/screen.png`. All three render the **identical shared `ReaderFailurePanel`** (warning triangle icon, title line, hint line, `Pn` page label, 「重试」 button, same rounded card geometry and centring), differing only in the host-classified copy (NextN 「图片不可用 / 请检查网络后重试 / P1」, NextE 「图片配额已用尽 / EH 返回 509 配额图片… / P4」, Koma 「无法加载页面 / 请重试，重新获取这张图片。/ P1」), exactly as the ownership boundary requires. No cross-host structural divergence.
  - **Display-mode pixel sweep (2026-09-17, NextE 197)**: `reader-display-modes/.../03-spread/changed.png` (two pages side by side, spread glyph active), `03-continuous/changed.png` (long-image list, no fixed row height), `05-vertical/vertical-p2.png` (single page, vertical-axis glyph active) all render the expected reading modes with the real page art. A zoom-in of the continuous top bar shows the shared chrome is an **overlay** over the content (`#CC000000` band). This is **not a regression**: legacy `ReaderPage.ets:4379` `ReaderHeader` is likewise a `Stack` overlay whose comment states "page count is an overlay at the viewport’s geometric center", so both backends overlay chrome on continuous content. Recorded by source check to avoid a false defect claim. (2026-09-17) The *node-set* half of that sweep is now objective and done: across the stored layout dumps of all three hosts (NextN `trial-debug-v2/.../shared-read.json`; NextE `shared-reader-package1/.../15-consolidated-lifecycle/enabled-timeout.json`; Koma `.hermes-artifacts/20260917-koma-237-largescreen/spread/layout.json`) exactly 13 shared ids are common to all three — `rkit-reading-surface`, `rkit-chrome-top`, `rkit-chrome-bottom`, `rkit-chrome-page`, `rkit-close`, `rkit-more`, `rkit-source-slider`, `rkit-toggle-spread`, `rkit-toggle-thumbnails`, `rkit-reading-mode`, `rkit-save-image`, `rkit-share-image`, `rkit-auto-read`. Every extra id traces to a host feature or capture state, not a missing shared control: NextN adds `rkit-image-viewport`/`rkit-native-pager`/`rkit-part-1-whole`/`rkit-entry-content`/`rkit-host-settings`; NextE's extra ids are its overflow original/retry/failure nodes plus the debug `rkit-trial-navigation`; Koma adds `rkit-shift-spread` (spread-pair offset) and `rkit-runtime-settings`. The *pixel* visual comparison half of this sweep is now also DONE (real same-state captures; see the unified sweep record below), so this whole dimension is closed.
  - **Unified three-host visual sweep DONE (pixel-level, 2026-09-17)** — the raster half of this gap is now closed with real pixels (same device 197, same viewport 1260x2720, same state: open reader, chrome shown): NextN `in-app-detail-shared-read.png`, NextE `shared-reader-package6/.../12-production-detail-and-grid/detail-reader.png`, Koma `.hermes-artifacts/20260917-koma-real-f450aad/02-shared-real-read/screen.png`. At native resolution the **top bar is pixel-identical across all three** (back chevron, centred `n / total`, reload / settings / more) and the **bottom bar has the same structure** (page number, slider track/knob, action row). All differences are the already-documented host-owned leaves, confirmed visually: NextN/NextE show 5 leaves left+right (NextN: save, original, paging-axis, spread, external-open; NextE: save, translate, original (orange accent = active translated/original state), image-block, thumbnails, spread, external-open), while **Koma shows the centred `章节 n / m` chapter control** where the other two have their extra actions. The NextN `14 | 4` left/right reversal is **intended RTL behaviour, not a defect** — source `ReaderChrome.ets:536/545` swaps the leading/trailing page labels and sets `reverse: true` when `policy.direction === 'rtl'` (device 197 persists RTL), exactly matching legacy `ReaderPage.ets` — verified by source before recording, to avoid a false defect claim. CORRECTION (2026-09-18): an earlier revision of this row wrongly stated that no host models `splitWidePages`/`rotateWidePages` as a persisted preference. That is true for NextN and NextE (`NextNReaderInitialPolicy`/`NextEReaderInitialPolicy` never set them and their legacy readers have no such menu item, so the hosts' `persistRuntimePolicy` correctly ignores the `onPolicy(policy, 'split_wide_pages')` in-session change), but **Koma does** persist it: `wideImageMode` (`keep_single | split_wide_pages | rotate_wide_pages`) is a real Koma reader preference, mapped into the shared policy by `KomaReaderInitialPolicy` (`wideImageMode === 'split_wide_pages'` -> `policy.splitWidePages`, `'rotate_wide_pages'` -> `policy.rotateWidePages`) and back by `KomaReaderPreferenceBridge`, and its shared-route device acceptance is recorded separately (see the Koma wide-page rotation record below). In-session wide-page rotation/split behavior is covered by `reader-kit/tests/reader-wide-page-rotation.test.cjs` (4/4) and `reader-display-map.test.cjs` (18/18).
  3. *Shared failure copy (acquisition + decode/render) is host-classified and CLOSED:* all three hosts own a failure classifier (`NextEReaderFailure`, `NextNReaderFailure` (device-verified `6f99aa28`), `KomaReaderFailure` (Koma `9d0d38ed`, and device-verified `36d52779`: with the new lab probe, `rkit-failure-page-1`/`rkit-retry-page-1` render 「无法加载页面」)), each implemented as `ReaderAssetFailureClassifier` on the host adapter and passed into `ReaderPagedSession`; NextN now owns a classifier (`NextNReaderFailure` + `ReaderAssetFailureClassifier` on `NextNReaderLabAdapter`, session wired) and the acquisition path is device-verified on 197 (`6f99aa28`: `rkit-failure-page-1`/`rkit-retry-page-1` render 「图片不可用 / 请检查网络后重试」, `.hvigor/outputs/nextn-failure-copy/.../06-failure-load-copy/`). CLOSED (2026-09-17): `reader-core`'s `ReaderSession` now routes both `reportPresentation(false)` and `reportRenderFailure` through the same `ReaderAssetFailureClassifier` port (reader-kit `f450aad`), so a native decode/render failure also carries host copy; the pin was bumped to `f450aad` in all three hosts (NextN `67e0905e`, NextE `6e360f83`, Koma `6553e2df`) and re-verified (reader-kit 63/63; NextN 17/17, NextE 11/11, Koma 7/7; each host builds). Device-verified on 197 through the real decode path: NextN `ReaderProductionFailureRecoveryTrial` asserts 「图片不可用」 and passes 1/1 (`.hvigor/outputs/nextn-failure-copy/.../08-decode-failure-copy/`), and the NextE acquisition-path `ReaderFailurePresentationTrial` re-passed 1/1 at `f450aad` (`.hvigor/outputs/shared-reader-package10/.../02-failure-presentation-f450aad/`) and Koma's forced-failure panel re-rendered 「无法加载页面」 at `f450aad` (`.hermes-artifacts/20260917-koma-failure-copy/02-failure-copy-f450aad/`), confirming the pin bump did not regress the previously-accepted failure path in any host. `reader-kit/tests/reader-failure-presentation.test.cjs` now pins both the load-path and decode/render classification.
  4. *NextE spread/paging-axis trials were LTR-geometry-brittle under the device's persisted RTL direction (CLOSED 2026-09-17 — trial fix only, no product change):* on 197 at pin `f450aad`, `ReaderSpreadLayoutTrial` (`:233`, slider right-edge click) and `ReaderPagingAxisTrial` (`:115`, horizontal "forward" swipe) both left the page at 1. Root cause identified by evidence, not speculation: the device's persisted direction is **RTL** (`[NextEReaderLab] initial_policy … direction=rtl`, `.hvigor/outputs/reader-display-modes/.../11-direction-probe/`), and the shared `ReaderChrome` slider is deliberately reversed for RTL (`reverse: this.snapshot.policy.direction === 'rtl'`) — exactly matching legacy NextE (`ReaderPage.ets:4522` `reverse: this.readMode.mode === ReadMode.RTL`). The failing trials hardcode LTR geometry, so in RTL their slider-right click seeks to page 1 and their "forward" horizontal swipe moves backward. This is trial brittleness under the device's direction setting (which those trials do not normalize; it may itself be residue from an earlier direction-setting trial on this device), not a shared-reader/anchor defect, and legacy parity holds. No product change made. CLOSED 2026-09-17: both trials now pin the Debug-only `readerLabEntryDirection=ltr` Want — the same launch-parameter pattern already used by `ReaderInitialPolicy`/`ReaderThumbnailEntry`/`ReaderProgressDurability`, never a persisted setting. On 197 at pin `f450aad` both pass 1/1 (`ReaderSpreadLayoutTrial joinedSplitGestureRotationAndSingleton`, `ReaderPagingAxisTrial verticalNativePagingAndReturnHorizontal`), artifacts under `.hvigor/outputs/nexte-rtl-normalized/`. A read-only re-probe after the runs confirms the device's stored direction is still `rtl`, and RTL navigation remains separately asserted by `ReaderInitialPolicyTrial` case 3 / `ReaderInitialPolicyReadOnlyTrial`, which negate the gesture sign for RTL. NextE commit `734c4a74`. (Investigation detail: an intermediate `ReaderSliderLifecycleTrial` re-run hit separate *trial* brittleness — an unwait-ed async runtime-menu row at `:40`, an unguarded `driver.dumpLayout` in `captureSeek`, and an unmounted `rkit-chrome-page` read at `:17`; those speculative trial edits were reverted, not shipped.)
  5. *Extensibility and migration coupling:* `ReaderSession:9-10` hardcodes `enhanced | translated` variant types, `ReaderSurface:158-162` has concrete business branching, and `NextEReaderLabAdapter` still adapts old `ReaderViewModel`. These are managed transition boundaries requiring narrow interface containment without claiming full pluggability.
- **Preserved fallback:** All three hosts keep cold starts defaulting to Legacy reader; shared reader selection is in-process and reversible; release builds fail closed to Legacy; no user data or persisted settings corrupted.
- **Device boundaries:** 237 covers large-screen, rotation, and responsive layout; 197 covers primary phone and runtime continuity; 103 designated as optional test support per user directive (2026-09-17) and never blocks progress.
- **Release authority boundary:** Completion of replacement parity does NOT constitute authorization to flip production defaults; default switching remains a separate user release decision.

### Per-app route matrix re-verified at the pinned revision — 2026-09-17

Package 5 requires the per-app route matrix on the *selected release candidate* (one pinned `reader-kit` revision). The earlier NextN/NextE normal-entry matrices were produced against `8112355`; they are now re-executed against the pinned `f450aad` on 197:

- NextN `ReaderProductionInAppDetailEntriesTrial`: **Pass 1/1**; logs `backend=legacy read=true compact=true grid=true gridReturned=true rootReturned=true` and `initial=legacy final=legacy backendWants=false seededProgress=false historyRestored=true`. The 7 layouts and 7 screenshots were retrieved; the layout audit shows 3 Shared frames each with 19 `rkit-*` nodes and no `legacy-reader-surface`, 3 Legacy frames each with `legacy-reader-surface` and no `rkit-*`, both paging through the same gallery, and the final frame restored to the host root. The page labels differ between the Shared and Legacy `read` frames (`4 / 14` vs `2 / 14`) because the Detail Read action resumes each backend from the progress state written earlier in the same run; the trial's own acceptance is the surface/pager parity plus exact thumbnail-return bounds equality, not equal labels. Artifacts: `.hvigor/outputs/nextn-f450aad-matrix/`.
- NextE `ReaderProductionInAppBackendRehearsalTrial`: **Pass 1/1** with `initial=legacy sharedSelectedInApp=true sharedTouch=true sharedReturned=true legacySelectedInApp=true legacyTouch=true legacyReturned=true queueUnchanged=true`. Artifacts: `.hvigor/outputs/nexte-f450aad-matrix/`.
- NextE **in-app backend rehearsal on the large-screen 237** at the pinned revision (2026-09-17, 237 `VDE-AL00` 1320x2120, candidate `b7d6d03f` reader-kit `f450aad`, `install -r` only; 197 was offline for a system update): the tracked `ReaderProductionInAppBackendRehearsalTrial` passes **1/1** with the same log as its 197 run — `initial=legacy sharedSelectedInApp=true sharedTouch=true sharedReturned=true legacySelectedInApp=true legacyTouch=true legacyReturned=true queueUnchanged=true`. Pixel evidence: `backend-shared-reader.png` shows the shared surface at `1 / 2` (RTL spread, slider reversed, full chrome) over the real fixture page; `backend-legacy-reader.png` shows the legacy reader entering immersive with only the passive `1 / 2` badge over the same page; `backend-shared-return.png` shows the Downloads root with the fixture restored. So the ordinary in-app entry route toggles Shared↔Legacy and preserves content and the download queue at both form factors. Artifacts: `.hvigor/outputs/nexte-237-matrix/{run,caps}/`. (Extends the earlier 197 rehearsal record to the large-screen device at the same candidate.)
- NextN shared-reader **large-screen real content on 237** (verified 2026-09-17, 237 `VDE-AL00` 1320x2120, candidate `cde04c94` reader-kit `f450aad`, `install -r` only): the NextN shared lab mounts the shared surface on the big screen with real long-strip gallery 678049 (`rkit-reading-surface` + `rkit-image-viewport` + `rkit-part-0-whole` + the full shared chrome, `1 / 14` with the RTL slider reversed). Together with the Koma 237 real-content records and the NextE 237 rehearsal, all three hosts now render real content through the shared reader at the large-screen form factor. Artifact: `.hvigor/outputs/nextn-237-lab/lab/layout.json` and `.png`.
- NextN large-screen rotation/responsive **re-confirmed at current HEAD** (2026-09-17, 237 `VDE-AL00` 1320x2120, candidate `4e50ccf6` reader-kit `f450aad`, `install -r` only): `ReaderProductionAdaptiveRotationTrial keepsTheSameRtlSplitSpreadAcrossTabletRotationAndPhysicalNavigation` passes **1/1**. No product-source change has occurred since the earlier `4f05e76e` rotation record, so this re-establishes the same acceptance at the current HEAD. Artifact: `.hvigor/outputs/nextn-237-rotation-head/run/run-metadata.json`.
- NextE `ReaderChromeTrial` on the large-screen 237 at the pinned revision (2026-09-17, 237 `VDE-AL00` 1320x2120, candidate `b7d6d03f` reader-kit `f450aad`, `install -r` only): the tracked trial passes **2/2** (`chromeDoesNotOwnTheViewport`, `sourceSeekAndDirectionRemainReadingIntents`), the same cases verified on 197. Pixel evidence at the large-screen viewport: `continuous.png` shows continuous mode at `19 / 46` with the body fitting the wide viewport and the full chrome/slider; `navigation-rtl.png` shows the in-session RTL applied (slider reversed, `46` left / `2` tracked) at `2 / 46`; `spread-seek.png` shows the spread + slider seek landing at `19 / 46`. So NextE's shared chrome controls (chrome toggle, zoom/seek, mode, direction) behave the same at both form factors. Artifacts: `.hvigor/outputs/nexte-237-chrome/{run,caps}/`.
- **Three-host large-screen (237) visual sweep DONE (pixel-level, 2026-09-17)** — same device 237 `VDE-AL00` 1320x2120, same state (shared reader open on real content, chrome shown): NextN `nextn-237-lab/lab/screen.png` (long-strip 678049, `1 / 14`), NextE `nexte-237-recon/lab/screen.png` (gallery 4175844, `1 / 46`), Koma `20260917-koma-237-real/portrait/screen.png` (real local comic, `1 / 10`). At the large-screen resolution the **top bar is the same structure across all three** (back chevron, centred `n / total`, reload / settings / more) and the **bottom bar is the same structure** (page counter, slider track/knob, action row); the only differences are the already-documented host-owned leaves — NextN's slider is reversed because 237 persists the app's RTL direction (the shared `ReaderChrome` RTL reversal), and Koma mounts its `章节 n / m` centre control. So the shared reader's chrome is consistent across the three hosts at both the phone (197) and large-screen (237) form factors. Artifacts: `.hvigor/outputs/nextn-237-lab/lab/`, `.hvigor/outputs/nexte-237-recon/lab/`, `.hermes-artifacts/20260917-koma-237-real/portrait/`.
- Koma ordinary shelf entry (same 197 protocol as the earlier record): the current signed candidate at `6553e2df` (pin `f450aad`) opens the shared surface from the ordinary shelf Continue action — the resulting layout has `rkit-reading-surface` + `rkit-native-pager` + `rkit-part-0-whole` + the chapter control `rkit-host-center-action`, with no legacy surface. Artifacts: `.hermes-artifacts/20260917-koma-ordinary-shared-f450aad/`. This supersedes the earlier `8f11c550` ordinary-entry record as the pinned-revision one.

  - **NextE runtime-continuity write trial is brittle when the durable page already equals its target (2026-09-17, 197)**: on the pinned `f450aad` candidate the write phase failed with `NextE Reader did not turn from page 3` at `ReaderRuntimeContinuity.test.ets:287`. The recovered failure capture `.hvigor/outputs/nexte-f450aad-continuity/03-caps/write-stuck-3.png` shows the shared reader correctly in **single-page mode at `4 / 46`** with the real page art — i.e. it is **not** a product defect and **not** the mode drift I initially suspected. Root cause is the trial’s own precondition: it reads `start = sharedVisiblePage()` and loops `while current !== target` with `target = 3`; when the device’s durable page is already index 3, `start === target`, the loop body never runs, and the guard `if (current === start) throw "did not turn from page N"` fires even though nothing was wrong to turn. The earlier record passed only because the durable page was 0 then. This is now RESOLVED by the shipped fix — `3018bcb2` replaced the fixed-target loop with the direction-agnostic `turnOnce` helper that taps a real non-menu zone and accepts whichever page it lands on, and that commit's pinned `f450aad` run passed (`resumed=45 expected=45 coldStart=legacy reset=legacy`); the stale fixed-target note here is superseded and kept only as history.
- NextE release fail-closed re-verified at the pinned revision (2026-09-17, 197): the pinned `f450aad` candidate was rebuilt with `buildMode=release` (main HAP `d501abd886773508bb4c8794`) and installed over the running build with `install -r` (user data preserved). `bm dump` reports `debug: false` / `versionCode 39` / `versionName 1.3.4`; the Settings -> Reading sub-page renders the normal reader options (`阅读模式`, `翻页方向`, `双页模式`, `点按区域`, `自动裁剪页面留边`) but no `nexte-reader-backend-rehearsal-row` and no 「替换演练」 text; and the ordinary Settings -> History -> Detail -> Read route opens `reader_key_surface` with zero `rkit-*` nodes. So the pinned release still fails a shared selection closed to Legacy. Artifacts: `.hvigor/outputs/nexte-f450aad-release/`. The debug candidate was rebuilt and reinstalled afterward.

- NextN release fail-closed re-verified at the pinned revision (2026-09-17, 197): the pinned candidate was rebuilt with `buildMode=release` under the `default` product, so the built `module.json` reports `debug: false` / `buildMode: release` while keeping the device-trusted signature. The `release`-product HAP is signed for a different source and the device rejects it with code 9568322 (signature verification failed / not trusted app source), so the trusted-signature path is the one that can actually be validated. On the release-mode build the Settings -> Reading sub-page renders the normal reader options (`阅读模式`, `翻页方向`, `双页模式`, `双页布局`, `翻页动画`, `点按区域`, `自动裁剪页面留边`, `连续模式`) with no `nextn-reader-backend-rehearsal-row`, no `nextn-reader-backend-rehearsal-group` and no 「替换演练」 section, and `Index.tryOpenProductionThumbnail`/`pushReader` still read the process-local selector that a release build can only resolve to Legacy. The debug candidate was reinstalled afterward and read back with `debug: true`. Artifacts: `.hvigor/outputs/nextn-f450aad-release/`.

- Koma release fail-closed re-verified at the pinned revision (2026-09-17, 197): the pinned candidate was rebuilt with `buildMode=release` under the `default` product (`module.json` `debug: false`, `buildMode: release`) so the device accepts it. On that build the ordinary Reader settings page renders the full normal option set (`阅读方向`, `跨页布局`, `阅读背景`, `图像缩放质量`, `显示页码`, `全屏`, `翻页动画`, `自动翻页间隔`, `预加载页数`, `保持常亮`, `点击区域预设`, `页间距`, `宽图模式`) with no `共享阅读器`/`现有阅读器` backend selector, and `Index.ets:244` still gates the selector through `connectKomaReaderBackendSelection().current(context.applicationInfo.debug)`, which is `false` in release. The Koma `release`-product artifact is signed for a different source and the device rejects it with code 9568322, so the trusted-signature release-mode build is the validated one. The debug candidate was reinstalled afterward. Artifacts: `.hermes-artifacts/20260917-koma-release-f450aad/`.
- NextN **release fail-closed re-verified on the Back-fix source** (2026-09-18, 197, candidate `c7fcc3ac` reader-kit `f450aad`): the host Back fix touched `Index.ets`, so the release gate is re-confirmed on the current source. Rebuilt the pinned candidate with `buildMode=release` under the `default` product (built `module.json` `debug: false` / `buildMode: release`, trusted signature) and installed it with `install -r` (user data preserved). Cold open → 我的 shows the normal 「阅读」 section with **no** 「替换演练」 / rehearsal row, and the 阅读 sub-page renders the normal reader options (`阅读模式 / 翻页方向 / 双页模式 / 双页布局 / 翻页动画 / 点按区域 / 自动裁剪页面留边 / 连续模式`) with **no** `nextn-reader-backend-rehearsal-row` and **no** shared/legacy backend selector. The debug candidate was rebuilt (`debug: true`) and reinstalled afterward. The fix itself is structurally release-inert (its guard requires `readerOverlay.activeReader`, which is set only for the shared backend, and a release build cannot select shared). Artifacts: `.hvigor/outputs/nextn-release-backfix/run2/, run4-mine/, run5-reading/`.


### Three-host parity matrix and open gap details (Package 5 Active)

| Dimension / Feature | Host / Layer | Legacy Implementation | Shared Implementation | Verified Evidence | Open Gap / Difference Classification |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Comic Visual Translation** | NextN | Legacy `ReaderPage` translation via `NextNReaderTranslationProvider`-adjacent services; manual + auto with pre-translate of the next page | Shared `NextNReaderTranslationProvider` + `NextNReaderTranslationProbe`; `translate-page`/`translate-auto` host actions | `.hermes-artifacts/20260913-shared-reader-translation-actions`, `...auto-translation{-spread,-continuous,-failure,-cancellation}` (all Pass 1/1); current-worktree rerun of `ReaderProductionTranslationTrial` on 197 `.hvigor/outputs/nextn-translation-result/.../01-result-toggle` (`Tests run: 1, Failure: 0, Pass: 1`, translation-result.png shows the translated variant applied) | **ADVANCED (Local Route Verified; Only Non-Local Provider OPEN):** manual apply→show-original→restore (197, current-worktree rerun), auto-translate in continuous (197), auto failure/next-page recovery (197+103), and navigation cancellation (197) pass 1/1; the spread-mode variants (base/failure/cancellation) now pass 1/1 on 197 at the pin through the ordinary shared entry (2026-09-18; see the spread-mode record above), replacing the earlier 103-only spread evidence. The `ReaderProductionTranslationTrial` earlier timed out six times on a Sep-13 build; on the current worktree it passes on 197. Non-local/cloud provider end-to-end remains OPEN (the trials use the Debug local seam). |
| **Comic Visual Translation** | NextE | `ReaderPage` + `ComicTranslationRuntimeService` orchestrates OCR/Inpainting/TextTranslator | `NextEReaderTranslationProvider` + `variant: 'translated'` generation swaps; `translate-page` / `translate-auto` host actions | `test_reader_translation_provider_runtime.mjs`; 197 真机 05z 复跑 `Tests run: 1, Failure: 0, Pass: 1`（`ReaderHostTranslationActionsTrial`），取回 4 张截图；05-host-translation-followup.png 显示真实译图叠加 | **ADVANCED (Local Route Verified End-to-End; Only Non-Local Provider OPEN):** 失败根因已定界并修复（`ab15c2b6`）：126e067f 的 init 预置 `currentSourceIndex=0` 使 `translationActions()` 只在 session `idle/catalog`（metaCount=0）时求值一次，More 菜单因此冻结为 `enabled=false`，05 试验在 672 行 `moreBtn` 断言失败。去掉该预置后，197 真机 05f/05g/05z 复跑：`rkit-host-action-translate-page` `enabled=true`，首次点击真实派发（`RKIT_DIAG2 dispatched busy=0`），重试后标签前进为「显示原图」（checkmark），followup 截图显示真实译图。失败文案已对齐（7c8717e0）。本地路线已四项真机验收，均 197 `Tests run: 1, Failure: 0, Pass: 1`：(1) ee4d3315 失败/恢复 prepare→unavailable→prepare→applied，失败时 rkit-host-status 显示「端侧漫画图像处理暂不可用，请稍后重试」；(2) 07e1b470 忙碌态驻留，显示「正在转录并翻译当前页…」后清除；(3) e440a64d auto 失败/下一页恢复，当前页失败时下一页仍 prepare→applied，重试后当前页恢复；(4) 05z 应用/回退往返。仅剩非本地/云端真实 provider 端到端未验。 |
| **Super Resolution** | NextE / NextN | Native NNRt / model upscaler | `NextEReaderSuperResolutionProvider` / `NextNReaderSuperResolutionProvider` + `variant: 'enhanced'` | `test_reader_super_resolution_provider_runtime.mjs`; `ReaderSuperResolutionBackend.test.ets` | **CLOSED (Parity verified):** Model path resolution, fallback on unsupported hardware, and generation switching pass in both hosts. |
| **Chapter Orchestration** | Koma | Legacy `ReaderPage` monitors chapter sequence and loads next chapter on edge | `KomaReaderLabPage` handles `ReaderChapterNavigation`, invokes `switchChapter`, and mounts `ReaderCenterAction` | `test_shared_reader_catalog_host.cjs`; `test_shared_reader_preference_bridge.cjs`; 197 real-content ordinary entry and chapter-switch pass | **CLOSED (Parity verified with preload):** Explicit previous/next chapter preparation, cancellation, rapid A-B-C selection, terminal semantics, and read state persistence pass. Preload depth is wired via `ReaderPreloadHost` in `KomaReaderLabAdapter` to fetch and cache adjacent remote pages ahead of navigation while local chapters skip network directly. |
| **Native Thumbnail Transition** | NextN | `ReaderThumbnailTransitionCoordinator` maps thumbnail bounds to reader viewport | Same coordinator hooked via `ReaderCloseContext` and `prepareReaderDestinationClose` in `Index.ets` | `test_gallery_reader_transition_contract.mjs`; `ReaderThumbnailEntryBoundaryTrial` (`dfc9ba06`) passing on 237 with exact source/opened/closed endpoint bounds; plus a real screen recording of the open flight on 197 (`.hvigor/outputs/nextn-transition-recording/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-open-record/nextn-transition-open-197.mp4`, sha256 `17ad0154…`) with frame evidence | **CLOSED (Dynamic Continuity Verified):** the recording resolves the mid-flight proxy expansion continuously from the Detail P1 thumbnail `[78,1960][395,2448]` into the reader landing position while the Detail page fades and the decoded page appears (`sheets-flight/contact-sheet_001.jpg`, frames 84-96 at 60fps, `.mp4` sha256 `17ad0154…`). The close recording returns to the exact Detail thumbnail, though its shortest mid-flight step is not resolved by the variable-rate recorder; endpoint bounds equality is separately asserted. |
| **Common Controls & Chrome** | All three hosts | Separate custom chrome implementations | Unified `ReaderSurface` (NextN:808, NextE:750, Koma:595) with shared top/bottom toolbars, slider, and page labels | Same-state captures reviewed at both form factors: 197 NextN read/compact (`trial-debug-v2/extracted_evidence/`), NextE dispatched/actions (`03-host-translation-followup/`), Koma reader/menu (`20260915-tap-policy/`); 237 large-screen three-host sweep (NextN `nextn-237-lab/lab/`, NextE `nexte-237-recon/lab/`, Koma `20260917-koma-237-real/portrait/`) | **CLOSED (Parity verified with exact pointers):** Full-bleed viewport, top toolbar (back, title, page counter), and bottom bar (slider, thumbnail toggle) match identically. Allowed host variance confirmed: Koma mounts `ReaderCenterAction` chapter control; NextE exposes translation/image-block in overflow; NextN exposes external open. |
| **Settings Sheets** | All three hosts | Host-specific settings dialogs | Injected via `@BuilderParam settingsSheetContent`; shared chrome owns only the `rkit-host-settings` gear entry | All three apps pass settings persistence across restart and rollback; plus pinned-revision 197 device checks that the shared gear opens each host's own sheet over real content — NextN `ReaderProductionHostActionsTrial` 1/1 (`hostSettings=true topRuntimeDuplicate=false`), NextE `ReaderHostSettingsTrial` 1/1, Koma host settings sheet opened at pin | **CLOSED (Allowed Host Boundary):** Each host retains its own preferences store (`reader_preferences`, `reading_settings`); common switches (mode, direction, spread, crop) function identically; the shared layer provides only the gear entry point and never the sheet content. |
| **Extensibility & Coupling** | reader-kit / NextE | Direct integration in legacy monolith | `ReaderSession:9-10` hardcodes `enhanced \| translated`; `NextEReaderLabAdapter` adapts `ReaderViewModel` | Core test suites pass; host test suites pass | **MANAGED TRANSITION BOUNDARY:** Contained within host lab adapters; does not break existing reader behavior or prevent shared reuse. Full pluggability deferred to future non-blocking cleanup. |
