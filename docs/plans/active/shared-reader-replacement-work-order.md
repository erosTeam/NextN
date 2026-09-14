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
| 3. Entry, chrome, thumbnails, and return | Detail, all-thumbnails, and reader-rail entry use the correct source identity and thumbnail geometry; single/spread/continuous/long-image UI and failure material remain legible; rotation/window changes keep anchors; close returns to the current source position and restores system UI. | Same-state full-page review on 197 and 103 for changed responsive/transition paths; NH partial thumbnails and EH sprites use their own host contracts; no known visual counterexample. | **ACTIVE** |
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

Package 3 remains ACTIVE. These runs close retained rail show/hide/reopen on an
NH phone and EH-sprite tablet, the current-frame return boundary in both gallery
hosts, and thumbnail-entry crop inheritance on the selected NextN phone route.
They do not yet close every NextE production Detail/all-thumbnails entry source,
Koma's chapter-scoped thumbnail invalidation, or the complete
rotation/window/system-UI return matrix. All production defaults remain legacy
and reversible.

## Single next action

Complete NextE's normal optional thumbnail-entry source boundary rather than
adding another renderer feature: compare Detail and all-thumbnails ownership for
remote, cached and downloaded originals; ensure each entry publishes the same EH
image/source identity used by the legacy reader; and exercise saved crop on that
host without changing its sprite-crop target or the legacy/default route. Start
with current-source contracts, implement only a demonstrated missing mapping,
then run one focused signed consumer build and one selected device path. Koma
chapter-scoped thumbnail invalidation follows after both gallery hosts have this
normal-entry boundary.

## Package completion record

Update one row here when a package closes: shared revision, host commits,
focused suite result, consumer build result, selected device/artifact roots,
observed user path, preserved fallback, and explicit untested/non-applicable
branches. Do not paste command transcripts or create a second status log.
