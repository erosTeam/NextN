# NextN F1 — current emulator evidence, 2026-10-03

The shared-reader replacement remains **OPEN**. This record accepts only the
recorded single-page entry/resume/return chain; Legacy remains available as a
fallback. Current NextN absent-key backend default is Shared (repository source),
so the earlier production-default sentence is withdrawn. No default choice is
changed by this slice. Device 197 was not retried. An explicit process-local shared-backend
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

## Native datasource6d84b61 — incomplete, not accepted

All three consumers compiled the same6d84b613 kit/pager702638c1 SHA.
NextN HAP18cce09ea57e5b53a38cdbd8b1090e080ee03f3fe5707f59727637fbc769c13c
was installed-r. NextE HAP5a310546238efbba6934380a1ca7df44366ddcfade96d51d55a2facff7469d14
and Koma HAPff4861235833965a9a45650243a0941325714837609c3788f6d0276082d50dfb
were built, never installed. Native datasource listener registration and
RELOAD are the same public channel used by Legacy; gesture epochs fence
layout-generated callbacks. This eliminates the outer revision-keyed remount,
but is not by itself a continuity fix.

The checked continuous source38 chain is captured in
`host-recording/native-datasource-spread38.mov`, SHA-256
`242f8e3925022c8f4efc7e2720a14daeefb70e352015488f494c61f801ad88e4`.
All888 frames/all25 sheets reviewed. Foregroundroot50, com.erosteam.nextn,
[0,117][1320,2232]; live Emulator window4419, 1260x1750 host movie, no audio.
Recorder10:39:03.364986–10:39:25.852123UTC and checked route
10:39:04.376776–10:39:22.094076UTC both exit0; original source/key/ledger,
movie and frame-timeline remain in the ignored emulator artifact root.

- ON body is black68–73, PTS1.626667–1.731667; selected RIGHT image returns74
  at1.773333, companion appears76. The first-blank to first-image sample
  interval is146.7ms; no improvement/no-prolongation conclusion is supported.
- OFF body is black367 atPTS9.321667; image returns368 at9.363333. Frame366
  still has the spread. This is a42ms sampled gap, not an inferred app frame
  rate or every-compositor-frame measurement. The overview contact sheet
  cannot establish no-black; raw enlarged frame367 is direct counter-evidence.
- Source38 entry lands RIGHT and LEFT companion gradually appears233–239.
  Four fast alternating swipe inputs show content following38→39→38→39→38;
  interrupted native animations produce two committed selections, source39
  and38, with final38/40. No black/loading appears in that cached swipe slice.
- Both closes resolve sourceIndex37 and return to the freshly gated source38
  bounds[311,862][607,1312]; final single mode and saved38 restored through
  actual navigation, not preference/history/cache reset. Detail rail differs
  from the earlier baseline, so no pixel-matched trajectory/latency claim.
- Crop(90,300,1070,1350) includes static frame residue: blank meanRGB≈2.40,
  image≈64.94. Do not call it all-zero. Current raw pixels disprove the early
  overview impression that OFF retained the image.

Source explains a remaining destructive transition: item identity is the full
canonical composition, so37:whole becomes36:whole+37:whole and the selected
viewport/nativeImage is replaced despite retained source-slot37. Official
LazyForEach key comparison preserves equal-key children and its V2 observed
properties support updating their content. The follow-up is one private
native-item identity separated from its observable display key, preserving the
selected item only for the same canonical unit/source anchor. Other source,
loading, entry, menu and host policies stay unchanged. Candidate6d is superseded
by this bounded correction, not promoted as accepted. Package5 remains OPEN.

## Retained native item15d9a07 — bounded image continuity, geometry OPEN

Shared source `15d9a07f00c8dff866f7baee2ec108195782a42e` retains the selected
native item only for the same canonical unit/source anchor, while its observable
display key adopts the new map. Other equal-composition items keep their identity.
The existing inner slot/fragment keys retain the selected image. This is private
pager reconciliation; menus, host state, cache/preload, entry flight and public
APIs are unchanged. Pager source SHA-256:
`8004597956650deba4724e43bdf5765ad5b0f3fcc0593e23b9f736ce99babcd6`.

All three consumers compile this exact clean kit. Signed HAP SHA-256 values:

- NextN: `d40a82921992cdcbaf3b3d263699b5f4e10e9cbe9dff8ca9f73b1fa24cae3c68`,
  installed-r through the checked protocol, no reset.
- NextE: `a53ae6faa687d5c7ec45193f8a4ceaedbec75bf98c514516268f012a5aef88cd`,
  build only; not installed. Its actual build entrypoint uses underscores.
- Koma: `1221ef4085109929b215aa8d20184f23efaf530e66534a09a722743bb8f28743`,
  build only; not installed. Unrelated host WIP is preserved.

Current source38 gate: foreground NextN root51 `[0,117][1320,2232]`, semantic
`reader-thumb-gallery-detail-1-page-37` at `[311,861][607,1311]`. Emulator remains
127.0.0.1:5555 / PHEMU-FD00 / portrait1320x2232. One continuous checked chain:
thumbnail38 single → ON → Back → thumbnail38 spread → OFF → four fast
alternating horizontal swipes → reveal counter → Back. All1080 original frames
and all30 contact sheets reviewed, with raw toggle/counter frames enlarged.

- ON: full selected image208; clipped old-size selected image209 at
  PTS5.046667; correct right-part selected image210 at5.068333; companion37
  appears213. No wholly empty image body in this recorded switch.
- OFF: pair504; selected38 remains centered at small spread size505 at
  PTS12.680000; full single38 returns506 at12.700000. No wholly empty body.
  Independent AVFoundation exact-PTS decoding confirms209 and505, so neither
  transient geometry can be dismissed as FFmpeg preview corruption.
- Explicit source38 spread flight365–383 goes directly to the RIGHT part;
  LEFT companion37 gradually reveals384–389. Initial entry and both returns
  retain root/source flight ownership, rather than opening full-screen first.
- Fast gestures568–665 visibly traverse38→39→38→39→38 without an empty/loader
  body in the recorded slice. Interrupted gestures produce two native commits,
  not four: PID29315 selected38/topology2/navigation3 at19:04:54.622, then
  selected37/topology2/navigation4 at19:04:56.474. Final counter721–748 is38/40.
- Back254–267 and749–766 returns selected38 to the same current visible source;
  terminal foreground is NextN Detail/root51, same viewport. Setting ends single.

Disposition: retain the source-proven removal of unnecessary selected-node
replacement. Accept only the observed cached image-presence/selection/entry/
return chain; **geometry continuity remains OPEN** because209 and505 are real
transient layouts. This is not a complete layout-switch acceptance, proof of
all compositor refreshes, physical performance, or Legacy parity. Source rail
positions differ from the earlier baseline; no matched flight-latency claim.
Changed-pager online/processed/midflight and other-host boundaries remain OPEN.
This geometry investigation was performed in the parent-fit slice below. The
15d movie remains historical evidence of the real old-size frames; it is not
the current candidate's disposition.

Local evidence under `.hvigor/outputs/emulator-reader-20261003/`:
`retained-item-consumer-binding.json`, `retained-item-source38.json`, current gate,
`retained-item-spread38.json` and partitioned command metadata; host movie
`host-recording/retained-item-spread38.mov`, SHA-256
`9a5f9b7faff40d036bb571d938d643bbb98efc97fbc58d9fb7d14bbe6226947d`,
26.983333s/1260x1750/no audio; `retained-item-capture-ledger.json`, all original
frames/PTS, and independent209/505 PNGs. Protocol and recorder exit0. A separate
wrapper invocation with unsupported `--dry-run` failed usage before input; it is
not product evidence. Actual wrapper invocation performed its mandatory dry-run.

## Ordinary parent-fit bd392c0 — cached layout chain accepted, replacement OPEN

Shared `bd392c07348c1ab55e163d4a1cd595b20af17cc8` changes only the two ordinary
Image size declarations in `ReaderPagedViewport.ets`: unrotated images use
'100%' of the already-fitted parent rather than the previous onAreaChange
width/height. Rotated, sprite/crop and fragment arithmetic is unchanged. Area
observation remains for actual geometry/readiness. This removes redundant
measurement→state→layout feedback without an API, timer, overlay or remount.
Legacy's ordinary ReaderCroppedImage uses the same parent-constraint relation.
Viewport source SHA-256:
`29d4c510aeb06829b5eb296f0049ec367579e691522f8024849178ab0c8235fd`.
Official [area-change API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-component-area-change-event)
does not guarantee ancestor/descendant callback ordering; that supports the
source cause, while the movie supplies the bounded visual result.

All three clean-kit consumers compiled. Signed HAP SHA-256 values:

- NextN `8c27bf7138a0434087e703f2b7a631dfadbdb0770acb6c39a5ae3d65bdf3d6ac`,
  installed-r through the checked protocol, no data/cache/default reset.
- NextE `4352c4b59dac430764b880a98d08954663c2bb28d66d3e911d579ad266815e7f`,
  build only; not installed.
- Koma `54b845784550dd093f62dfb1c40aba11b6177dc909e1fb897dd30190d501fa81`,
  build only; not installed. Unrelated host WIP retained.

Current gate is NextN root52 `[0,117][1320,2232]`, same effective viewport as
15d; source38 `reader-thumb-gallery-detail-1-page-37` now at
`[311,808][607,1258]`. The differing source position precludes matched flight
trajectory/latency claims. Emulator127.0.0.1:5555/PHEMU-FD00 only. One continuous
thumbnail38 single→ON→Back→thumbnail38 spread→OFF→four fast alternating
swipes→counter→Back chain was recorded. All1080 original frames/all30 sheets
reviewed, toggle198–200/515–516 and final counter740 enlarged.

- ON198 (PTS4.941667) full single→199 (4.963333) correctly fitted RIGHT38;
  companion37 appears203 (5.046667). No old-size clipped or wholly empty body
  is observed in this switch.
- OFF515 (12.616667) pair→516 (12.638333) full single38 directly; no small
  old-size centered intermediate or wholly empty body is observed.
- Initial root-owned thumbnail flight72–85 and spread flight355–373 remain;
  the latter lands directly in RIGHT38. LEFT companion gradually reveals
  379–385. No full-screen-first internal zoom workaround is introduced.
- Fast recorded gestures581–684 visibly traverse38→39→38→39→38 without an
  empty/loader body. PID7860 commits sourceIndex38/topology2/navigation3 at
  19:22:47.734, then37/topology2/navigation4 at19:22:49.548. Interrupted gestures
  do not imply four committed page changes. Counter732–757 reads38/40.
- Back245–258 and758–777 return selected38 to the same current source.
  Terminal foreground is NextN Detail/root52, same viewport; setting ends single.
  Native transition logs bind both close_target/source scopes to index37.

Disposition: accept the recorded cached whole-image ON/OFF geometry, image
presence, entry/companion, selection and source-return chain. Compared with
15d at the same root viewport, its real old-size209/505 transients are absent
from this movie. This is host-window sampled evidence, not proof of every
compositor refresh, app FPS, physical performance, or Legacy performance parity.
Movie0–1 are the pre-protocol old host buffer; exclude them from route evidence.
Rotated/cropped/continuous, changed-pager online/processed/midflight and other
hosts remain OPEN. Do not replay the accepted cached slice without a material
reopening trigger. Current next action is the processed replacement owner/route
assessment and applicable F2 handoff on the same candidate.

Ignored local artifacts under `.hvigor/outputs/emulator-reader-20261003/`:
`parent-fit-consumer-binding.json`, `parent-fit-source38.json` and gate,
`parent-fit-spread38.json` plus partitioned run metadata/layout/screen/logs;
`host-recording/parent-fit-spread38.mov`, SHA-256
`620539f69aa1e49ce55ffeea4c2d749a0a70c9aad53176b0c6f547e8a8da1475`,
26.986667s/1260x1750/no audio; window4419 metadata, capture ledger, original
frames and PTS in `parent-fit-spread38-frames/`. Checked protocol and finite
recorder both exit0. Pre/post power is AWAKE; actual normal timeout30000,
active temporary override86400000. No physical197 operation.

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

## Processed replacement applicability — bounded emulator failure disposition

On the same bd392c0 / HAP8c27 candidate, the actual host Reading sheet
reported system image SR installed, enabled toggle initially OFF and max height
2000px; platform API level readback was26. The real setting was enabled once
without changing the model/height. PID7860 requested source37 at19:47:50.062;
CoreVision returned `The service is abnormal` at50.134 and the provider returned
`reader_variant_not_applied:processing_failed` at50.137. No processed URI/output
was produced, so **successful F2 handoff remains unproven**. Capability/menu
availability is not proof that the platform processing service works.

The original switch OFF was restored through the host sheet, checked=false
read back at `[1140,1645][1248,1705]`, then sheet and reader closed to the same
Detail source38. No model download, parameter sweep, default change, reset or
algorithm compatibility edit. This attempt is dispositioned; continue other
applicable host paths rather than replaying the same emulator limitation.

Retained local evidence: `system-enhancement-on.json`,
`enhancement-restored-off.json`, `enhancement-restored-return.json` and their
partitioned layouts/logs; `host-recording/system-enhancement-on.mov` SHA256
9ba100687d283d36901914ea7c4606fa8521ed3f53702d432c664a7d80f655ac.
Frames0–143 only were reviewed: actual ON/sheet-dismiss interval retains the
image; terminal reader image is visible. This is a bounded interval observation,
**not** a full-movie image-continuity acceptance or successful processed swap.

## Same-kit NextE consumer boundary

Current NextE hostcdd2a8295ade6a18cd0495809313580cb14cf010, clean kitbd392c07348c1ab55e163d4a1cd595b20af17cc8,
signed HAP4352c4b59dac430764b880a98d08954663c2bb28d66d3e911d579ad266815e7f
was installed-r. Generic incoming EH gallery URL admitted actual production
Non-H Detail4203217. Fresh root53 `[0,117][1320,2232]` and fully visible source
`reader-thumb-gallery-detail-1-page-0` `[73,1144][347,1530]` bind the route.
No lab entry, data/cache reset, backend default or NextE product source edit.

Two finite macOS window4419 recordings, with checked continuous manifests,
were reviewed completely:

- `ordinary-entry-reentry.mov`, SHA256243ee5c63236508c71d2152bbb4bfcd190208c0c031b8b26314182f200fa693b:
  all737 frames/all21 sheets. First flight138–155, selected-image handoff155→156
  retains image presence; hidden chrome/counter1/124, Back root flight, same
  source return and re-entry372 onward observed. Raw336/340 are return-flight
  frames, not landing endpoints; no exact landing geometry or Legacy latency
  claim. Runtime initial_policy confirms single/horizontal/LTR.
- `original-on-off-return.mov`, SHA25695927854d0d7528324cd7adbd2477fb79910dd41b3b56b2fa6c314f1cade2e9f:
  all630 frames/all18 sheets. Existing enabled original control executes twice
  ON→OFF, then Back. Enlarged raw312 is blue,335 white,376 blue and445 white;
  selected image remains visible throughout the recorded replacements. Final
  Detail is the same source1. This accepts the observed variant-button and
  body-continuity chain; it does not prove every preparation/loading-feedback
  interval, exact original-file identity, uncached source absence or app FPS.
  Initial old capture buffers are excluded from product transitions.

Artifacts reside under
`/Users/honjow/git/NextE/.hvigor/outputs/emulator-reader-20261003/`:
checked `ordinary-entry-reentry.json` / `original-on-off-return.json`, partitioned
run metadata/layout/screens/logs, `host-recording/` movies, capture ledgers,
original-PTS frames and contact sheets. Recorder and checked protocol both
exit0. The observed NextE path does not reproduce NextN's dim handoff, so source
similarity alone does not justify synchronizing the NextN host-opacity patch.
These continuity paths are frozen.

## Same-kit Koma ordinary consumer boundary

The ordinary shared consumer is the isolated host93771857 plus inherited
integration in `/Users/honjow/git/Koma-current-kit-verify`, clean kitbd392c0,
installed HAP6846ee8d. The earlier master HAP54b84578 remains build-only and
uses Legacy on its ordinary route; it is not shared replacement evidence.

Real file-picker CBZ import → ordinary Detail entry → one forward swipe2 →
spread ON/OFF → Back/re-entry2 was observed on simulator127.0.0.1:5555.
All393/400/566 frames of the three movies were reviewed. The separate five
alternating rapid-swipe chain ended1 instead of declared2 and is rejected;
input exit0 and image presence cannot turn it into a pass. Cause not established.

The bounded acceptance, exact source/HAP binding, raw artifacts and counterexample
are recorded once in Koma's `docs/reader-current-kit-boundary-20261003.md`.
Local entry/layout/return are frozen. Two pages do not establish rolling preload,
chapter/network/auto-read or performance. Full replacement stays OPEN.

## Ordinary NextN initialization canvas — bounded conclusion

Host baseb86ebf66 plus the four-line ordinary initialization-canvas patch,
unchanged kitbd392c0, signed/installed HAP
b6cd548126744b2dbaaa3f9d32ad72774e70003c3ab40e3338a327a60e63226b
uses the existing canvas while the host session initializes. No new state,
timer, navigation, image/loading owner or thumbnail transition was introduced.
Current fresh root55 and baseline root52 both bind NextN Detail663205,
ContinueP38 and `[0,117][1320,2232]`.

All404 baseline and402 candidate movie frames were reviewed. Baseline incoming
frames68–70 expose a light empty host before the dark canvas; candidate's
first incoming frame70 already paints the dark canvas. Candidate image38
appears81 before system push settles, preparation retires84, and Back181–198
returns the same Detail38. No post-arrival empty body or internal zoom observed.
Older frames648–650 are during push, not landing; they do not establish a
post-arrival black flash. This accepts the bounded ordinary initialization,
entry and return route and freezes it; latency parity remains unproven.

Local `default-entry-canvas-binding.json` and checked
`default-entry-return.json` / `default-entry-canvas-return.json` bind the
source/HAP, current layouts and window4419 captures. Movies SHA256
5b07400031cb5e1d78c76707ad8fbe02c9040e7512c7ad2c4c4826c5fb143755
and6fe1d44860087cbc921e59c6eaed80f2a0a939b58db4d5a67580359861f0a060
and all original-PTS frames remain under the existing ignored artifact root.
Recorder and checked protocol exit0. Other package5 gaps remain OPEN; the
single work-order row selects the next actionable boundary.
