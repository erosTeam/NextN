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
selector remains outside preferences, backup and user data.

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

## Single next action

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
- Window geometry differs by backend and is the one open visual question:
  Shared frames report `nextn-reader-entry-host`/`rkit-reading-surface` at
  `[0,124][1260,2720]` with the system status bar visible, while Legacy frames
  report `[0,0][1260,2720]` with no status bar. Both capture sets were taken
  with the reader chrome raised. Whether the Shared ordinary entry is expected
  to keep the status bar visible while Legacy hides it is unresolved; it is
  recorded here as an open boundary rather than called a defect.

Hypium 1/1, screenshot review DONE, ordinary-entry status-bar geometry OPEN.
An earlier run reported App died with a ReaderPageCropStrength SyntaxError;
the root cause of that failure has not been established. The passing run
supersedes it as the current candidate phone-path trial evidence.

Next Package 5 boundaries:
- 103 tablet normal-entry admission remains OPEN. 103 and 197 were both
  confirmed `Connected` by an outside-sandbox `hdc list targets -v` readback on
  2026-09-16, so the earlier "device connectivity unknown" note is stale; the
  open dimension is the tablet ordinary-entry acceptance itself, not the link.
  237 remains untouched.
- The A/B/C file-hash experiments prove only that install -r preserves
  checked durable files between builds; runtime continuity (read, upgrade,
  reopen same page, rollback, reopen same page) remains OPEN for all
  three hosts.
- Correction (2026-09-16, after reviewing the raw runs): the NextN and NextE
  entries previously written as "runtime continuity DONE" overstate what was
  executed. In both runs the main revision was only installed, cold-opened, and
  layout-dumped; the same content was never resumed inside the main revision.
  So what the evidence actually proves is narrower: **after** two `install -r`
  replacements, the candidate build still restores the same content identity,
  page, and persisted state through its ordinary entry. It does not prove that
  a real rolled-back revision can resume the same reading, and a Legacy
  fallback observed inside the candidate build is not evidence about the main
  rollback revision. Both remain OPEN; the minimum remaining check is to hold
  the existing state, resume the same content/page/settings through the
  ordinary entry **inside the main revision itself**, confirm the progress
  written on exit, and then restore the candidate.
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
  ordinary entry. Still not verified for NextN: exiting the main-revision
  reader and re-reading the durable row written from that revision.
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
  durable page and column mode are unchanged, the ordinary entry resumes the
  same page, and the rehearsal selector returns to Legacy. Not verified: a real
  Legacy reading fallback (the trial only opens Shared, so `reset=legacy` shows
  selector reset, not a Legacy read), the NextE equivalent of the NextN
  main-revision resume check above (only NextN has it so far), and the durable
  row reread after exiting a reader in the main revision.
- Koma runtime continuity remains OPEN. A previous note here claimed the 197
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
  Remaining Package 5 dimensions: the main-revision resume check for NextN and
  NextE, NextE's real Legacy reading fallback, Koma continuity, and 103 tablet
  ordinary admission. The three drafts under `docs/plans/active/` remain
  superseded and unintegrated.
- Production defaults remain Legacy. Phone-path evidence does not establish
  tablet ordinary admission.

## Package completion record

Update one row here when a package closes: shared revision, host commits,
focused suite result, consumer build result, selected device/artifact roots,
observed user path, preserved fallback, and explicit untested/non-applicable
branches. Do not paste command transcripts or create a second status log.
