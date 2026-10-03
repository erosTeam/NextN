# NextN F1 — current emulator evidence, 2026-10-03

The shared-reader replacement remains **OPEN**. This record accepts only the
recorded single-page entry/resume/return chain; Legacy remains the production
default. Device 197 was not retried. An explicit process-local shared-backend
Want selected the normal production Detail and reader routes.

## Current source, artifact and target

- NextN base `f34b0732`, with the scoped `NextNReaderLabPage` image-handoff change;
  reader-kit `a48e119737c4aed410bf7f7a9dc39ad8d22d0718` is unchanged.
- Changed source SHA-256:
  `066be48de36586c821e5c93e9e6e5dca0305db5eb87ddd805a915ba06a84c02c`.
- Signed HAP SHA-256:
  `c922f3312163a70d6ea5102275710927aba426fe9160c3ae78f60b15a909b310`.
  `scripts/build-hvigor-signed.sh debug` succeeded; checked `install -r` installed
  that HAP without a data/cache reset.
- Emulator `127.0.0.1:5555`, PHEMU-FD00, portrait root viewport 1320x2232, 60Hz
  configured display. Fresh gate proves NextN foreground/root47 before the route.
- Standard non-H gallery663205, 40 pages. Fresh semantic source
  `reader-thumb-gallery-detail-1-page-0` has bounds `[72,734][368,1184]`;
  `gallery-detail-read-action` has bounds `[1013,2046][1272,2184]`.

## Recording method and source-proven repair

The emulator's system AVRecorder failure is not a general recording gap.
macOS `/usr/sbin/screencapture -v -V <seconds> -l <current-window-id> -x <mov>`
records the visible Emulator window. A dynamic probe captured actual swipes.
The current window4419 capture includes the emulator frame/toolbar, uses no
audio, and does not capture the whole desktop. Source resolution is1260x1750.
Variable host capture cadence is **not** evidence of 60/120fps rendering or
physical-device performance.

Baseline HAP `ff9b1562…634643e` on the same kit produced a first-entry dim flash
at movie frames124–133, PTS2.586667–2.773333. Source inspection found two owners
suppressing the same reveal: the shared entry selected-image fade and the host
outer content opacity. The Reader placeholder also first mounted at root-proxy
removal. Root and departure-preview PixelMaps are independent; release aliasing
was ruled out.

The narrow host change mounts the existing placeholder during root OPENING,
beneath the unchanged root flight. After arrival, shared selected-image opacity
owns the reveal and host content opacity remains1. Reverse/close and non-root
paths retain their existing gates. No timing, geometry, route, menu, thumbnail
rail, cache, preload, background or shared-library change was made.

## Observed chain and limits

The checked manifest executes continuously, with no screenshot/model inspection
between actions: first thumbnail → three fast swipes to page4 → Back → ordinary
Read/resume4 → reveal chrome → Back → explicit thumbnail1 → reveal chrome → Back.
All1536 decoded frames and their PTS were retained; all32 contact sheets were
reviewed, with page counters enlarged at frames856 and1245.

- First and warm thumbnail flights remain root-owned. The first-entry dim flash
  does not recur at the image ownership boundary in this capture.
- Chrome is hidden at thumbnail entry. Ordinary Read restores `4 / 40`;
  explicit thumbnail1 selects `1 / 40` despite the saved page4.
- Three cached-page swipes retain displayed content. Final Back shrinks the
  selected image into the current visible thumbnail. Page4/ordinary exit uses
  the existing system fallback when its selected source is not fully visible.
- The ordinary no-thumbnail system entrance briefly contains a dark incoming
  content area before its native image appears (frames648–650). This is not
  accepted as a no-black-frame path, and this patch does not address it.
- Before/after Detail rail positions differ (baseline thumb y793, current y734).
  Thus the movies are not a pixel-matched flight-trajectory/latency comparison.
  The source-proven handoff defect and its full-image endpoint are the bounded
  comparison, not a claim that the whole transition matches Legacy.
- Online loading is observed below. Spread companion fade, Back during flight,
  processed-image replacement, other hosts and performance superiority remain
  unproven. Spread entry is observed below; the next action is source mapping of
  its same-session layout-toggle counterexample before any implementation change.

## Current online-loading branch

Without deleting cache/data or forcing reload, the normal Detail rail was moved
continuously to page38. Fresh source `reader-thumb-gallery-detail-1-page-37` is
fully visible at `[311,734][607,1184]`, same root47/viewport. One continuous
recording covers entry → wait → reveal `38 / 40` → Back to that source.
All704 frames/all15 contact sheets were reviewed; loading/native/counter states
were enlarged at frames120,166,340. Movie SHA-256 is
`bdae6155eb2f9669347cb0e0bbb01414254a5020679518c4a9cee7fe5cd6ee76`.

- Frames105–158 show the existing “正在加载图片” bar over the retained enlarged
  thumbnail; decoded original follows without an empty/black image interval.
  The loading bar is gone at the native-image handoff (frame164 onward).
- The selected page counter is38/40, chrome starts hidden, and Back shrinks the
  image into the same current visible page38 source (frames369–379).
- Runtime logs bind index37: flight-waiting17:03:35.659, original handoff36.966,
  finished37.113. Four `NextNReaderCache stored` records at36.731–36.761 and
  preload-ready sources38/39 show actual cache writes during the online route.
  No forced retry was used. Exact selected-file absence is **not** independently
  established: a guessed host cache path was absent, then the correct process
  namespace read was denied. Those commands are excluded as cache-miss proof;
  no privilege bypass or cache reset was attempted. This is accepted for the
  observed loading-to-image path, not an exhaustive file-cache audit.
- Local evidence: `unread38-loading-return.json`, its partitioned run output,
  `host-recording/unread38-loading-return.mov`, `unread38-capture-ledger.json`
  and `unread38-frames/`. The recording begins with two different rail frames
  before its sustained current source state; no UI input occurred there, so
  those initial capture frames are not treated as a product state transition.

## Current spread entry and layout-toggle counterexample

The same c922f331 HAP/root47 was recorded continuously: single38 → existing
spread control ON → Back → explicit thumbnail38 → reveal chrome → spread OFF.
The prior single-page setting was restored. Original MOV SHA-256 is
`84abd92264653f992e13f862ce695232ad66ce81df1aff9f3c96dbf4e57f99e8`;
all618 frames/all13 original contact sheets were reviewed, with affected
frames enlarged. Source/companion brightness was checked from original PNGs.

- Thumbnail38 flies directly into the RIGHT spread part, rather than first
  filling the whole reader. The LEFT companion37 gradually appears in
  frames247–255 (PTS5.965000–6.131667); the original fade remains present.
  The selected image stays visible and chrome starts hidden.
- The chain is **not accepted as a complete layout-change path**. Switching
  single→spread removes the image body in frames77–81
  (PTS1.876667–1.960000); spread→single does the same in frames376–377
  (PTS9.426667–9.446667). Both body regions are all-zero RGB, while reader
  chrome remains. Independent AVFoundation decoding also contains the empty
  body. Native images return at82/378; the final control is OFF and38/40.
- A preview impression of malformed fixed glyphs did not establish decoder
  corruption. Default, single-thread and single-frame PNG376 have identical
  RGB pixels. The final extractor replaces `setpts=N` with passthrough/demux
  time base; all618 RGB frames and original PTS are exactly unchanged, with
  the former non-monotonic output timestamp warnings gone. No thread workaround
  remains. Original artifacts are preserved; no new device replay was needed.
- Source mapping: `ReaderChrome.setLayout` updates session policy immediately;
  `ReaderPagedSession.setPolicy` rebuilds the map and retains matching source
  slots. `ReaderPagerSurface` nevertheless keys its entire `ReaderNativePager`
  by `topologyRevision`, with an immutable listener-free IDataSource. A layout
  change increments that revision and destroys the mounted native image tree.
  The established Repeat/container-retention change in kit commit1d6651b is
  not an ancestor of currenta48e119. This is a proven remount path, not yet a
  claim that a specific patch eliminates every empty frame. The next action
  is to reconcile that existing pager change with the current tree and Legacy
  layout owner, including callback fencing, before a narrow shared edit.
- Local artifacts: `spread38-entry-restore-single.json`, partitioned run
  output, `host-recording/spread38-entry-restore-single.mov`,
  `spread38-capture-ledger.json`, original `spread38-frames/`, and final
  timestamp-preserving `spread38-final-frames/`. Initial2 capture frames show
  an earlier Detail state before the sustained current Reader precondition;
  no input occurred there and they are excluded as a product transition.

## Rejected native-pager retention candidate and completed withdrawal

Candidate kitb03e090 retained one Swiper, changed immutable LazyForEach to
Repeat.virtualScroll with position keys, and fenced queued topology/navigation
callbacks. Exact changes stayed withinReaderPagerSurface; no host menu, entry
geometry, preload or cache change. All three signed builds succeeded:

| Consumer | Host | Signed HAP SHA-256 | Runtime boundary |
| --- | --- | --- | --- |
| NextN | 708f332603f7455489b625591a20c718056e5e62 | c6cd0bbb06c846b02fe63ef63f41e7f0a3d19b0bffcc89408ea62049fe9617ef | Installed-r; rejected continuous chain |
| NextE | cdd2a8295ade6a18cd0495809313580cb14cf010 | 70ef1aa1aa30f8987b82bf300794cf1d85d4589196d8293b38355174d5875882 | Build only; not installed |
| Koma | 7cb4d41c6c90724ff1e37f71c64dd87c1c907ca3 + preserved unrelated WIP | e71266b21c9e6192b6bb41a764ed4d9d79e9b45ade0b8b8108dfd472359ccada | Build only; not installed |

`stable-pager-consumer-binding.json` binds matching kit/pager hashes and actual
build outputs. Koma's --warn build exited0 with new HAP/module output; its log
suppresses the BUILD SUCCESS line, so that text is not claimed as evidence.

OnPHEMU-FD00/1320x2232, `stable-pager-spread38.json` records one uninterrupted
single38 → ON → Back → thumbnail38 → OFF → four alternating fast swipes →
reveal counter → Back chain. Recorder and checked protocol both exit0;
`host-recording/stable-pager-capture-ledger.json` binds their actual timestamps.
Movie `host-recording/stable-pager-spread38.mov` SHA-256:
`1075f9f48535cabb9f4a4efe38df69c003c89fae776b296391b38037a32398c5`.
All890 original frames/all25 sheets reviewed, with affected frames enlarged.

- ON removes the image body at64–71, PTS1.501667–1.690000; pair returns72.
- Thumbnail38 still flies to the RIGHT part, with LEFT companion gradual
  reveal245–250. This bounded observation does not accept the whole chain.
- OFF removes the body384–470 (PTS9.238333–11.428333), still blank at471.
  The first subsequent fast swipe writes2/40 rather than the page38 anchor;
  first front content returns474. Final counter is1/40 after four swipes.
  RuntimeReaderPager selected=1/topology=2/navigation=3, then selected=0/
  topology=2/navigation=4 confirms these wrong selections. The following Back
  uses systemPOP because the wrongly selected front source is outside the
  retained37–40 rail; it is not accepted as same-source return.
- The body crop(90,300,1070,1350) includes fixed window residue: mean≈2.38 in
  the blank interval versus≈64 in the preceding image. Do not describe this
  different crop as all-zero RGB. Original movie/frame evidence is retained.
  Initial capture prefix is excluded from product transition conclusions.
- Keeping an outer container does not by itself keep valid rendered children
  or the selected native index. OfficialRepeat guide supportsSwiper and
  requires wholeRepeatItem observation across custom-component/Builder reuse;
  candidate passed only a computed forItem snapshot. Swiper.index documents
  out-of-range→0. These are investigation leads; exact index-event ordering
  and the cause of the prolonged blank remain unestablished, not a licence to
  add timing, opacity, forced index refresh or another wrapper.

Candidate is REJECTED and withdrawn in shared commit
`60276c40efeff324ae37612d869dc3f246d30f2d`. Its complete tree is identical to
pre-candidatea48e119. All three source checkouts point at60276c40; NextE/Koma
candidate HAPs above remain historical rejected build artifacts, not current
rollback builds. NextN rollback signed build succeeds, HAP SHA-256
`303d9cfd9ad81306391f8af02429776ae4c60d01abdb1b4eddc454fa9a9507c6`.
`stable-pager-rollback.json` installs-r, cold opens ordinary Detail663205 and
confirms foregroundcom.erosteam.nextn/root[0,117][1320,2232] through the checked
protocol. The failed chain changed saved progress38→1; no data/cache/default
reset was used to hide that side effect. Baseline layout counterexample and
Package5 stay OPEN. One next action is source/official contract investigation
of reused-item observation and native index remapping before another patch.

## Retained local evidence

All paths below are under `.hvigor/outputs/emulator-reader-20261003/`:

- `nextn-handoff-build.log`, `handoff-candidate-binding.json`.
- `detail-handoff.json` and
  `emulator__PHEMU-FD00/not-applicable/portrait-1320x2232/detail-handoff/`.
- `f1-resume-handoff-r2.json` and its matching protocol output directory.
- `host-recording/f1-handoff-r2-capture-ledger.json` binds current window,
  protocol and recorder timestamps; both exit0.
- Original `host-recording/f1-resume-handoff-r2.mov`; route excerpt
  `host-recording/f1-handoff-route.mov`, SHA-256
  `c4b88db2f118c9fb155c1c281739c04311df557ca6c751f483ec72dccbb2ec8c`.
- `host-recording/f1-handoff-route-frames/`: all1536 frames, original PTS and
  all32 contact sheets. Baseline `host-recording/f1-route.mov`, SHA-256
  `f7470f404d666558e11d2afacd3a32c8deba84024a2b98f763c195d4201f8c89`.

Earlier `1afe5e7` captures and screenshot-derived “no regression” claims are
superseded. The failed manifest-preparation recording
`f1-resume-handoff.mov` dispatched no UI inputs and is excluded. Historical
build/suite results across three consumers do not establish their runtime
replacement acceptance.
