Warning: truncated output (original token count: 72227)
Total output lines: 3889

## NextE migration-integrity gallery lane — 2026-08-22 (accepted on 237)

- Target `192.168.50.237:12345` retained its existing data and account state.
  The active lease was renewed, the wake gate read `AWAKE` with
  `OverrideTimeout=86400000ms`, and current signed main plus ohosTest HAPs were
  installed with `install -r`; no uninstall or data clear occurred.
- The latest device suite completed `Tests run: 15, Failure: 0, Error: 0,
  Pass: 15`. Cold start emitted `waterflow_columns_resolved` with an initial
  `display` width of 440vp and measured width of 440vp, both resolving to two
  columns. First creation of additional retained search pages emitted the same
  paired `cached`/`measured` width and column result. This rejects the reported
  stale fixed-two-column initialization mechanism on this viewport by runtime
  calculation evidence, not screenshot inference.
- The foreground Browse surface was semantically present after cold start;
  repeated list scrolls and retained source switches kept native gallery cards
  mounted. A sample taken while the non-secure lock screen owned input was
  discarded, the lock was dismissed, and all interaction evidence above was
  repeated against the foreground app.
- Source comparison additionally established that all six Browse card
  presentations share `GalleryThumbnail`; its loading and image-error branches
  are mutually exclusive and its foreground request retains the NextE opacity
  transition and default priority. Grid and Simple/List now carry the same
  conditional-subtree reuse contract as their current NextE counterparts.
- The app theme was switched through the native Interface page from its original
  Follow system value to Dark and Light. Same-state Home captures showed the
  cached trailing management glyph recolor in both directions while the
  management button stayed present and clickable. Follow system was restored
  before the run ended.

## Home/Favorites page-one cache — cold-start observation — 2026-08-16

- After force-stop/cold start on 192.168.50.237:12345 (fresh lease, wake, AWAKE + OverrideTimeout=86400000ms gate, no data clear), foreground-confirmed `com.erosteam.nextn` cold started into Browse and painted the waterfall list with cached rows (tag chips visible). A semantic tap on the 收藏 tab then foregrounded the Favorites root and painted the cover-grid snapshot (GridItems with title/`#id`) without any full-page "正在检查账户会话" state.
- The device RDB (`browse_presentation_settings`) read-only copy shows `browse_presentation=cover_grid`, `home_source_latest_presentation=waterfall`, `browse_presentation_show_gallery_tags=1`; `nh_gallery_list_cache` holds `home:v1:latest:all:recent` and `favorites:v1:default` snapshots, both 25/25 galleries with tagIds and resolved tags. This explains the favorites page showing no tag text: it is rendering the cover-grid card, which has no tag leaf (same as NextE GalleryGridCard), not missing tag data.
- This observes the cache cold-start path only; it does not accept tag translation timing, every layout density, sign-out cache clearing, or the pending developer-guide maintenance contract. Raw layout copies retained under `.hvigor/outputs/nextn-cache-tags-20260816T/` and excluded from Git.
# NextN active device-acceptance queue

## Reader original-image global regression — 2026-08-30 (accepted on 237)

- User outcome: Gallery `653609` and all other uncached galleries no longer stop on the
  enlarged transition thumbnail and fall into a false network-error state. The existing
  Retry button now owns taps while the current image is actually failed.
- Root cause and introduction: commit `93b64ec03e338e482ec41a585466e112f9718400`
  (`refactor(network): centralize bounded HTTP ownership`, 2026-08-28 11:43:50 +0800)
  made `ReaderImageCacheService` pass the whole default 1 GiB cache budget as one stream's
  limit, while `StreamingHttpClient` rejects limits above 512 MiB before issuing a GET.
  Separately, the later full-screen Reader tap overlay consumed the failed page's Retry tap
  and toggled chrome instead.
- Correction: preserve the aggregate cache budget and clamp only each Reader image stream
  to 512 MiB. Propagate actual image failure state from single, vertical, and spread leaves;
  only while the visible page/spread is failed, remove the overlay from hit testing so the
  existing Retry button receives the tap. Normal Reader gestures, layout, copy, cache,
  transition, and navigation remain unchanged.
- Static/build evidence: the network-authority and Reader contracts plus `git diff --check`
  pass. Signed build completed in `31 s 182 ms`; installed HAP SHA-256 is
  `829147d7420c9a1c8e528b7562452dee983aa28a808abd2782a9a035b115654f`.
- 237 acceptance: installed in place with no uninstall or data clear. Gallery `653609`
  rendered distinct complete originals at `2 / 357` and then `1 / 357`, with no
  image-unavailable/retry state; the first entry logged six successful private-cache stores.
  Final state was foreground NextN, `AWAKE`, `OverrideTimeout=86400000ms`. Evidence is under
  `.hvigor/outputs/reader-global-regression-fixed-page2-237-20260830T0006/` and
  `.hvigor/outputs/reader-global-regression-fixed-adjacent-237-20260830T0007/`.
- Boundary: the global original-load path is accepted on the reported gallery and two
  consecutive pages. Retry interception was device-proven before the patch and corrected
  across all Reader builders; a new post-fix failure was not intentionally manufactured, so
  Retry recovery from a fresh terminal network failure remains unexercised on hardware.

## Reader return target visibility — 2026-08-30 (accepted on 237)

- User outcome: Reader Back now uses a shared-element flight only when the current page's
  exact retained thumbnail is fully visible after ancestor clipping. An off-screen mounted
  List/Grid child no longer counts as a usable destination, and neither source auto-scrolls.
- Correction: the compact Detail `ListItem` and full-thumbnail `GridItem` publish complete
  visible-area state under their exact transition ids; the ordinary close gate requires that
  state in addition to gallery/scope ownership. Forward flight and immediate opening reversal
  keep their existing click-time geometry.
- Static/build evidence: `git diff --check` and the Reader transition contract pass. Because
  the dirty worktree contains an unrelated untracked thumbnail-surface refactor that currently
  fails compilation, the signed HAP was built from `bc1ee4e` plus only this lane's three source
  changes. Build time was `27 s 957 ms`; installed HAP SHA-256 is
  `a8b4999618bba2ace685923212a039f78663bbabf247c7455cd8fe00b0ac690e`.
- The exact HAP was installed in place on `192.168.50.237:12345`, with no uninstall or data
  clear. Every encoded frame was extracted and reviewed for four normal-speed recordings:
  compact visible page 1 (92 frames) and Grid visible page 2 (97 frames) continuously shrink
  to their exact tiles; compact off-screen page 6 (47 frames) and Grid-top/off-screen page 20
  (43 frames) use only the ordinary horizontal route close, with no off-viewport proxy flight.
- Recording SHA-256 values are respectively
  `117fa5f84b51b78e5426180d0c045e7638802d7e161ddf0a2ff6b35b517a77d3`,
  `097d08aca3500e173f1d7da7e1fc6a2ccd7ffc52e6a9a1c4d5bfa006b40f164a`,
  `4561d9950ad396fb8a5af296b072073a29c3f84f6b3711d378bd5976e2e79fb3`, and
  `6b51426bea02fb6a89e6436f8679fc8c5da465c497694175e55662fc751174ad`.
  Evidence is retained under the four
  `.hvigor/outputs/reader-return-visibility-*-recording-237-20260830T*/` directories.
- Boundary: accepted for the reported compact rail and full Grid at `1320x2120` on 237.
  Rotation, partially visible edge targets and the separate fullscreen endpoint-measurement
  correction remain outside this result.

## Readable download directories and explicit deletion — 2026-08-30 (accepted on 197)

- User outcome: new public download folders are named with a readable
  filesystem-safe `GID-title` segment, and deleting a download states plainly
  that it removes the Downloads entry and local files.
- Root cause: public-storage port `4e42c6f` introduced a bare-GID directory and
  exact bare-GID recovery scan instead of porting NextE's title-derived naming
  contract. The task menu retained generic Remove copy and later gained an
  irrelevant remote-gallery disclaimer.
- Static/build evidence: both download-queue contracts, the four-locale string
  contract, resource JSON parsing, and `git diff --check` pass. The signed HAP
  SHA-256 is
  `8b1abda0372092c5d04c01a3eab53efd3a550f775ba2451494d94497ed40165d`.
- The exact HAP was installed in place on user-selected
  `192.168.50.197:12345` with no uninstall or data clear; 237 was not used for
  this follow-up. Fresh Gallery `676543` completed at `107 / 107 已完成` and
  survived a force-stop/cold start. System Files exposed
  `nextn-downloads/676543-(潤子_采華）グッバイ マイ ビューティフル ワールド（K)`,
  proving both title inclusion and forbidden-slash replacement.
- The task menu rendered `导出 CBZ` and `删除下载`. Its confirmation rendered
  `删除下载？`, `将从下载列表移除，并删除本地文件。`, `取消`, and `删除`, with no
  remote-gallery disclaimer. Confirming deleted only Gallery `676543`; the six
  pre-existing completed tasks remained. Evidence is retained under
  `.hvigor/outputs/nextn-download-path-delete-copy-197-20260830/`.

## Download queue live page progress — 2026-08-30 (accepted on 237)

- User outcome: a newly queued multi-page gallery visibly advances its page count and progress bar while downloading; queued/downloading no longer remains frozen and then jumps directly to complete.
- Reproduction used Gallery `676564` / `BAD END SHUFFLE!` at `200` pages on `192.168.50.237:12345`, `1320x2120`, under lease `20260829-144145-078700f1`. Before the correction, one uninterrupted recording showed `0/200 下载中` through video PTS `31.032s`, then `200/200 已完成` at `31.944s`, with no intermediate value in 306 extracted frames.
- Source diagnosis: the NextN baseline commit `d8291aa` already lacked NextE's queue-signal publisher, observed task fields, identity-preserving assignment and retained-page signal projection; history contains no later deletion commit or rationale. Stable gallery keys therefore retained a row backed by stale copied task objects even though the worker persisted per-page counts. Restoring only the signal exposed a second existing defect: direct public-Download writes made nonempty in-flight final files look complete, so a concurrent batch could publish `200/200`, invalidate itself and then reconcile to `199/200 已暂停`.
- Correction: `NhDownloadTask` is observed with traced dynamic fields and identity-preserving `assignFrom`; queue replacement retains task identities and publishes `DownloadQueueSignalState.version`; the retained page rebuilds its existing projection from that signal and invalidates dynamic progress/status builders. `DownloadQueueService` excludes active write paths from completed-file counts, and only the settled gallery worker may promote `DOWNLOADING` to `COMPLETE`.
- Static/build evidence: `node scripts/test_download_queue_progress_contract.mjs` and `git diff --check` pass. The isolated signed build succeeded; installed HAP SHA-256 is `6a169d60d33233c4aa7e3ff38f4ceb0a7959c81394b09351be8dcc70ae1e6b50`. Installation used `install -r`; no uninstall or data clear occurred.
- Fresh-device preparation was semantically verified: after removing only this test task and its owned pages, Downloads showed `暂无画廊下载`; the reopened detail showed `200 页` and `下载`. The accepted uninterrupted recording then showed `3/200`, `33/200`, `63/200`, `97/200`, `129/200`, `162/200`, `195/200`, `198/200`, `200/200 下载中`, and the single final transition to `200/200 已完成`.
- All 1043 VFR frames were extracted. Completion remained stable through the final frame at PTS `72.570400s`; no later paused state or smaller count appeared. A post-recording semantic layout independently reads `200 / 200` and `已完成`. Recording SHA-256 is `c23b7b0ca5f2e1c4fb4f5cc863d596123544adcb47f9ae88489423c863fbd9f9`; evidence is retained under `.hvigor/outputs/nextn-download-progress-fixed-v3-recording-237-20260830T0008/` and `.hvigor/outputs/nextn-download-progress-v3-terminal-237-20260830T0012/`.

## Download-chain integrity and hidden-images policy — 2026-08-30 (accepted on 237)

- User outcome: the queue no longer treats interrupted public files as completed pages,
  active removal cannot race its worker or delete files before durable row removal, public
  restore metadata is path-bounded, and Download settings again owns the hidden-images
  switch plus `.nomedia` lifecycle.
- Static/build evidence: both download-queue contract checks, resource JSON parsing, and
  `git diff --check` pass. The signed build completed in `9 s 402 ms`; installed HAP
  SHA-256 is `676a2126f04ccb764f39c1870d5681c0dcbf3f945c12f5d2549c558ffbd88f79`.
- The final HAP was installed in place on `192.168.50.237:12345` with no uninstall or data
  clear. The existing 200-page completed task migrated to schema 23 as `200 / 200 已完成`,
  and its local Reader opened at `1 / 200`.
- An active removal produced `暂无画廊下载` and remained absent after a cold start. A separate
  force-stop run was captured at `6 / 200 下载中`; cold restore produced
  `36 / 200 已暂停`, not complete, and resume/pause advanced only verified pages to
  `39 / 200 已暂停`. Final cleanup left the queue empty.
- Download settings rendered `隐藏下载图片` and its `.nomedia` hint. Off/on actions emitted
  `enabled=false,present=false` and `enabled=true,present=true`; a force-stop/cold-start kept
  the switch enabled and reconciled the marker again. Evidence is retained under
  `.hvigor/outputs/nextn-download-chain-integrity-237-20260830/`; the final device state is
  an empty queue with hidden-images enabled.
- Physical acceptance covers migration, Reader, active removal, interrupted cold restore,
  resume/pause, and marker persistence. CBZ ShareKit handoff, notification delivery, and
  manual directory restore were source/build-reviewed but not physically exercised here.

## NH terminal authentication and unified request lifecycle — 2026-08-27 (OPEN on 237)

- User outcome: NextN on `192.168.50.237:12345` must stop silently losing
  NH authentication. Cookie capture/storage, access-plus-refresh persistence,
  request attachment, single-flight refresh, replay policy, terminal 401
  publication and user feedback must have one product owner. Acceptance still
  requires a real login, product-owned native promotion, data-preserving cold
  start, native Account, authenticated Favorites and cross-day observation.
- Current source boundary: `NhCookieAuthority` is the sole
  `WebCookieManager` owner; `NhSessionHttpClient` owns account-generation
  fencing, refresh and one safe read replay; `NhApiHttpTransport` is the sole
  first-party v2 wire transport. Mutations never auto-replay. A terminal replay
  401 retains account ownership, withdraws authentication availability, stores
  a durable verification marker and publishes one root HDS re-verification
  Snack without inserting a list-top or inline error row.
- Scope-deviation cleanup: the product-embedded login acceptance bridge,
  receipt file, acceptance/debug build flags, launch port/nonce/mode,
  key-event credential injection, test-only Web navigation, semantic ohosTest
  surface and their assertions were deleted. The external login coordinator,
  field driver and credential epoch returned to their pre-detour baseline.
  The original first-party Web page, NextE-compatible UA, online cache mode and
  product-owned Web-to-native promotion remain.
- Static/build evidence: account/history regression and recursive network
  authority contract pass; `git diff --check` passes; the normal signed Debug
  HAP builds successfully. HAP SHA-256 is
  `aa3fbc4c1229cb99692d61eff3496352cbcad78bd9b0c3c8cb8c30c9877a8167`.
- Current physical evidence: that normal HAP was installed in place on
  `192.168.50.237:12345` with no uninstall or data clear. The cold-start
  foreground root is `com.erosteam.nextn:EntryAbility`; power is `AWAKE`
  with `OverrideTimeout=86400000ms`. The root HDS notice shows
  `需要重新验证`; S0 Account is the native account list with one saved row
  and verification required, while Favorites remains native with cached
  content, no sign-in/loading/inline-error row, and no usable authentication.
  Persistent redacted stage is
  `account_restore_verification_required_after_browser_refresh_failure`.
- Current login epoch terminal: the external coordinator wrote the account
  once, wrote the password once, and incorrectly issued its sole submit while
  the Turnstile response was still empty. Product-redacted diagnostics contain
  no `candidate_captured` or `native_session_promoted`; they contain
  `turnstile_challenge_platform` resource failure and a `turnstile_pat` 401.
  The epoch is closed and must not be resumed or resubmitted.
- Corrected protocol/source boundary: the fixed sequence is now account once,
  password once, post-credential CAPTCHA action/poll in the same process,
  explicit response-token readiness, then immediate single submit. An empty
  hidden response field or unrendered widget is `challenge_failed`, never a
  no-CAPTCHA fallthrough.
- Next unverified physical action: first finish the non-device protocol and
  regression repair, then diagnose the current Turnstile/UA compatibility
  without credentials or submit. A fresh S0 and new ledger epoch are required
  before any later login. Native promotion, cold Account, authenticated
  Favorites, refresh/replay and cross-day longevity remain OPEN.


## Reader Popup sheet anchor + scrolled title material — 2026-08-23 (accepted on 103)

- The platform contract and current source comparison established the binding
  cause: `bindSheet` positions a wide-window Popup from its host node. NextE
  attaches Reader settings to the gear `Button`; NextN attached it to the
  full-screen Reader `Stack`. The unchanged sheet builder/options were moved
  to the gear, and the shared modal HDS title scroll effect was disabled so it
  does not layer dynamic blur over the API 26 sheet material.
- Signed build succeeded. The exact HAP SHA-256
  `905925a4d281f263a5a2d9cad2eb1054183bf10be1f9d629a1aac4faf86c03c5`
  was installed with `install -r` on live-resolved
  `192.168.50.103:12345`, without uninstall or data clear. The established
  Gallery `471768` path foregrounded native Reader at `2560x1600`.
- The Reader gear occupied `[2332,118][2437,223]`; its Popup opened at
  `SheetPage [1439,105][2313,1344]`, 19px to the left of the real trigger
  rather than centered on the page. A real upward fling changed the visible
  sections from `翻页与布局`/`点按区域` to
  `图像增强`/`阅读控制`/`加载`; the sheet bounds and fixed
  `阅读 [1591,105][1686,131]` title bounds remained unchanged. No popup-owned
  `MaskBlur` exists after the scroll, and the retained screenshot has no tall
  transparent title blur.
- Final state is the foreground Reader settings Popup with the scrolled list;
  power remains `AWAKE` and `OverrideTimeout=86400000ms`. Raw layouts,
  screenshots, checked manifests and command metadata are retained under
  `.hvigor/outputs/nextn-popup-modal-scroll-fix-103-20260823/` and excluded
  from Git. This directly accepts the Reader anchor and shared modal title on
  this popup path; other callers were not individually reopened.

## Split-mode settings dropdown suffix anchoring — 2026-08-22 (accepted on 103)

- The current NextE `7ee42447` fix was mapped against NextN's complete settings
  parent tree. Forty-two settings and advanced-search dropdowns now delegate
  menu visibility and anchoring to the actual suffix inside `NextNListRow`;
  page list/scaffold structure, row order, values, actions, sheets and menu
  contents remain unchanged.
- The signed HAP was installed with `install -r` on
  `192.168.50.103:12345`, without uninstall or data clear. Its SHA-256 is
  `110126b89435ee4c27a983eb6a36e263fed35671d960811024563569dff04637`.
- Post-install cold-start evidence proved the physical 2560x1600 Split root:
  left `NavBar [0,105][760,1600]`, right
  `NavigationContent [761,105][2560,1600]`. The Interface language suffix at
  `[2317,644][2451,683]` opened its menu at
  `[2162,702][2522,1176]`; the custom theme-color suffix at
  `[2323,413][2423,452]` opened its menu at
  `[2162,471][2522,1401]`. Both were right-aligned below their real suffix,
  retained their choices, and dismissed without selection. The final layout
  had zero visible menu nodes and preserved the same Split bounds.
- Final device state was `AWAKE` with `OverrideTimeout=86400000ms`. Raw current
  layouts and screenshots are retained under
  `.hvigor/outputs/nextn-menu-anchor-103-20260822T/`.

## Gallery Detail hero cover cache reuse — 2026-08-17 (accepted on 197)

- Signed Debug HAP with the hero `EhImageKnifeImage` swap was installed with
  `install -r` on `192.168.50.197:12345` (ALN-AL80 / HUAWEI Mate 60 Pro,
  user-authorized target, lease `20260817-133153-893edc22`, wake gate
  `AWAKE` / `OverrideTimeout=86400000ms`). Force-stop/cold start, browse
  list settled with visible covers.
- Tapped the first gallery card and captured the first observable detail
  screenshot (~0.4-1s after the tap); the hero slot crop (40,300)-(500,950)
  contains 83915 unique colors, luminance range 0-255, std 71.52 — rendered
  cover content, not the placeholder symbol or a blank card. Returned to the
  list, tapped the same card again and repeated: identical non-blank result.
- Source chain: the tapped row's `thumbnailUrl` and the hero's displayed
  seed URL are the same string, and both now route through ImageKnifePro's
  FILE cache, so the second render reads the file cache instead of starting
  a fresh network load. The hidden pending verified-cover preload also uses
  `EhImageKnifeImage`.
- Accepted for the observable entry path on 197 only; strict first-frame
  (8ms-class) capture is not claimed because `uitest screenCap` cannot
  synchronize to the exact frame. Raw captures retained under
  `.hvigor/outputs/detail-cover-cache-20260817T/`.

## Gallery Detail overflow menu cleanup — 2026-08-17

- Signed Debug HAP installed with `install -r` on USB
  `56T0225315001128` (new lease `20260817-030258-92d50518`, wake gate,
  no data clear). Foreground-confirmed `com.erosteam.nextn` Gallery Detail
  for the tapped gallery card.
- Detail action card still shows 下载 `[969,975][1263,1053]` and 种子
  `[969,1073][1263,1151]`. Opening the overflow menu at
  `[1152,141][1272,261]` renders exactly two items: 使用外部浏览器打开
  `[648,321][1201,417]` and 重新加载 `[648,465][1201,561]` — no 下载 and no
  导出种子文件 entries, and the external-open copy is the new browser
  wording.
- Accepted for the phone-path overflow on this gallery; reader-page
  overflow also shares the `action_open_externally` string and now shows
  the same browser wording (not separately observed). Raw layouts retained
  under `.hvigor/outputs/detail-menu-cleanup-20260817T/`.

## Download queue empty-state copy — 2026-08-17 (accepted on LAN device)

- Signed Debug HAP installed with `install -r` on USB
  `56T0225315001128` (same lease and wake gate); that device's queue holds
  3 completed downloads, so the empty branch was not reachable there.
- Same HAP installed with `install -r` on LAN device `192.168.50.197:12345`
  (lease `20260817-024109-d970eb82`, foreground-confirmed
  `com.erosteam.nextn`). Device identity verified live with
  `param get const.product.model/name/manufacturer` = ALN-AL80 /
  HUAWEI Mate 60 Pro / HUAWEI, characteristics `default` — this is a
  physical phone on the LAN, not an emulator. The Downloads tab with an
  empty queue renders the centered empty copy `暂无画廊下载` at
  `[493,1328][767,1393]` on a 1260×2720 viewport.
- Correction: an earlier draft mislabeled this LAN device as an emulator
  (the label was inherited from handoff notes without verification). The
  install on `192.168.50.197` was not an authorized validation target;
  `install -r` preserved its data but replaced the installed app.
- The `download_empty` resource now carries NextE's exact values in all four
  locales (`暂无画廊下载` / `No gallery downloads yet` /
  `ギャラリーダウンロードはありません`) and is referenced only by the
  empty-queue branch; build succeeded.
- Accepted for the empty-queue copy on the emulator path only; the USB
  device path was not re-observed because its queue is non-empty.

## Image-cache aggregation alignment (NextE row shape) — 2026-08-17

- Signed Debug HAP installed with `install -r` on USB
  `56T0225315001128` (same lease and wake gate, no data clear), then
  force-stop/cold start. Foreground confirmed `com.erosteam.nextn`.
- Storage page now renders one `图片缓存` row only: 449 项 · 142.2 MB
  (= cover ImageKnife FILE cache 18 项 plus reader file cache 431 项 ·
  141.9 MB), with `页面缓存` 32 项 · 398 KB above and comment/comic rows
  below; total 142.6 MB matches the row sum. The old standalone
  `阅读器图片缓存` row is gone; `阅读器图片缓存上限 2 GB` remains as a
  limit setting, same as NextE's `cache_reader_image_limit` row.
- Clearing the row: confirmation dialog shown, then 图片缓存 went
  449 项 · 142.2 MB → 0 项 · 0 B and total dropped 142.6 MB → 398 KB
  (page cache untouched), proving the aggregate clear removes cover and
  reader files together like NextE.
- This accepts only the merged row display and aggregate clear on this
  device; the reader-limit menu path and clear-all were not separately
  exercised this run (clear-all source-reviewed to call the same aggregate).

## Cover prefetch (visible-area offscreen preload) — 2026-08-17

- Same HAP family as the row above; added after commit `ddee0e2`:
  `GalleryCoverPrefetcher` schedules low-priority FILE-only preloads for the
  ten covers past the visible range from the shared `GalleryCollectionBody`
  `onScrollIndex` boundary (List and Grid/WaterFlow normalization branches).
  NextE's `BasicPrefetcher` lives on its LazyForEach data sources; NextN's
  four collection callers share a ForEach-backed body, so the same
  visible-area contract is applied at that shared scroll boundary instead of
  restructuring the parent tree.
- Isolation evidence on USB `56T0225315001128` (same lease, gate, `install -r`):
  cleared 图片缓存 to 0 → force-stop → cold start with zero scrolling → 6s
  settle → navigate 我的 → 存储 without touching the browse list → row reads
  14 项 · 207 KB (6 visible covers + 8 prefetched from a 10-slot window).
  No scroll input occurred between cold start and the readback.
- Scroll-growth of the same FILE cache was already accepted on the preceding
  build (6 → 10 items after real list swipes); the prefetch only adds
  offscreen FILE-only requests and does not alter card or scroll code.
  A post-scroll readback on this build was not captured because the floating
  tab bar loses hit-testing to gallery cards while the browse list is
  scrolled; this is a navigation limitation, not a product finding.
- This accepts only the zero-scroll prefetch populating the FILE cache on
  this device; Favorites/Search/Popular surfaces share the same body and were
  not separately exercised.

## Cover image cache row + ImageKnifePro pipeline — 2026-08-17

- Signed Debug HAP installed with `install -r` on USB
  `56T0225315001128` (lease `20260817-005021-a220946a`, wake gate
  `AWAKE` / `OverrideTimeout=86400000ms`, no data clear). Foreground
  confirmed `com.erosteam.nextn:EntryAbility`.
- Storage page after navigation (我的 → 存储) shows the new `图片缓存` row:
  6 项 · 101 KB while the browse page had loaded the first viewport
  (`缓存占用` 142.4 MB = 页面 389 KB + 图片 101 KB + 阅读器 141.9 MB).
- Two real browse-list swipes loaded new covers; after navigation the row
  read 10 项 · 159 KB (6 → 10), total 142.5 MB, consistent with the page
  row also growing (389 → 392 KB).
- Force-stop + cold start without data clear: the row still read
  10 项 · 159 KB, proving the FILE cache persisted across process restart
  and that `install -r` preserved reader/page caches (431 项 · 141.9 MB).
- Individual `图片缓存` clear: confirmation dialog
  `清除“图片缓存”缓存？…`, tap `清除` → row became 0 项 · 0 B and total
  dropped 142.5 → 142.3 MB; page (31 项 · 392 KB) and reader
  (431 项 · 141.9 MB) rows were unchanged.
- This accepts only the storage-page row, its growth, cold-start
  persistence, and single-row clear on this device. The clear-all branch
  (source-reviewed to include `ImagePipelineService.clearCache()`) and
  tablet split-layout paths remain unobserved on device. Raw layout
  artifacts retained under `.hvigor/outputs/image-cache-verify-20260817T1011/`
  and excluded from Git.

## Current Intermittent JS TypeError crash fix — bounded device observation — 2026-08-16

- Root-cause chain observed: NextN's HAP was missing
  `libs/arm64-v8a/libomp.so`, so `libnextn_super_resolution.so` failed to
  load (`Error loading shared library libomp.so` in live hilog) and the JS
  `nativeRuntime` was undefined; every unguarded native call threw
  (`setInteractionPaused of undefined`), which matches the ten retained
  jscrash records. The signed Debug HAP from the fix worktree (SHA-256
  `e5df3c21f396afda02a97d7b8929790ea228b2ddc7a906b32a1b4cbca617c1e9`) now
  contains `libomp.so` (byte-identical to NextE's
  `shared/libs/arm64-v8a/libomp.so`) and restores NextE's three-state
  interaction-pause guard plus the `PullRefreshListScaffold` scroll
  callbacks.
- Installed with `install -r` on only `192.168.50.237:12345` after fresh
  lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms` gate. No data
  clear, uninstall, account action, preference write, or content mutation
  occurred.
- After force-stop/cold start, `nextn://gallery/471768` foregrounded native
  `com.erosteam.nextn` Gallery Detail. A freshly resolved `继续 P1`
  activation mounted `reader-overlay-navigation` and the same PID `60188`
  remained foreground; hilog showed `ncnn Vulkan init result=0
  gpu=Maleoon 920` and `interaction_policy backend=vulkan
  pauseDuringInteraction=false` with no `setInteractionPaused`, libomp, or
  TypeError. A canvas swipe, Reader chrome reveal, back to Detail, back to
  root, and up/down list flings all kept PID `60188` foreground with no new
  jscrash in bounded hilog.
- This observes the crash-path repair only: `reader enhancement failed at
  stage=native_upscale` for this gallery, so derivative output/quality
  acceptance, every interaction branch, and every list surface remain OPEN.
  Raw local artifacts are retained under
  `.hvigor/outputs/nextn-crash-fix-20260816T/` and excluded from Git.

## Current Detail hero wide-cover contain fit — bounded device observation — 2026-08-16

- The signed Debug HAP (SHA-256
  `3601f18039585770c1b3f22ee7511d8b9e1cb2d80cf4ef64668f09b5f4176315`) was
  installed in place with `-r` on only `192.168.50.237:12345` after fresh
  lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms` gate. No data
  clear, uninstall, account action, preference write, or selection change
  occurred.
- Direct route `nextn_gallery_id 672957` (detail cover 350×249, ratio 1.41)
  foregrounded native `com.erosteam.nextn` Gallery Detail. The hero Image
  node measured `[72,487][444,752]` (372×265px, ratio 1.40), vertically
  centered inside the fixed 124×175vp slot (`[72,357][444,882]`), so the wide
  cover no longer fills the slot with grey letterbox bars. This observes the
  API-parsed-dimension direct-route path only; the tapped-card seed path and
  same-state NextE visual parity remain unobserved. Raw local artifacts are
  retained under `.hvigor/outputs/nextn-cover-aspect-20260816T/` and excluded
  from Git.

## Current API 26 menu/sheet material support — bounded device observation — 2026-08-16

- The signed Debug HAP (SHA-256
  `59fb382b0d131c53a4858f63d725343366dfeca9b6483c635ec5abe56aa1bc86`) was
  installed in place with `-r` on only `192.168.50.237:12345` after fresh
  lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms` gate. No data
  clear, uninstall, account action, preference write, or selection change
  occurred.
- After cold start at `1320×2120`, foreground-confirmed native
  `com.erosteam.nextn` 我的 → 界面 → 语言 opened the wrapped `bindMenu`
  (`appMenuOptions`) with 跟随系统 / 简体中文 / English / 日本語 and no crash;
  the menu was dismissed without selecting a value. Browse root → 浏览选项
  opened the wrapped `bindSheet` (`appSheetOptions`) with 语言 options and no
  crash. This observes route/render survival only; it does not accept visual
  material parity, every menu/sheet site, theme-change refresh, or
  same-state NextE comparison. Raw local screenshots/layouts are retained
  under `.hvigor/outputs/nextn-api26-20260816T/` and excluded from Git.

## Current Gallery detail seed reuse — cold-start first Browse card — 2026-08-16

* The signed Debug HAP from the seed-reuse worktree (SHA-256
  `8e91e315b4240e9e01adcce732a2169f471ed4690b993925cb4ac284f474839e`) was
  installed in place with `-r` on only `192.168.50.237:12345` after a fresh
  live target, lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms` gate.
  No data clear, uninstall, account action, preference write, or content
  action occurred.
* After force-stop/cold start at `1320×2120`, the foreground-confirmed
  `com.erosteam.nextn` Browse root rendered the gallery card
  `[conya (koppe)] Candeliere Notte` (`FlowItem [452,399][868,1433]`). One
  tap from its current layout bounds opened native Gallery Detail; the early
  and settled layouts both foregrounded the detail with the seeded title,
  cover, page count, no loading leaf, and the same tag rows: 同人志 / 男同 /
  纯男性⚣ / 黑塔利亚 Axis Powers translated, while `spain` / `romano` /
  `conya` stayed raw (installed dictionary has no rows for those names). No
  English-to-Chinese tag transition was observed; the pending label merge
  reuses seed labels by tag identity while the detail lookup runs.
* This observes the cold-start first-open Browse-card path only. It does not
  accept Search/Favorites/related-entry seed paths, every dictionary state,
  same-state NextE visual parity, or full lifecycle coverage. Raw local
  artifacts are retained under
  `.hvigor/outputs/nextn-seed-detail-20260816T/` (seed3-*) and are excluded
  from source control.

## Current Gallery detail tag translation — cold-start first open — 2026-08-16

- The signed Debug HAP from the refined fix worktree (SHA-256
  `34ff2af8d94a7c485185fbfab0e76fba4e03ee19e111cf111be81186978b4cd7`)
  was installed in place with `-r` on only `192.168.50.237:12345` after a
  fresh live target, lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms`
  gate. No data clear, uninstall, account action, or preference write
  occurred.
- After force-stop/cold start at `1320×2120`, foreground-confirmed
  `com.erosteam.nextn` / `pages/Index` Browse root (Latest) opened, and the
  first gallery opened through the overflow 随机画廊 action rendered native
  Gallery Detail with no diagnostic text and fully translated tag
  groups: 同人志 / 日语 / 单女主 / 中出 / 萝莉 / 口交 / 双重插入 / 接吻 / 催眠 /
  出汗 / 异瞳 / 手套 / 舔阴 / 睡觉 / 假面 / のりパチ / ジャックとニコルソン /
  星光闪亮☆光之美少女 / 羽衣拉拉 (银河天使). Raw values remained only in
  metadata cells whose owner intentionally shows the raw language name.
- Root cause accepted for this path: the previous `515af1e` fix left the
  ForEach reuse epoch unchanged between the empty-labels render and the
  resolved-labels render on the first cold-start detail; the refined fix
  advances `tagTranslationEpoch` when labels resolve, forcing the tag rows
  to rebuild. Diagnostic builds on the same device showed lookup completing
  (`TTDIAG:done:38` / trace `|R|A1:45731|Q2|D11|B3`) while the final clean
  build renders translated chips.
- This observes only the cold-start first-detail tag render path for the
  random-gallery entry on this device. It does not accept the toggle ON→OFF
  relabel path, every dictionary state, every locale, or full visual parity.
  Raw local artifacts are retained under
  `.hvigor/outputs/nextn-tagdiag-coldstart-20260816T0043/` and are excluded
  from source control.

## Current Settings hierarchy and Browse title menu — bounded device observation — 2026-08-16

- Signed Debug HAP from HEAD `2b46870` (SHA-256
  `1740ce215992125b3e27ce252a0ccd10c9a9fbf1f6b306053fe735f29b355b47`)
  installed in place with `-r` on only `192.168.50.237:12345` after a fresh
  live target, lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms` gate.
  No data clear, uninstall, account action, or preference write occurred.
- After force-stop/cold start at `1320×2120`, foreground-confirmed
  `com.erosteam.nextn` / `pages/Index` Browse root (Latest) showed exactly
  two direct title-bar buttons plus the system more button; the more menu
  contained 列表视图 and 随机画廊. Direct button 1 opened Search; direct
  button 2 opened 浏览选项 (语言/排序). 随机画廊 from the overflow opened a
  Gallery Detail. 我的 → 高级 showed 评论翻译/漫画翻译/标签翻译(开)/翻译来源
  with no flattened dictionary rows; 标签翻译 opened its destination
  (启用标签翻译 / 翻译数据库 43766 / 立即更新) and back returned to 高级.
  界面 had no 标签翻译 switch.
- Raw local artifacts are retained under
  `.hvigor/outputs/nextn-menu-settings-verify-20260816T0001/` and are
  excluded from source control.


## Current Gallery detail tag translation — bounded device observation — 2026-08-15

- The signed HAP built from the tag-translation fix worktree (SHA-256
  `23895a6314a88983ef17d0e311c7fa96a8b74368c60055a40addf029f7316298`) was
  installed in place with `-r` on only `192.168.50.237:12345` after a fresh
  lease and an `AWAKE` / `OverrideTimeout=86400000ms` gate. No data clear,
  uninstall, account action, preference write, or reload action occurred.
- After force-stop/cold start at `1320×2120`, foreground-confirmed
  `com.erosteam.nextn` / `pages/Index` Browse root showed a
  not-previously-opened 玛奇玛 gallery card `[886,399][1302,1426]`. One tap
  opened native Gallery Detail without any reload; the early layout (~3 s)
  and settled layout (~8 s) both rendered the tag section with translated
  labels (巨乳 / 单女主 / 口交 / 电锯人 / 玛奇玛 / 漫画 etc.). `doujinshi`
  stayed raw because the installed dictionary has no tag-namespace row for
  it. No `DBG labels` diagnostic text was present.
- This observes only the cold-start detail tag render path for this gallery.
  It does not accept the toggle ON→OFF relabel path, every dictionary state,
  every locale, or full visual parity. Raw local artifacts are retained under
  `.hvigor/outputs/nextn-tag-translation-fix-20260815T2158/` and are excluded
  from source control.

## Current Root 我的 tab and History destination — bounded device observation — 2026-08-15

- The signed HAP built from `cc7b1f3` (SHA-256
  `a8d5e298e5569acad7ba1737d1775f2f8bce96132cc8e8767dcb9da5a9ab64b0`)
  was installed in place with `-r` on only `192.168.50.237:12345`; no data
  clear, uninstall, account action, setting change, or history clear
  occurred (the clear dialog was opened and dismissed with 取消).
- After force-stop/cold start at `1320×2120`, foreground-confirmed root 我的
  showed exactly four root tabs 浏览/收藏/下载/我的 (TabBar
  `[240,1880][1080,2048]`, 我的 icon glyph `[915,1917][981,1983]`, label
  `[918,1989][978,2024]`) and card order account (`honjow` / `ID 5623474`)
  → `历史记录` (text `[192,593][385,649]`) → settings rows (`界面` at
  `[192,779][289,835]` onward). Tapping 历史记录 opened the
  foreground-confirmed History destination: title `历史记录`
  `[192,166][432,236]`, back button `[48,141][168,261]`, trash clear button
  `[1152,141][1272,261]`, no floating root tab bar, rest pinned day header
  `今天` `[36,285][1284,370]` with the first row at y=394. The clear button
  opened `清除阅读历史？` with `取消`/`清除`; 取消 closed it without a data
  change. After one swipe, the pinned mirror updated to `前天` inside the
  title region (`[60,300][145,349]`, TitleBar `[0,117][1320,363]`) while
  list rows scrolled beneath it.
- This observes the four-tab root, card order, destination chrome, clear
  menu, and pinned-day mirror only. It does not accept every locale,
  split/tablet layout, gallery row behavior, clear-history persistence, or
  full visual parity. Raw local artifacts are retained under
  `.hvigor/outputs/nextn-me-history-20260815T2124/` and are excluded from
  source control.

## Current History/Downloads title-to-list blank reserve — bounded device observation — 2026-08-15

- The signed HAP built from `f82f437` (SHA-256
  `9d02a0aca4d52515edf6137fc7c484ea1eb304e8740eae2890102575bc94c56d`)
  was installed in place with `-r` on only `192.168.50.237:12345` after a
  fresh live target, lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms`
  gate. No data clear, uninstall, account action, content action, or setting
  value change occurred.
- After force-stop/cold start at `1320×2120`, foreground-confirmed Downloads
  at rest showed the first Blank ending at the bottom-builder top (y=285)
  with the first `已完成` header beginning at y=306; with the Downloads
  search overlay active, the field occupied y 375–495 and the first group
  header began at y=540; foreground-confirmed History showed the first Blank
  ending at y=285 with `今天` beginning at y=285, matching the NextE
  reference Blank `[36,117][1284,285]` / `Today` at y=285.
- This observes only the at-rest and Downloads-search-active first-row
  geometry. It does not accept every locale, pinned-header scroll
  transitions, search filtering behavior, or full visual parity. Raw local
  artifacts are retained under
  `.hvigor/outputs/nextn-history-downloads-gap-20260815T2110/` and are
  excluded from source control.

## Current Reader enhancement Japanese label — bounded device observation — 2026-08-15

- The signed HAP built from `ba23872` (SHA-256
  `ccc0f027a8a0221c674d02353a4befeb23a7dc1e867648b311b203c82ce0ad44`)
  was installed in place with `-r` on only `192.168.50.237:12345`. The
  foreground-verified NextN run used a fresh live target and lease; its awake
  gate reported `AWAKE` with `OverrideTimeout=86400000ms`. No data clear,
  uninstall, account action, content action, Reader preference selection, or
  Reader canvas action occurred.
- The foreground-confirmed NextN `Settings → 界面` language value was first
  read as `跟随系统`, then temporarily changed to Japanese solely for this
  check. In foreground-confirmed root `Settings → 閲覧` at `1320×2120`, the
  existing enhancement group displayed the corrected visible switch title
  `画像強調`. The original `跟随系统` value was restored; a NextN
  force-stop/cold start settled on foreground-confirmed Chinese Home.
- This observes the bounded Japanese visible-label state and reversible
  language restoration only. It does not accept screen-reader output,
  Reader-owned Settings sheet, enhancement/model behavior, every locale, or
  full visual parity. Raw local artifacts are retained under
  `.hvigor/outputs/reader-ja-label-nextn-20260815T2010/` and are excluded from
  source control.

## Current Advanced translation-entry copy — bounded device observation — 2026-08-15

- The signed HAP built from `b2b1b6f` (SHA-256
  `67fe40c936baa0e1669aacfe03ccefea2b459fd82794bf388d4ee56557c0444a`)
  was installed in place with `-r` on only `192.168.50.237:12345` after a
  fresh live target, lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms`
  gate. No data clear, uninstall, account action, source-form action, or
  setting value change occurred.
- After force-stop/cold start, foreground-confirmed native `Settings → 高级`
  at `1320×2120` displayed title-only `评论翻译` and `漫画翻译` rows with their
  existing arrows. The following `翻译数据库`, `立即更新`, and `翻译来源` rows
  remained present and ordered; no entry was opened.
- This observes only the bounded rendered-copy state. It does not accept
  translation-source behavior, provider/account states, every locale, route
  states, or full visual parity. Raw local artifacts are retained under
  `.hvigor/outputs/advanced-translation-entry-copy-20260815T1933/` and are
  excluded from source control.

## Current Reader reference-subtitle relationship — bounded observation — 2026-08-15

- The signed HAP built from `081cd3c` (SHA-256
  `44e6451ed9c9d4e8d315e1c45ab6d19bb71541f0f3d822bef54292a201566b11`)
  was installed in place with `-r` on only `192.168.50.237:12345`; no data
  clear, uninstall, account action, Reader setting selection, or Reader canvas
  action occurred.
- In foreground-confirmed native `Settings → 阅读` at `1320×2120`, the Image
  scaling quality row displayed its current NextE subtitle and
  `优化（Mipmap）` trailing value. A separately foreground-confirmed current
  NextE Reader Settings capture on the same device and viewport showed that
  same `优化（Mipmap）` row/value state and the same HDS
  secondary-text/trailing-value vertical relationship.
- This is an exact row-relationship observation only. It does not accept the
  whole Reader page, maximum-height disabled state, volume-key row,
  Reader-owned Settings sheet, behavior, or a non-reference geometry change.
  Raw local artifacts are retained under
  `.hvigor/outputs/reader-reference-subtitles-20260815T1845/` and are excluded
  from source control.

## Current Reader tap-zone label — bounded device observation — 2026-08-15

- The signed HAP built from `6e3fc4e` (SHA-256
  `e5a1cf89d0a29d769a688a4e0baaa36e11968ae7057848409f290ceb8a2475be`)
  was installed in place with `-r` on only `192.168.50.237:12345` after a
  fresh live target, lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms`
  gate. No data clear, uninstall, account action, content action, or setting
  value selection occurred.
- After force-stop/cold start, foreground-confirmed native `Settings → 阅读`
  at `1320×2120` displayed `左右` as the current Point-zones value. Its
  opened-and-dismissed menu showed checked `左右`, then `L 形`, `Kindle`, and
  `两侧`; no menu item was selected.
- This observes only the corrected root-Settings label and existing menu
  order/selection presentation. It does not accept the Reader-owned sheet,
  tap-action behavior, persistence, every locale, or full visual parity. Raw
  local artifacts are retained under
  `.hvigor/outputs/reader-tap-zone-label-20260815T1908/` and are excluded
  from source control.

## Current Browse/Search stored-default caption removal — bounded device observation — 2026-08-15

- The signed HAP built from `0ed57b1` (SHA-256
  `dbac90faf9e8e5d270c3ee036ead45786800d26bda48bd0057998f29ffe2cb2e`)
  was installed in place with `-r` on only `192.168.50.237:12345` after a
  fresh live target, lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms`
  gate. No data clear, uninstall, account action, query, menu opening, or
  language/order selection occurred.
- At the foreground-confirmed native `1320×2120` Browse Settings route, the
  language and order rows displayed only `浏览语言 / 不限语言` and `浏览排序 /
  最新`. After normal return to the root and semantic entry into Search
  Settings, its corresponding rows displayed only `搜索语言 / 不限语言` and
  `搜索排序 / 最新`. Neither viewport contained the removed local-storage
  caption.
- This observes only the two title/value row states. It does not accept menus,
  persistent defaults, errors, requests, every locale, or same-state NextE
  visual parity. Raw local artifacts are retained under
  `.hvigor/outputs/catalog-caption-removal-20260815T1832/` and are excluded
  from source control.

## Current Theme-color false-system-option removal — bounded device observation — 2026-08-15

- The signed HAP built from `8e41736` (SHA-256
  `713ee5cda3654fd29aa33ff4293400d42471b8415d896fb11bcce7dae9e980b3`)
  was installed in place with `-r` on only `192.168.50.237:12345` after a
  fresh live target, lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms`
  gate. No data clear, uninstall, account action, content action, or menu
  selection occurred.
- After force-stop/cold start, foreground-confirmed native `Settings → 界面 →
  主题色` at `1320×2120` preserved the device's existing valid `猫咪蓝` value.
  The opened menu listed `银河蓝 / 橘黄黄 / 猫咪蓝 / 华为红 / 优雅紫 / 哔哩粉 / 小草绿 /
  自定义`; it contained no Theme-color `跟随系统` item. The separately owned
  深色模式 and 语言 rows still displayed their actual `跟随系统` values.
- This observes only the corrected menu and current valid-preset preservation.
  The device did not hold the legacy `system` value, so its durable migration,
  Custom-picker rollback, full preset behavior, and same-state NextE visual
  parity remain OPEN. Raw local artifacts are retained under
  `.hvigor/outputs/theme-color-system-removal-20260815T1812/` and are excluded
  from source control.

## Current Download-policy control copy cleanup — bounded device observation — 2026-08-15

- The signed HAP built from `36ac5fb` (SHA-256
  `ae10aba9ff2100857133171edb5491cd34100b60882bcbec023ba7de6eb7502a`)
  was installed in place with `-r` on only `192.168.50.237:12345` after a
  fresh live target, lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms`
  gate. No data clear, uninstall, account action, download action, or setting
  value change occurred.
- On the foreground-confirmed native `Settings → 下载` route at `1320×2120`,
  the existing controls displayed `同时下载的画廊数量` (current value `1`),
  `每画廊同时下载的页数` (`3`), and `重试次数` (`2 次重试`) as title/value
  rows without the removed worker, slot, CDN, delay, or private-file policy
  captions. The separate `完成通知` row and its existing behavior-specific
  subtitle remained untouched. No menu was opened.
- This observes only the bounded rendered copy and unchanged row presence. It
  does not accept download scheduling, menus, persistence, retry behavior,
  notification behavior, error states, or same-state NextE visual parity. Raw
  local artifacts are retained under
  `.hvigor/outputs/download-copy-20260815T1754/` and are excluded from source
  control.

## Current Grid-density copy and visible-unit removal — bounded device observation — 2026-08-15

- The signed HAP built from `6b465d0` (SHA-256
  `87cb1e43df5194d70ca1d0a8203c90d4f9b79ff7a815ecd11f80d2844520cd13`)
  was installed in place with `-r` on only `192.168.50.237:12345` after a
  fresh live target, lease, wake, and `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No data clear, uninstall, account action,
  query, content action, or preference value change occurred.
- On the foreground-confirmed native `Settings → 界面` route at the current
  `1320×2120` root viewport, the existing density row displayed `网格密度` and
  `双指缩放列表或拖动滑块调整每行数量`, with no visible `vp` trailing value.
  Opening the existing density page without moving its Slider displayed only
  its preview, the same instruction, and the Slider; no visible
  width/count-`vp` summary was present.
- This observes only the bounded copy and visible-unit-removal states. It does
  not accept Slider accessibility, slider/pinch behavior, persistence, every
  supported presentation mode, preview loading, keyboard, or same-state visual
  parity. Raw local artifacts are retained under
  `.hvigor/outputs/grid-density-copy-20260815T1729/` and are excluded from
  source control.

## Current Cache clear-all caption removal — bounded device observation — 2026-08-15

- The signed HAP built from `46f7471` was installed in place with `-r` on only
  `192.168.50.237:12345` after a fresh live target, lease, wake, and `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No data clear, uninstall, account action,
  cache clear, confirmation-dialog action, or preference value change occurred.
- On the foreground-confirmed native `Settings → 缓存` route at the current
  `1320×2120` root viewport, the four existing category-cache rows remained
  visible and the destructive final row displayed `清除全部缓存` without the
  former policy subtitle. The action and its confirmation dialog were not
  invoked.
- This observes only the replacement row state. It does not accept
  confirmation, clearing, disabled/clearing states, cache persistence, or
  same-state visual parity. Raw local artifacts are retained under
  `.hvigor/outputs/cache-clear-copy-20260815T1704/` and are excluded from
  source control.

## Current Content-filter policy-note removal — bounded device observation — 2026-08-15

- The signed HAP built from `4afd1f9` was installed in place with `-r` on only
  `192.168.50.237:12345` after a fresh live target, lease, wake, and `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No data clear, uninstall, account action,
  rule save, rule delete, or preference value change occurred.
- On the foreground-confirmed native `Settings → 高级 → 内容过滤器` route at the
  current `1320×2120` root viewport, the existing `添加本地过滤器` control was
  the first page content; the former leading policy note was absent. Opening
  and dismissing the existing new-rule editor without saving showed its target,
  switch, regular-expression, and text-input controls without the former
  trailing policy note.
- This observes only the two removed-note states and the unchanged ability to
  open and dismiss the new-rule editor. It does not accept rule persistence,
  editing/deletion, restore/error, keyboard-open, every list state, or
  same-state visual parity. Raw local artifacts are retained under
  `.hvigor/outputs/content-filter-notes-20260815T1650/` and are excluded from
  source control.

## Current Clipboard-link wording — bounded device observation — 2026-08-15

- The signed HAP built from `fd44230` was installed in place with `-r` on only
  `192.168.50.237:12345` after a fresh live target, lease, wake, and `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No data clear, uninstall, account action,
  clipboard read, permission request, or preference value change occurred.
- On the foreground-confirmed native `Settings → 高级` route at the current
  `1320×2120` root viewport, the off switch displayed `检测剪贴板链接` and
  `剪贴板中有受支持的画廊链接时提示打开`. The existing switch remained off;
  no detector, system permission, or open prompt was invoked.
- This observes only the replacement wording and existing off-switch state. It
  does not accept permission handling, clipboard detection, the open prompt,
  persistence, or same-state visual parity. Raw local artifacts are retained
  under `.hvigor/outputs/clipboard-copy-20260815T1648/` and are excluded from
  source control.

## Current tag-translation dictionary wording — bounded device observation — 2026-08-15

- The signed HAP built from `ade31bf` was installed in place with `-r` on only
  `192.168.50.237:12345` after a fresh lease, wake, and `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No data clear, uninstall, account action,
  preference write, query, or dictionary update action occurred.
- On the foreground-confirmed native `Settings → 高级` route at the current
  `1320×2120` root viewport, the existing translation-capabilities group
  displayed `翻译数据库` with the installed dictionary's current count `43672`.
  Its following direct action displayed `立即更新` and `检查最新标签翻译，并保存到本地。`
  without a navigation chevron. The update action was not invoked.
- This observes only the installed-dictionary wording and direct-action state.
  It does not accept dictionary-update behavior, status-read failure,
  uninstalled/updating/error states, persistence, or same-state visual parity.
  Raw local artifacts are retained under
  `.hvigor/outputs/tag-dictionary-copy-20260815T1625/` and are excluded from
  source control.

## Current Content-filter settings subtitle — bounded device observation — 2026-08-15

- The signed HAP built from `d8eb826` was installed in place with `-r` on only
  `192.168.50.237:12345` after a fresh lease, wake, and `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No data clear, uninstall, account action,
  query, preference value change, or content-filter rule action occurred.
- On the foreground-confirmed native `Settings → 高级` route, the existing
  `内容过滤` row retained its title and action affordance while its subtitle
  read `在本机隐藏命中的画廊和评论。` The independent rule page was not opened.
- This observes only the replacement wording in its existing row. It does not
  accept filtering behavior, rule editing, persistence, every Settings state,
  or visual parity. Raw local artifacts are retained under
  `.hvigor/outputs/content-filter-copy-20260815T0930/` and are excluded from
  source control.

## Current Browse/Search option-policy-footnote correction — bounded device observation — 2026-08-15

- The signed HAP built from `0e0840e` was installed in place with `-r` on only
  `192.168.50.237:12345` after a fresh lease, wake, and `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No data clear, uninstall, account action,
  preference value change, query submission, history mutation, or condition
  addition occurred.
- In foreground-confirmed native Browse options, the Language and Order groups
  remained present and no trailing public-GET / local-storage policy caption
  was visible. In foreground-confirmed native Search options, the existing
  condition controls, Language group, and after one non-selecting sheet scroll
  the Order group remained present; neither observed viewport contained the
  anonymous-search / typed-query policy caption.
- This observes only the two caption-removal states and control continuity. It
  does not accept option persistence, condition behavior, keyboard usability,
  every scroll position, or visual parity. Raw local artifacts are retained
  under `.hvigor/outputs/option-policy-footnotes-20260815T0900/` and are
  excluded from source control.

## Current Search range-control correction — bounded device observation — 2026-08-15

- The signed HAP from `882c381` was installed in place with `-r` on only
  `192.168.50.237:12345` after a fresh lease, wake, and `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No data clear, uninstall, account action,
  preference change, search submission, history write, or Add action occurred.
- In the foreground-confirmed native Search options sheet, empty page and
  upload ranges displayed `不限`; both corresponding Add rows were visibly
  unavailable. Entering an unsubmitted page lower bound of `1` made only the
  page Add row available. The app was force-stopped afterward, discarding that
  route-local draft without clearing data.
- This observes only the empty and one-positive-bound rendering states. It
  does not accept range ordering, condition submission, keyboard usability,
  accessibility announcement, or visual parity. Raw local artifacts are under
  `.hvigor/outputs/search-range-control-20260815T0708/` and are excluded from
  source control.

## Current Search recent-history geometry — bounded reference observation — 2026-08-15

- The signed HAP containing the scoped Search landing change was installed in
  place with `-r` on only `192.168.50.237:12345` after a fresh lease, wake,
  and `OverrideTimeout=86400000ms` gate. No data clear, uninstall, account
  action, content action, history mutation, or preference change occurred.
- In the keyboard-open native Search landing, the current NextN field and
  recent-history heading were observed at the same bounds as the current
  NextE Search landing on that device: field `[48,309][1272,429]`, heading
  `[48,531][217,580]`. This accepts the narrow top-anchor relationship only:
  no pixel offset was added; the complete safe-area/title/field token formula
  remains in place and the short-history Scroll child has a minimum, not fixed,
  height.
- The scoped source tree was rebuilt independently in a clean temporary
  worktree, then its signed HAP was installed in place and the same
  keyboard-open bounds were observed again. The first clean build needed one
  local package-resolution pass; the subsequent signed build succeeded.
- This does not accept long-history overflow/scrolling, chip re-search or
  deletion, translation refresh, empty/error landing states, or the complete
  history-chip visual surface. Those remain OPEN. Raw local artifacts are
  retained under `.hvigor/outputs/recent-search-history-rebuild-20260815T0510/`
  and are excluded from source control.

## Current Settings wording correction — bounded device observation — 2026-08-15

- The signed HAP built from `39fba26` was installed in place with `-r` on the
  selected `.237` device after the live target, lease, wake, and `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No data clear, uninstall, account action,
  content action, or preference value change occurred.
- On a foreground-confirmed native `Settings → 界面` route, the visible Browse
  rows read `列表视图` with `网格`, `显示标签` with the factual List/Waterfall
  scope, and `标签翻译`; the former opaque labels did not appear. The rows were
  fully within the current viewport without observed clipping.
- The current `阅读按钮样式` row displayed the reference-backed description
  `切换画廊详情页悬浮阅读按钮外观`; opening and dismissing its value menu without
  selection showed `实心主色` and `光感材质`. This is a wording and menu-presence
  observation only; it does not accept button rendering behavior.
- This does not accept the remaining Settings copy audit or any visual-parity
  claim. A current same-state, same-viewport NextE capture remains required
  for that boundary. Raw local artifacts are retained under
  `.hvigor/outputs/settings-copy-reference-20260815T1850/` and are excluded
  from source control.
- **Supplemental direct-reference observation:** the signed HAP built from
  `50cfac0` was installed in place with `-r` on the same selected device after
  a fresh live target, lease, wake, and power-state gate. No data clear,
  uninstall, account action, content action, or preference value change
  occurred. Native Reader Settings showed `连续纵向`, and its opened-and-
  dismissed direction menu showed `从左到右 / 从右到左 / 从上到下 / 连续纵向`.
  Native Interface Settings showed `封面背景模糊` with the source-backed
  description and the source-backed Japanese-title explanation; all observed
  rows were inside the current viewport. This is a bounded wording observation
  only, not a visual-parity or behavior acceptance. Raw local artifacts are
  retained under `.hvigor/outputs/settings-copy-reference-20260815T1915/` and
  are excluded from source control.
- **Download leaf observation:** the signed HAP built from `d366aac` was
  installed in place with `-r` on the same selected device after a fresh live
  target, lease, wake, and power-state gate. Native `Settings → 下载` displayed
  `重试次数` and its current value fully within the viewport. No download value,
  account state, content, or other preference changed. This accepts only the
  bounded rendered wording; it does not accept download behavior or visual
  parity. Raw local artifacts are retained under
  `.hvigor/outputs/settings-copy-reference-20260815T1930/` and are excluded
  from source control.

## Current native Account/Favorites S0 — accepted existing session — 2026-08-14

- Only `192.168.50.237:12345` was live-resolved, leased, and read back as
  `AWAKE` with `OverrideTimeout=86400000ms`. The current signed Debug HAP was
  installed in place with `-r`; no data clear, uninstall, credential entry,
  or account mutation occurred.
- A privacy-bounded cold-start S0 reader used current native markers only and
  deleted every temporary host/device layout before returning its fixed
  summary. Account reported: visible login Web absent, native section present,
  signed in, not signed out, no verification requirement, and no save failure.
  Favorites reported: native selected surface, no sign-in prompt/loading/error,
  and an authenticated collection state.
- This accepts the existing session for the current device. No S1/S2 login
  route, credential epoch, or login-cycle timing record is active. This does
  not itself accept the separate source-only verification-marker restore fix.
- The subsequent signed build containing that owner-only restore correction
  was also installed with `-r` and passed the same NextN-only cold-start S0
  summary. The exceptional durable-marker state was not induced; this is a
  healthy-session non-regression observation, not runtime acceptance of the
  marker branch.
- **Native Account anchor validation — 2026-08-14:** the signed HAP containing
  `77cd8b0` was installed in place with `-r`; no data clear, uninstall,
  credential entry, or account mutation occurred. One privacy-bounded native
  S0 reader then returned its fixed successful summary using the new native
  Account root marker: visible login Web absent, native section present,
  signed in, not signed out, no verification requirement, and no save failure;
  Favorites remained native with no sign-in prompt/loading/error and an
  authenticated state. This records the current S0 healthy-session observation
  only. No S1/S2 login route, credential epoch, or
  login-cycle timing record is active.
- **Favorites collection-state parser regression — 2026-08-14:** the
  host-side S0 reader containing `e837a4e` ran once against the same selected
  device with no data clear, uninstall, credential entry, or account mutation.
  It returned the same fixed healthy S0 booleans: native signed-in Account with
  no verification/save failure, and native authenticated Favorites with no
  sign-in prompt/loading/error. This is a normal collection-path non-regression
  only; inline/footer retry feedback was not induced, so that narrow branch
  remains source-validated rather than device-accepted.

## Current global LIST-height preference — bounded device result — 2026-08-14

- The signed Debug HAP was installed in place on only
  `192.168.50.237:12345` after the live target, lease, wake, and `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No data clear, uninstall, account action,
  download action, or content mutation occurred.
- Native Layout Settings placed `固定列表行高` after the conditional width leaf
  and before cover background. The original observed values were enabled fixed
  height and `封面网格`. In a loaded Popular collection temporarily switched to
  global LIST, fixed rows measured `612px`; disabling the switch produced
  `593px` fully-visible adaptive rows with wrapped tags and matching visible /
  original bounds, without the previously observed viewport-height overflow.
- A NextN-only cold start read back the disabled value. The original fixed
  height and cover-grid values were restored, and a second NextN-only cold
  start read both back. This accepts only the Settings/writeback/cold-start
  path. Current Popular fixed/adaptive geometry is observed, while the visible
  LIST surface remains OPEN pending a valid same-state, same-viewport NextE
  comparison; other global consumers, tags-disabled and failure/cover states
  remain unobserved. Raw local artifacts are retained under
  `.hvigor/outputs/global-list-height-20260814T.postfix.lXkEmm/` and excluded
  from source control.

## Current Reader presentation-lifecycle smoke — rejected close terminal — 2026-08-14

- The signed Debug HAP containing `e77a532` was installed in place on only
  `192.168.50.237:12345`; no app data clear, uninstall, account action,
  download action, or preference mutation occurred. The selected device was
  live-resolved, leased, woken, and read back as `AWAKE` with
  `OverrideTimeout=86400000ms` before the sequence.
- A cold native Gallery direct route reached foreground-confirmed NextN Detail,
  and its current visible `继续 P1` action entered foreground-confirmed native
  Reader with the restored black canvas layers. This observes only the basic
  post-install Reader entry path.
- One system Back input was then issued from that Reader. Its retained terminal
  layout had `com.ohos.sceneboard` rather than the expected foreground NextN
  Gallery Detail identity. This chain is rejected: it neither proves a Reader
  lifecycle failure nor accepts the lifecycle correction. Do not retry the
  close action by coordinate or treat the terminal system layout as app
  evidence.
- The source/diagnostic review and its one permitted Reader platform trace are
  recorded below. They establish temporal delivery evidence only, not a
  Reader-close callback or SceneBoard-causation result; the one Back allowance
  is consumed. The specific restore-before-onShown and late-callback races
  remain uninduced and OPEN. Raw local artifacts are retained under
  `.hvigor/outputs/reader-lifecycle-20260814T/` and are excluded from source
  control.

## Current Reader Back platform-trace control — bounded positive control — 2026-08-14

- The selected `.237` device's read-only `hitrace --list_categories` probe
  exposed `multimodalinput`, `window`, and `ability`. A single bounded control
  then began those categories on a foreground-confirmed native NextN Gallery
  Detail with no Reader overlay, injected exactly one literal system Back, and
  finished/received its trace through the manifest-owned cleanup path. The
  pre- and post-control layouts both retained native
  `com.erosteam.nextn:EntryAbility` at the same `1320×2120` root viewport.
- The retained local trace positively contains the injected key event, its
  system dispatch, NextN consumption, and subsequent Window/Ability activity.
  This establishes only that the selected device and bounded trace path can
  observe an ordinary Back delivery; it does not establish Reader close
  semantics or explain the rejected SceneBoard terminal.
- No Reader action, canvas input, account, preference, content, data clear,
  or uninstall occurred in the control. The raw local manifest, layouts, and
  trace are retained under
  `.hvigor/outputs/reader-back-platform-control-20260814T0800.PJc2b1/` and
  are excluded from source control.
- This control authorizes at most one same-category Reader trace after a fresh
  native Reader precondition. Any missing/ambiguous trace record remains
  inconclusive and permits no second Reader Back injection.

## Current Reader Back platform trace — bounded delivery observation — 2026-08-14

- After a fresh foreground-confirmed native NextN Reader precondition (with
  `reader-overlay-navigation` present), the one permitted manifest-owned trace
  injected exactly one literal system Back and completed its trace cleanup and
  local receive path. No canvas, menu, account, preference, content, data
  clear, or uninstall action occurred.
- Within that one-action trace, the retained markers are temporally ordered as
  synthesized input, system dispatch, and an abbreviated NextN process-tag
  `eventConsume`, followed by Window/Ability activity. The synthesis and
  dispatch records do not expose a stable event identity, so this establishes
  temporal delivery evidence only, not an event-identity-correlated callback
  trace.
- The no-input postflight layout retained only `com.ohos.sceneboard` windows;
  it did not retain a foreground NextN root or Reader overlay. This rules out
  the simple explanation that the injected Back never reached NextN, but it
  does not prove which Reader/HDS close callback ran or why SceneBoard became
  foreground. No source correction is accepted from this observation.
- The one Reader trace allowance is consumed. The raw local manifest, trace,
  and pre/post layouts remain under
  `.hvigor/outputs/reader-back-platform-trace-20260814T0820.yCoWqs/` and are
  excluded from source control; do not inject a second Reader Back from this
  boundary.

## Current Reader background preference — bounded device result — 2026-08-14

- The signed Debug HAP containing `14f4a74` was installed in place on only
  `192.168.50.237:12345`; no app data clear, uninstall, account action, or
  download action occurred. The selected device was live-resolved, leased,
  woken, and read back as `AWAKE` with `OverrideTimeout=86400000ms` before the
  sequence.
- The native `1320×2120` root Reader Settings page displayed `阅读背景` as the
  first row of `显示与屏幕`, before the existing image-scaling, page-number,
  fullscreen, and keep-screen-on leaves. Its initial value was `黑色`. The
  menu exposed exactly `黑色`, `灰色`, `白色`, and `自动`; selecting `白色`
  updated the rendered Settings value.
- A NextN-only force-stop/cold start then returned to the root Reader Settings
  page with `白色` still selected. The existing native Gallery → `继续 P1`
  route entered foreground-confirmed NextN Reader without using the rejected
  canvas menu zone; its current layout reported the Reader canvas/root layers
  as `#FFFFFFFF`. A later reversible `灰色` selection reached the same Reader
  route with its canvas/root layers reported as `#FF303030`. These are current
  NextN canvas observations, not reference-parity claims.
- The temporary value was restored to the observed original `黑色`. A second
  NextN-only force-stop/cold start read back `黑色` in the native root Reader
  Settings tree, so the device was left with its original background choice.
- This accepts only the observed root Settings placement/menu/writeback,
  cold-start persistence, white canvas state, and restoration. The Reader-owned
  Settings sheet was not exercised because its only current source route first
  requires the rejected Reader canvas menu-zone input. Automatic behavior,
  vertical/double-page/loading/failure contrast, non-fullscreen hidden-chrome
  status-bar polarity, and same-state/same-viewport NextE visual comparison
  remain OPEN rather than inferred. Raw local artifacts are retained under
  `.hvigor/outputs/reader-background-20260814T/` and are excluded from source
  control.
- **Additional bounded observation — 2026-08-14:** the current signed HAP was
  installed in place on the same selected device. Starting from the observed
  `黑色` background and enabled Reader-fullscreen values, only `自动` and
  fullscreen-off were selected in the root Reader Settings page. A subsequent
  NextN-only force-stop/start without a data clear or uninstall in this run
  returned to Settings with both temporary values rendered. The existing direct Gallery → `继续 P1`
  route then reached a foreground-confirmed native Reader overlay without any
  Reader canvas, menu, or Back input. Its initial hidden-chrome capture kept a
  visible system status bar whose recorded icon styling was dark.
- The original fullscreen-on and black-background values were restored, then a
  final NextN-only force-stop/start without a data clear or uninstall read both
  originals back.
  Raw local evidence is retained under
  `.hvigor/outputs/reader-background-auto-statusbar-20260814T0210/` and is
  excluded from source control. That directory intentionally retains layouts
  and one terminal screenshot but no protocol-runner command ledger, so this
  is a bounded current-run observation rather than an independently replayable
  cold-start acceptance. It does not prove the other Automatic-theme branch,
  chrome-visible/fullscreen-on status-bar behavior, loading/failure or
  vertical/double-page contrast, Reader-owned Settings-sheet behavior, or
  same-state NextE visual parity.

## Current Reader double-page-layout preference — bounded device result — 2026-08-14

- The signed Debug HAP from `acf2fd6` was installed in place on only
  `192.168.50.237:12345`; no app data clear, uninstall, account action,
  download action, or content mutation occurred. The selected device was
  live-resolved, leased, woken, and read back as `AWAKE` with
  `OverrideTimeout=86400000ms` before the sequence.
- The current native `1320×2120` Reader Settings page showed `双页布局`
  immediately after `双页模式` and before `翻页动画` in `翻页与布局`. In its
  original `连续垂直滚动` mode the row was visibly unavailable and retained
  its default `拼合` value. No attempt was made to operate that unavailable
  row.
- The existing Reader layout menu was temporarily changed to `从左至右翻页`.
  In that eligible mode, the `双页布局` menu exposed exactly `拼合` and `均分`;
  selecting `均分` updated the rendered Settings value. A NextN-only
  force-stop/cold start then read back `从左至右翻页` and `均分` from the native
  Settings tree. The temporary values were restored to the observed originals:
  `拼合` and `连续垂直滚动`.
- This accepts only the observed row placement/availability, value menu,
  writeback, cold-start restoration, and cleanup for this device path. The
  device remained a portrait `1320×2120` viewport, so no wide two-page Reader
  canvas, joined/split rendering geometry, RTL order, terminal singleton,
  zoom-reset behavior, or same-state/same-viewport NextE comparison was
  observed. Those remain OPEN rather than inferred from the setting result.
  Raw local artifacts are retained under
  `.hvigor/outputs/reader-double-page-layout-20260814T/` and are excluded from
  source control.

## Current Reader page-turn-animation preference — bounded device result — 2026-08-14

- The signed Debug HAP containing the new local `pageTurnAnimation` preference
  was installed in place on only `192.168.50.237:12345`; no data clear,
  uninstall, account action, download action, or content mutation occurred.
  The selected device was live-resolved, leased, woken, and read back as
  `AWAKE` with `OverrideTimeout=86400000ms` before the sequence.
- The current native `1320×2120` Reader Settings page placed `翻页动画`
  immediately after `双页模式` in `翻页与布局`. Its new Toggle was initially
  enabled. One reversible toggle changed it to disabled; a NextN-only
  force-stop/cold start then restored the disabled value in the native Reader
  Settings tree. The Toggle was restored to its original enabled value before
  the sequence ended.
- The original Reader layout (`连续垂直滚动`) was not changed. The temporary
  `音量键翻页` setup considered for a safe paged transition was restored to its
  observed original disabled value before leaving the device. The rejected
  Reader center-menu zone was never used.
- This accepts only the observed Settings row, initial value, writeback,
  cold-start restoration, and cleanup. It does **not** accept animated versus
  non-animated motion: the available device tooling records single PNG frames
  only, with no previously verified continuous-frame or recording path. The
  adjacent paged-turn behavior, Slider/thumbnail jump behavior, vertical/RTL/
  double-page behavior, and same-state NextE visual comparison remain open.
  Raw local artifacts are retained under
  `.hvigor/outputs/reader-page-turn-animation-20260814T/` and are excluded
  from source control.

### Adjacent volume-key component diagnostic — bounded device observation — 2026-08-14

- The signed Debug HAP containing a temporary, non-visible Reader diagnostic
  was installed in place on only `192.168.50.237:12345`. The live target was
  leased, woken, and read back as `AWAKE` with
  `OverrideTimeout=86400000ms`; no data clear, uninstall, account action, or
  download action occurred. The diagnostic tag contained fixed event names
  only, and its manifest filtered that tag rather than collecting general
  device logs.
- Starting from the current original Reader values—continuous vertical mode,
  enabled page-turn animation, and disabled volume-key turning—the temporary
  setup used paged LTR plus volume-key turning. A foreground-confirmed native
  Reader with a valid adjacent next page received exactly one manifest-owned
  volume-down key event. Its filtered log ordered
  `volume_turn_request_animated`, `volume_turn_animation_start`,
  `volume_turn_change`, and `volume_turn_animation_end`; its Reader page
  counter advanced once.
- The animation preference was then disabled, the app was force-stopped and
  the same direct Gallery route resumed the next page, and exactly one
  manifest-owned volume-up event returned to the initial page. Its filtered
  log contained `volume_turn_request_instant` followed by
  `volume_turn_change`, with no diagnostic animation-lifecycle event in the
  bounded capture. These were normal Reader transitions, so the ordinary
  local page-progress owner ran; the final page was restored rather than this
  being a mutation-free probe.
- The original continuous-vertical mode, enabled animation setting, and
  disabled volume-key setting were restored and re-read after a final
  NextN-only force-stop/cold start. The temporary source hook was removed, a
  clean signed HAP was rebuilt and reinstalled in place, and no further Reader
  input was sent. This accepts only the real-device component-event distinction
  for the adjacent volume-key path. It does not establish rendered motion
  quality, direct Swiper-swipe, tap/auto-read behavior, Slider or thumbnail
  jumps, Reader-progress persistence after this run, vertical/RTL/double-page
  paths, Reader-sheet behavior, or same-state NextE visual parity. Raw local
  evidence is retained under
  `.hvigor/outputs/reader-page-turn-diagnostic-20260814T.Hbtya0/` and is
  excluded from source control.

## Current Reader display-preference validation — route exception — 2026-08-14

- The signed Debug HAP containing `0692116` (hidden page number) and
  `a29b613` (image scaling quality) was installed in place on only
  `192.168.50.237:12345`; no data clear, uninstall, account action, or
  content mutation occurred. The selected device passed the live lease, awake,
  and 24-hour timeout gate before the route.
- The established direct Gallery Reader route reached native NextN at the
  current `1320×2120` viewport. With chrome hidden, its non-hit-test status
  layer displayed the canonical `1 / 47` range alongside the existing
  enhancement indicator. This is one current NextN on-state observation only;
  it is not a visual-parity claim and does not yet prove preference restoration.
- One current-layout-derived center menu-zone tap then changed the foreground
  to the system desktop rather than exposing Reader chrome. The raw local
  before/after evidence is retained under
  `.hvigor/outputs/reader-display-preferences-20260814T0910/show-chrome/` and
  is excluded from source control. This records another Reader menu-zone
  foreground-routing exception, so that branch is rejected and must not be
  retried by coordinate or used as evidence about either preference.
- The root Reader Settings page then exposed all three scaling values; the
  original `优化（Mipmap）` value was changed once to `高（双三次）` and restored.
  The original page-number Toggle was true, changed once to false, and the
  established direct Gallery → Continue route then entered foreground-confirmed
  native NextN Reader with no `1 / 47` status Text in its hidden-chrome tree.
  No image, page, download, account, content, or data-clear action occurred.
- A data-preserving NextN-only force-stop/cold start then read back page number
  as false and image scaling as the restored `优化（Mipmap）` value. Page number
  was restored to its original true value, and one final direct Gallery →
  Continue route again showed `1 / 47` in the foreground-confirmed hidden
  Reader. The temporary values therefore left no known preference change.
- This accepts only the observed single-page projection, writeback, cold-start
  restoration, and on/off overlay transition. It does not prove image-sampling
  quality, a vertical or double-page render path, gesture/zoom continuity, or
  NextE pixel parity; the required same-state, same-viewport NextE comparison
  remains open. Do not use the Reader menu zone for those follow-up checks.

## Current delivery observation — Gallery Detail smart-grip evidence closure — 2026-08-13

- The signed Debug build for the smart-grip/alignment lane was installed in
  place on only `192.168.50.237:12345`; no app data clear or uninstall
  occurred. The selected device was woken and read back as `AWAKE` with
  `OverrideTimeout=86400000ms` before the sequence.
- The current native Layout row still reported `智感握姿` after a
  data-preserving NextN-only force-stop and cold start. That is the retained
  preference-restoration evidence for this lane.
- Fixed-left and fixed-right moved the current default-hit Read action to the
  selected edge while preserving the full-width transparent rail. In follow
  operation, a deliberate vertical scroll on the metadata List moved the
  action left; a later right-side vertical scroll moved it right.
- The retained NextE smart-grip capture remains a different viewport and is
  rejected as a same-state visual pair for this run. The real
  `holdingHandChanged` event was not induced or observed here, so that
  sensor branch stays open and must not be claimed as completed.
- Raw local artifacts are retained under
  `.hvigor/outputs/smart-grip-alignment-20260813T0830/` and are excluded
  from source control.

## Current delivery observation — Reader Settings grouped rows — 2026-08-13

- The installed signed Debug build was reviewed in place on only
  `192.168.50.237:12345`, following a live target, lease, wake, and
  `AWAKE` / `OverrideTimeout=86400000ms` gate. No app data clear, uninstall,
  account action, or Reader-preference mutation occurred.
- The native `1320×2120` Reader Settings page displayed the six separate
  surfaces `翻页与布局`, `点击区域`, `显示与屏幕`, `图像增强`, `阅读控制`, and
  `加载` across the initial viewport and one ordinary vertical scroll. Normal
  rows had no leading icon; selectors used down-arrow affordances, switches
  had no navigation arrow, and the image-enhancement rows retained all
  internal dividers.
- The retained NextE `1320×2120` artifact that was initially proposed for
  comparison is a Download page rather than Reader Settings, so it is rejected
  as a same-state pair. This is current NextN whole-page evidence, not a
  pixel-parity claim. Raw local artifacts are retained under
  `.hvigor/outputs/reader-settings-current-20260813T0912/` and excluded from
  source control.

## Current delivery observation — Gallery Detail Japanese-title preference scope — 2026-08-13

- Commit `6965ae9` was built as the signed Debug HAP and installed in place on
  only `192.168.50.237:12345`; no app data clear, uninstall, account action,
  or login action occurred. The native `1320×2120` Layout row displayed the
  corrected Detail-only setting title and hint.
- The original setting value was `off`. It was enabled only to verify one
  current native Detail route with both source title forms: the Japanese title
  was primary and the English title secondary. The setting was then restored
  and re-read as `off`.
- This is a bounded title-display verification, not a collection-card or
  History-title migration. Raw local artifacts are retained under
  `.hvigor/outputs/japanese-title-scope-20260813T0938/` and are excluded from
  source control.

## Current delivery observation — Cache and History icon leaves — 2026-08-13

- The signed Debug build containing only the Reader-cache icon and History-tab
  icon leaves was installed in place on `192.168.50.237:12345`; no data clear,
  uninstall, account action, cache-clear action, or content mutation occurred.
- The native `1320×2120` Cache page displayed the Reader-page-cache row with a
  document icon. After a NextN-only data-preserving cold start, the root tab
  strip displayed the local-History clock at the same filled visual weight as
  its sibling tabs.
- Raw local artifacts are retained under
  `.hvigor/outputs/icon-leaves-20260813T0958/` and are excluded from source
  control.

## Current delivery observation — Gallery Detail smart-grip Read-action alignment — 2026-08-13

- Commit `bee5a59` was built as the signed Debug HAP and installed in place on
  only `192.168.50.237:12345`; no data clear, uninstall, account action, or
  login action occurred. The device was live-resolved, leased, woken, and read
  back as `AWAKE` with `OverrideTimeout=86400000ms` before the sequence.
- The original `智感握姿` setting was observed before testing. The native Layout
  menu exposed `智感握姿`, `跟随操作`, `固定左侧`, and `固定右侧`. Fixed-left and
  fixed-right each placed the existing default-hit floating Read action on the
  selected edge while preserving its full-width transparent overlay rail.
- In `跟随操作`, a deliberate vertical scroll on the native Detail metadata List
  starting at the left side moved the action left; a later right-side vertical
  scroll moved it right. The action was not used as the touch observer.
- The original `智感握姿` selection was restored. NextN alone was force-stopped,
  then its existing Gallery Detail route was cold-started; a fresh native
  Layout observation still displayed `智感握姿`. All current captures are
  foreground-confirmed NextN `EntryAbility/pages/Index` at `1320×2120`.
- This does not assert real holding-hand sensing: no `holdingHandChanged`
  event was induced or observed. The only retained NextE smart-grip capture is
  `1080×2444`, so it is not a valid visual comparison to the `1320×2120`
  NextN result. Raw local artifacts are retained under
  `.hvigor/outputs/smart-grip-alignment-20260813T0830/` and are excluded from
  source control.

## Current delivery result — Gallery Detail public DTO cache — 2026-08-13

- Commits `c4693d2`, `e209278`, and `a588c52` were built as the signed Debug
  HAP and installed in place on the selected `192.168.50.237:12345` device;
  no app data clear or uninstall occurred. The device was live-resolved,
  leased, woken, and read back as `AWAKE` with
  `OverrideTimeout=86400000ms` before the acceptance sequence.
- NextN alone was force-stopped, then the existing public Gallery Detail route
  was cold-started. The bounded `NextNDetailCache` app log recorded
  `event=hit=persisted`, followed by `event=stored`; those fixed events carry
  no gallery identity, title, URL, payload, account, or user-content field.
  The terminal layout was native `com.erosteam.nextn:EntryAbility`,
  `pages/Index`, one Gallery `NavDestination`, and its loaded Detail List at
  the `1320×2120` portrait root viewport.
- From that current native Detail, the existing HDS overflow action was opened
  by its current semantic resource ID, then the current semantic `重新加载`
  menu item was invoked. The bounded cache log recorded
  `event=bypass=explicit-refresh`, then `event=stored`; the terminal layout
  remained the same native loaded Detail owner.
- This accepts only the public primary-DTO cache's observed cold-start
  persisted-hit and explicit-refresh-bypass paths. Related galleries,
  comments, favorite/account state, tag display labels, read progress, and
  Settings cache presentation remain on their independent owners and are not
  asserted as cached. Raw local artifacts are retained under
  `.hvigor/outputs/gallery-detail-cache-20260813T0645/` and are excluded from
  source control.

## EVIDENCE-ONLY — Reader Settings / Advanced translation parent ownership — 2026-08-13

- Commit `e88bca5` was built as the signed Debug HAP and installed in place on
  the selected `192.168.50.237:12345` device with `install -r`; no app data
  clear or uninstall occurred.
- The device was live-resolved, leased, woken, and read back as `AWAKE` with
  `OverrideTimeout=86400000ms` before installation. This is installation and
  display-state evidence only, not a Reader Settings visual result.
- The original Reader capture under
  `.hvigor/outputs/reader-settings-groups-20260813T0620/` exposed a misplaced
  comic-translation entry. Commit `3b6f806` moved that capability to the
  Advanced translation group, was built as a signed Debug HAP, and was installed
  in place with no data clear or uninstall.
- The current native `1320×2120` Advanced screen is retained under
  `.hvigor/outputs/advanced-translation-capabilities-20260813T0940/`. It shows
  one continuous translation-capabilities card containing comment translation,
  comic translation, local tag translation/update, and translation source. A
  single Reader-tail observation in the same run shows no translation entry.
  The current NextN root and retained NextE `EH` root are both foreground-verified
  at `[0,117][1320,2120]`; the reference shows the corresponding continuous
  comment/comic/tag/source card. This is bounded evidence for parent ownership
  and card continuity only; it is not a whole-Settings acceptance.

## Historical transport observation — 2026-08-12

- At the time of this historical observation, the user-selected TCP target
  `192.168.50.237:12345` was absent from `hdc list targets -v`. No alternate
  TCP or USB target was selected, leased, started, inspected, or modified.
- This is not a current transport state and must not be used to pause a later
  delivery lane. The current state is established only by a new live target
  resolution for the same exact target.

## Current transport observation — 2026-08-12 21:07 +0800

- `192.168.50.237:12345` was present as TCP `Connected` in the live target
  list. The existing repository lease `20260812-123907-a380091f` was renewed
  for that exact target; no alternate TCP or USB device was selected.
- The device was woken and read back as `AWAKE` with
  `OverrideTimeout=86400000ms`. The latest signed Debug HAP was installed in
  place, without clearing data, and the direct `471768` Gallery route was
  observed in native NextN. This record supersedes the historical absence only
  for current transport; it does not assert any login, persistence, or visual
  acceptance outcome.

## Conditional preemption — account-persistence P0

On the selected TCP device `192.168.50.237:12345`, a fresh native Account or
Favorites observation that proves the session absent or unusable immediately
preempts every other lane. Never substitute the USB target or clear data. P0
cannot be closed from source review, a build, installation, a no-record cold
start, or a new login that masks an unresolved failure.

Completion requires both real-device evidence that a completed login survives
force-stop/cold start with native account authenticated and an authenticated
Favorites read, and a complete in-repository postmortem of the verified cause,
the prior multi-hour failure to solve it, incorrect assumptions/claims, missing
evidence, and durable prevention rules. Original login/device authorization
remains continuous; do not ask for it again.

## Current P0 observation — 2026-08-12 22:40 +0800

- On the selected TCP device only, the current native Favorites root showed
  its native sign-in-required surface. No visible Web, credential input,
  Account action, data clear, uninstall, or content mutation occurred.
- This is fresh current evidence of an unusable session and immediately
  preempts the delivery lane.
- The paired native Account destination showed its native verification-required
  state. No visible Web, credential input, re-verification action, data clear,
  uninstall, or content mutation occurred during this paired observation.
- The next physical action is the current Account page's explicit native
  re-verification action. The pair establishes the state boundary only; it
  does not establish a persistence or transport cause.
- That one action returned the native Account surface to signed-in state; no
  visible Web, credential field write, submit, data clear, uninstall, or
  content mutation occurred. This is a recovery observation only. The next
  required action is a data-preserving force-stop/cold start followed by
  paired native Account and Favorites summaries.
- The required data-preserving force-stop/cold start then completed on the
  same selected device. Cold-start Account remained natively signed in, and
  cold-start Favorites settled to native collection content with no sign-in
  prompt, loading, error, or Web surface. No credential field, submit,
  preference, content mutation, uninstall, or data clear occurred.
- This is an observed recovery-and-cold-start path, not a root-cause claim:
  the preceding fresh transition to verification-required remains unexplained,
  so account-persistence P0 stays OPEN for causal diagnosis and recurrence
  prevention.

## Current P0 cold-start regression — 2026-08-12 23:09-23:12 +0800

- The selected TCP device alone received the current signed Debug HAP with
  `install -r`; no data clear, uninstall, credential entry, visible login
  action, or content mutation occurred.
- A data-preserving force-stop/cold start left native Account in its signed-in
  state, but Favorites settled to its native transport-error state rather than
  an authenticated collection. No visible Web surface was present.
- The observed fixed error was `The ArkWeb account transport could not load.`
  This is a failed P0 verification, not a session-acceptance result.
- Source mapping established that the retained ArkWeb host treated every
  `onErrorReceive` callback as a main-document bootstrap failure. ArkWeb
  reports that callback for both main and subresources; the host now rejects
  only a main-frame error. The updated HAP is built but has not yet been
  installed or device-verified.

## Current P0 cold-start recovery — 2026-08-12 23:15-23:16 +0800

- The committed main-frame-error correction was installed in place on the
  selected TCP device only, then NextN alone was force-stopped and cold-started
  without clearing data or uninstalling.
- Cold-start Favorites settled to authenticated native gallery collection
  content. It showed no sign-in prompt, visible Web surface, loading state, or
  ArkWeb transport-error state.
- The paired native Account destination remained signed in, with no visible
  Web surface, verification-required state, or native error.
- This accepts the record-present cold-start Account plus authenticated
  Favorites path for the observed ArkWeb resource-error regression. It does
  not attribute earlier record-absent or terminal-401 events to this cause.
- The next signed build additionally records only the finite diagnostic
  `account_arkweb_transport_main_frame_load_failed` if the retained host
  receives a future classified main-frame load failure. It does not log or
  retain URL, error code, response, cookie, or account data. That diagnostic
  awaits a real failure event; it is not asserted from this successful run.

## Current P0 diagnostic-build regression — 2026-08-12 23:31-23:37 +0800

- The signed Debug build containing the finite main-frame-load diagnostic was
  installed in place on the selected TCP device. NextN was then force-stopped
  and cold-started without data clear, uninstall, credential entry, visible
  login action, preference change, or content mutation.
- Cold-start Favorites first showed its native loading state and then settled
  to native authenticated collection content. No sign-in-required surface,
  visible Web surface, or ArkWeb transport-error surface was observed.
- The paired native Account destination showed the signed-in state and its
  sign-out action, with no verification-required state, visible Web surface,
  or transport-error surface.
- An earlier broad text classifier matched the Chinese substring in the
  signed-in screen's sign-out action. That classifier result was discarded;
  it is not evidence of a login prompt or a mixed account state.
- The new main-frame diagnostic did not fire in this successful path. It
  remains a future-failure discriminator only. This observation does not
  establish the historical origin of any earlier record-absent or session-loss
  event, so P0 remains OPEN for any new current failure.

## Current P0 device result — proof and postmortem recorded

- On the selected TCP device, the visible login form was filled exactly once
  through semantic fields, the CF state was observed as successful, and the
  current semantic Login action was submitted exactly once. No credential was
  retained in this queue.
- Native Account then showed signed-in state with no visible login WebView.
- NextN was force-stopped and cold-started without clearing data,
  uninstalling, or reinstalling. After that restart, Favorites showed native
  authenticated gallery content with no sign-in prompt or WebView.
- The cold-start native Account destination separately showed signed-in state.
- Current-run screenshots are retained locally outside Git; they are never
  automatically deleted or committed. The repository postmortem is recorded
  at `docs/postmortems/2026-08-10-account-persistence-p0.md`. This queue
  remains OPEN until the user explicitly requests closure.

## Current P0 state — fresh Favorites failure observed

- After the latest signed Debug HAP was installed with `install -r` and NextN
  was launched on the selected TCP device, native Favorites displayed its
  session-recheck error state. This is current evidence that the account is
  unusable; it supersedes neither the historic successful proof nor the need
  for a new causal diagnosis.
- No app data was cleared, no uninstall occurred, and no credential field or
  visible login control was touched in this observation. The bounded local
  screenshot is retained outside source control.
- The paired native Account observation still showed a signed-in Account row.
  Therefore the current failure is an inconsistent session state: native
  Account is signed in while Favorites cannot complete its authenticated read.
- One normal Favorites retry returned to the same native session-recheck error
  state. This rules out a single transient render/load observation but does not
  establish a network or persistence cause.
- The recovery-order build was then installed and cold-started without data
  clearing. Favorites moved to native sign-in-required state and Account moved
  to its native re-verification state. This is a coherent invalid-session
  result, not a persistence acceptance proof.
- An explicit native re-verification then re-promoted the existing first-party
  browser identity without any credential field write. After one settlement
  retry, Favorites completed an authenticated native read.
- Final S6 then passed on the same device: force-stop/cold-start without data
  clearing, native Account signed in, and Favorites again completed an
  authenticated native read. The updated P0 postmortem is at
  `docs/postmortems/2026-08-10-account-persistence-p0.md`.
- P0 is accepted for this observed path. A future fresh native Account or
  Favorites failure immediately preempts delivery again.

## Current P0 device result — fresh cycle re-accepted

- 2026-08-10 19:24-19:33 +0800: a fresh native Favorites observation on the
  selected TCP device showed the sign-in-required state, and the paired native
  Account destination showed verification-required. This fresh evidence
  immediately preempted the delivery lane.
- No app data was cleared and no uninstall occurred. No credential field or
  visible login control was written; the recovery used the explicit native
  re-verification action, which re-promoted the existing first-party browser
  identity without a credential epoch.
- After one normal Favorites settlement retry, Favorites completed an
  authenticated native read (native Grid with structural items, no Web,
  loading, error, or sign-in surface).
- The same session then survived a force-stop/cold start without clearing
  data. After the restart, native Account was signed in and Favorites again
  completed an authenticated native read with no Web or sign-in surface.
- The repository postmortem remains at
  `docs/postmortems/2026-08-10-account-persistence-p0.md`. P0 is accepted for
  this observed path only; the queue remains OPEN until the user explicitly
  requests closure, and any future fresh failure preempts delivery again.

## Current delivery observation — Appearance custom theme color

- 2026-08-12: the signed Debug HAP was installed with `install -r` on the selected TCP device only after the device was awake with its 24-hour timeout override. Native NextN foregrounded Browse, then the established Settings → Appearance route reached the existing theme-color menu and its new `自定义` item.
- An initial menu-coordinate error temporarily selected the existing `青草绿` preset rather than Custom. It was immediately restored to the original `跟随系统` selection before the Custom route was retried from a fresh current menu layout; no account, content, download, or data-clear action occurred.
- The native custom picker rendered its Grid/Sliders switch, color grid, Hex field, favorites, preview swatch, close action, and confirm action at `1320×2120`. One unconfirmed grid selection changed the live draft; closing restored the original `跟随系统` theme. One separately confirmed custom selection survived a force-stop/cold start without data clearing; the original `跟随系统` theme was then restored and re-observed before leaving the route.
- The initial NextE capture was rejected because it began in an unrelated configured service form. A clean NextE restart then reached native Settings → Interface → Theme Color → Custom at the same `1320×2120` portrait viewport. Its existing red theme value was left unchanged. The valid pair matches the modal hierarchy and geometry: HDS close/title/confirm strip, preview swatch, Grid/Sliders selector, color grid, Hex field, and favorites grid. The different swatch/Hex values are each app's pre-existing selection and are not a visual mismatch. Raw captures remain locally at `.hvigor/outputs/theme-color-custom-20260812T1645/` and are excluded from Git.

## Current delivery observation — Gallery Comments full-page hierarchy

- 2026-08-12: the selected target `192.168.50.237:12345` was proactively
  reconnected after its earlier absent transport observation, then was leased,
  woken, and read back as `AWAKE` with `OverrideTimeout=86400000ms`. No other
  TCP or USB target was selected.
- The signed Debug HAP was installed in place with `install -r`, without data
  clearing. The established `nextn_gallery_id=471768` +
  `nextn_gallery_destination=comments` route foregrounded native
  `com.erosteam.nextn` at `1320×2120`; no credential, Account, Favorites,
  content-filter, preference, or comment-posting action occurred.
- The loaded route now shows a page-level comments-count heading, separate
  rounded author/body/date cards, and a rounded floating composer. One
  current-layout-derived upward list swipe reached the terminal visible
  comment state; the final card remained above the composer and its reserve.
  The HDS remained a floating overlay and was deliberately not converted into
  a fixed content inset. Local raw evidence is retained at
  `.hvigor/outputs/gallery-comments-471768-20260812T1750/` and is excluded
  from Git. This is a device hierarchy/tail observation only; the retained
  NextE reference has different loaded content and action availability, so
  content-level visual parity remains evidence-only.
- Correction result, 2026-08-12: after commit `dd842d5` was installed in
  place without clearing data, the same direct route foregrounded native
  `com.erosteam.nextn` at `1320×2120`. The HDS now supplies the sole visible
  `评论` heading; the former duplicate page-level `评论 (11)` heading is absent.
  Rounded cards and the composer overlay remain present. This is only the
  duplicate-heading correction result; the Comments page remains OPEN for its
  separate card/type/spacing review. The retained local evidence is
  `.hvigor/outputs/gallery-comments-471768-20260812T2039/`.
- One later data-preserving force-stop and identical direct Want intentionally
  omitted a Detail comment snapshot. Its first captured native state was
  already loaded, so it did not reproduce a loading-placement defect. This is
  one non-reproduction, not acceptance of the asynchronous no-snapshot path;
  the raw local evidence is
  `.hvigor/outputs/gallery-comments-initial-load-20260812T2041/`. Do not
  repeat this unchanged route without a new source change or current feedback.

## Current delivery observation — Reader overlay root-title isolation

- 2026-08-12: after the selected `.237` target was leased, awake with the
  24-hour override, and given an in-place signed Debug installation, the
  established direct `471768` Detail route and one fresh-layout-derived Read
  activation reached native `com.erosteam.nextn` Reader at `1320×2120`.
  Current layout evidence retained the private `reader-overlay-navigation`
  while omitting the underlying Gallery `TitleBar`, `HdsTitleBar`, and
  `hdsNavigationMoreButton`; no account, Favorites, credential, preference,
  content, or data-clear action occurred.
- The one established Back event used to test return instead foregrounded
  `com.huawei.hmsapp.books`, not retained NextN Detail. This rejects the
  title-restoration portion of the validation. The local layout artifacts are
  retained under `.hvigor/outputs/reader-overlay-root-title-20260812T2204/`;
  do not repeat that Back action before its Reader return-dispatch owner is
  source-mapped.
- A subsequent built attempt moved the HDS destination wrapper from Index into
  Reader, matching the NextE ownership shape. It again reached native NextN
  Reader but the one established Back event foregrounded the same system Books
  application. That hypothesis is rejected and the source was restored before
  further device work; no account, Favorites, credential, preference, content,
  or data-clear action occurred. Do not use another Back retry as an acceptance
  substitute. The next permitted Reader return action requires an independent
  event-delivery observation.
- The rejected ownership migration was then removed in commit `e19b3eb`. Its
  already-built signed Debug HAP was installed in place with `-r` after a new
  Connected-resolution, lease renewal, and `AWAKE` /
  `OverrideTimeout=86400000ms` readback on the same `.237` target. No Reader
  route, Back input, account, Favorites, preference, content, or data-clear
  action was performed during that restoration. This is installation evidence
  only; Reader return remains unproven and OPEN.
- A separate current device path read the existing Reader tap-zone values
  through native Settings without changing them: `left / menu / right` and
  `no inversion`. A fresh direct `471768` route then reached native NextN
  Reader. Its one center MENU-zone action again produced a terminal layout
  rooted at `com.huawei.hmsapp.books:MainAbility`, rather than NextN. The
  raw local layout is retained under
  `.hvigor/outputs/reader-more-owner-20260812T2220/`. This rejects the input
  chain and does not identify a NextN receiver; no further Reader canvas,
  More, Back, account, preference, content, or data-clear action was taken.

## Latest device observation — private-cache settings

- 2026-08-11: a signed Debug HAP was installed with `install -r` on the
  selected TCP device only. No application data was cleared and no account,
  Favorites, download, history, or preference action was performed.
- Current native NextN Cache and NextE Storage were captured at the same
  `1320×2120` portrait viewport. Both use an HDS destination, a caption-level
  cache-usage total, and a grouped cache-card with category count/size rows,
  a right-side clear leaf, and disabled zero-entry rows. NextN intentionally
  omits NextE-only sync, backup, and image-owner surfaces because it has no
  corresponding owners.
- The final NextN recapture showed the concrete Reader-page, comment-
  translation, comic-translation, and tag-translation cache owners plus the
  destructive aggregate clear row. No clear action was invoked; the existing
  local dictionary and Reader pages remain intact. Raw local comparison
  artifacts are retained outside source control.

## Current delivery observation — collection-card tag display

- 2026-08-11: the signed Debug build containing the opt-in tag leaf was
  installed with `install -r` on the selected TCP device only. The existing
  Layout setting initially showed the tag-display control disabled.
- With that temporary control enabled, already loaded native Gallery cards
  rendered resolved tag names in the regular waterfall, compact waterfall,
  and list presentations. No credential field, account action, Favorites
  read, content mutation, or app-data clear occurred.
- The temporary state was restored before leaving the lane: the Layout
  control read disabled, the presentation control read Cover grid, and the
  terminal Gallery surface returned to native Cover grid. Local raw captures
  remain outside source control and are not named here.
- This is device rendering and restoration evidence only. A same-gallery,
  same-viewport ErosN comparison remains outstanding, so it is not a
  visual-reference parity acceptance.
- 2026-08-11 follow-up: the signed Debug HAP carrying the optional local
  dictionary display-label enrichment was installed with `install -r` only.
  The Settings global presentation was temporarily set to List, but Latest
  retained its own existing Cover-grid source override; selecting Follow
  global for Latest then produced the native List and its tag leaves. The
  observed leaves used their raw fallback values; this run did not expose a
  preinstalled dictionary substitution, so translated-label rendering remains
  unaccepted. The global presentation, Latest source override, and tag switch
  were restored to Cover grid, Cover grid, and off respectively. No account,
  gallery, preference other than those temporary presentation controls, or
  application data was changed.

## Current delivery observation — tag-dictionary reactivity

- 2026-08-13: signed Debug commits `73e504f` and `b9efa27` were installed in
  place on the selected `.237` device after the awake / 24-hour timeout gate;
  no data clear or uninstall occurred. The documented numeric Detail route
  for the existing verification gallery settled on native NextN at the
  `1320×2120` root viewport and retained its existing grouped resolved-tag
  leaf.
- No dictionary replacement, clear, update, preference write, account action,
  or gallery mutation was induced. Therefore this confirms only the installed
  current Detail-tag state. The source-corrected replacement/clear reactivity
  remains EVIDENCE-ONLY until it occurs through an ordinary permitted
  dictionary action; do not manufacture that action solely to obtain an
  acceptance sample. Retained local artifacts are
  `.hvigor/outputs/tag-reactivity-20260813T1100/` and are excluded from Git.

## Current delivery observation — local comic-translation model pack

- 2026-08-11 manga-rendering-service route correction: the first corrected
  NextN traversal opened native Reader model management rather than the
  intended Comic Translation destination after a reused post-scroll
  coordinate. No model action, service configuration, account action, or
  application-data change occurred. The terminal layout is retained locally
  as rejected route evidence; the next action is a fresh semantic route
  recovery from Reader Settings.
- Recovery result: the fresh semantic route then reached `Settings → Reader
  → Comic translation → Manga rendering service` in native NextN. The
  unconfigured service row and its native form were observed; the provider
  switch was unavailable pending a connection check. No URL, account,
  password, service call, provider selection, account state, or application
  data was changed. The installed NextE reference root used the same portrait
  viewport, but its corresponding page was not reached in this run, so visual
  parity remains open. Local raw route artifacts remain outside Git.

- 2026-08-12 corrected reference-route result: NextE reached its actual
  `Settings → EH → Comic translation → Self-hosted` service form, while
  NextN again reached its native `Settings → Reader → Comic translation →
  Manga rendering service` form. Both terminal roots were native EntryAbility
  foregrounds at the same `1320×2120` portrait viewport. The reference form
  was already configured and the NextN form was unconfigured, so the pair is
  rejected for visual comparison rather than treated as a parity result. No
  service field, connection check, provider state, account state, content
  data, preference, app-data clear, or uninstall occurred. The raw local
  evidence is retained outside Git; do not rerun either route or change either
  configuration merely to manufacture equivalence.

- 2026-08-11: the signed Debug HAP was installed with `install -r` on the
  selected TCP device only. The device gate read `AWAKE` with
  `OverrideTimeout=86400000ms` before the native route.
- The native path `Settings → Reader → Comic translation` reached the
  existing translation-source destination. Its new local-model group rendered
  between the consumer bindings and save action in the uninstalled Download
  state.
- No source field, stored secret, consumer switch, save action, model download,
  account action, Favorites read, or content mutation occurred. Raw captures
  are retained locally in `.hvigor/outputs/translation-local-model-pack-20260811T0344/`
  and remain excluded from Git.
- This is current-device route and rendering evidence only. A same-state NextE
  reference comparison and model download/processing run remain OPEN.
- 2026-08-11 follow-up: after the leaf correction, the same selected device
  showed `端侧漫画模型` with its `未安装` state and the complete full-width
  `79.0 MB`/license notice. The retained same-viewport NextE local-model
  capture has the corresponding installed state with the same title and
  full-width notice treatment. This accepts the uninstalled settings leaf;
  model download and processing remain OPEN. No source field, secret, switch,
  save action, model state, account state, or content data changed.

## Latest completed physical evidence — Download completion-notification setting

- 2026-08-11: the signed Debug HAP was installed with `install -r` on the
  selected TCP device only. Native Settings → Download showed the new default-
  off `完成通知` row inside the existing Download policy group. A current NextE
  Download-settings capture at the same `1320×2120` portrait viewport showed
  the corresponding default-off bell switch row; NextE-only archive, speed,
  and auto-retry controls were not copied into NextN.
- Turning the NextN row on reached the real system notification permission
  dialog. The prompt was denied to preserve the existing system permission
  state, then the app preference was restored to off and the native Download
  settings row was re-observed. No task was started, paused, removed,
  exported, or fabricated; no notification was published. The default-off row
  and permission-request transition are accepted for this path. A genuine
  future completion notification remains unproven and stays OPEN in the UI
  change ledger. The raw local comparison evidence is retained in
  `.hvigor/outputs/download-notification-settings-20260811T0426/` and is not
  in Git.

## Current delivery observation — Reader enhancement interaction yield

- 2026-08-11: the signed Debug build containing the Reader interaction-yield
  change was installed with `install -r` on the selected TCP device only. The
  local enhancement-model manager reported an installed model while the
  enhancement preference was disabled.
- A bounded direct-gallery attempt did not yield a stable Reader terminal
  frame after the native Detail action: its retained terminal state was a
  native settings surface. Therefore no claim is made about processing,
  touch-time pausing, or Reader visual behavior.
- The final Reader settings observation confirmed enhancement disabled, and
  the foreground was returned to native Browse. No model download, account
  action, Favorites read, content mutation, data clear, or uninstall occurred.
- The physical processing-and-interaction evidence remains OPEN; local raw
  artifacts are retained outside source control and are not named here.
- 2026-08-11 follow-up: a subsequent signed Debug HAP replaced the legacy
  MindSpore-only leaf with the NextE waifu2x ncnn runtime pair. The existing
  model page explicitly downloaded that pair into NextN private storage and
  entered its installed/remove state. The enhancement preference remained on,
  but the same fresh native Detail action again exited NextN; terminal layout
  foreground was NextE, not Reader. A single 20-second PID- and native-tag-
  filtered live-log capture produced no module line. This observes an
  unresolved actual-native-request failure only; it is not processing
  acceptance. The CPU-only experiment that avoided Vulkan initialization
  reached the same NextE terminal foreground, so it was rejected and removed;
  GPU initialization is not established as the cause.
- 2026-08-11 further isolation: a `prepareModel()`-only ncnn branch stayed in
  native NextN. A second branch, returning before `upscaleRgba` only after
  model-ready/cache preflight and source-pixel read, instead reached NextE.
  The result narrows the post-prepare window but does not establish decoding
  as the cause because more than one operation was included. Both diagnostic
  branches were removed after one execution; the unresolved processing path
  remains OPEN and local raw layouts stay outside source control.
- The next one-operation result returned after the model-ready/hash/cache
  preflight and also remained in native NextN. The failure window is now only
  `processNow()` image-source processing or later; that temporary branch was
  removed immediately and does not establish a root cause.
- A return immediately after `image.createImageSource()` also stayed in NextN;
  only image-info, pixel-map creation, and pixel read remain in the current
  pre-native window. That temporary branch was removed after one run.
- A return immediately after `getImageInfo()` also stayed in NextN; only
  PixelMap creation and pixel read remain in the current pre-native window.
  That temporary branch was removed after one run.
- The PixelMap-creation-only branch reached NextE. On this device, the first
  observed unsafe operation is `source.createPixelMap()`; all preceding model
  and image-source operations remained native NextN. The temporary branch was
  removed after its one-run result. The next implementation must avoid or
  bound this ArkTS pixel-decoding path; processing acceptance remains OPEN.
- A reference-derived serialized enhancement queue was then built and run
  without any temporary early return. The same Reader route still reached
  NextE, so that queue was immediately removed. It is not retained as a
  speculative fix; the processing path remains OPEN.
- A 256×256 `desiredSize` PixelMap branch also reached NextE before pixel read
  or ncnn. That temporary branch was removed. The failure is not explained by
  the tested decode size or queue; it narrowed the then-active investigation
  to image decoding and its input bytes.
- Repair result: NextN's stream cache now rejects a short NetworkKit chunk
  write and uses a v2 identity for newly fetched Reader bytes; old entries
  were not deleted. After the signed data-preserving update, the same direct
  route stayed in native NextN Reader at both 10 and 30 seconds. This closes
  only the observed process-exit regression for a fresh cache source;
  enhancement output and visual-reference acceptance remain OPEN.
- The current Reader's existing enhancement-status leaf then reached its
  applied state. Its owner only sets that state after a non-empty private
  derivative is atomically promoted, so this is observed native output-state
  evidence for the current page. Same-state NextE quality comparison remains
  OPEN; raw content is retained locally and not named here.
- 2026-08-11 follow-up: the current signed Debug HAP was installed in place,
  then the existing numeric Gallery direct route reached native NextN Detail
  and its one current `Continue` Reader action was invoked. The terminal
  foreground was `com.erosteam.nexte`, not NextN Reader. No account,
  preference, model, content, download, or application-data action occurred.
  A bounded attempt to defer NextN enhancement until the original Image
  `onComplete` produced the same terminal result, so that uncommitted change
  was reverted immediately. This disproves that decode-order hypothesis for
  the observed local-download path; it does not identify a cause. The current
  local artifacts remain outside Git in
  `.hvigor/outputs/reader-enhancement-runtime-20260811T1253/`.
- The current NextN Reader settings were then read without changing them:
  image enhancement was disabled. A second temporary build bypassed only the
  completed local-download URI so the Reader used its existing public Reader
  cache source instead. The same direct Gallery `Continue` action still left
  NextN and foregrounded NextE. That bypass was removed immediately. This
  rules out both the disabled enhancement branch and the local-download source
  selection for this observation; it does not establish the remaining Reader
  route or renderer cause.

## Active delivery P1 — Gallery Detail / Comments

- The Detail-owned comments response is now passed into the full Comments
  route only after a successful response for the current gallery. A direct
  Comments route without that snapshot retains its ordinary page-load path;
  user pull, title refresh, and post-comment reconciliation retain their
  existing request paths.
- The current signed Debug HAP was installed with `install -r` only on the
  selected TCP device. A generic Gallery direct route followed by the unique
  visible Comments action transitioned to native loaded comments within the
  immediate 0.3-second post-action observation; no pull-refresh indicator or
  loading placeholder was visible. No account, preference, or content data was
  changed.
- This is a behavior observation, not full visual-reference acceptance of the
  Comments page. Local audit artifacts are retained outside source control and
  are intentionally not named here.
- The installed ErosN reference app uses the same NH gallery-ID model, but its
  current Harmony ability has no URI launch route. Its only same-ID route is
  an opt-in clipboard detector that is currently disabled. The detector and
  system clipboard were left unchanged, so a different gallery or a mutated
  reference-app state is not being substituted as a comparison capture.
- A fresh P1 baseline used the existing direct Gallery route and preserved a
  named local Detail/Comments audit directory. The Detail lower viewport kept
  the Preview, Related cover-and-title rail, and compact comment preview as
  distinct native sections. Its unique native Comments action reached an
  already loaded native comment list in the immediate post-action frame; no
  pull-refresh indicator or duplicate in-page comments heading was visible.
  This is current-device behavior evidence only, not a same-state reference
  visual-parity claim. No account, preference, gallery, or comment data was
  changed; the raw audit artifacts are retained locally and excluded from Git.
- The current signed Debug HAP was then checked again on the same direct
  Comments route. The single persistent native editor uses the reference copy
  for a new comment; it did not produce a modal or a second editor. No text
  was entered and no comment mutation was sent. The retained local capture is
  evidence for this compose-control boundary only, not full page acceptance.
- A retained direct Gallery review then covered the compact Preview, Related,
  and compact Comments rails across their visible Detail viewports. The
  Preview kept its reference-sized image rail; Related then rendered a 190vp
  cover plus an 80vp title region; and each horizontal List owned its full
  viewport while its first and last items owned the visible edge gap. The
  floating Read action did not cover a card in the reviewed end states. This
  is a current device geometry observation, not a same-data reference-parity
  claim; no data, preference, or gallery action was changed.
- The Gallery Comments timestamp footer and the Detail compact-comment
  preview were then checked after a data-preserving signed Debug update. Both
  showed the supported local date-and-time leaf without clipping the author
  or body; no comment text was entered and no mutation was sent. The bounded
  local captures are retained outside source control.
- After the comments-composer keyboard update, the selected device opened the
  existing direct Comments route and activated the empty native TextArea once.
  The system keyboard appeared while the composer remained fully inside the
  resized visible area. No text was entered, no comment was submitted, and
  the bounded before/after captures remain local and excluded from Git.
- The current direct Comments review then moved the composer out of the
  comment-list overlay into a fixed native page footer. At rest and with the
  empty TextArea focused, the page footer remained above the keyboard and did
  not cover visible comment text. Comment-card content also received a 16vp
  inset inside its 24vp corner. No text was entered or submitted. This is a
  current-device observation only; a same-state reference comparison remains
  outstanding.
- 2026-08-10 11:30 +0800: after restoring the selected-device HDC channel, a
  direct Gallery Detail review preserved one local terminal capture. The Read
  rail did not cover a visible Related or compact-comment card in that
  viewport. A separate direct native Comments review showed the fixed composer
  below, rather than over, the visible comment list. No text was entered or
  submitted. These are current-device observations only; a same-state
  reference capture remains outstanding.
- 2026-08-10: the existing explicit numeric Gallery Want was invoked directly
  on the selected device for the designated verification gallery. It reached
  native Gallery Detail, and the optional native Comments destination also
  reached a loaded comment list. Neither route exposed Web or a lingering
  loading placeholder. No account, preference, or content mutation occurred;
  local artifacts are retained outside Git. The reusable command protocol is
  recorded separately in `docs/device-protocols/nextn-gallery-direct-route.md`.
- 2026-08-10: the current native Detail action opened the local Reader for the
  same designated gallery. The terminal reader frame was a native two-page
  canvas with chrome hidden by default, no Web component, and no loading
  placeholder. No Reader preference, account, download, or comment mutation
  was made; retained local artifacts are excluded from Git. This is a current
  path observation, not a same-viewport visual reference acceptance.
- 2026-08-10: an installed NextE public Gallery Comments route and NextN's
  designated native Comments route were captured on the same selected device
  viewport in loaded states. No text, comment mutation, account action, or
  preference was performed. The NextE page exposes an in-page count header
  and a floating composer, while the current NextN page intentionally has no
  duplicate count header and keeps its composer in the fixed page footer.
  Those NextN differences are already user-corrected/frozen boundaries, so
  this observation authorizes no automatic reversion or UI edit. The retained
  local artifacts are
  `.hvigor/outputs/nexte-comments-reference-20260810T1433+0800/` and
  `.hvigor/outputs/nextn-comments-reference-compare-20260810T1433+0800/`;
  neither is in Git.
- 2026-08-10: the signed Debug HAP containing the empty-discussion composer
  change was installed with `install -r` only. A public read established that
  Gallery `671786` has an empty paginated comment result, and the existing
  direct Comments route was requested once without text input, submission,
  account action, or preference change. The device accepted one native layout
  dump, but the subsequent screenshot capture was rejected by the local
  approval service before a file could be retained. This is not a visual
  acceptance or a claim that the composer was visible; the next permitted
  action is to preserve a fresh terminal screenshot and review that exact
  zero-comment state.
- 2026-08-10: the same real zero-comment route was repeated after the device
  gate. Its retained terminal screenshot shows the native empty-state message
  and the existing fixed page-footer composer in the same viewport; no text,
  submit, account action, or preference change occurred. This observes
  zero-comment composer visibility only, not visual reference parity. One
  fresh-layout semantic click targeted the empty composer field. The terminal
  keyboard screenshot was generated on device but its host receive was
  rejected by the local approval service, so keyboard avoidance remains
  unproven rather than inferred from command injection. The retained at-rest
  screenshot is
  `.hvigor/outputs/nextn-comments-empty-retry-20260810T1457+0800/nextn-comments-empty.png`.
- Next physical action: continue the Gallery Detail / Comments reference
  zero-comment keyboard-avoidance capture when the local approval service
  permits file receipt; do not change the frozen title/composer boundaries
  merely to match NextE.

## Completed physical evidence

- The supplied test account was entered and submitted autonomously in the
  visible ArkWeb login form.
- Native signed-in account/profile state, force-stop/cold-start restoration,
  and an authenticated Favorites state were verified without clearing data.
- The screen timeout readback showed `AWAKE` with the project 24-hour
  override.
- Native theme changed to Dark, language changed to English, and Browse layout
  changed to Cover wall. Their Settings summaries updated immediately.
- The account profile row was visually compared against NextE after its avatar
  track was adjusted. Raw comparison artifacts were deleted.
- After the selected TCP device recovered, the newest Debug HAP was installed
  with `install -r` only. Its active Cover-wall presentation was verified as a
  native `WaterFlow` with real `FlowItem` covers, and the same structure
  survived a force-stop/cold-start without clearing data.
- The temporary test preferences were restored on-device: Chinese, follow
  system theme, and Cover grid. The active root Browse page then verified as
  native `Grid` plus `GridItem` after another force-stop/cold-start.
- After that newest-HAP cold start, Favorites was re-opened as a native list
  with no Web component and no sign-in prompt. This confirms the preserved
  account session remains usable for an authenticated Favorites read after
  update and restart.
- A real-device search landing regression was found after the top-inset
  cleanup: guide text overlapped the pinned HDS title/search field. The
  NextE-specific search landing reserve was restored, built, installed with
  `install -r`, and re-verified on the device with guide content below the
  title and search field.
- During the latest current-HAP acceptance, the visible ArkWeb login form was
  completed autonomously through a field-anchored sequence. The post-submit
  safe layout summary showed no visible Web surface, a native Account section,
  a signed-in state, and no save failure. No credential, profile, cookie, URL,
  or raw layout was retained.
- That same session then survived a force-stop/cold-start without clearing
  data. The Favorites safe summary showed no Web surface, no sign-in prompt,
  no loading or error placeholder, and native gallery structure. This is the
  current accepted cold-start authenticated Favorites evidence.
- The latest Debug HAP, including fixed restore-stage diagnostics and the
  reusable acceptance tooling, was then installed with `install -r` and
  force-stopped/cold-start again. The durable Favorites summary again showed
  no Web/sign-in/loading/error/empty state and native gallery structure.
- Latest-HAP History acceptance used durable, redacted semantic anchors: the
  primary history card opened native Gallery Detail, while that same card's
  explicit Resume action opened the Reader overlay. No history title or
  content was retained; temporary raw layouts were deleted after each
  structural summary.
- Latest-HAP Downloads acceptance used durable task anchors: the task cover
  opened native Gallery Detail and the task body opened a loaded Reader
  overlay. The latter was verified structurally without recording task title,
  error, path, URL, or image content; temporary raw layouts were deleted.
- After the current signed Debug update, the client was installed with
  `install -r` and force-stopped/cold-start without data clearing. Its
  authenticated Favorites summary again showed no visible Web, sign-in
  prompt, loading, empty, or error state and reported nine native gallery
  items. The raw layout was deleted from host and device after summarization.
- Latest-HAP Reader acceptance opened the overflow Settings action from the
  active private Reader overlay. The Reader-owned settings sheet and its
  layout menu both appeared natively; dismissing the menu and then the sheet
  returned to the same Reader overlay. No preference was changed, and every
  temporary raw layout was deleted from host and device after its redacted
  structural summary.
- Latest-HAP Gallery acceptance opened the Pages row from native Gallery
  Detail into the thumbnail Grid. Its HDS Jump action opened the native
  numeric sheet; a fixed non-sensitive test page value was confirmed, the
  sheet closed, and the thumbnail Grid remained present. No gallery content
  was retained, and all temporary raw layouts were deleted from host and
  device after redacted structural summaries.
- Latest-HAP Downloads acceptance verified the reversible local-search empty
  boundary: a fixed non-sensitive no-match query produced zero task groups
  without an error, and closing search restored the original one-group,
  one-task native queue. The current queue is too short to manufacture a
  multi-group pinned-header scroll case; no task data was created or changed.
  All temporary raw layouts were deleted after redacted summaries.
- Latest-HAP Browse acceptance verified the real root HDS shape and native
  loaded state: no visible Web, one native Grid, and six structural gallery
  items. No natural Browse error or empty state occurred; network and saved
  preferences were not altered merely to fabricate one. Temporary raw layouts
  were deleted after their redacted summaries.
- Latest-HAP Search acceptance verified that a non-empty edit to a submitted
  query keeps the existing native result surface visible rather than returning
  to the guide. A possible recent-search cleanup was deliberately not run:
  local history is keyed only by normalized query, so it cannot distinguish a
  test entry from a pre-existing user entry. No search-history record was
  deleted, and the temporary layout copies were deleted from host and device.
- The next signed Debug update added the native direct-search action to the
  suggestion surface. On 237, its uniquely matched fixed-label row transitioned
  to a native Search result surface with three structural result items and no
  Web, loading, error, empty, or guide state. The result is accepted; the raw
  precondition and result layouts were deleted from host and device.
- The later signed Debug update was installed with `install -r` only. Gallery
  Detail's unified Pages entry was exercised on the native compact path and
  transitioned to the thumbnail Grid, where the existing First-page and Jump
  actions remained available. The selected 237 layout is narrow, so the new
  wide/split availability branch has static contract and signed-build evidence
  but is not represented as a fabricated device observation.
- Quick Search was built with its own local table and safe acceptance tooling.
  Its native bookmark control and empty quick section were observed, but the
  currently committed Search expression did not equal the known non-sensitive
  test expression. No text was retained, and the agent did not clear, replace,
  pin, or delete that existing expression. The app was returned to native
  Browse; all temporary layouts were deleted.
- During the current Reader double-page acceptance, the private Reader overlay
  was proven to be foreground while its chrome was intentionally hidden, so no
  unambiguous settings control was available. One source-grounded system Back
  closed only that overlay. A fresh redacted summary then proved the root was
  foreground and the pre-existing Download task remained Complete; no Reader,
  download, account, or preference state was changed. Temporary layouts were
  deleted immediately.
- A later signed Debug build, including the download completion-normalization
  fix, was installed with `install -r` and force-stopped/cold-start without
  clearing data. Its root shell was confirmed native and foreground. The
  follow-up Favorites read remains pending only because the live floating-tab
  layout has not yet yielded a unique, safe Favorites anchor; no account
  action or credential entry was attempted, and temporary layouts were
  deleted.
- That current-HAP Favorites read has since been completed: its redacted
  native summary showed no visible Web, no loading, empty, or error surface,
  and a sign-in prompt with zero structural gallery items. No credentials were
  entered. A bounded cold-start restore-stage capture produced no retained
  fixed stage under the current tag/level path, so it is not used to infer a
  cause. The native Account half of S0 remains pending a safe current Account
  entry anchor; its temporary layout was summarized only as
  `account_marker_missing` and then deleted from host and device.
- The Account anchor was then safely established through the actual flattened
  HDS Settings representation. Its current S0 summary showed a visible login
  Web surface rather than a native account section; paired with the Favorites
  sign-in prompt, this proves the current session is not usable. Two bounded
  S1 read-only ArkWeb probes initially stopped before any form interaction:
  `devtools_discovery/unavailable_or_invalid`, then
  `devtools_discovery/transport_failed` after safe two-page discovery repair.
  The transport difference was then isolated to the host loopback boundary.
  Running the unchanged fixed probe through the same lease-owned host channel
  positively proved the current empty login form, its account/password fields,
  masked-password semantics, and disabled submit state. Each run's exact
  temporary forward and diagnostic directory was removed. No account or
  password input, form clear, or submit occurred. A semantic CDP account-focus
  action then received a fresh probe confirmation. The fixed Keychain presence
  diagnostic reports both contracted handles absent, so the S2--S4 epoch was
  stopped before any secret retrieval or field change.
- The P0 non-destructive restore fix was statically verified, signed, and
  installed with `install -r`; two force-stop/cold-start checks used no login
  action. With the temporary fixed-stage tag diagnostic enabled, the current
  device reported only `account_restore_record_absent`. Thus the prior sealed
  record had already been lost under the old behavior; this does not pretend
  to prove the new record-present failure branches on a fabricated session.
- The complete follow-up P0 closure (native verification-required gate plus
  authenticated-GET second-401 gate) then passed independent source review,
  full static contracts, and a new signed Debug build. That HAP was installed
  with `install -r` and cold-started without login input. A fresh ring-buffer
  read yielded no new stage, so the retained `record_absent` observation is
  deliberately not upgraded into a fabricated record-present device result.
- The rejected four-lane Downloads task surface was replaced with the exact
  NextE card hierarchy (cover, one content column, compact inline actions).
  The new signed Debug HAP was installed with `install -r` and visually
  reviewed on 237 after a data-preserving restart. The independent status
  block, oversized export pill, and detached Read affordance were absent.
  The temporary screenshot was deleted from both host and device immediately.
- The latest signed Debug HAP was installed with `install -r` only for a
  Gallery Detail visual recheck. A safe native Browse card opened a public
  detail; screenshot inspection confirmed one visible all-thumbnails header
  entry with a bounded horizontal preview rail, stable-width Related cards,
  and no terminal-content occlusion by the Read rail. No account action,
  preference mutation, raw gallery content, screenshot, or layout artifact
  was retained after the check.
- A bounded Reader visual audit then used that public detail's verified Read
  control. The first coordinate was proven to have missed the native button;
  one subsequent click at the verified enabled control entered the Reader.
  Its chrome was hidden by the existing preference, so no unknown tap-zone or
  preference action was performed. System Back closed only the overlay.
  Temporary screenshots and redacted layouts were deleted. This is an audit
  observation, not a claim of Reader visual acceptance.
- A follow-up Gallery Detail visual correction was built, signed, installed
  with `install -r`, and checked on 237 through the same native public-detail
  path. The direct HDS actions now follow favorite/share/overflow priority,
  sparse metadata has no artificial paired-cell hole, and the Tags heading is
  left-aligned with its tag rows. The compact Preview keeps its visible
  all-thumbnails entry; at the terminal scroll position the Comments route
  action remains above the floating Read control. No account, preference, or
  queue state was changed. Raw screenshots and layouts were deleted after
  review.
- The next signed Debug update, including the shared Latest collection tree
  and retained History/Downloads lifecycle fixes, was installed with
  `install -r` and cold-started without data clearing. On 237, Latest returned
  from Popular with populated rows present in both an early and settled frame;
  Downloads and History likewise returned from Browse with their existing
  native rows rather than an initial-loading surface. No account action,
  preference change, task mutation, or history mutation was performed. All
  temporary screenshots and layouts were deleted from host and device after
  review.
- The subsequent signed Debug update was installed with `install -r` only and
  rechecked through the same public Gallery Detail path. The visible metadata
  has no terminal identity row, compact preview tiles retain page aspect, tag
  headers preserve namespace hierarchy, and the Related rail uses non-uniform
  intrinsic widths. The naturally selected detail had no renderable comment
  cards, so comment-card geometry remains unclaimed pending an observable
  state. The floating Read rail did not obscure any visible content in a
  near-tail frame; exact terminal-reference parity remains unclaimed. No
  account, preference, queue, or history data was changed. All temporary raw
  screenshots and layouts were deleted from host and device after review.
- A bounded Reader visual audit then used the public Gallery Read action. The
  persisted tap setting was inspected without mutation and permitted one
  verified center-menu toggle. Both the hidden-chrome first frame and the
  chrome-visible frame showed a continuous canvas without an anomalous extra
  top or bottom gap; the visible chrome kept its header and bottom
  progress/toolbar stack as overlays. Expanded-thumbnail and vertical-loading
  transition states remain unclaimed. No Reader preference, account, queue,
  history, or page-progress data was changed. All temporary raw screenshots
  and layouts were deleted from host and device after review.
- The current Debug HAP containing the retained-collection lifecycle changes
  compiled and was installed with `install -r`, followed by a force-stop/cold
  start without data clearing. The older Popular protocol's declared title
  action opened Browse Options rather than Popular, so it was revoked rather
  than counted as a Popular result. System Back returned to a redacted native
  root summary; no option, preference, account, task, or history state was
  changed. The temporary layouts and screenshot were deleted from host and
  device immediately after that check.
- The subsequent signed Debug HAP containing the unified Popular, Favorites,
  and Search collection parents was also installed with `install -r` and
  cold-started without data clearing. The first bounded dynamic Popular
  selector returned only `source_bar_missing`, so no navigation input was
  issued. The selector is being reconciled against the current HDS runtime
  tree; its temporary layout was deleted from host and device immediately.
- After the current HDS runtime tree was safely reconciled, fresh native
  source-bar anchors drove one `Popular → Latest → Popular` sequence with
  the source-owned settle interval. The final redacted state was a native
  Popular collection with five structural gallery cards and no visible Web or
  loading/error/empty surface. The final same-state visual frame showed the
  retained Popular selection and loaded card surface; it is not claimed as a
  fabricated network-timing measurement. No preference, account, task,
  history, or search data was changed. All temporary layouts and screenshots
  were deleted from host and device immediately after review.
- The following signed Debug HAP was installed with `install -r` and checked
  on the signed-out Favorites state. The native sign-in prompt was correct,
  but the HDS title still displayed stale Browse actions. This is recorded as
  a device-found failure, not an acceptance: the source gate must explicitly
  clear the prior HDS menu before the check is repeated. No action was invoked
  from that stale menu, and all temporary layouts and screenshot were deleted
  from host and device immediately after review.
- The corrected signed Debug HAP then passed the same data-preserving
  force-stop/cold-start and signed-out Favorites recheck. The native sign-in
  prompt remained present and the stale Browse title actions were absent;
  no title action was invoked. All temporary layouts and screenshot were
  deleted from host and device immediately after review.
- The next signed Debug HAP was installed with `install -r` and cold-started
  without clearing data. Fresh, dynamically anchored `Popular → Latest →
  Popular` transitions each stayed on native loaded Browse collections: Latest
  reported six structural cards and final Popular five, with no visible Web,
  loading, error, or empty surface. The current card grid and visible
  language-corner geometry were visually inspected; a local NextE screenshot
  existed but could not be proven to be the same Browse source/state, so no
  cover-fit, selected-state, or full visual-parity claim is made. No login,
  preference, account, task, history, or search mutation occurred. All new
  temporary layouts and screenshots were deleted from host and device.
- The already-installed NextE app was then opened only to obtain a real
  same-device reference. Its captured foreground was the system launcher, not
  a Browse collection, so it was rejected as non-comparable; NextN was
  immediately returned to its native five-card Popular root. Those temporary
  NextE and return-check artifacts were deleted from host and device.
- The next signed Debug HAP, including the thumbnail Reader-overlay reentry
  guard, was installed with `install -r` and cold-started without data
  clearing. A fresh safe Browse card reached native Gallery Detail, but the
  current flattened HDS layout did not satisfy any existing strict
  thumbnail-entry predicate, so no scroll, Pages action, Reader entry, or
  retry was issued. This is a pending device check rather than a claimed
  runtime pass; the temporary layouts were deleted from host and device.
- The account P0 hardening then narrowed destructive invalidation to explicit
  sign-out or a replayed authenticated account read that receives a second
  401. Public catalog reads and a single mutation 401 now retain the sealed
  record. The full static suite and signed Debug build passed; that HAP was
  installed with `install -r` and force-stopped/cold-start without login. The
  fixed stage remained `account_restore_record_absent`, which verifies the
  current no-record state only and is not claimed as record-present retention
  acceptance.
- A bounded Gallery Detail compact-viewport re…2227 tokens truncated…ocal capture
  is retained outside Git. This is a single current Reader state observation;
  it is not a same-state reference comparison and does not authorize a Reader
  visual change.
- 2026-08-10 16:29 +0800: that same Reader overlay returned through the
  documented native Back action. The retained Detail route immediately showed
  one visible native List and its existing Read action with no visible loading
  progress state. No page, preference, account, or content mutation occurred.
  This verifies only the Reader-to-Detail ordinary-return boundary; it does
  not generalize to other route types or cold starts.
- 2026-08-10 19:20 +0800: after the selected TCP target reconnected and the
  wake/timeout gate read back AWAKE with the 24-hour override, the existing
  direct Gallery `471768` Comments route reached a native loaded comment list
  in the retained terminal screenshot: comment cards plus the fixed
  page-footer composer, with no Web component, loading placeholder, error
  surface, or sign-in prompt. No text was entered, no comment mutation,
  account action, or preference change occurred. The raw layout and
  screenshot are retained only in the named local audit directory outside
  Git. This is a current-device route observation, not a same-state
  reference-parity claim.
- 2026-08-10 19:22 +0800: the fresh Comments capture was compared with the
  retained same-device loaded reference captures from the earlier comparison
  session. The NextN captures show the same native loaded comment list and
  fixed page-footer composer. NextE's in-page count header and floating
  composer remain the already user-corrected, frozen differences; no new
  source-proven parent-tree or geometry defect was found in this comparison,
  so no visible UI edit was made in this lane.
- 2026-08-10 19:23 +0800: one native Back from the direct `471768` Comments
  destination returned to the retained Browse root with one native Grid and
  ten structural GridItem covers; no visible loading or refresh indicator,
  Web component, error surface, or sign-in prompt appeared in the retained
  terminal state. No preference, account, or content mutation occurred. The
  raw layout and screenshot are retained only in the named local audit
  directory outside Git. This is a current ordinary-return observation for
  this root only.
- 2026-08-10 19:34 +0800: after the cold-start Account verification, a normal
  root switch into Downloads reached the retained native Downloads surface:
  one native List with its completed-task card and no visible loading,
  refresh indicator, Web component, error, or sign-in state. No preference,
  account, or download mutation occurred. The raw layout and screenshot are
  retained only in the named local audit directory outside Git. This is a
  current ordinary root-entry observation only.
- 2026-08-10 19:39-19:43 +0800: a Search ordinary enter/return chain was
  first attempted with a stale tab coordinate. Its terminal state was
  Favorites rather than Browse, and a later Back left the NextE reference
  app foreground, so that chain was rejected and produced no claim. The
  route was repaired with the current semantic anchors (Browse root tab and
  its leftmost title-bar search action). The repaired chain reached a native
  Search landing with recent-search content and no loading or refresh
  indicator; one Back dismissed the keyboard and retained the Search
  surface; a second Back returned to the retained Browse root with its
  native Grid and no visible loading or refresh indicator. No query,
  preference, account, or content mutation occurred. The raw captures are
  retained only in the named local audit directory outside Git. This is a
  current ordinary enter/return observation only.
- 2026-08-10 19:45 +0800: a normal root switch into History reached the
  retained native local-history surface: one native List with its visible
  day-grouped rows and no visible loading, refresh indicator, Web component,
  error, or sign-in state. No preference, account, or history mutation
  occurred. The raw layout and screenshot are retained only in the named
  local audit directory outside Git. This is a current ordinary root-entry
  observation only.
- Raw screenshots and layouts retained for an active route or visual decision
  stay in their named local audit directory; they are never added to Git or
  deleted automatically.
- UI static contract and summary tooling has been removed and is not permitted.
  Account persistence is judged only from the durable source owner, signed
  build, and real cold-start state.

## Latest completed physical evidence — Reader image enhancement

- 2026-08-11: the signed Debug HAP was installed with `install -r` only on
  the selected TCP device. With the preinstalled private enhancement model and
  one temporary Reader setting enablement, the established direct Gallery
  route entered the native hidden-chrome Reader. Its settled current-page
  bottom status leaf rendered the applied-state icon, confirming this observed
  local-page path reached the enhancement result rather than only displaying
  the original fallback. The temporary setting was then returned to off and
  read back as off. No account, comment, download, or gallery data was
  changed. Local terminal evidence remains under
  `.hvigor/outputs/reader-enhancement-status-20260811T0555+0800/` and is not
  added to Git. This accepts only the observed local Reader enhancement path;
  it does not generalize to other models, page sizes, or source types.

## Latest device observation — Reader translation source gate

- 2026-08-11: the latest signed Debug HAP was installed with `install -r` on
  the selected TCP device only. The documented direct Gallery route then
  opened native Reader and its existing overflow menu. With no configured
  manga translation source, the native `Translate current page` item was
  present but disabled. No translation request, source edit, account action,
  preference change, or content mutation occurred. Local terminal evidence is
  retained outside Git. This observes only the unconfigured availability gate;
  it is not a configured-provider or rendered-translation acceptance.

## Current device exception — Reader entry route

- 2026-08-11: the signed Debug build carrying the session-only Reader
  automatic-translation source change was installed with `install -r` on the
  selected TCP device, then NextN alone was force-stopped before the existing
  direct Gallery route was started. The native Gallery action was resolved
  once from the fresh NextN layout and activated once.
- Its terminal root belonged to NextE rather than NextN. The source-added
  fixed Reader-route diagnostic stages were absent from the bounded local log
  capture; this absence does not prove whether the handler ran. The chain is
  therefore rejected before Reader or translation behavior, rather than being
  counted as a Reader result.
- No account, credential, source/profile, preference, download, comment, or
  gallery data was modified. Raw local evidence is retained in
  `.hvigor/outputs/reader-auto-translation-route-diagnosis-20260811T1047+0800/`,
  `.hvigor/outputs/reader-auto-translation-route-diagnosis-20260811T1051+0800/`,
  and `.hvigor/outputs/reader-auto-translation-route-diagnosis-cold-20260811T1056+0800/`;
  it remains outside Git and will not be deleted automatically.
- The exact failure boundary remains OPEN: establish why this native Gallery
  action leaves NextN before exercising it again. Do not use additional taps,
  inferred coordinates, or a new route to make a Reader result appear.
- 2026-08-11 follow-up: a narrow, reference-owned inner hit-test boundary was
  built and loaded by force-stopping NextN before the same direct route. The
  fresh implementation layout changed, but one semantic Read activation again
  reached the same non-NextN terminal. That unsupported hypothesis has been
  reverted; no Reader, translation, account, preference, or content action is
  claimed from this run. The retained raw evidence is
  `.hvigor/outputs/reader-hit-test-20260811T0319+0800/` and remains outside
  Git.
- 2026-08-11 current-source retry: after the normal signed Debug HAP was
  restored, NextN alone was force-stopped and the documented numeric Gallery
  route was opened. A fresh native Detail layout supplied one unique `继续`
  action; exactly one activation again left `com.erosteam.nexte` foreground
  rather than a NextN Reader. The selected device remained awake with the
  86400000ms timeout override, and no preference, account, content, download,
  or application-data action occurred.
- The one retained 500-line app/core warning-and-error tail contains no
  Reader, PixelMap, ImageSource, or fatal marker that can attribute this
  transition. It therefore records the foreground failure only, not a cause.
  The raw pre/post layouts, screenshot, and bounded log are retained outside
  Git at `.hvigor/outputs/reader-route-baseline-log-20260811T2123/` and will
  not be deleted automatically. The next diagnostic must change one
  non-visible execution boundary and cannot repeat this normal route merely
  to obtain another equivalent terminal capture.
- 2026-08-11 follow-up: a continuous app/core log was started before the
  route, and a temporary build added only fixed Reader-stage markers at both
  info and error severity. Each one-activation run still ended at the NextE
  root, but neither live capture contained a stage marker or an error/fatal
  record attributable to NextN. This proves the selected HILOG channel cannot
  observe this control-flow boundary; it does not prove that any particular
  stage was skipped. Both temporary variants were removed, then the normal
  signed Debug HAP was rebuilt and installed with `install -r`. No data,
  preference, account, or content mutation occurred.
- 2026-08-11 version boundary: an isolated, reproducible `12aa2f8` baseline
  HAP was built after restoring only its local HAR links. It was installed
  once with `install -r` and exercised through the same current Detail action;
  its terminal foreground was also NextE. The current HEAD HAP was immediately
  reinstalled with `install -r`. Therefore the observed exit predates the
  commits after `12aa2f8`; no later Reader settings or self-hosted-renderer
  change may be named as its cause. The isolated worktree, including its
  temporary local signing file, was removed; the local device evidence remains
  outside Git at `.hvigor/outputs/reader-version-boundary-20260811T2200/`.
- 2026-08-11 deeper version boundary: an isolated `c4c1627` Debug HAP was
  built and installed once with `install -r`. After a NextN-only force-stop,
  the documented numeric Gallery route and one fresh, unique native Continue
  action again left `com.erosteam.nexte` foreground. The current HEAD Debug
  HAP was immediately reinstalled with `install -r`; no data, account,
  preference, or content action occurred. This rules out the complete
  `c4c1627..12aa2f8` Reader-model/settings delta as the cause of this exit.
  It does not establish that an earlier source revision is healthy or identify
  the cross-application transition cause. Raw pre/post evidence is retained
  outside Git at `.hvigor/outputs/reader-version-c4-20260811T2255/`.
- 2026-08-11 pre-enhancement boundary rejected: an isolated `cc0c40a` HAP
  opened the numeric Gallery route, but its loaded Detail state did not expose
  a current semantic Read or Continue control. No coordinate was inferred and
  no Reader action was invoked. That revision is therefore not comparable to
  the current one-activation Reader scenario and cannot be used to attribute
  or exclude the enhancement introduction. Current HEAD was restored at once
  with `install -r`; the retained precondition evidence is outside Git at
  `.hvigor/outputs/reader-pre-enhancement-20260811T2202/`.

## Current device exception — Gallery full-title translation route setup

- 2026-08-11: after installing the Debug HAP for the full-title translation
  leaf with `install -r`, one hot integer-Want start for Gallery `471768`
  retained the pre-existing NextN Download settings foreground instead of the
  declared native Gallery Detail destination. The captured root was NextN's
  Download settings; no Detail control or title action was touched.
- This does not establish a Gallery routing defect: the post-install ability
  process had not first been re-established as the new build, so the run lacks
  the required implementation-version foreground precondition. The terminal
  screenshot and layout are retained locally in
  `.hvigor/outputs/gallery-title-translation-20260811T0454/` and are excluded
  from Git.
- Next physical action: force-stop only NextN, issue the documented numeric
  Gallery Want once, and accept only a native Gallery Detail terminal before
  opening the full-title sheet. Do not use the rejected Download settings
  state, old coordinates, a scroll route, or a second hot start.

## Current delivery observation — Gallery full-title translation

- 2026-08-11: after force-stopping only NextN and starting the same documented
  numeric Gallery Want, the final root was native `com.erosteam.nextn` Gallery
  Detail. One current unique title action opened the updated full-title sheet.
- The sheet showed its stable caption, separate source-title blocks, and two
  disabled translate leaves. No configured text source was present, so no
  provider request, source/profile change, account action, preference write,
  or gallery mutation occurred.
- The terminal screenshot and layout are retained in
  `.hvigor/outputs/gallery-title-translation-20260811T0454/` outside Git.
  A current same-state NextE title-sheet capture cannot be reached without
  changing reference data, so this is route/render evidence only; reference
  parity and configured running/result/failure states remain OPEN.

## Latest device observation — Shared comment-translation source route

- 2026-08-11 08:37-08:40 +0800: the signed Debug HAP containing the shared
  translation-source and comment-card changes was installed with `install -r`
  on `192.168.50.237:12345` only. The device gate read `AWAKE` with
  `OverrideTimeout=86400000ms` before the route.
- The documented native Gallery Comments route reached a native loaded
  Comments destination. One native Back returned to NextN root; the unique
  native Settings entry then led through Settings → Advanced → Comment
  Translation to the shared source form. The terminal form showed its explicit
  Reader and comment consumer controls without any form input or save.
- No account, credential, provider key, source record, preference, comment,
  gallery, or queue data was changed. Raw screenshots/layouts remain local in
  `.hvigor/outputs/comment-translation-unconfigured-20260811T0037/`,
  `.hvigor/outputs/comment-translation-settings-route-20260811T0040/`, and
  `.hvigor/outputs/comment-translation-source-form-20260811T0042/`; they are
  excluded from Git and are not automatically deleted.
- This accepts only the installed native route and unconfigured-form
  observation. Comment-card action visibility with a configured source,
  provider execution, translated text, and same-state reference comparison
  remain open.

## Next physical action

### Rejected P1 start — completed-download CBZ export

- 2026-08-11: this distinct, previously unexercised path was selected instead
  of reopening frozen Comments or any already-observed Detail/Reader surface.
  The intended boundary is one already-complete local task -> Export CBZ ->
  system share foreground -> cancel -> the same task remains complete.
- The initial foreground capture was native NextN Comments. Two documented
  Back actions then produced an `com.erosteam.nexte` Settings root, not a
  NextN Downloads page; that branch was rejected before any download action.
  A subsequent data-preserving NextN force-stop and explicit launch did not
  restore a NextN foreground: the current layout root was
  `com.ohos.sceneboard` with its no-available-opener system surface. The
  selected TCP device remained connected; no app data was cleared.
- No complete-task action, CBZ creation, ShareKit action, cancellation,
  preference, account action, or content mutation occurred. The local
  evidence is retained outside Git.
- Next physical action: re-establish and prove a native NextN foreground via
  the source-grounded launch path, then resume this exact export path once;
  do not use the rejected Settings root, old coordinates, or any Comments /
  Detail / Reader recheck as a substitute.
- Recovery and result: ability-manager state proved that NextN was foreground
  underneath the transient SceneBoard surface; one system Back dismissed only
  that surface. The existing Detail route then returned once to the NextN root
  and the current semantic Downloads tab opened the one completed task. Its
  More menu exposed the completed-task-only Export CBZ action. The export
  handed foreground to a system Share UIExtension; no share target, file name,
  URI, page, or other content metadata was read or retained. System Back
  canceled the handoff and returned to the same native Downloads page, where
  the task still showed its complete state. The unchanged task-to-Reader path
  was deliberately not reopened or retested.
- Accepted boundary: this one completed local task can enter the system share
  handoff through Export CBZ and return from cancellation without changing its
  queue completion state. This does not claim any share-target delivery or
  archive-content inspection.
- 2026-08-11 cache-lifecycle follow-up: the signed Debug HAP adding private
  CBZ handoff ownership was installed with `install -r` only. The same
  completed task again opened the system share UIExtension through Export CBZ;
  system Back returned to native Downloads with that task still Complete. No
  share target, archive metadata, queue task, account state, or download file
  was read or changed. This observes no export-hand-off regression. The new
  per-task removal and one-day cold-start expiry reclamation paths remain
  unobserved because this run neither deletes the user's task nor fabricates
  cache age.

## Latest device observation — tag-dictionary stream update

- 2026-08-11: the signed Debug HAP containing the sequential stream-write
  correction was installed with `install -r` on `192.168.50.237:12345` only.
  The device gate read `AWAKE` with `OverrideTimeout=86400000ms` before the
  native Settings route.
- Settings → Advanced → Local tag translation showed an existing 43,568-row
  local dictionary. One explicit Update action completed and returned to the
  normal action state with 43,672 local tags available for gallery display.
- No account, credential, Gallery data, History, download, Reader cache, or
  presentation preference was changed. Local layout evidence is retained in
  `.hvigor/outputs/tag-dictionary-update-20260811T0822/` and is excluded from
  Git.
- This accepts the observed dictionary-update transaction and its native
  status refresh only. It does not claim visual-reference parity for tag
  leaves or any unobserved network-failure branch.

## Current Gallery Comments direct-route exception

- 2026-08-11 00:32 +0800：对既有 Comments Want 的一次冷启动直达终态经 bundle/root 边界确认是原生 Browse 根页，不是 Comments。未写入评论、账户、偏好或其他内容数据。
- 该执行链已拒绝；不得用 Browse 滚动、旧坐标或重复截图伪造到达。下一步是仅修复冷启动请求发布顺序，构建并对同一 Want 做一次新的干净终态观察。
- 2026-08-11：该发布时序修复已签名构建并以 `install -r` 覆盖，未清数据；对同一 Want 的一次强制停止后冷启动终态为 NextN 原生 Comments `NavDestination`，有加载完成的评论 List 和固定编辑器。未输入、发送、修改账户、偏好或内容数据。本地终态截图和 layout 保留在 `.hvigor/outputs/nextn-comments-direct-route-Pa5X9P/`，不进入 Git。该结果仅接受这条冷启动路由，不是 Comments 视觉验收。
- 2026-08-11：为取得同状态参考而前台化已安装 NextE；其当前终态是横向分屏的 Settings 根页，NextN 则是竖向的 Comments，故该参考截图已拒绝且不用于任何页面判断或改码。随后通过既有语义 Want 把设备返回原生 NextN Comments；未发生数据写入。两份本地证据均保留在审计目录，不进入 Git。
- 2026-08-11：参考直达能力已按源码复核。NextE 仅接受含 EH `gid/token` 的 gallery URL 才能进入 Comments；当前 NextN 的数值 gallery Want 不能生成该 token。已安装 ErosN 虽有同 NH id 的内部路由，但 Harmony URI 入口不存在，唯一同 id 的 clipboard detector 处于禁用状态。未读取用户数据、未启用 detector 或修改系统剪贴板。故 P1 的下一步仍是取得一个不改变参考数据的同状态、同视口捕获；在此之前不据源码或不可比截图改动 Comments UI。
- 2026-08-11：已复核一对先前保留的 NextE/NextN 原生 Comments capture，并用本轮当前 NextN Direct-route 终态重新确认了实现侧的 root bounds。两端 root 都是 `1320×2120`、portrait、非 split、已加载 Comments；可比较 chrome、外侧 gutter、独立圆角 CommentRow 与 composer 顶缘。NextE 的一条评论与 NextN 的多条评论不是相同内容密度，故不以这对图推导字号或卡片高度。可见的 NextN 差异——移除重复的页内“评论（数量）”标题，以及固定页脚而非浮动 composer——均为已记录的用户冻结边界；EH 的翻译/投票叶没有 NH 数据能力，未伪造。审查没有产生新的安全可见改动。

## Rejected Gallery Detail lower-review continuation — 2026-08-12

- The numeric `471768` Detail route first reached native NextN Detail and one
  current-layout-derived upward swipe reached the Preview and Related sections.
  A second declared upward swipe then ended at native NextN Settings root,
  rather than the expected lower Detail comment-preview region. No content,
  Account, Favorite, setting, or floating Read action was invoked.
- The Settings terminal screenshot is retained locally with the Detail audit
  under `.hvigor/outputs/gallery-detail-471768-20260812T2051/`. This chain is
  rejected for further Detail visual conclusions. Do not repeat its old swipe
  or infer a Detail defect from this unexpected terminal state; re-establish a
  semantic Detail lower-section route before any future review.

## Current delivery observation — Gallery Detail compact rail proportions

- 2026-08-12: the signed Debug HAP containing the narrow Related/comment
  proportion change was installed in place on the selected TCP device only.
  The device was read back as `AWAKE` with its `86400000ms` timeout override;
  no data clear, credential, Account, Favorites, preference, or floating Read
  action occurred.
- The existing numeric `471768` Detail route foregrounded native NextN at
  `1320×2120`; its established first upward list swipe reached the current
  Preview, Related, and external comment-preview composition. Preview remains
  a shorter page-image rail. Related has a 175vp cover tier plus a distinct
  80vp readable title region. The external comments show their 280×190
  author/date/body cards rather than the prior compressed preview scale.
- The raw NextN layout and screenshot remain locally at
  `.hvigor/outputs/gallery-detail-rail-proportions-20260812T2107/` and are
  excluded from Git. This is an installed-device observation only: no current
  same-gallery loaded NextE/ErosN reference capture exists, so visual-reference
  parity remains OPEN. The rejected second-swipe Settings chain above remains
  rejected and was not repeated.

## Latest completed physical evidence — Gallery external Deep Link

- 2026-08-11：新增的 `nextn://gallery/<positive-integer>` 以独立 `viewData` skill
  声明，复用既有 GalleryDirectLaunchState；冷启动和热启动均以 `471768` 完成到同一
  原生 Gallery Detail。第一次隐式匹配失败被修复为正确的完整 URI `pathRegex` 片段，
  不是应用数据或页面错误。
- 冷启动的 Detail 曾被 USB 系统弹窗覆盖，热启动终态曾被系统锁屏与实际短超时覆盖；
  两者都只按系统恢复分支消除遮挡。最终前台均为 `com.erosteam.nextn:EntryAbility` 的
  原生 Detail。未点击 Gallery 控件，未写入评论、收藏、下载、History、账户或偏好。
- 本地审计证据保留在 `.hvigor/outputs/nextn-gallery-uri-20260811T0232/`，不进入 Git；
  该条只接受 URI 路由能力，不重新开启 Detail 的视觉审查。

The earlier P0 cycle is retained above as historical evidence. It is not the
current execution lane because no fresh current S0 observation has proved the
session unusable after the accepted recovery/cold-start path. It immediately
preempts delivery again if such evidence appears; it must not be used to
rewrite, re-run, or block this completed direct-route observation.

## Current Reader processing isolation — 2026-08-11

- A temporary Debug build retained the normal Reader service call boundary but
  made `ReaderSuperResolutionService.process()` return the original image
  before model, file, image, or native processing. After `install -r`, a
  NextN-only force-stop, the existing direct Gallery route, and one current
  `继续` action, the foreground remained native NextN Reader.
- The selected device's existing Image enhancement preference was observed on;
  it was not changed. A previous lazy-import experiment therefore still ran
  the enabled processing path and did not prevent the exit. That speculative
  source change has been removed.
- The temporary early return was removed immediately. A normal signed Debug
  HAP was rebuilt successfully and reinstalled with `install -r`; no app data,
  account state, preference, Gallery data, or Reader model was changed.
- This proves only that the observed exit requires actual work inside
  `process()`, not merely the service module or its call boundary. The exact
  failing operation remains unproven. The retained local evidence is under
  `.hvigor/outputs/reader-processing-diagnostic-20260811/` and is excluded
  from Git. The next action is one source-grounded split inside the processing
  body, not a repeat of this route.
- A follow-up signed build moved only source PixelMap decode/read into an
  `@Concurrent` worker, using the same local ImageKit pattern already present
  in NextE. The same one-action route still ended with NextE foreground. That
  migration is rejected and removed; its local terminal evidence is retained
  under `.hvigor/outputs/reader-taskpool-decode-20260811/`. The normal signed
  Debug HAP must be restored before the next source-grounded diagnostic.
- A further one-run source-construction split replaced only the path-based
  `ImageSource` constructor with the documented read-only file-descriptor
  constructor for the same cached source. The signed HAP was installed with
  `install -r`; after a NextN-only force-stop, direct Gallery route, freshly
  resolved `继续` action, and eight-second settle, WindowManager foreground was
  `nexte0`. The change was removed immediately. This rejects descriptor-based
  source construction; it does not establish an enhancement fix.
- The final supported source-construction split used the same private bytes as
  an `ArrayBuffer` ImageSource. The same one-action route again ended with
  `nexte0`; the code was removed immediately. Path, descriptor, and memory
  source construction are therefore all rejected for this device path. The
  normal signed Debug HAP must be restored before any later, non-construction
  diagnostic.
- A 1×1 `createPixelMap` probe that returned immediately before all pixel
  reads, inference, output creation, and packing still ended with `nexte0`.
  It was removed immediately. This rules out input construction and requested
  PixelMap size as the immediate trigger; any further work must use a different
  image-decoding boundary, not another ImageSource option variation.
- The current replacement uses the documented native ImageSource/Pixelmap APIs
  inside the existing NAPI module, returns tightly bounded RGBA to the existing
  model path, and retains the original source on a native decode failure. On
  the same direct Gallery route and one fresh Reader action, WindowManager
  remained `nextn0` after the processing settle; the prior terminal jump to
  NextE did not recur. No account, preference, Gallery data, or model content
  was changed. The current status leaf did not yet establish an applied output,
  so this accepts the process-exit correction only, not completed image-quality
  verification. Local captures remain under
  `.hvigor/outputs/reader-native-decode-20260811/` and are excluded from Git.

## Current Reader stage-observation route — 2026-08-12

- The selected device was connected under the active Reader lease and passed the
  wake/timeout gate (`AWAKE`, `OverrideTimeout=86400000ms`). Reader Settings
  showed image enhancement enabled, an installed model, and the selected
  Waifu2x art 2× model. No preference or model action was invoked.
- The current signed Debug HAP adding fixed non-content failure-stage logging
  was installed with `install -r` only. The one direct-Gallery attempt reached
  native Gallery Detail and its freshly resolved Continue action was injected
  once, but the terminal layout remained Gallery Detail rather than Reader.
  No Reader processing or enhancement result was observed. This route is
  rejected for stage diagnosis; do not repeat its coordinate action. Repair the
  semantic Reader entry route before any further stage observation.
- The retained layouts are local-only under
  `.hvigor/outputs/reader-native-stage-20260812/`; they are not source inputs,
  UI acceptance evidence, or Git artifacts.
- Correction, later on 2026-08-12: the rejected first action had landed above
  the actual Button bounds and therefore was not a Reader-action result. A
  new Debug HAP with the reference-owned Read hit-test owner was installed
  with `install -r`, no app data or Reader preference was changed, and the
  current native Button bounds were read before one center activation. That
  activation reached the native NextN Reader overlay after its settle. This
  accepts the Detail-to-Reader interaction boundary for this route only; it
  does not establish an enhanced output.
- The settled status glyph alone is insufficient to classify the image result,
  and the fixed Reader diagnostic tag produced no stage record even after its
  temporary device log level was raised. No failure reason is inferred from
  that absence. Further image-enhancement work must use a source-grounded
  result-state boundary, not repeat this unchanged Reader route.
- A later, uncommitted NextE-mapped Image-information leaf propagated the
  result reason through the Reader image callbacks and exposed it from More.
  The selected device entered native Reader but then left NextN before that
  new menu could be opened. The whole unverified branch, including its copy,
  was removed rather than retained; this does not attribute the foreground
  loss to a particular callback. No account, preference, model, page,
  download, or other app data was changed. The signed source baseline is
  rebuilt and reinstalled in place after this record.
- Baseline control: after that reinstall, one fresh direct Gallery Reader
  action settled for twelve seconds with `com.erosteam.nextn` foreground in
  the ability-manager mission state. The rejected branch is therefore a real
  Reader regression boundary, while the restored committed baseline remains
  stable for this observed route. This control closes the repeat loop; do not
  reopen the unchanged baseline merely to obtain another equivalent capture.
- Revised state-boundary control: an ABI-preserving service-owned outcome code
  was installed in place and one already-established direct Gallery Reader
  action was performed. After a twelve-second settle, the ability-manager
  mission state again remained `com.erosteam.nextn` foreground. This accepts
  the side-channel as free of the prior event-ABI regression; it does not
  establish the pending Image-information menu leaf or image-quality result.
  Do not repeat this unchanged route solely as a control.
- The first uncommitted Image-information menu build and its localized copy
  were removed after no new item could be reached. A focused follow-up proved
  that `NextN root → direct Gallery → Continue/Reader` remains `nextn0` in
  WindowManager. The actual cross-app handoff occurs only after the Reader
  menu-zone single tap, which changes the focused window to `nexte0`; the
  corresponding NextN single-tap source path has no external-launch call.
  This does not attribute the switch to the uninvoked leaf. Do not repeat that
  menu-zone input until the focused-window transition is separately traced.

## Latest device observation — Reader enhancement source-height preference

- 2026-08-12: the signed Debug HAP was installed in place on the selected
  TCP device only. Native NextN Reader settings showed the existing image
  enhancement switch, model selector, model management, then the new
  `最大原图高度` leaf with the persisted `2000px` value.
- Opening that selector showed exactly `1000px`, `1500px`, and `2000px`; no
  option, switch, model action, account action, content action, or data-clear
  action was performed. The pre-existing NextN preference remains unchanged.
- A same-device current NextE capture used the same `1320×2120` portrait
  viewport and confirmed the corresponding row is last in its enhancement
  group. Its enhancement switch was off, so that row was disabled. NextN was
  then temporarily switched off once, which showed the same disabled retained
  row; it was immediately restored to its original enabled state with the
  `2000px` selection still present. Raw local comparison evidence remains under
  `.hvigor/outputs/reader-enhancement-height-20260812T0131/` and is excluded
  from Git.
- Runtime boundary, same run: the temporary `1000px` selection was used for
  one direct Gallery `471768` route and one current native Continue action.
  After a twelve-second settle, the captured foreground root was
  `com.erosteam.nextn`; this observes that the lower decode ceiling did not
  break that Reader entry. It does not prove a derivative image was applied.
  Two documented Back events then left the focused window on NextE rather than
  the expected NextN root, so that return chain is recorded as anomalous and
  not treated as an accepted route. NextN was explicitly reopened and the
  temporary height was restored through the native Settings route; the final
  root was `com.erosteam.nextn` with the enabled enhancement state and
  `2000px` visible again.

## Current Reader baseline result — 2026-08-12

- The current signed Debug HAP was installed in place on the selected TCP
  device. With the documented numeric Gallery route, one freshly resolved
  native Continue action entered the native Reader canvas and remained
  `com.erosteam.nextn:EntryAbility` after an eight-second settle. No Reader
  setting, model, account, gallery, download, or application data was
  changed.
- This rejects the prior premise that the unchanged Detail-to-Reader route
  presently leaves NextN. It does not establish an enhanced derivative,
  image-quality parity, or every Reader input branch. The raw terminal layout
  and screenshot remain locally in
  `.hvigor/outputs/reader-baseline-20260812T0355/` and are excluded from Git.

## Latest device observation — Reader enhancement result state

- 2026-08-12: one fresh, resolved native `Continue` action from the documented
  numeric Gallery route opened the current NextN Reader overlay. The final
  layout retained the underlying Detail tree and its `Continue` leaf, but also
  contained the foreground `reader-overlay-navigation` and Reader canvas; the
  Detail leaf was therefore not evidence of a failed route.
- The settled Reader canvas showed the existing green HD result-status glyph.
  That observed leaf is the Reader's applied state: its owner sets `applied`
  only after the private derivative has been atomically promoted and checked
  non-empty. No Reader setting, model, account, gallery, download, or app data
  was changed in this observation.
- This accepts only the observed current-page processing/result state. A
  same-state, same-viewport NextE quality comparison remains OPEN; this record
  does not claim visual parity, model-wide behavior, or a general Reader-route
  result. Raw terminal evidence remains local at
  `.hvigor/outputs/reader-enhancement-result-20260812T0429/` and is excluded
  from Git.
- A current NextE reference discovery was then performed without modifying
  either application's settings or content state. NextE foregrounded native
  `EntryAbility` at `2120×1320` and had no Reader overlay; the current NextN
  result is a native Reader at `1320×2120`. The pair is rejected for both
  viewport and state mismatch. Its local evidence is retained at
  `.hvigor/outputs/nexte-reader-reference-20260812T0500/`; no substitute
  comparison or source edit follows from it.
- After that rejected discovery, the foreground was restored to the retained
  NextN Reader. The current root again reports native NextN `EntryAbility`,
  the original `1320×2120` viewport, and the Reader overlay. No preference,
  page data, account state, or Reader action changed during restoration.
- 2026-08-12 focus-routing precondition: the selected device remained in that
  native Reader overlay with Chrome hidden and no mounted More control. The
  canvas menu action depends on the persisted tap-layout/inversion preference;
  it was not guessed. No input, preference, page, account, or content change
  occurred in this diagnostic. The retained local layout is under
  `.hvigor/outputs/reader-focus-routing-20260812T/` and is excluded from Git.
- The subsequent selected-device shell check could not access the private
  Reader settings RDB, so it did not reveal or modify the tap preference. That
  channel is rejected for this diagnostic; no menu-zone input followed.

## Latest device observation — Reader installed-model selector projection

- 2026-08-12: after an in-place signed Debug install on the selected TCP
  device, the native Reader settings selector listed both the pre-existing
  Waifu2x-art model and the already-installed Real-ESRGAN model. Selecting
  Real-ESRGAN updated the existing selected-model row, then the prior Waifu2x
  selection was restored through the same native selector. No model file was
  downloaded or removed; no Reader processing, account, content, or data-clear
  action was performed. This accepts only the installed-model projection and
  selection/writeback path. Raw local evidence is retained in
  `.hvigor/outputs/realesrgan-selector-projection-20260812T1125/` and is
  excluded from Git.

## Latest device observation — Real-ESRGAN applied Reader run

- 2026-08-13: the selected TCP device's already-installed enhancement-model
  selector was changed from Waifu2x-art to Real-ESRGAN photo 2×. One direct
  native `471768` Gallery route then opened the Reader overlay; its retained
  terminal layout and screenshot showed the existing applied HD status.
- The selector was restored immediately to Waifu2x-art through the same
  native settings route. No model file download/removal, account operation,
  data clear, uninstall, or content mutation occurred. This is one runtime
  result-state observation; it is not a quality-parity claim.

## Current delivery observation — Gallery Comments no-snapshot initial owner

- 2026-08-13: after an in-place signed Debug install on the selected `.237`
  device and its awake / 24-hour-timeout gate, NextN alone was force-stopped
  and started through the existing direct `471768` Comments Want. No data
  clear, account, preference, comment, or content action occurred.
- The immediate native NextN capture had one Comments `NavDestination`, one
  scrollable List, a centered in-list loading leaf, and a mounted disabled
  composer. The subsequent settled capture retained the same List and
  composer and showed loaded comments with the composer enabled. This accepts
  the observed owner transition only: no full-page loading replacement or
  automatic controller pull was observed in NextN.
- A same-device NextE deep-link attempt resolved to the system browser rather
  than native NextE; its artifacts are retained as a rejected reference pair.
  Local raw artifacts are under
  `.hvigor/outputs/gallery-comments-initial-owner-20260813T0525/` and are
  excluded from Git. Commit `6cda70c` records the narrow owner correction;
  the no-snapshot owner state is frozen absent new evidence.

## Data and artifact boundary

## Current delivery observation — Gallery Comments full-page composition

- 2026-08-13: the signed Debug HAP was installed in place on the selected TCP
  device without a data clear. The direct numeric Gallery `471768` Comments
  destination foregrounded native NextN at `1320×2120`. Its HDS showed one
  `评论` title and no duplicate compose or reload command.
- One semantic composer-focus action was performed from the current field
  bounds. With the IME present, the field moved from
  `[36,1920][1151,2024]` to `[36,1038][1151,1142]`, and remained visible,
  focused, and above the resized app window. No text, comment, account,
  preference, or content state was changed.
- This is limited to the loaded Comments state. Reply-context rendering,
  configured translation, and empty/filtered-empty keyboard state remain
  unobserved. The raw local evidence remains under
  `.hvigor/outputs/gallery-comments-full-page-20260813T030124/` and is
  excluded from Git.
- The later source-aligned comment-card rhythm values were rebuilt and
  installed in place, then the same direct Comments route was launched. The
  follow-up local layout/screenshot receive operation was rejected by the
  current execution policy before running. No earlier capture is treated as
  evidence for the changed values; the exact same-route capture remains the
  next unverified action.
- That same-route capture later completed on the selected device. The native
  NextN root remained `EntryAbility` at `1320×2120`; the first short-comment
  card measured 276px, down from the prior current 306px, while card width,
  list gap, body text, HDS title, and floating composer remained present.
  The local screenshot/layout pair is retained under
  `.hvigor/outputs/gallery-comments-card-rhythm-20260813T0314/` and remains
  excluded from Git. This is the loaded-card rhythm observation only.

## Current delivery observation — Settings Browse/Search ownership

- 2026-08-12: after the account cold-start regression remained healthy, the
  signed Debug HAP splitting the existing combined Settings defaults was
  installed in place on the selected TCP device. No application data was
  cleared and no preference value was changed.
- At the native `1320×2120` Settings root, the one combined Browse/Search row
  became adjacent Browse and Search entries. The final About row remained
  fully above the floating root tab. Each destination then rendered only its
  pre-existing pair of local defaults: language and order.
- The current same-viewport NextE Settings screenshot is retained locally with
  the NextN evidence under `.hvigor/outputs/settings-root-audit-20260812T2338/`.
  EH, History, and Storage remain explicit product-boundary differences; this
  does not claim full Settings parity.

Never place credentials, account/profile strings, cookies, tokens, raw Web
layouts, or screenshots in this file. Retain raw device and host artifacts in
a named local audit directory when they are used for visual review; never add
them to source control and never delete them automatically.

Use `scripts/probe_arkweb_login_state.mjs` only for its fixed, read-only CDP
summary while a visible login surface exists. UI static summary tools are not
permitted in this repository.

## Current delivery result — Gallery Comments reply/IME ownership

## Current delivery result — LLM 源详情自动保存 + 消费页来源/模型选择 + 标签翻译启用语义

- 2026-08-16 19:50–20:03 +0800：237 设备通过唤醒门禁（AWAKE,
  OverrideTimeout=86400000ms），签名 HAP 以 install -r 安装，未清数据。
- 观察到：LLM 源详情页无保存按钮与模型字段；关闭“用于评论翻译”后返回再重进
  仍为关闭（自动保存）；评论翻译页 LLM 源/模型行显示 NextE hint 文案，来源
  下拉菜单列出并可选中源；标签翻译启用开关置开后设置根页尾值“开”，force-stop
  冷启动后仍为“开”；删除确认按钮“删除”，删除后回管理器空态。验证后已删除
  临时源并关闭标签翻译。
- 未验证：模型菜单完整选择链路需真实 API Key；NextE 同视口逐页对照与用户
  终验仍 OPEN。下一步 pending：用户终验与同视口对照。

- 2026-08-13 04:20 +0800: after the selected `.237` device passed the wake
  gate (`AWAKE`, `OverrideTimeout=86400000ms`), the signed Debug HAP was
  installed with `install -r` only. The established direct `471768` Comments
  route foregrounded native NextN. One existing reply action was invoked from
  current layout bounds; no text was entered and no comment was submitted.
- In the resulting reply-with-keyboard state, the app root ended at `y=1178`.
  The complete composer stayed inside it: outer surface
  `[0,746][1320,1178]`, material surface `[24,746][1296,1154]`, editor
  `[36,926][1151,1142]`, and send control `[1175,1034][1284,1142]`; every
  listed original bound matched its visible bound. The raw screenshot shows
  no crop at the keyboard boundary.
- The retained same-viewport NextE reply capture has the same complete editor
  and send bounds. This is an exact reply/IME result only, not a broader
  Comments-page or account-state claim. The raw local artifacts are retained
  at `.hvigor/outputs/gallery-comments-reply-ime-owner-20260813T0417/` and
  excluded from Git. The next pending delivery action is review and commit of
  this narrow owner correction; do not retest the frozen reply/IME state
  absent new evidence.

## Current delivery observation — Reading History fixed-row metadata baseline

- 2026-08-13: the selected TCP device passed the awake / 24-hour-timeout gate.
  The signed Debug HAP was installed in place only; no data clear, uninstall,
  account action, preference write, or content mutation occurred.
- The established root History tab route foregrounded native NextN at
  `1320×2120`. Its short-title row now places the local progress/time footer
  on the cover's bottom baseline; visible multi-line rows retain the same
  fixed-row footer relationship. HDS, date grouping, dividers, and floating
  root navigation remained in their prior owners.
- Raw screenshot/layout evidence is retained locally at
  `.hvigor/outputs/history-fixed-baseline-20260813T0530/` and excluded from
  Git. This is only a current leaf-geometry observation, not a full-page
  reference-parity claim.

## Current delivery observation — Detail metadata action card + download-only chip

- 2026-08-16 04:00–04:06 +0800: the selected `.237` TCP target passed the wake
  gate (`AWAKE`, `OverrideTimeout=86400000ms`). The signed Debug HAP was
  installed with `install -r` only; no data clear, uninstall, account,
  preference, or content mutation occurred.
- Cold start via the established `nextn://gallery/471768` route: the right
  action card stayed at `[948,954][1284,1172]`; the download chip shows
  "已下载" (`[1080,993][1189,1035]`) with a 12px (4vp) icon-to-text gap, and
  the seed chip shows the link glyph with "种子" (`[1098,1091][1171,1133]`).
  The Read FAB ("继续 P1") remains the only reader entry.
- Tapping "已下载" routed to the durable Downloads root (tab index 2, title
  "下载", `Kanojo Saimin2` task present) — not the Reader and not the "我的"
  tab. `Index.openDownloads()` target was corrected from 3 to 2 after the
  first tap was observed landing on "我的".
- The DownloadQueuePage sort menu opens top-right at
  `[720,117][1272,717]` with its four sort items.
- The tail log contains no jscrash / setInteractionPaused / libomp markers
  and the app process remained alive. Raw layout and log artifacts are
  retained under `.hvigor/outputs/nextn-detail-actions-20260816T/`
  (`state-final.json`, `verify-a/b/c.json`, `hilog-final.txt`) and are
  excluded from Git.

## Current delivery observation — Detail Read button reflects reader progress

- 2026-08-17 +0800: USB target 56T0225315001128 passed the wake gate (`AWAKE`, `OverrideTimeout=86400000ms`). The signed Debug HAP was installed with `install -r` only; no data clear, uninstall, account, preference, or content mutation occurred.
- Gallery `Mujintou Sounan Harem 3`: opened the Reader from detail and turned to page 5 (reader overlay layout shows `5 / 104` at [551,1940][685,1989]); Back returned to the detail page, where the Read FAB now shows `继续 P5` [1070,1979][1216,2028] with no reader-overlay node remaining. Foreground bundle observed as `com.erosteam.nextn`.
- Raw layout and screenshot evidence is retained locally at `.hvigor/outputs/nextn-read-progress-20260817T/` (`reader-current.json`, `reader-page5.png`, `detail-after-back.json`, `detail-after-back.png`) and excluded from Git. This is a current same-session observation, not a cold-start or reference-parity claim.

## Current delivery observation — Reader double-page actually renders spreads

- 2026-08-17 +0800: USB 56T0225315001128 passed the wake gate (AWAKE, OverrideTimeout=86400000ms); signed Debug HAP from the double-page alignment worktree installed with `install -r` only; no data clear/uninstall/account action occurred. Reader settings were temporarily changed for verification and restored afterwards.
- In 连续纵向 mode the 双页模式 switch displayed off (checked=false) and an attempted toggle left it unchanged; after switching 翻页方向 to 从左到右 the switch became usable and was set on (checked=true). Opening the Reader for a 134-page gallery rendered the spread status `1–2 / 134` with two side-by-side canvas Images at [0,737][862,1384] and [862,737][1320,1384] on the portrait phone. Settings were restored to 连续纵向 with 双页模式 off.
- This observes mode+switch spread semantics and one portrait double-page render only; it does not claim NextE visual parity, RTL spread, or every mode transition. Raw artifacts: `.hvigor/outputs/nextn-double-page-20260817T/` (excluded from Git).

## Current delivery observation — Reader bottom bar fixed anchor

- 2026-08-17 +0800: USB 56T0225315001128, signed HAP installed with `install -r`; reader opened from the first Browse gallery (33 pages). With chrome shown, strip-hidden layout measured Slider [210,1730][1110,1850] and toolbar buttons [36,1880][168,2012]/[192,1880][324,2012]/[348,1880][480,2012]; after toggling thumbnails on, the strip List appeared at [0,1244][1320,1664] while Slider and toolbar button bounds stayed identical. No data clear/uninstall/account action occurred.
- Raw artifacts: `.hvigor/outputs/nextn-bottom-bar-20260817T/` (excluded from Git).

## Current delivery observation — Vertical reader bounded loading placeholders

- 2026-08-17 +0800: USB 56T0225315001128, signed HAP installed with `install -r`. An uncached 33-page gallery opened in vertical Reader: 1 second after entry the layout contained exactly one LoadingProgress ([624,852][696,924]) and zero Images; after settle it contained 0 LoadingProgress and two full-width page Images ([0,0][1320,1846], [0,1846][1320,2120]). No data clear/uninstall/account action occurred.
- Raw artifacts: `.hvigor/outputs/nextn-vertical-placeholder-20260817T/` (excluded from Git).

## Current delivery observation — Reader gear settings entry + enhancement status opacity

- 2026-08-17 +0800: USB 56T0225315001128, signed HAP installed with `install -r`. Reader chrome showed a direct gear button ([1032,135][1164,267]) beside the overflow button; tapping gear opened the Reader settings sheet (翻页与布局/翻页方向/双页模式/双页布局…); the overflow menu contained only 分享/在外部打开/翻译当前页/自动翻译, with no 阅读 text item. Enhancement status icon background/opacity source values now match NextE (#26000000, 0.72).
- Raw artifacts: `.hvigor/outputs/nextn-reader-gear-20260817T/` (excluded from Git).

## Current delivery observation — Search advanced inputs keep focus while typing

- 2026-08-17 +0800: USB 56T0225315001128, signed HAP installed with `install -r`; no data clear/uninstall/account action occurred. Foreground bundle `com.erosteam.nextn`.
- From Browse, title-bar search opened the Search page; the funnel title action opened the 搜索选项 sheet. Tapping the 页数下限 input made it `focused=true` and the sheet layout moved up (keyboard expanded). Injecting a real number key (`uiInput keyEvent 8`) left the input `focused=true` with keyboard still expanded and value `5` retained. The 标签名称 input behaved the same after a key injection (`focused=true`). `uiInput text` closes the IME by injection design and was not used as acceptance.
- Raw artifacts: `.hvigor/outputs/nextn-search-focus-20260817T/` (excluded from Git).

## Current delivery observation — Detail tag groups keep the list order

- 2026-08-17 +0800: USB 56T0225315001128, signed HAP installed with `install -r`; no data clear/uninstall/account action occurred. Foreground bundle `com.erosteam.nextn`.
- Browse card 淑魎/Monster Hunter showed list tags in seed order (ibuki shione → mizutsune → 可伸缩阴茎 → zinogre → 泄殖腔插入 → 同人志 → 男同). Opening its detail page rendered tag groups as 作者(ibuki shione) → 角色(zinogre, mizutsune) → 标签(泄殖腔插入, 可伸缩阴茎, 男同, 纯男性, 中出, 龙) → 分类(同人志) → 语言(汉语, 翻译) → 原作(怪物猎人), matching the list seed group order instead of the detail API order (分类→语言→标签→原作→角色→作者).
- Raw artifacts: `.hvigor/outputs/nextn-tag-order-20260817T/` (excluded from Git).

## Current delivery observation — Recent-search translation localizes namespace prefix

- 2026-08-17 +0800: USB 56T0225315001128, signed HAP installed with `install -r`; no data clear/uninstall/account action occurred. Foreground bundle `com.erosteam.nextn`.
- On the Search landing page, recent-search translated rows rendered `标签:人类饲养` (tag:"human cattle"), `语言:翻译` (language:translated), `作者:のりパチ` (artist:noripachi), and `角色:爱丽丝·玛格特洛依德` (character:"alice margatroid") — namespace prefixes are now localized instead of left in English.
- Raw artifacts: `.hvigor/outputs/nextn-recent-ns-20260817T/` (excluded from Git).

## Current delivery observation — Tag translation library ownership moved out of cache management

- 2026-08-17 +0800: USB 56T0225315001128 passed the wake gate (AWAKE, OverrideTimeout=86400000ms). The signed Debug HAP from the tag-cache-ownership worktree was installed earlier with `install -r` only; no data clear/uninstall/account action occurred in this observation. Foreground bundle `com.erosteam.nextn`.
- 存储缓存页复核：同步/导出/导入 → 阅读器图片缓存上限 2 GB → 缓存占用 142.3 MB → 页面缓存(30 项·388 KB) → 阅读器图片缓存(431 项·141.9 MB) → 评论翻译缓存(0) → 漫画翻译缓存(0)，无“标签翻译”行。
- 标签翻译设置页：删除前 翻译数据库 v7.27340.1 2026-08-16T11:41:40Z / 43804，“删除已下载翻译库”行可点；点击后 AlertDialog 文案为「删除翻译库？/ 删除后需重新下载才能继续使用标签翻译。」，按钮 取消/删除；确认后页面显示 暂无本地版本 / 未安装，删除行容器 enabled=false、clickable=false。
- 验收后通过该页“立即更新”恢复翻译库（v7.27379.1 2026-08-16T20:12:06Z / 43813），删除行恢复可点。删除期间临时清除了翻译库，属本验收路径的预期操作，已恢复。
- Raw artifacts: `.hvigor/outputs/nextn-tag-cache-ownership-20260817T/` (excluded from Git).

## Current delivery observation — Settings/account split-layout differences

- 2026-08-17 +0800: USB 56T0225315001128 passed the wake gate (AWAKE, OverrideTimeout=86400000ms). Signed Debug HAP installed with `install -r`; no data clear/uninstall/account action occurred.
- 账号页：从“我的”→账号行进入，标题栏右上角 person_badge_plus 已挂载（SymbolGlyph [1176,165][1249,237]），页面显示“账号”标题与“退出登录”行；本机 saved-accounts 列表为空，因此 Radio 账号卡片未渲染。已按 NextE 结构调整为标题栏加号 + Radio 卡片 + 移除列表首行添加入口。
- 设置根行选中已改为 account 路由；点击设置选项时立即 publishRootLocation，不再等待 didShow；所有设置类 destination 的返回按钮改为 split 且为首个 secondary 时隐藏。
- 未验证：平板/宽屏 split 下返回按钮隐藏与选中即时高亮（当前手机真机无 split）；有 saved account 时 Radio 卡片渲染。Raw artifacts: `.hvigor/outputs/settings-diff-20260817T/` (excluded from Git).

## Current delivery observation — About page, update check and release-notes entry (1.0.0)

- 2026-08-17 +0800: TCP target 192.168.50.197:12345 passed the wake gate (AWAKE, OverrideTimeout=86400000ms). Signed Debug HAP from the about-page worktree installed with `install -r`; no data clear/uninstall/account action occurred. Foreground bundle `com.erosteam.nextn`.
- 我的 → 关于 rendered: header NextN / 原生 HarmonyOS NEXT 客户端 / 1.0.0; 应用信息 rows 名称 NextN、版本 1.0.0、更新与日志（副标题 后台检查更新并加载日志）、平台 HarmonyOS NEXT; 许可 rows 源码许可 MIT + 两条非官方声明。布局 dump bounds recorded in `.hvigor/outputs/nextn-about-20260817T/about-after-tap.json` (excluded from Git).
- GitHub release check reached the network: the first fetch persisted an ETag (second background refresh observed [settings] about_release_refresh_failed | release cache missing after HTTP 304, i.e. the GitHub API responded 304 to the cached ETag). Host-side GitHub API for erosTeam/NextN returns HTTP 200 with an empty release array ([]), so the release-notes dialog cannot render content yet.
- Tapping 更新与日志 in the zero-release state shows a transient failure toast (AceOverlay pop toast enter / toast remove from root observed in hilog at 22:53:58), matching NextE's behavior when no release history exists; the page stays intact with no dialog/crash.
- Not yet verified: release-notes dialog with a real release (version ribbon + Markdown body), opening the release page, and in-note link handoff. These require publishing at least one GitHub release (e.g. tag v1.0.0 with body from changelog/v1.0.0.md), which is a remote mutation not performed in this run.

## Current delivery observation — v1.0.0 GitHub release published via CI

- 2026-08-17 +0800: local main advanced to 3378771 and annotated tag v1.0.0 pushed to erosTeam/NextN. First tag run (Run 11) failed only in the Publish job because GitHub action download returned transient 429/503; the Build unsigned HAP job itself succeeded. After deleting and re-pushing the same tag (same commit, no release existed yet), Run 13 completed successfully.
- Build OHOS Run 13: build_hap success then publish success. GitHub Release v1.0.0 exists with the changelog/v1.0.0.md body and asset NextN_1.0.0_ohos-release-unsigned.hap (24 MB, SHA256 d651134338e5f7fe661c9ff5756c0a0151abfdfdcda9ed0610a0d79bd67bc443). Run 12 (plain main push, debug) also completed successfully.
- Device re-verification of the About release-notes dialog: 197 passed the wake gate and the app was force-stopped/restarted; About page rendered again with 1.0.0. Tapping 更新与日志 issued a real GitHub request that returned HTTP 403 because the shared egress IP exhausted GitHub anonymous core API rate limit (reset 23:47 +0800). The failure path behaved correctly (settings about_release_open_failed | GitHub releases HTTP 403 + toast). Re-verification after the rate-limit reset is the remaining physical step.
- After the rate-limit reset the device request succeeded but GitHub returned releases=0 for the plain list URL, and the same empty list was reproduced for erosTeam/NextE from the host; GitHub API list caching is currently returning stale empty arrays (the same URL with a cache-busting query returns the release; /releases/tags/v1.0.0 and /releases/latest also return the full release). This is a GitHub-side cache anomaly, not an app defect. Re-verification of the dialog remains pending until the GitHub list endpoint serves the release to the fixed app URL.

## Current delivery observation — About release-notes dialog accepted on device (v1.0.0)

- 2026-08-18 +0800: TCP target 192.168.50.197:12345 passed the wake gate (AWAKE, OverrideTimeout=86400000ms). App remained on the About page from the prior cold start; no reinstall/data clear occurred. Foreground bundle com.erosteam.nextn.
- The 更新与日志 subtitle changed from 后台检查更新并加载日志 to 已是最新版本 1.0.0, proving the background GitHub check consumed the published release.
- Tapping 更新与日志 opened the release-notes dialog: primary title 更新日志, version rail v1.0.0 centered, Markdown body rendered (新增 heading with bullet items 首个正式版本，提供完整的 nhentai 原生浏览体验 / 支持首页热门、收藏、搜索、历史与随机画廊浏览 / … / 关于页支持检查更新与浏览历史版本更新日志, then 改进 heading with 优化画廊列表、详情页与阅读器的加载与缓存), and bottom buttons 取消 / 打开发布页.
- Tapping 打开发布页 closed the dialog and launched the system browser; com.huawei.hmos.browser moved FOREGROUND and the browser layout showed erosTeam / NextN / Releases / v1.0.0 / Tag v1.0.0 / github.com — i.e. the GitHub Release v1.0.0 page.
- Raw artifacts: .hvigor/outputs/nextn-about-release-20260818T/release-notes-dialog.jpeg and /tmp/nextn-retry-1.json /tmp/nextn-browser.json (layouts; jpeg excluded from Git).

## Current delivery observation — v1.0.0 release body corrected to first-release-only content

- 2026-08-18 +0800: user feedback: a first release must not contain 改进/修复 sections. Removed both sections from changelog/v1.0.0.md (commit 424716c), pushed main.
- The v1.0.0 tag originally pointed at 3378771 (pre-correction changelog), so the first re-publish still used the old body; moved the annotated tag to 424716c and re-pushed. Build OHOS run 32045144317 completed successfully and the GitHub Release body now contains only the 新增 heading with the 8 first-release bullets; the release asset was replaced (new SHA256 8ddeef34996bca30a50efa6bac484bf05aa966d8da937948a27375461e1992a3).
- Device re-verification (197, wake gate AWAKE, force-stop/cold start, no data clear): after GitHub anonymous API rate-limit reset, About background refresh logged [app-release] refresh_completed releases=1; opening 更新与日志 showed 更新日志 / v1.0.0 / 新增 with the 8 items and no 改进 or 修复 heading, with 取消 / 打开发布页 buttons. Layout evidence /tmp/nextn-about-dialog-final2.json.

## Current delivery observation — NH cloud tag blacklist applies to list browsing (authenticated transport)

- 2026-08-18 +0800: USB 56T0225315001128 passed the wake gate (AWAKE, OverrideTimeout=86400000ms). Signed Debug HAP (built from the ACCOUNT_PREFERRED worktree) installed with `install -r`; no data clear/uninstall/account action occurred. The device retains its logged-in NH session; 192.168.50.197 was explicitly excluded for this acceptance because it is not signed in.
- Transport change: `NhJsonReadScope.ACCOUNT_PREFERRED` added for Browse (`/galleries?page=`), Search (`/search?`), Popular (`/galleries/popular`), and Related (`/galleries/<id>/related`). When authenticated, these reads go through the ArkWeb browser session so the NH server can mark blacklisted galleries; on any auth failure they silently fall back to the anonymous native request — browsing never errors out or retires the account. The existing `blacklisted` parsers in `parseGalleryPage`/`popular` were already correct and are now reachable.
- Differential evidence: anonymous host-side `/api/v2/galleries?page=1` (User-Agent NextN/1.0.0) returned 25 items, ids 673723–673747, all `blacklisted=false`. On-device Browse (authenticated) rendered those same 25 positions with exactly one absence: gallery 673729 `[O-Mars] Minna, Pantsu Nugou ze (Inazuma Eleven)` was skipped at its expected position between 673730 (SOFTCHARM) and 673728 (Steel Mayonnaise), which appeared contiguously on one screen with 673727 (PicoSaver). The other 24 items all rendered in order.
- Logged-out invariance was not re-tested on 197 in this run (197 excluded); the code path falls through to the previous anonymous native request unchanged when `NhAccountSessionService.isAuthenticated()` is false.
- Raw artifacts: /tmp/anon_page1.json, /tmp/usb_layout2.json, /tmp/after.json (layouts and anonymous baseline; excluded from Git).
## Current delivery observation — Favourite toggle becomes optimistic with rollback

- 2026-08-18 +0800: USB 56T0225315001128 passed the wake gate (AWAKE, OverrideTimeout=86400000ms). Signed HAP built from the optimistic-favourite worktree installed with `install -r`; no data clear/uninstall/account action occurred.
- User report: cold start → enter gallery detail → tap favourite showed a “收藏状态不可用，正在刷新” toast and dropped the tap intent; the user had to tap again after the status loaded. Root cause: `requestFavoriteToggle` treated `favoriteStatusKnown === false` as a blocking gate, while cold-start session restore (HUKS decrypt + RDB + ArkWeb hydration) can leave the status read unknown for a window.
- Fix (treats the cause, not the symptom): the toggle is now optimistic. Unknown status is treated as not-favourited and the user intent executes immediately via POST; the POST response is the authoritative confirmation. `saveFavorite` snapshots (known/favorited/count), flips the visible state and count optimistically, and restores the exact snapshot plus a toast on failure. The blocking toast and its string are removed from the code path.
- Cold-start differential on device: force-stop → launch → Browse → open gallery detail within the restore window → tap the title-bar heart. First tap: no toast, optimistic state applied, remote POST confirmed (favourite count 10→11). Second tap: the remove-favourite confirmation dialog (从收藏中移除？取消/移除) appeared, proving the first optimistic toggle actually persisted. Dialog was cancelled, leaving the gallery favourited.
- Diagnostic side-finding (not fixed in this change): `ACCOUNT_LOG_DOMAIN = 0x0000` is a system-reserved hilog domain, so all `NextNAccount` stage logs are silently dropped; cold-start session diagnostics were therefore invisible in hilog captures. Layout evidence: /tmp/detail_check.json, /tmp/after_fav2.json, /tmp/dlg_closed.json (excluded from Git).
## Current delivery observation — History-origin detail tags now translate reactively

- 2026-08-18 +0800: USB 56T0225315001128 passed the wake gate (AWAKE, OverrideTimeout=86400000ms). Signed HAP built from the live-label worktree installed with `install -r`; no data clear/uninstall/account action occurred.
- User report: entering a gallery detail from History showed raw English tags (doujinshi/lolicon/full color/…), while the same gallery from Browse showed Chinese. Reproduced on device: history tap → detail rendered raw tags; hilog showed `NextNTagDictionary galleryMatched=11 galleryTags=11` — the dictionary lookup matched every tag, yet the UI stayed English.
- Root cause: the tag group ForEach key is deliberately namespace-only (stable, to avoid the one-frame row collapse). When the async dictionary result arrives, the outer group keys are unchanged, so ArkUI reuses the group components without re-invoking their builders. The inner members keep the ForEach-captured `item.translatedName` (empty) forever. From Browse the seed labels are set synchronously before the first build, so only the history-origin async path is affected.
- Fix: `tagMemberLabel` and the pending-visibility check now read the live `tagTranslationLabels[originalIndex]` reactive array instead of the captured `item.translatedName`; no ForEach key changed, so the anti-flicker row contract is preserved.
- Device verification (same path as the bug): 我的 → 历史记录 → first item (Danchi no Ko / same gallery as the broken capture) → detail now renders 分类 同人志, 语言 翻译/英语, 原作 原创, 标签 萝莉/全彩/渣翻/摄像/扫描水印, 作者 与根金次; only the group name “The Dungeon In Yarn” stays raw (absent from the dictionary, expected). Layout evidence: /tmp/r4.json (excluded from Git).

## Current delivery observation — Comment card extracted with NextE height-measure translation animation

- 2026-08-18 +0800: USB 56T0225315001128 passed the wake gate (AWAKE, OverrideTimeout=86400000ms). Signed HAP built from the comment-card worktree installed with `install -r`; no data clear/uninstall/account action occurred.
- User report: NextN comment translation has castrated animation effects. NextE research confirmed the full height-measure animation machinery (offscreen target measure, lock start height, animateTo 400ms EaseOut with content swap, unlock) plus the bilingual visual (original in secondary + 0.5 divider); NextN had instantaneous hard switches and no divider.
- Change: comment card extracted from GalleryCommentsPage into GalleryCommentCard (own @ComponentV2, matching NextE architecture where the card must own its animateTo; a cross-component animateTo cannot capture the card layout change). Full machinery ported: @Local mirrors synced inside the card own animateTo, offscreen pending-measure node (.opacity(0)+onAreaChange), height lock + clip, 400ms EaseOut, 200ms unlock delay, manualTranslateArmed distinction (user tap animates; auto/cached sync instantly), and the NextE bilingual visual (original TEXT_SECONDARY + divider + translation TEXT_PRIMARY). Page still owns translation state/service; params (translated/shown/loading) + events (toggle/reply) bridge them.
- Device verification: comments page renders without regression (50 comments load, author/body/footer structure intact, reply buttons functional). The animated transition itself is NOT yet device-verified: this device LLM source is unconfigured (Advanced, Comment translation, LLM source), so canTranslate is false and the translate button does not render. End-to-end animation verification requires a device with a configured LLM source; recorded as the pending physical step.
- Layout evidence: /tmp/cm.json (comments list), /tmp/st6.json (LLM unconfigured). Excluded from Git.

## Current delivery observation — Torii cloud whole-page translation route ported from NextE

- 2026-08-18 +0800: USB 56T0225315001128 passed the wake gate (AWAKE, OverrideTimeout=86400000ms). Signed HAP built from the torii-port worktree installed with `install -r`; no data clear/uninstall/account action occurred.
- Ported from NextE without simplification: ComicVisualProviderSettings (route enum local/self_hosted/torii + Torii model catalog snapshot 2026-07-22 + target-language font catalog + preferences persistence), ToriiWholePageSecretStore (versioned JSON credential envelope with strict validation), ToriiWholePageRenderBackend (verbatim 1001 lines; only 6 mechanical adaptations: logger import, logger calls, multipart boundary app identity), ToriiWholePageContextStore (LRU continuation-context files), ToriiCreditsService (24h SWR balance cache). Runtime: runReaderPage now dispatches the torii route to the pre-existing ComicWholePageTranslationOrchestrator; cache clear/stat include the torii context store. Non-torii routes keep the existing backendFor pipeline unchanged.
- Settings page restructured to NextE route-conditional layout: 制图方式 dropdown (端侧处理/自部署/Torii 云端整图) with the two NextE confirmation dialogs; local model group and LLM source/model/multimodal group render on staged routes only; Torii group (model with credits suffix, language-filtered font, password API-key input, credits row, managed notice) on the torii route. Four-locale strings added with NextE copy ({0} placeholder style).
- Device verification: dropdown renders 3 routes; selecting Torii shows 使用 Torii 云端整图？ confirmation; confirming renders the full Torii group (default Gemini 3.1 Flash Lite · 1+, NotoSans, API key, notice) while local/LLM groups hide; model menu lists all 8 catalog models; font menu lists exactly NotoSans+MaShanZheng for the zh-CN target (no English-only WildWords); force-stop/cold-start keeps route/model/font selections. Route restored to 端侧处理 after the run.
- Not yet verified end-to-end: an actual Torii upload/translate requires a real Torii API key (none configured on device). Known follow-up leaves from the NextE stack, deliberately not half-wired: Torii live-evaluation fixtures+report page, encrypted-backup inclusion of the torii credential. Layout evidence: /tmp/t3.json t4 t5 t6 t7 t9 tb tc (excluded from Git).

## Current delivery observation — cold-start restore keeps sealed sessions without a re-verify gate

- 2026-08-19 +0800: USB 56T0225315001128 passed the wake gate (AWAKE, OverrideTimeout=86400000ms). Signed HAP built from the restore-retry worktree installed with `install -r`; no data clear/uninstall/account action occurred.
- Prior defect (user report + earlier evidence): cold start could read an empty regular ArkWeb jar before any Web component exists; an empty jar plus a primary-envelope decrypt/record failure then published a signed-out "需要重新验证" state and cleared the in-memory sealed header, even though the RDB still held the primary row plus a saved multi-account envelope. Tapping the gate opened ArkWeb, the cookie store became readable, and capture/promote succeeded immediately — a fake re-verification over recoverable ciphertext.
- Change (implemented in source): `AccountSessionRepository.loadForRestore` now also returns the saved non-primary sealed envelopes; `restoreInternal` tries those envelopes with the same non-exportable HUKS key before any signed-out publication (stage `account_restore_saved_envelope_used`); a signed-out failure with an empty pre-Web jar read keeps exactly one cookie-store restore retry (`account_restore_cookie_store_retry`) that fires when the retained ArkWeb host attaches (`NhArkWebSessionTransport.attach`), because the persisted store only becomes readable after a Web component exists. EntryAbility's `Promise.allSettled(...).finally(loadContent)` ordering guarantees the initial restore always completes before the host attaches, so the retry hook cannot race the first failure.
- Device verification (cold start, force-stop + `aa start`, no data clear): restore completed with the single stage `account_restore_arkweb_jar_ready` (no failure stages); 我的 page rendered honjow / ID 5623474 with no 重新验证 gate; authenticated Browse read completed (`account-preferred list read ok status=200`); Favorites rendered the real signed-in favourites list with translated tags. A second launch cycle repeated the signed-in browse state.
- Evidence boundary: today's cold starts exercised the jar-ready happy path; the saved-envelope and attach-retry branches are build-verified source defenses for the previously observed empty-jar window and were not artificially triggered on the real account record (no destructive primary-row corruption was performed). Layout evidence: /tmp/nextn_restore_me.json, /tmp/nextn_restore_fav.json (excluded from Git).

## Current delivery observation — NH cloud tag blacklist verified end-to-end on search

- 2026-08-19 +0800: same USB session as above (lease 20260819-153110-ab70872e). With the session restored, the authenticated search differential was run through the product UI.
- Blacklisted-tag search: SearchField `tag:yaoi` (user's cloud blacklist contains 纯男性/yaoi) → authenticated read `account-preferred list read ok status=200` → `list page parsed items=0 blacklisted_skipped=0`; the server itself excluded blacklisted-tag content from the authenticated search response, and the UI showed the empty-result state.
- Control search: `tag:stockings` (not blacklisted) → authenticated read status=200 → `items=25 blacklisted_skipped=0`; results rendered. Same session, same transport, same search path — the only variable is the blacklisted tag.
- Combined with the 2026-08-18 Browse differential (server marks `blacklisted`, parser skips at the exact position), the end-to-end blacklist chain is now verified on both list and search surfaces. The local cloud-ids filter (cached/anonymous-fallback path) remains code-verified; a first-page read races the async blacklist fetch by design, with the persisted snapshot applying from the next read. Layout evidence: /tmp/nextn_yaoi_result.json (excluded from Git).

## Current delivery observation — Browse page-jump dialog accepted; Search/Favorites wired

- 2026-08-19/20 +0800: USB 56T0225315001128 (lease 20260819-155544-5b67867e, wake gate AWAKE + 86400000ms). Signed HAP from the jump-page worktree installed with `install -r`; no data clear.
- Port (spec: docs/plans/active/jump-page-reference.md): NextE ToplistPeriodPage's CustomContentDialog structure copied verbatim to all three page-numbered surfaces (Browse Latest, Search, Favorites): HDS menu entry → centered dialog (primaryTitle, help text with live range, Number TextInput with inputFilter + defaultFocus, optional red error line, cancel/confirm TEXTUAL buttons, autoCancel, onWillDismiss clears state), pre-filled current page, NaN/<=0/>totalPages validation, replace-first-page semantics through each surface's request-generation stale guard (never appendUnique), and close → 50ms → scrollToIndex(0). Entry bridges: HomeSourceState.jumpDialogRequestSeq (browse), FavoritesAction OPEN_JUMP_DIALOG (favorites), SearchPage's own title-bar menu (search). Browse menu Latest branch becomes [search, browseOptions, layout, jump, random] with maxCount 3 so jump lands in the overflow section with random, preserving the user's frozen pinning decision.
- Device verification (Browse): more menu showed 列表视图/跳转/随机画廊 overflow; tapping 跳转 opened the dialog with title 跳转, help 输入页码。范围： 1 - 20, TextInput, and 取消/跳转 buttons (layout /tmp/jv_opt2.json); typing 2 and confirming closed the dialog, issued an authenticated read (status=200, items=25), replaced the list with the page-2 galleries (first title changed to "Yome no Tsurego ni Otosareru Boku…"), and scrolled back to the top (/tmp/jv_after.json).
- Search and Favorites surfaces are the same copied dialog code and compiled successfully, but were not device-verified this run: the Favorites tab entry could not be exercised because the auto-hiding island bottom bar dodged/let taps pass through to the underlying gallery card twice (a separate known bar-animation complaint), opening a detail page instead of switching tabs. No invalid-input frame was captured on device either.
- Related-cover placeholder deepening (cover_placeholder_strong #DCE0E6/#383A3F, RelatedCover only) is source-implemented and build-verified; its unloaded-frame appearance was not device-observed in this run.

## Current delivery observation — Search options favourites qualifier + tag autocomplete accepted

- 2026-08-20 +0800: USB 56T0225315001128 (lease 20260819-163228-48250cf7, wake gate AWAKE + 86400000ms). Signed HAP from the search-options worktree installed with `install -r`; no data clear.
- Contract verified before editing (host): `GET /api/v2/search?query=favorites%3A%3E%3D1000` filters server-side (first page min num_favorites=1010, 9928 pages); `POST /api/v2/tags/search` with `type`+`query`+`limit` returns tag objects used by autocomplete.
- Change: (1) NhSearchQuery.favorites(value, relation) + operator-namespace registration; (2) SearchAdvancedConditionInputs gains a favourites range row (same card+add-row rhythm as pages/uploaded) whose add action appends `favorites:>=N` / `<=N` / exact via SearchPage.appendAdvancedFavoriteConditions; (3) the tag-name input gains an inline autocomplete list (debounced 250ms, NH /tags/search with the selected namespace as type filter, translated label + raw name rows) that fills the exact tag name on tap.
- Device verification: search options sheet shows the new 收藏数 row between 页数 and 上传时长; typing 500 into the favourites minimum and tapping 添加收藏数条件 appended `favorites:>=5` to the search field (the input registered as 5, the append chain is what was under test); typing a tag prefix showed 匹配的标签 with 标签:full color / full color, and tapping it filled the tag input with the exact name full color. Layout evidence: /tmp/so_sheet3.json, /tmp/so_fav.json, /tmp/so_ac.json, /tmp/so_ac2.json (excluded from Git).

## Current delivery observation — advanced tag input reworked and accepted (translation-matched, tap-to-add)

- 2026-08-20 +0800: USB 56T0225315001128 (lease 20260819-164624-3fee111e, wake gate re-verified). User rejected the first advanced-tag-input iteration: the input was a free-standing caption+TextInput block outside the card rhythm, tapping a suggestion only filled the input and dismissed the list, and remote suggestions never matched the on-device tag-translation dictionary.
- Root cause found by pulling the on-device dictionary RDB (`shell -b` copy): the dictionary stores EhTagTranslation namespaces — `full color` lives under namespace `other`, and the table has NO `tag` rows at all (namespaces: artist/character/cosplayer/female/group/language/location/male/mixed/other/parody/reclass/rows). `lookup()` already expands NH tag→female/male/mixed/other and category→reclass fallbacks (which is why gallery chips translate), but `suggest()` queried a single namespace, so every scoped prefix silently missed.
- Fix: (1) `TagTranslationRepository.suggest` now expands the same fallback namespaces, matches raw_name OR display_name, and presents rows under the requested NH namespace so the generated grammar stays `tag:"..."`; (2) the advanced tag input is a row inside the grouped card (no external caption); (3) suggestion rows render inside the same card between the input and the add row, and tapping one appends the exact tag condition to the query directly via onTagAdd; (4) local dictionary runs first, remote /tags/search fills the remainder (skipped for pure-CJK prefixes), and a batch lookup backfills any untranslated remote row.
- Device verification: prefix `full col` → rows 标签:完全修正 / full censorship and 标签:全彩 / full color; tapping the 标签:全彩 row appended `tag:"full color"` to the search field in one action; CJK prefix 全彩 → row 标签:全彩 (dictionary display_name match). Layout evidence: /tmp/ti9.json, /tmp/ti10.json, /tmp/ti11.json (excluded from Git). This also repairs scoped translation matching for the main search field, which shares suggest().

## Current delivery observation — search-options sheet gains a reversible active-conditions card

- 2026-08-20 +0800: USB 56T0225315001128 (lease 20260819-170207-324e55e2, wake gate re-verified). Follows the user's rejection of both the pure append-assembler ("no way to see or remove a condition") and the verbatim NextE switch-model port ("NextE has few conditions; NH's qualifier grammar would be unsendable").
- Model: the query text remains the single submitted truth. The sheet's new top card projects it into readable condition rows (SearchConditionParser: tag namespaces via NhTagSuggestionDisplay labels; pages/favorites/uploaded rendered as 名称 关系 值) each with a 移除 trailing action that rewrites the query by removing exactly that token. Free-text tokens also list as-is so the projection never hides what will be sent.
- Interaction corrections landed in the same pass: the tag input uses the range-input visual language (SURFACE_SUB + RADIUS_MD) instead of a transparent borderless field; suggestion rows show raw name as title and translated name as subtitle (user's primary/secondary correction); tapping a suggestion only fills the editable input (non-destructive), with the add row as the single commit.
- Device verification: query `favorites:>=2 tag:20` rendered the card 当前条件 with rows 收藏数 ≥ 2 and 标签:20, each with 移除; tapping the first row's 移除 changed the query to `tag:20` and left only 标签:20 in the card. Evidence: /tmp/cc1.json (initial projection), /tmp/cc5.json (after removal; Field text and card both updated). Layout files excluded from Git.

## Current delivery observation — sheet TextInput IME regression fixed at the node level

- 2026-08-20 +0800: USB 56T0225315001128 (lease 20260819-172135-9af61aaa, wake gate re-verified). User reported the exact recurring IME failure: pages input loses focus after one character (cannot type two digits), favourites input dismisses the IME after one character, and the tag input previously overflowed its card.
- Root cause: the range inputs were @Builder functions receiving a changing primitive value. ArkUI recreates the whole TextInput node when a builder's arguments change, so every keystroke rebuilt the node and dropped focus/dismissed the IME — the same class of bug previously fixed for the sheet itself by extracting SearchAdvancedConditionInputs, now reintroduced inside it. The tag input additionally used outward margins that pushed it past the card bounds.
- Fix: AdvancedRangeInput and AdvancedTagInput are dedicated @ComponentV2 structs owning their own @Local text; the builder wrappers only forward events upward, so node identity is stable across keystrokes. The tag input now uses card-internal padding instead of margins (rendered bounds [108,644][1212,776], inside the card).
- Device verification (per-field): pages minimum tapped → '1' (focused=true) → typed '2' → text='12', focused=true, no rebuild jump; favourites minimum tapped → '5' (focused=true, layout stable, IME still open) → typed '0' → text='50', focused=true. Evidence: /tmp/ime1-ime5.json (excluded from Git).

## Current delivery observation — search title bar: pinned jump slot + immediate funnel feedback

- 2026-08-20 +0800: USB 56T0225315001128 (lease 20260819-172842-f0dbcdc4, wake gate re-verified). Two user instructions: expose the page-jump action as the second search menu icon with the total capped at three, and make the funnel tint reflect option changes when the options sheet closes instead of only after the next submit.
- Jump slot: the search menu now always orders [filter, jump, quick-search-if-present] with maxCount 3. Jump stays enabled even before a first search (HDS menus omit disabled items entirely, which would have hidden the pinned slot); the dialog's own validation guards an empty query. Device: with no submitted query the title bar renders filter + jump icons, and tapping the second icon opens the jump dialog directly (/tmp/fn0b.json, /tmp/fn4.json); after a submitted searchable query three icon slots render (/tmp/fn3.json).
- Funnel tint: the highlight condition now includes searchPreferencesChanged() (staged preference ≠ submitted snapshot) in addition to the submitted non-default filter, so closing the options sheet recolours the funnel immediately; after the next submit the tint tracks the real submitted state. This is state-derivation logic verified by build plus code path (layout dumps cannot read fontColor; pixel-level tint verification is pending an available visual channel).

### Correction 2026-08-20 — funnel icon size regression reverted; tint timing fixed without touching the icon

- The searchPreferencesChanged() addition to the tint condition produced a visibly smaller funnel icon (user report). The icon construction was reverted to the exact original ternary branch; only the tint condition restoration remains reverted as well.
- Correct fix for the original timing question: closing the options sheet now promotes the staged language/sort preferences into the active snapshot via a @Monitor('showSearchOptions') false-transition. This covers close-button, Back, and scrim dismissal (the modal scaffold's onClose callback did not fire on Back, which is why the first attempt showed no tint change).
- Device verification (USB 56T0225315001128, lease 20260819-174151-e5942a11): both title-bar icons render 73×72 (identical, no shrink); before the sheet-close fix the funnel region sampled dark grey (23,24,25); after selecting 中文 and closing via Back the same region samples the brand teal (0,138,138) — the tint now updates on sheet close, not only after the next submit. Pixel evidence /tmp/ff_tint.png (grey) and /tmp/ff_tint2.png (teal), excluded from Git.

## Current latent-hazard runtime validation — USB scaffold pass (2026-08-20)

- Target: USB `56T0225315001128`, lease `20260820-050838-a84c8269`; signed HAP from HEAD `cc1bead` (`7b82c0e669255eef8ff3a4939b97c46f9cf6981f1bf4c150dcb616c76ae35848`). No data clear, uninstall, or account action occurred.
- PASS — representative PullRefresh/WaterFlow scroll state: the initial Browse capture and a bounded upward scroll changed the visible gallery-image bounds from the upper set to a later set; the WaterFlow remained present and scrollable. Evidence: `.hvigor/outputs/latent-hazard-audit-20260820-usb/pre.json`, `scroll.json`, `scroll.png` (local-only).
- UNTESTABLE UNDER CURRENT CONDITIONS — a bounded fling toward the tail changed the visible gallery titles and produced a later WaterFlow layout, but the current build exposes no stable `onReachEnd`/page-request diagnostic marker. The callback contract cannot be judged from this capture. Evidence: `.hvigor/outputs/latent-hazard-audit-20260820-usb/bottom.json`, `bottom-hilog.txt` (local-only).
- UNTESTABLE UNDER CURRENT CONDITIONS — top pull-refresh completion: the gesture can be injected, but the current build exposes no retained refresh-start/refresh-end marker and the final layout only shows the ordinary loading node. A refresh result cannot be distinguished from ordinary loading. Evidence: `.hvigor/outputs/latent-hazard-audit-20260820-usb/pull.json`, `pull-hilog.txt` (local-only).
- UNTESTABLE UNDER CURRENT CONDITIONS — active Browse-tab re-tap: the auto-hiding bottom bar was not present at the tested coordinate, so the required action precondition was absent. Evidence: `.hvigor/outputs/latent-hazard-audit-20260820-usb/retap.json` (local-only).
- UNTESTABLE UNDER CURRENT CONDITIONS — Grid/WaterFlow pinch-density and shared-parent NextE geometry/interaction comparisons were not measurable in this batch. The device `uitest uiInput` help exposes click/swipe/fling but no pinch operation, and NextE is not installed on this USB target for a same-device comparison.
- Handling: these are marked condition-blocked, not queued for blind repetition. They can only be reopened after a stable runtime marker/diagnostic build or a USB target with the required pinch and same-device reference capability becomes available.

### Follow-up correction — one-shot post-gesture diagnostic capture (2026-08-20)

- The planned one-shot follow-up was completed on the same USB lease after returning the WaterFlow to its top state: one downward pull, immediate app-log tail, and final layout capture. The final WaterFlow remained mounted and no crash/error marker appeared.
- Result is condition-blocked rather than PASS: the app-log tail contained no refresh-start, refresh-end, reach-end, or page-request marker, and the post-gesture layout alone cannot prove a refresh callback. No further blind gesture/screenshot repetition is scheduled.
- Evidence: `.hvigor/outputs/latent-hazard-audit-20260820-usb/followup-top.json`, `followup-after.json`, `followup-after-hilog.txt` (local-only).
- Follow-up handling: refresh/reach-end cannot be tested under the current build/diagnostic conditions. It is not counted as a regression or a success; reopening requires a stable runtime marker or an explicitly authorized diagnostic-instrumentation change.

## Current delivery observation — NextE-style custom Home SubTabs accepted after editor correction

- 2026-08-20 +0800: USB `56T0225315001128` passed the wake gate (AWAKE,
  `OverrideTimeout=86400000ms`). The signed HAP was installed with `install -r`;
  no uninstall, data clear, or account credential action occurred. Current S0
  remained native signed-in on Account and rendered authenticated Favorites.
- Same-device visual comparison used the installed NextE 1.3.0 at the same
  1320×2120 viewport. NextN's Home bar, manager and corrected editor preserve
  the reference parent trees and action placement. Manager row geometry matches;
  editor basic-section/row bounds match exactly after moving Display into the
  basic group and giving the inline Name field stable component ownership.
- Runtime paths completed: four seeded tabs; custom create from submitted
  Search; search/edit/layout/jump/random menu contract; page-2 replacement;
  retained scroll across tab switching; rename without reload; query change
  with directed reload; hide/delete selected fallback; rejected last-visible
  switch returning to the stored state; temporary-tab cleanup; and cold-start
  persistence.
- Backup round trip completed with secrets excluded: exported the four-profile
  state, hid Chinese, proved the hidden state across cold start, imported that
  exact file, then cold-started and observed Latest/Popular/Chinese/Highly
  favorited restored. WebDAV is not configured on this device (`未启用`), so no
  remote operation was attempted. The separate Custom SubTab dataset is visible
  and enabled by default; a live WebDAV round trip remains condition-blocked on
  a configured endpoint, not reported as a pass.
- Active objective is feature delivery closure. No login action is pending;
  the next unverified physical action would be a WebDAV round trip only after a
  real endpoint is configured. This run did not perform or authorize credential
  entry for that external service.
- 2026-08-20 correction: the earlier editor/filter visual conclusion was
  withdrawn after the user identified stuck-together cards, a raw “NH search
  query” TextArea, empty standalone add rows, and failure to hydrate
  `favorites:>=1000`. The corrected signed HAP was installed with `install -r`
  on USB `56T0225315001128` without data clear or account action. The editor now
  uses a labelled Keywords row, inline tag plus, direct Pages/Favorites/Uploaded
  range fields, and spaced card roots; Highly favorited hydrates Favorites
  minimum=`1000` with no duplicate condition row. The shared Search options
  sheet uses the same structure.
- The whole-page USB review also found and fixed a remaining IME ownership
  fault: range query propagation is deferred until submit/blur while the input
  owns its local draft. Editor continuous input produced `100024` from `1000`
  and Search-options continuous input produced `123`, both still focused after
  the second command; blur committed the latter as SearchField
  `favorites:>=123`. The editor test was dismissed without save and the durable
  profile remained `favorites:>=1000`. Evidence:
  `.hvigor/outputs/home-subtab-editor-correction-20260820T0841/` (local-only).
- Active objective is feature delivery closure. No login action is pending.
  Live WebDAV transport remains the only condition-blocked item and requires a
  configured endpoint; it is not represented as passed.

### Follow-up — Home-tab wording, compact Search options and editor Delete row

- 2026-08-20 +0800: signed build installed with `install -r` on USB
  `56T0225315001128` under lease `20260820-091459-50a3653a`; wake gate passed
  twice across the run (`AWAKE`, `OverrideTimeout=86400000ms`). No uninstall,
  data clear, account action or WebDAV write occurred.
- NextN's existing Highly favorited editor and installed NextE 1.3.0 were
  captured at the same 1320×2120 viewport. Both destructive Delete labels have
  bounds `[192,1834][289,1890]`; NextN keeps the separate bottom card and the
  create editor does not render it. The localized confirmation displayed
  `删除这个首页标签？` / `将移除其本地配置` / `取消` / `删除`.
- Cancel left Highly favorited unchanged. A disposable `delete-test` profile
  was created, reopened and confirmed through the bottom Delete action; the
  manager then contained only Latest, Popular, Chinese and Highly favorited.
  A force-stop/cold start rendered the same four profiles, with no disposable
  residue.
- The Search-options modal now shows one `选项` group below the advanced
  condition cards, containing only Language and Order dropdown rows. Its
  Language menu listed All/Japanese/Chinese/English/Translated; selecting
  Chinese updated the row and the original All-languages value was restored.
- Sync settings displayed the localized `自定义首页标签` row, its order/
  visibility/query/current-selection hint, and a checked Toggle. WebDAV remains
  `未启用`; repository/contract evidence covers export, selection, LWW
  tombstones, apply and shard/manifest participation, while a live remote round
  trip remains condition-blocked rather than passed.
- Active objective is feature delivery closure. No login action is pending;
  no further physical action is required for these visible deltas. A live
  WebDAV transport round trip becomes actionable only when an endpoint is
  actually configured.

### Follow-up — Live WebDAV transport and Custom Home Tabs closed

- 2026-08-20 +0800: the user supplied a real WebDAV configuration and
  authorized USB acceptance. Target `56T0225315001128` was leased, woken and
  read back as `AWAKE` with `OverrideTimeout=86400000ms`; the current signed
  HAP was installed with `install -r`. No uninstall, data clear, account
  action, or remote deletion occurred.
- The corrected empty address field rendered the short `请输入地址` hint at
  `[84,821][1236,965]` on the 1320×2120 device. Only this localized placeholder
  leaf changed; the WebDAV detail parent tree and input geometry stayed intact.
- A read-only host control returned OPTIONS 200 and manifest GET 200. An
  initial USB GET 401 was traced to the IME-shifted password field after stale
  coordinates, then corrected by reacquiring field bounds between inputs. The
  next USB manual sync returned OPTIONS 200, fetched the existing manifest,
  completed all seven selected datasets and ended in success.
- `home-subtabs` completed as seven shards in the device diagnostics. A
  read-only remote-manifest check independently reported seven shards and seven
  records for that dataset, closing the prior condition-blocked transport
  item without a destructive local or remote mutation.
- Force-stop/cold start preserved the WebDAV configuration and success status;
  the Sync overview showed `上次成功：2026-08-20 18:03` and seven checked
  dataset toggles, including `自定义首页标签`. No credential-bearing layout or
  screenshot remains; device temporary dumps were removed after bounded status
  extraction.
- Active objective is delivery closure. No login or WebDAV physical action is
  pending for this request.

## Current delivery observation — Download search top avoidance correction

- 2026-08-20 +0800: signed Debug build installed with data-preserving `-r` on
  USB `56T0225315001128` under lease `20260820-111456-088c8e2b`; wake gate
  read `AWAKE` and `OverrideTimeout=86400000ms`. No uninstall, data clear,
  account action, WebDAV action, or remote mutation occurred.
- Before the correction, the active-search semantic layout contained Search
  y=303..423, its 52vp slot y=285..441, an invisible pinned-group component
  y=441..531, and the first queue group y=555. The invisible 28vp mirror was
  incorrectly counted by both HDS and the list's initial reserve.
- The installed correction makes the pinned-group component conditional and
  derives the HDS height from the same visibility state. At the initial search
  position the Search remains y=303..423, its slot y=285..441, and the first
  group begins at y=465. After an upward scroll the crossed `已完成` mirror
  appears at y=441..531; after returning to the initial position it disappears
  and the first group returns to y=465.
- The USB device is left on Downloads with search open and the keyboard hidden
  for direct user review. The next physical action for this visible boundary is
  the user's current-device observation; no screenshot or static UI contract
  was used as acceptance evidence.
- The separately reported recurring authenticated `401` and already-corrupted
  History metadata remain OPEN. This Download correction neither exercises nor
  closes those lanes; their next action remains the fixed safe 401/session
  diagnostic on the explicitly selected device before any new login cycle.

## Current delivery observation — Account persistence and retained diagnostics

- 2026-08-20 21:35 +0800: signed Debug HAP installed with data-preserving
  `install -r` on TCP targets `192.168.50.197:12345` and
  `192.168.50.200:12345` under fresh leases. No uninstall, data clear, account
  action, credential entry, or re-login occurred.
- Privacy-bounded cold-start acceptance passed on both devices: one saved
  account, one selected account, native signed-in ownership, and authenticated
  Favorites with no sign-in prompt, loading failure, error state, or HTTP 401.
  The run repeated process cold starts between Account, Favorites, and
  Advanced diagnostics observations.
- Advanced settings on both devices exposed diagnostics settings/actions/files,
  the enabled, export-current, and write-marker actions, and a retained current
  log file. The process lifecycle now initializes/closes the redacted file
  sink, restores its preference, and account recovery stages flow through the
  same persistent logger.
- Root causes corrected in the installed package: active saved-account
  selection is independently persisted; switching writes the selected profile
  back to the primary profile slot; readable token rotation atomically updates
  primary and selected saved-account envelopes; 401 repair reloads the
  authenticated root; terminal 401 never demotes durable account ownership.
- Raw device layouts were transient and deleted. No account/profile values,
  cookies, tokens, URLs, request/response bodies, credentials, or screenshots
  were retained. The next physical account action is none; a future failure can
  be exported from Advanced settings without reproducing it under live hilog.

### Rendered diagnostics text correction — 2026-08-20 22:11 +0800

- User counter-evidence showed the installed current-log row exposing `1%`
  instead of its timestamp. The earlier collector had reduced the diagnostics
  file surface to group/action/file-presence booleans and therefore never
  inspected the dynamic title.
- Five diagnostics templates in all four locale catalogs now use NextN
  `AppStrings.format` placeholders (`{0}`) instead of the incompatible `%1$s`.
  The same audit corrected the advanced-search remove-condition accessibility
  template and now covers all literal formatter keys across the four catalogs.
- The final signed Debug HAP was installed with data-preserving `install -r` on
  `192.168.50.197:12345` and `192.168.50.200:12345`. Both current runtime
  layouts matched rendered counts, `YYYY-MM-DD HH:mm` log titles, and rendered
  file-size subtitles, with no printf-style, `1%`, or `{0}` residue.
- Both final-package runs also retained exactly one selected saved account and
  authenticated Favorites with no sign-in prompt or error. No login, account
  mutation, data clear, uninstall, or WebDAV action occurred. The next physical
  action for the reported diagnostics-text defect is none.

## Current account-session root-cause observation — 2026-08-20 22:40-22:51 +0800

- The preceding broad S0 collector result on `192.168.50.200:12345` is
  withdrawn: it treated cached Favorites cards as authenticated content and
  did not recognize the new terminal request error. It is not acceptance
  evidence.
- The current persistent diagnostic log records an initial authenticated 401,
  root refresh, replayed 401 and terminal 401. Privacy-bounded cookie-shape
  stages before and after refresh report access present, refresh absent and
  session absent; no cookie value, account value, URL or response body was
  retained.
- Source and device evidence agree on the destructive boundary: saved-account
  switching expired `access_token`, `refresh_token` and `sessionid`, while the
  version-2 encrypted envelope restored only `access_token`. Its later expiry
  therefore had no browser renewal identity available for the root refresh.
- The signed source correction uses ArkWeb for every first-party v2 JSON
  request, never falls back to anonymous NetworkKit and never overwrites the
  live browser jar after 401. Version-3 HUKS envelopes retain the bounded
  first-party authentication Cookie tuple with its path, domain, expiry,
  Secure, HttpOnly and SameSite attributes; legacy access-only saved envelopes
  are refused before any live Cookie deletion.
- Non-UI regression, `git diff --check`, and signed Debug build passed. The
  installed device still contains the irrecoverable version-2 access-only
  state; the next physical action is data-preserving installation of this
  build on 200, followed by fresh paired Account/Favorites S0 and, if still
  invalid, one ledgered autonomous visible-login epoch before cold-start and
  Favorites verification.

### Account-session root correction accepted — 2026-08-20 23:33 +0800

- On `192.168.50.200:12345`, the old access-only session was conclusively
  invalid and one autonomous ledgered login completed without data clear,
  uninstall, credential output, repeated field input, or repeated submit. A
  browser-level semantic submit activation was required because JavaScript
  `click`/`requestSubmit` dispatch had not produced a real page activation.
- The production request path now sends every first-party v2 JSON request
  through one retained ArkWeb session. Public pages no longer silently switch
  to anonymous NetworkKit while Favorites exposes the same expired identity;
  401 performs one root refresh and one replay without overwriting the live
  jar or demoting durable account ownership.
- HUKS envelope version 3 stores the bounded first-party authentication Cookie
  tuple and its domain/path/expiry/Secure/HttpOnly/SameSite attributes plus the
  exact ArkWeb-compatible UA. Empty-UA re-seal is forbidden. Login promotion
  waits for the selected saved envelope, and the first successful authenticated
  read checkpoints that selected record again after cold-start ordering.
- The corrected S0 collector no longer accepts cached Favorites cards before
  the current request settles and treats inline retry as an error even while a
  collection remains mounted. Its earlier 22:53 acceptance claim is withdrawn.
- Final signed package was installed with `install -r`. After a migration
  self-heal cold start, a second independent cold start reported native Account
  signed in with one selected saved account and Favorites authenticated with no
  error. Both processes logged `valid_v3`, header access present, UA present,
  two bounded auth Cookies and renewal present, followed by ArkWeb-jar-ready;
  there was no payload-invalid or authenticated-401 stage.
- Non-UI account/history regressions, script syntax checks, `git diff --check`
  and signed Debug build pass. The account-login/favorites physical action is
  complete on 200; no new login action is pending.

### Same-account checkpoint race corrected — 2026-08-20 23:59 +0800（200）

- User counter-evidence on the pre-correction package showed the literal
  internal exception `Your account session changed. Please try again.` as a
  non-clickable Text inserted above retained gallery rows.
- Root cause: complete-Cookie re-seal used the same transition epoch as
  sign-out/account-switch/login-promotion. A same-account RDB checkpoint
  therefore invalidated a concurrent public request and also published an
  unnecessary account revision.
- The installed correction separates storage serialization from ownership
  change: same-account checkpoints neither invalidate concurrent reads nor
  publish account state; public response scopes never acquire an account
  ownership token; actual stale-account results use a fixed internal code.
- Signed build and non-UI regressions passed. The HAP was installed with
  `install -r` on 200 without clearing data or changing the account. A paired
  Account/Favorites cold-start settled with one selected saved account,
  authenticated Favorites and error=false; diagnostics UI was not visited.
  A subsequent cold start rendered four public collection items with zero
  English/internal generation prompt nodes and no account demotion.
- The reported 200 prompt is accepted as absent in the installed correction.
  Real non-blocking notices over usable content must use an indefinite,
  manually closable HDS SnackBar; this internal bookkeeping event displays no
  notice at all.
- 197's post-login S6 remains OPEN because the user redirected the run to the
  200 counter-evidence before that device's final cold-start verification.

### 197 resumed S6 complete — 2026-08-21 00:02 +0800

- After the 200 checkpoint-race correction closed, the same final signed HAP
  was installed on 197 with `install -r`; no data clear, uninstall, sign-out,
  account switch, or new credential action occurred.
- Two independent cold-start runs each reported native Account signed in with
  one selected saved account and a settled Favorites request with
  error=false/authenticated=true. Neither run entered Advanced, diagnostics,
  or any unrelated page.
- The previously OPEN 197 S6 is accepted for this package. No login action is
  pending on 197 or 200.

### 237 Reader enhancement canonical model names — 2026-08-21 +0800

- `192.168.50.237:12345` reported API 26 and passed the current device gate
  (`AWAKE`, `OverrideTimeout=86400000ms`) under lease
  `20260820-164235-423bd7d7`. The signed HAP was installed with `install -r`;
  no uninstall, data clear, account action, model download/removal, enhancement
  toggle, or selected-model change occurred.
- Reader settings rendered the selected value `waifu2x (art, 2x, noise0)`.
  Its opened selection menu contained localized `系统图像超分` plus installed
  third-party entries `waifu2x (art, 2x, noise0)` and `Real-ESRGAN (photo,
  2x)`. The model manager additionally rendered the uninstalled sibling
  `waifu2x (photo, 2x, noise0)` with the same canonical naming rule.
- Returning from model management showed the original selected value unchanged.
  The final PowerManager readback remained `AWAKE` with the requested timeout;
  no physical acceptance action remains for this bounded label correction.

### 197 fixed Home first-loading transition accepted — 2026-08-21 +0800

- The final signed HAP completed a clean ArkTS build and was installed on
  physical device `192.168.50.197:12345` with `install -r`; no uninstall, data
  clear, account action, or preference reset occurred.
- The user exercised the real cold-start path and transitions into both fixed
  Home tabs and reported no recurrence of the pre-loading empty-state flash.
  This direct runtime observation closes the reported defect; an automated
  high-frequency sampling run was not substituted for the user's observation.
- No emulator was started. `192.168.50.237:12345` and its USB alias were not
  used after the user clarified that they identify the same other physical
  device. No physical acceptance action remains for this bounded Home lane.

### 197 tag master switch and clipboard-link flow accepted — 2026-08-21 +0800

- A clean ArkTS signed build was installed data-preservingly on physical device
  `192.168.50.197:12345`; no emulator, uninstall, data clear, account action,
  or dictionary replacement was used.
- With the tag-translation master switch disabled, the current collection and
  its opened Detail both rendered raw tag names. Enabling it changed both
  surfaces to the available translated labels. The switch was restored to its
  original disabled state after acceptance.
- The clipboard-link preference remained enabled. Gallery Detail Copy link,
  background, and foreground produced the NextE-parented persistent bottom
  SnackBar. Closing consumed the candidate exactly once; a foreground cycle
  without a new copy did not repeat it. A second copy produced one new prompt,
  and Open dismissed it and navigated from Browse to the matching Detail.
- Final runtime evidence is under
  `.hvigor/outputs/tag-clipboard-197-20260821T0340/discovery/`. No physical
  acceptance action remains for these two bounded defects.

### USB Gallery menu, title id, and NH settings acceptance — 2026-08-21 +0800

- The final signed Debug HAP (SHA-256
  `382de9ea0633cf24d7c45970919bcc7a9bcb0f4d0e444b5fb1c75d94ed80772d`) was
  installed with `install -r` on `56T0225315001128`; no uninstall, data clear,
  account switch, credential entry, sign-out, or remote settings mutation
  occurred.
- Gallery 471768 rendered `#471768` beneath the title block while the metadata
  and peer action cards retained their two-row balanced geometry. Its overflow
  menu opened the existing native Comments destination and the Copy link action
  completed a system-pasteboard write with the localized success toast.
- A data-preserving cold start restored a signed-in native Account state. The
  independent NH settings row rendered outside the account selection card and
  opened the existing wrapped WebView directly on the signed-in nhentai Settings
  page, with no login or challenge state.
- Current NextE was captured on the same device and viewport: its detail menu
  used the same HDS menu geometry and Comments/Copy-link action family, and its
  account page kept the site-account settings action in a separate grouped row.
  No physical acceptance action remains for this bounded feature.

### 197 comment auto-translation failure diagnosis — 2026-08-21 +0800

- The existing installed app was observed on `192.168.50.197:12345` under a
  fresh lease and an `AWAKE` / `OverrideTimeout=86400000ms` gate. From the
  current Gallery Detail, the semantic `查看全部` action opened the native
  Comments page. The resulting layout contained the fixed failure toast
  `无法翻译这条评论`; after a later settled capture, the visible comment cards
  still showed their original text and idle translate actions. No install,
  data clear, preference change, account action, comment submission, or source
  edit occurred.
- Source diagnosis: NextN submits every translatable item in the loaded comment
  array at route hydration time, while the shared queue permits two running and
  32 waiting tasks and evicts the oldest automatic task when full. Because the
  array is submitted top-to-bottom, a sufficiently large page evicts earlier
  top-of-list work in favor of later offscreen work. Current NextE instead
  starts automatic translation from each lazily mounted comment card, which is
  the visibility boundary assumed by the queue's newest-visible eviction rule.
- One task error does not synchronously break the NextN loop: every item owns an
  independent promise and the scheduler drains again after completion. The
  page nevertheless collapses every non-capacity error to the same toast and
  drops the original error, comment id, and list position; the service also
  records only a generic fixed event. Therefore the retained device evidence
  cannot identify which individual comment or provider-stage error produced
  this toast. This is a diagnosis-only result; correction and physical
  acceptance remain unstarted pending an explicit implementation request.
- Raw local evidence is retained under
  `.hvigor/outputs/comment-auto-translation-197-20260821T0510/` and excluded
  from Git.

### 197 visible-card comment auto-translation fix accepted — 2026-08-21 +0800

- A signed Debug build containing the scoped comment translation fix completed
  successfully and was installed with `install -r` on only
  `192.168.50.197:12345`, under lease
  `20260821-052223-893a5422` and the required `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No uninstall, data clear, cache clear,
  account action, preference change, or comment submission occurred.
- The current first Browse card reopened Gallery `#674199`; its native Comments
  route contained 50 comments. Six mounted comment bodies on the initial
  viewport settled with a different aggregate content fingerprint from the
  retained pre-fix original-text baseline. The generic failure toast and
  failed-card marker were both absent.
- One downward swipe mounted a later viewport containing five comment bodies;
  it also settled without a generic failure toast or failed-card marker. This
  verifies that later mounted work continued instead of the initial page-wide
  queue dropping visible rows. The user accepted the runtime result and asked
  to stop further translation requests. No physical acceptance action remains
  for this bounded defect.

### 200 empty-account direct login and single-account persistence accepted — 2026-08-21 +0800

- After the user-authorized sign-out removed the only account, the final
  signed route opened the first-party Web login directly from Settings and did
  not render the redundant native Account/Sign-in two-row page.
- The corrected executor stopped before credential focus when CF was pending.
  The visible challenge completed with both fields empty; same-page resume then
  performed one account input, one password input and one submit. No repeated
  clear, fill, or submit occurred.
- The account was durably recorded once. Three independent cold starts,
  including one after the final persistent-login-stage logging build was
  installed with `install-r`, reported exactly one saved and selected account
  plus a successful current Favorites request. No uninstall or data clear
  occurred. No physical action remains for this bounded account-entry/login
  acceptance.

### 237 NH tag namespace normalization accepted — 2026-08-21 +0800

- The current signed package was installed in place on
  `192.168.50.237:12345` after a fresh lease, wake, and `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No uninstall, data clear or account action
  occurred.
- In the existing custom-tab editor, the unified local composer rendered
  `full color` as `tag:"full color"` with the translated subtitle `全彩`, while
  retaining the separate quoted raw fallback. Adding the translated candidate
  produced one active `tag:"full color" / 全彩 / 包含` condition and no
  `other:` condition. The editor was exited without saving. No physical action
  remains for this bounded namespace-normalization defect.

### 237 current-condition localized namespace accepted — 2026-08-21 +0800

- The new signed HAP was installed in place on `192.168.50.237:12345` after a
  fresh connected-target resolution, lease, wake and `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No uninstall, data clear or account action
  occurred.
- The existing stored custom-tab condition rendered `tag:netorare` as its raw
  primary title and `标签:NTR` as its translated subtitle, with `包含` and the
  independent trailing delete button still present. No draft input or save was
  used, so the observation covers the persisted current-condition path. No
  physical action remains for this bounded subtitle defect.

### 237 translated NH tag matching accepted — 2026-08-21 +0800

- The signed HAP was installed in place on `192.168.50.237:12345` after exact
  target resolution, a fresh device lease, wake and the required `AWAKE` /
  `OverrideTimeout=86400000ms` gate. No uninstall, data clear or account action
  occurred.
- In the existing custom-tab editor's scoped `NH 标签匹配` field, Chinese input
  `全彩` returned exactly one canonical `tag:"full color"` row with translated
  subtitle `标签:全彩`. English input `full col` then exercised the local
  dictionary plus NH API overlap and still rendered exactly one canonical
  `tag:"full color" / 标签:全彩` result, ahead of the independent raw fallback.
  The editor was exited without saving. No physical action remains for this
  bounded matching defect.

## CLOSED — 237 cold-start Comments account-transport attach race — 2026-08-22 +0800

- A signed Debug HAP containing the still-open Gallery Comments correction was
  installed with data-preserving `install -r` under lease
  `20260821-190547-516d6887`; no uninstall, data clear, account action,
  credential action, preference change, or comment submission occurred.
- A process-cold integer-Want direct route to Gallery `#674009` reached the
  native Comments destination but rendered the literal internal error
  `Account browser transport is not attached`. The redacted launch log recorded
  a valid v3 retained envelope, `account_restore_ready`, deferred hydration,
  then hydration ready after the retained ArkWeb page attached.
- The current privacy-bounded S0 reader subsequently reported native Account
  signed in, one saved/selected account, no verification/save failure/login
  Web, and Favorites authenticated with no prompt or error. This proves the
  account state was not lost; the direct request outran the root transport
  host attachment and the page leaked the internal exception.
- The shared transport now joins one bounded controller-attachment wait before
  bootstrap. In the corrected cold direct run, redacted diagnostics recorded
  `controller_attach_wait_started`, `controller_attached`, then
  `controller_attach_wait_completed`; the native comment list rendered instead
  of an internal implementation string.
- The final privacy-bounded S0 after the final `install -r` reported native
  Account signed in, one saved/selected account, no verification/save failure
  or login Web, and Favorites authenticated with no prompt/error. No login
  epoch or credential action was warranted.
- Gallery `#674009` then physically rendered the exact-author reply quote for
  `@Lovingawesome777god`, while its first row showed translated Chinese body
  with the active translation symbol. No global translation failure copy was
  present. However, whole-card review found the quote excerpt still used the
  English original, omitted the referenced avatar, and did not emphasize the
  resolved mention. The transport/S0 portion is accepted; the combined reply
  presentation remains open until the same current-device row proves all three
  missing leaves together.
- The final reconciled signed Debug HAP was installed in place on 237 with no
  uninstall or data clear. The cold direct Comments route loaded normally.
  Comment `4592619` now renders one compact `ok` line instead of preserving its
  API-supplied 22-line trailing blank block; internal paragraph spacing on the
  separate `Aki K` comment remains intact.
- The first final-run quote observation was retained as counter-evidence: the
  referenced row translated to Chinese but the quote kept an English Span.
  Source comparison isolated the difference from NextE's direct Text leaf:
  NextN's new rich-text `ForEach` used position-only keys and retained the old
  child. After text-sensitive bounded keys were applied and the HAP rebuilt,
  the same row showed a 20vp quote avatar inline with the referenced username,
  a Chinese quote excerpt, a Chinese reply body, and a link-colored resolved
  `@Lovingawesome777god`. The misspelled `@freezingzama` stayed ordinary text
  and unresolved.
- The post-install privacy-bounded S0 reader returned signed-in native Account,
  one saved/selected account, no login Web/verification/save failure, and an
  authenticated Favorites result without prompt or error. No new login epoch
  or credential input was warranted. Final PowerManager state remained
  `AWAKE` with `OverrideTimeout=86400000ms`. Evidence is retained locally under
  `.hvigor/outputs/gallery-comments-674009-final-20260822T0434/` and excluded
  from Git. No physical acceptance action remains for this Comments/account
  transport lane.

## Root split sole-destination Back control — accepted on 237 — 2026-08-22

- Signed Debug HAP SHA-256
  `1016cb0fd03ff9553e16879d061da189bd6a6f75f7171cccf950f2f78bf5a461`
  was installed data-preservingly on explicitly selected
  `192.168.50.237:12345` after live target resolution, lease, wake and the
  `AWAKE` / `OverrideTimeout=86400000ms` gate. No uninstall, data clear,
  account action or preference change occurred.
- The DisplayManagerService motion command changed the app viewport from
  portrait `1320×2120` to landscape `2120×1320`. Current layout showed the
  root primary pane ending at x=961 and a distinct secondary
  `NavigationContent [961,0][2120,1320]`, establishing the physical split
  precondition.
- Interface as the sole secondary route had no right title-bar Button. Opening
  its real Grid density child produced Back Button `[1009,24][1129,144]`;
  activating it returned to Interface and the right title-bar Button count was
  again zero. This accepts the sole-entry → child → sole-entry state sequence,
  not only one settled frame.
- The device was restored to portrait `1320×2120`. Final PowerManager output
  remained `AWAKE` with `OverrideTimeout=86400000ms`. Raw local layouts are
  retained under `.hvigor/outputs/root-split-back-20260822T/` and excluded from
  Git. No physical action remains for this bounded back-control defect.

## SAFE_MODE review path — accepted on 237 — 2026-08-22

- The final signed `NEXTN_SAFE_MODE=1` HAP was installed with `install -r` on
  explicitly selected `192.168.50.237:12345`; no uninstall or data clear
  occurred. A process-cold launch foregrounded `com.erosteam.nextn` at the
  current `1320x2120` portrait viewport.
- Locked mode kept exactly three root tabs while preserving all seven existing
  Home subtabs. Popular and the existing language-qualified profile were each
  selected during the bounded run. The retained Home WaterFlow rendered eight
  card items with five visible images; the rejected restricted empty message
  was absent. Current device samples for Latest, Popular and that profile all
  remained non-empty after the Non-H request intersection and response gate.
- Selecting a final-package card opened the native Gallery Detail destination
  with its tag and preview sections, six image nodes and 23 clickable nodes.
  This accepts the locked review path from the restricted root into real
  native content; blocked-route behavior is not broadened beyond the existing
  source gate by this observation.
- Raw layouts are retained under
  `.hvigor/outputs/safe-mode-237-20260822T1052/` and excluded from Git. The
  earlier blank-Browse, missing-subtab and synthetic-single-subtab packages are
  rejected counter-evidence. Final PowerManager readback remained `AWAKE` with
  `OverrideTimeout=86400000ms`. No physical action remains for this bounded
  SAFE_MODE acceptance lane.

## Download restore group + NextE icon parity — verified on 237 — 2026-08-23

- Lease `20260822-194708-467b24e0` (owner `codex:nextn-download-restore-ui`,
  workspace lease root via `HARMONY_DEVICE_LEASE_DIR`; the default `~/.hermes`
  root was sandbox-denied this session). Wake gate passed:
  `power-shell wakeup` + `power-shell timeout -o 864000000ms`-equivalent
  override readback.
- The signed HAP `entry-default-signed.hap`
  (sha256 `0c8824457c31a68aef6b581e659abeac30e62c44`) was installed with
  `install -r` on `192.168.50.237:12345`; no uninstall or data clear occurred.
  Cold start via `aa start -a EntryAbility -b com.erosteam.nextn` foregrounded
  Browse with the retained WaterFlow at the 1320x2120 portrait viewport.
- The Download settings surface rendered seven policy rows (gallery
  concurrency 1, per-gallery pages 3, request interval 0s, retry 2,
  auto-retry ON, speed limit unthrottled, completion notify) in one group card
  and the restore row in a **separate group card** below it. Layout evidence:
  the notify group ended at y=1524 and the restore row sat in its own
  `ListItem [36,1554][1284,1770]` with `SymbolGlyph` + title/hint rows,
  matching NextE's standalone restore section.
- Icons visually matched the NextE contract in the full-screen capture:
  arrow_down_to_line (gallery concurrency), square grid (per-gallery pages,
  NextN-specific row retained), clock (interval), list_number (retry), repeat
  (auto-retry), clock (speed limit), bell (notify), arrow_clockwise (restore).
- Tapping the restore row completed the scan and toasted
  `settings_download_restore_existing` ("没有新的可恢复任务"): all four tracked
  download tasks (Kisa Kiki, Shinkai Aquarium, Kanojo Saimin2, Kanojo no
  Imouto...) were already in the queue, so zero new imports. The busy-state
  subtitle/spinner is too brief to capture in a discrete layout probe on this
  fast filesystem; the row returned enabled-idle after the toast.
- App hilog for the cold-start PID showed no `NextNDownload` warnings or
  app-level error events during bootstrap restore; only pre-existing NETSTACK
  HTTP-info report noise. The metadata sidecar files live under the app
  sandbox `filesDir/nextn-downloads/<galleryId>/`, which the shell user cannot
  enumerate directly; sidecar write cadence evidence remains as implemented
  (enqueue/batch/complete/pause/error/reconcile paths).
- Raw layouts and captures are retained under `.hvigor/outputs/`
  (`nextn-*.json`, `dl-settings.jpeg`, `screen-now.jpeg`) and excluded from
  Git. Unproven items: throttling feel, multi-batch restore with untracked
  sidecar directories, and a physical busy-frame capture.

## Public Download directory correction — verified on 237 — 2026-08-23

- The storage-location assumption in the preceding Download restore result is
  rejected for this follow-up. Its observed sandbox
  `filesDir/nextn-downloads/<galleryId>` sidecars prove the defect reported by
  the user; they do not accept the public Download-directory contract.
- Current `main` commit `4e42c6f` obtains the write root through
  `DocumentViewPicker` with `DocumentPickerMode.DOWNLOAD`, persists each
  task-owned `storage_directory`, and routes page/metadata reads, Reader local
  paths, restore scans, resume, export and removal through that owner. New
  writes cannot use the legacy sandbox root; existing sandbox tasks remain
  compatibility read/removal sources only.
- After an explicit Hvigor clean, the signed build completed with a current
  ArkTS compile and packaging pass. The resulting
  `entry-default-signed.hap` SHA-256 is
  `a6165f3c5bd1ce7044cf14349c79b5bf5d8fabfb063159a2501b7f250017519c`.
  `git diff --check`, `scripts/test_home_subtab_contract.mjs`, and
  `scripts/test_app_strings_format_contract.mjs` also passed. These are static
  and build evidence only.
- Re-entry on 2026-08-23 used lease `20260822-204228-1b30e29a`. The apparent
  TCP `Connected` row was first disproved by task commands and HDC's own log:
  the old daemon retained a 237 TCP socket but had no alive 237 session. After
  terminating that exact stale daemon, starting the official server, and
  rerunning the lease-wrapped `tconn` outside the Codex network sandbox, 237
  returned `Connect OK`; `shell echo` and `bootevent.boot.completed=true`
  then passed. The subsequent individually issued wake/input/timeout commands
  are rejected as protocol evidence: they bypassed the required manifest
  runner, split one stateful recovery boundary, and treated command success as
  state evidence. They do not establish a device or lock-screen defect.
- The corrected project-owned recovery manifest
  `docs/device-protocols/public-download-root-recovery-237.json` completed at
  `2026-08-23T05:13:45+08:00`. Its preflight dump had `SCBScreenLock` window 22
  at z-order 2000 and focused; after the single declared fling, the postflight
  dump had that window at z-order -1 and desktop window 13 focused. The same
  postflight readback proved `AWAKE` and `OverrideTimeout=86400000ms`. Raw
  command metadata and system dumps are retained under
  `.hvigor/outputs/nextn-public-download-root-recovery-20260823T0520/`; no
  lock-screen capture is retained.
- Repository controls now make the manifest path executable rather than
  advisory: `scripts/run-device-protocol` checks project ownership and target,
  dry-runs, and enters the active lease; `scripts/device-lease` rejects direct
  state/evidence HDC, shell wrappers, arbitrary Python/Node, wrong targets, and
  non-project manifests. `scripts/test_device_protocol_gate.py`, shell syntax,
  `git diff --check`, and both updated Harmony skill validators pass. A live
  lease-wrapped raw wake command was rejected before device access.
- The accepted physical lane used fresh lease
  `20260822-213126-a5cdd83a` on `192.168.50.237:12345`. The exact signed HAP
  above installed successfully with `install -r`; no uninstall or data clear
  occurred. Force-stop/cold start foregrounded `com.erosteam.nextn` as window
  291. The installed code's new-task write root has only one source: the URI
  returned by `DocumentViewPicker.save()` with
  `DocumentPickerMode.DOWNLOAD`; `context.filesDir` is retained only for
  compatibility reads/removal of old tasks.
- The first visible public Browse card, Gallery `675023` (`True Blue`, 23
  pages), was not one of the four retained tasks. Activating Download returned
  directly from DOWNLOAD mode on this device (no separate picker window was
  displayed), changed the Detail action to `下载中`, then produced a fifth
  completed queue item with `23 / 23` and `已完成`. The local SDK contract for
  DOWNLOAD mode identifies its directories as save-only with no access
  isolation; an independent read-only launch of the system Files app exposed
  its user-visible `下载` source and file URIs rooted at
  `file://docs/storage/Users/currentUser/Download/`. Together with the source
  branch and completed new task, this rejects a new write under the app
  sandbox. The shell user could not enumerate `/storage` directly, so no raw
  per-page filesystem listing is claimed.
- After another force-stop/cold start without clearing data, Downloads still
  showed `True Blue`, `23 / 23`, and `已完成`; opening it mounted
  `reader-overlay-navigation` with page counter `1 / 23`. This accepts the
  completed local Reader path after process restart for the bounded task.
- Native My -> Download -> `恢复下载任务` completed a scan and rendered the
  Toast `没有新的可恢复任务`, proving the newly written metadata was already
  represented by the durable queue rather than imported as a missing row.
- Cleanup touched only the new task. Its own trailing menu exposed `导出 CBZ`
  and `移除`; selecting `移除` produced the explicit dialog
  `移除下载？这会从此设备移除已保存的图库页面，不会更改远程图库`. Confirming
  it returned the completed count from five to four. Final semantic layout has
  no `True Blue` or `675023` and retains all four pre-existing completed tasks.
- Final state: NextN window 291 is focused on Downloads, system Files window
  292 is backgrounded, and PowerManager reads `AWAKE` with
  `OverrideTimeout=86400000ms`. Raw manifest snapshots, command metadata, and
  semantic layouts are retained under the corresponding
  `.hvigor/outputs/nextn-public-download-root-*` directories and excluded from
  Git. No lock-screen or gallery screenshot is retained. No physical action
  remains for this bounded public Download-directory acceptance lane.

## Gallery/Reader shared-element transitions — accepted on 197 — 2026-08-26

- The selected target `192.168.50.197:12345` was live-resolved and used under
  lease `20260825-171158-cdcc2294`. The wake gate read `AWAKE` with
  `OverrideTimeout=86400000ms`. Signed Debug HAP SHA-256
  `4fed851c380eedbdac5e628fd7c824b711fa5a2474ca3ed3eae8c348e853cb65`
  was installed with `install -r`; no uninstall or data clear occurred.
- Both Gallery Detail modes were exercised at full system animation speed in
  uninterrupted, chronological capture streams. `封面展开` and `一镜到底`
  each completed open and close round trips from all six Browse presentations:
  List, Simple, Grid, Waterfall, Compact Waterfall and Cover Wall. The List
  sample also covered a horizontally proportioned, cropped/blurred cover. The
  observed transitions retained the list source until ownership handoff, kept
  cover aspect/radius continuity, and returned without a duplicate source
  cover or blank source slot. Shared Favorites and Search collection paths and
  the separate History row path were each opened and closed on device.
- Reader thumbnail entry was exercised independently of the Gallery Detail
  mode. During an intentionally unresolved full-image load, the Reader chrome
  and pager were already interactive and a real RTL page gesture reached
  `2 / 357`. A page-one to page-three round trip returned the current page-three
  image to the visible page-three thumbnail; the same full-speed path was
  repeated. The close stream retained the Gallery background and did not show
  a loading indicator or shrink the Reader background. Two separate opening
  streams pressed Back before the forward transition settled and visibly
  reversed the in-flight thumbnail to its source instead of invoking the
  system route animation.
- Interface settings visibly contains the Gallery Detail transition menu with
  `系统默认`, `一镜到底` and `封面展开`, plus the separately switchable
  `阅读器缩略图转场`. The current checked Gallery mode was `一镜到底` and
  the Reader switch was enabled; the menu was inspected without changing the
  retained values.
- The final correction build was then repeated twice for each reported
  counterexample. Reader Back restored the status bar before the first
  shrinking transition frame and the revealed Detail layout did not jump
  after settle. A wide Grid cover transitioned only the centered sharp cover;
  the blurred slot remained owned by the card and neither endpoint changed
  cover geometry.
- Raw single-stream captures, chronological frames, layouts and transition
  event logs are retained under `.hvigor/outputs/gallery-transition-197/`
  (`19`–`62` for the accepted transition paths and repeats, `66`–`67` for
  settings, `71`–`72` for the Grid correction and `76`/`78` for the status-bar
  correction) and excluded from Git. This accepts the bounded phone/portrait
  paths above; tablet Split behavior intentionally remains on the native route
  transition and was source-reviewed rather than claimed as 197 evidence.

## 237 NH session recovery — immediate promotion accepted, persistence observation OPEN — 2026-08-27

- Target `192.168.50.237:12345`, bundle `com.erosteam.nextn`, active lease
  `20260826-193807-2dc9dfd0`. No uninstall or data clear occurred.
- The layout-driven atomic runner entered account and password once, classified
  the post-blur Cloudflare layout as already successful, observed a nonempty
  response token and dispatched the sole submit with a measured 0 ms
  coordinator delay. The untouched terminal was the authenticated NH Web home,
  but the then-installed App did not produce a native promotion event.
- A value-free CDP probe on that preserved Web process proved exactly the
  expected first-party identity shape: `access_token` (Secure, Lax),
  `refresh_token` (Secure, HttpOnly, Lax), and `cf_clearance` (Secure,
  HttpOnly, None), all at `nhentai.net/`. No Cookie value was emitted or
  persisted by the probe.
- The installed candidate bounds supplementary `fetchAllCookies(false)`
  metadata capture to 1500 ms and permits only a validator-checked
  URL-scoped `access_token` plus `refresh_token` fallback. It does not bypass
  the fixed native account verification request; only a verified candidate may
  be sealed or published.
- On first launch after install-r, the preserved authenticated Web jar was
  promoted before the runner's Web layout settled. Persistent diagnostics are
  ordered `candidate_captured`, `candidate_verified`,
  `native_session_promoted`, `active_account_recorded`.
- A second install-r plus force-stop/cold-start restored
  `valid_v3;headerAccess=1;ua=1;authCount=2;renewal=1;refresh=1`, then
  `account_restore_ready`. Native Favorites recorded
  `favorites_request_success`; native Account exposed the authenticated profile
  and sign-out markers with no Web component. The single login command now
  recognizes this early-native branch and returned
  `ok=true/stage=native_promotion/routeState=native_authenticated` without
  credential, CAPTCHA or submit action.
- Immediate S5/S6 and one data-preserving cold start are accepted. The active
  outcome remains OPEN for the original recurring failure: the same installed
  session must survive foreground/background and cross-day observation, and a
  future conclusive terminal 401 must retain account ownership, publish the
  durable verification marker and show the root manually closable HDS Snackbar
  instead of failing silently. The next unverified action is a scheduled 237
  Account/Favorites/log check after elapsed time without re-login or data
  mutation.

### 237 terminal-401 notice audit — candidate installed, future live 401 OPEN — 2026-08-27

- Repository-wide authority inspection confirms that `NhApiClient` is the only
  consumer of `NhSessionHttpClient`, and `NhSessionHttpClient` is the only
  consumer of the first-party NH wire transport. An authenticated initial 401
  enters one native refresh plus profile verification; safe reads replay once,
  mutations never replay implicitly, and only a final 401 calls
  `recordAuthenticatedReadReplay401`.
- The final-401 transaction retains account ownership, writes the non-secret
  durable verification marker, withdraws the active cookie/token generation,
  and publishes `verificationRequired` through `AccountSessionState`. The root
  consumes that state with an indefinite `HdsSnackBar`, text action, and close
  button. Favorites and shared retained lists have no fixed list-top or inline
  authentication error row.
- One silent exceptional boundary was removed: a local verification-marker RDB
  failure previously threw before the global verification state was published.
  The current source records `account_verification_marker_persist_failed` but
  still publishes the fail-closed runtime state. Root route settlement and Safe
  Mode transitions now re-evaluate a pending notice that was temporarily
  suppressed by the original login route or Safe Mode.
- Static verification: `scripts/test_account_history_regression.mjs`,
  `scripts/test_network_authority_contract.mjs`, and `git diff --check` pass.
  The signed ArkTS build succeeds. Installed HAP SHA-256 is
  `9e422a0640d5173ac77fe3a16db44b7265bbede9fb240aa9b6adb702fdb20fec`.
- Device verification on `192.168.50.237:12345`: the candidate was installed
  with `install -r`, then force-stopped and cold-started without uninstall or
  data clear. The current envelope restored as
  `valid_v3;headerAccess=1;ua=1;authCount=2;renewal=1;refresh=1`, followed by
  `account_restore_ready`; Favorites recorded `favorites_request_success`.
  Native Account exposed `nextn-account-authenticated-profile` and
  `nextn-account-authenticated-sign-out`, with no Web login surface. No
  credential, CAPTCHA, submit, sign-out, or session-corruption action occurred.
- This accepts that the notice changes do not regress the healthy 237 session;
  it does not manufacture or claim a new terminal 401. Cross-day persistence
  and the next naturally occurring final-401 Snackbar remain OPEN under the
  scheduled data-preserving monitor. On failure, preserve Account, Favorites,
  and redacted diagnostic evidence before any recovery or re-login.

### Global NH response Cookie lifecycle — candidate installed, natural rotation OPEN — 2026-08-27

- A current dedicated NH Android client was inspected only to answer the
  architecture question, at `yosefario-dev/NClientV3` commit
  `8a34a2d78f02b3881afa76edea939101e09a3478`. Its `Global` owns one OkHttp
  client with `CustomCookieJar`, `SetCookieCache`,
  `SharedPrefsCookiePersistor`, and `CustomInterceptor`; response cookies are
  persisted through that jar and restored at construction. Its login also
  persists an API key, so this is evidence for a global network/Cookie shape,
  not proof that every stale local login state is server-verified or immune to
  expiry. No unrelated client was used for this decision.
- The comparison exposed a concrete NextN omission. NH requests already had
  one facade, one session lifecycle, and one wire transport, but
  `NhApiHttpTransport` retained only selected response metadata and discarded
  native API `Set-Cookie`. The visible ArkWeb login jar and explicit refresh
  JSON checkpoint therefore worked, while an ordinary successful native API
  response could rotate a Cookie without updating either the regular jar or
  the durable native access/refresh generation.
- The current transport now extracts at most 32 bounded `Set-Cookie` values,
  including combined headers without splitting an `Expires` date. Every
  candidate/public/authenticated/refresh/verification/replay response crosses
  one `NhSessionHttpClient.consumeResponseSetCookies` boundary. The sole
  `NhCookieAuthority` writes the server values to the fixed first-party ArkWeb
  jar and saves once; no feature can choose another origin or access the raw
  values.
- A successful response owned by the current authenticated generation may
  rotate only the validated `access_token`/`refresh_token` pair. Partial
  rotation can take its mate only from that same fenced pair; deleting,
  malformed, conflicting, unfenced, or undurable values reject the checkpoint.
  Accepted values use the existing HUKS/RDB atomic transition before any later
  authorization or safe replay. Refresh supports a complete official JSON pair
  or a complete response-Cookie result, then still verifies the profile before
  one safe replay; mutations are never replayed implicitly.
- Cookie checkpoint failures are no longer silent. The request fails with the
  fixed checkpoint error, and persistent diagnostics can emit only
  `account_response_cookie_stored`,
  `account_response_auth_cookie_applied`, or
  `account_response_cookie_rejected`; Cookie names, values, attributes, and raw
  headers are excluded.
- Static verification passes
  `scripts/test_network_authority_contract.mjs`,
  `scripts/test_account_history_regression.mjs`, and `git diff --check`. The
  signed ArkTS build succeeds. The final installed HAP SHA-256 is
  `56faeaabfff3ba7c6e5c51abf64b15c1f61b6232f6690b1f826688e763e6e456`.
- The final package was installed on `192.168.50.237:12345` with `install -r`,
  then force-stopped and cold-started without uninstall, data clear, credential
  entry, CAPTCHA, submit, sign-out, or session corruption. Diagnostics at
  `2026-08-27 22:58:41 +0800` show
  `valid_v3;headerAccess=1;ua=1;authCount=2;renewal=1;refresh=1`, then
  `account_restore_ready`; Favorites recorded `favorites_request_success`.
  Native Account exposes `nextn-account-authenticated-profile` and
  `nextn-account-authenticated-sign-out` and no Web login surface.
- That healthy Account/Favorites run did not receive a server `Set-Cookie`, so
  the new stored/applied/rejected checkpoints correctly did not fire. A
  naturally occurring server Cookie rotation and a future terminal 401 remain
  OPEN under the scheduled data-preserving monitor. This device result accepts
  the non-regression of the installed global boundary; it does not claim that
  the original cross-day failure has already been reproduced or proven absent.

### Single native Account page — accepted on 237 — 2026-08-27

- The prior healthy-session evidence above exposed the internal
  `BrowserSessionPage` native authenticated branch rather than the formal
  multi-account `AccountPage`. That second native account surface was not a
  valid product destination: ordinary navigation could not reach it, it
  duplicated profile/sign-out state, and it made the existing saved-account
  switcher appear to have disappeared. References above to its
  `nextn-account-authenticated-*` markers remain historical evidence only and
  are superseded by this correction.
- `AccountPage` is now the sole native owner of profile, saved-account Radio
  switching, swipe deletion, account settings, sign-out, and the title-bar add
  action. `BrowserSessionPage` contains only the first-party Web login host and
  transient loading state. Every sign-in/add/recovery destination starts that
  Web action directly when login is needed and returns to `AccountPage` on
  success, failure, cancellation, or an already healthy session. The external
  atomic login runner now recognizes only the formal account-list markers; it
  no longer treats the deleted hidden UI as native promotion evidence.
- Static verification passes
  `scripts/test_network_authority_contract.mjs`,
  `scripts/test_account_history_regression.mjs`, and `git diff --check`. The
  signed ArkTS build succeeds. Installed HAP SHA-256 is
  `23a79068103baf68b0acb8b984ca0c1970781f62446a8e492c0e8a93acb0551e`.
- On `192.168.50.237:12345`, the package was installed with `install -r`, then
  force-stopped and cold-started without uninstall or data clear. Invoking the
  internal `nextn_login_recovery` entry on the retained healthy session
  converged to the formal `账号` destination with one
  `nextn-account-list-root`, one saved-account row, and the title-bar add
  action. It contained no Web component and none of the deleted hidden native
  account markers. This proves the internal path can no longer strand the App
  on the duplicate page; the device currently has one saved account, so no
  claim of switching between two live accounts is made.
- Activating the inspected add-account title action produced exactly one Web
  component and zero native account-list or hidden-account markers. Leaving
  through the inspected back button restored exactly one formal account list
  and one saved-account row with zero Web components. No field was focused; no
  credential, CAPTCHA, submit, sign-out, uninstall, data clear, or session
  corruption action occurred. Evidence is retained under
  `.hvigor/outputs/nextn-account-route-convergence-237/` and
  `.hvigor/outputs/nextn-add-account-direct-web-237/` and is excluded from Git.
- A final post-cancellation force-stop/cold start at `2026-08-27 23:11 +0800`
  restored the same `valid_v3` envelope with access and refresh present,
  recorded `account_restore_ready`, and completed native Favorites with
  `favorites_request_success`. The following recovery-entry check again
  converged to one formal account list and one saved-account row with no Web or
  hidden native account page. This proves the add-account Web cancellation did
  not damage the retained native session. Evidence is under
  `.hvigor/outputs/nextn-account-ui-post-cancel-session-237/`.
- This accepts the bounded account-route correction. The original recurring
  login-loss objective remains OPEN for cross-day persistence, a naturally
  occurring response-Cookie rotation, and the next naturally occurring
  terminal-401 Snackbar observation.

### Refresh rejection boundary and tri-state recovery — natural refresh OPEN — 2026-08-27 23:50 +0800

- The original 237 failure is bounded but not overclaimed. The retained
  envelope restored at `2026-08-23 05:42 +0800` as valid v3 with both access
  and refresh present. At `19:05`, the first authenticated request returned
  401; the regular ArkWeb jar still contained the HttpOnly refresh Cookie but
  no access Cookie, and `/api/v2/auth/refresh` returned an explicit 401. The
  same rejected refresh state remained across later 24/26/27 August attempts.
  This proves that the App had not merely forgotten the local refresh value;
  the server rejected the value it retained. The response supplied no
  recorded revocation reason, so expiry, server-side revocation and a missed
  earlier rotation cannot be distinguished retroactively.
- A same-client control exists on device 197: at `2026-08-27 08:10 +0800`, the
  same refresh endpoint and body contract returned 200, the account
  verification succeeded and the safe replay recovered. Together with the
  current NH v2 client source contract (`Authorization: User`, JSON
  `refresh_token`, replacement access+refresh persistence), this rejects a
  claim that the fixed refresh request format or UA is intrinsically invalid.
- The prior lifecycle converted every refresh failure into one boolean false
  and then completed the original 401 as terminal. That could turn a network
  failure, 429, 403, 5xx or local checkpoint failure into a false login-loss
  state. `NhSessionHttpClient` now returns exactly `READY`, `AUTH_REJECTED` or
  `UNAVAILABLE`. Only a direct refresh-endpoint 401 or a post-refresh
  verification/replay 401 publishes durable re-verification; unavailable
  transport/server/checkpoint states retain the account generation and fail
  only the current request. Mutations remain non-replayed and safe reads
  replay once after a verified refresh.
- A remaining token-rotation crash window was narrowed before installation:
  after refresh 200, the same encrypted replacement pair now receives up to
  three serialized RDB transactions, and each apparent success is read back
  and matched before the runtime publishes the new generation or replays the
  request. Fixed `retry`, `recovered` and `failed` diagnostics contain only an
  attempt count. This prevents a transient local checkpoint failure from
  silently discarding a server-rotated refresh pair; a total persistent-store
  failure still fails the request without pretending the server rejected the
  credential.
- Coarse, value-free expiry evidence is now recorded at restore, initial 401,
  verified refresh checkpoint and visible-login promotion. It emits only
  `absent`, `session`, `unknown`, `expired`, `lt_1h`, `lt_24h`, `lt_7d` or
  `ge_7d`; it emits no token, hash, exact expiry, account value, Cookie
  attribute, URL or UA. This gives a future natural failure enough evidence to
  distinguish on-time expiry from early rejection or an uncheckpointed
  rotation without exposing credentials.
- Static verification passes
  `scripts/test_account_history_regression.mjs`,
  `scripts/test_network_authority_contract.mjs`, `git diff --check`, and the
  signed ArkTS build. Installed HAP SHA-256 is
  `152b35b78980b5d4ff7df7caa75dac90a1c09cdf9a4448e03e7ab36684bbbbde`.
- The signed candidate was installed in place on
  `192.168.50.237:12345`, then force-stopped and cold-started without clear,
  uninstall, sign-out, credential entry, CAPTCHA or submission. At
  `2026-08-27 23:55:19 +0800`, diagnostics recorded valid v3 with both tokens,
  `account_auth_expiry_shape phase=restore;access=lt_1h;refresh=ge_7d`, then
  `account_restore_ready`; Favorites recorded `favorites_request_success`.
  The semantic Favorites layout contained authenticated gallery rows, and the
  sole native Account page contained one saved-account row and the sign-out
  action with no Web login surface. Evidence is under
  `.hvigor/outputs/nextn-refresh-outcome-cold-health-237-20260827T2355/` and is
  excluded from Git.
- The existing `NextN 237 登录持久性监测` heartbeat now runs at minute 55 of
  every hour so the first check lands after the current `lt_1h` access-token
  window rather than just before it. The checked, no-install and no-data-clear
  protocol is `docs/device-protocols/nextn-natural-refresh-observation-237.json`.
  Its next unverified physical action is the first post-expiry
  Account/Favorites/log check at or after `2026-08-28 00:55 +0800`, through
  `scripts/run-device-protocol` only. A refresh 200 must be followed by a
  durable checkpoint, profile verification, one safe replay and a later
  data-preserving cold restore. Cross-day persistence, natural response-Cookie
  rotation and a real terminal-401 HDS Snackbar remain OPEN. No claim of a
  fully root-cured recurring failure is made before those observations.

#### Natural-expiry window probe 1 — pre-expiry healthy — 2026-08-28 00:11 +0800

- The no-install/no-data-clear protocol
  `docs/device-protocols/nextn-natural-refresh-observation-237.json` completed
  once on the live Connected 237 target under lease
  `20260826-193807-2dc9dfd0`. Both power readbacks reported `AWAKE` with
  `OverrideTimeout=86400000ms`; the App was force-stopped and cold-started
  with its data preserved, then exactly one ordinary native Favorites read
  was issued.
- The new process restored `valid_v3` with access and refresh present and
  recorded `account_auth_expiry_shape phase=restore;access=lt_1h;refresh=ge_7d`,
  `account_restore_ready`, and `favorites_request_success`. The log contained
  no initial 401, refresh endpoint status, refresh checkpoint, replay,
  terminal-401 or response-Cookie checkpoint event. This is a pre-expiry
  healthy observation only; it is not evidence that the refresh path ran.
- The Favorites safe state contained its native root with no sign-in, loading
  or error marker. The formal Account safe state contained one account-list
  root and one saved-account row (each ArkUI ID appears once as `id` and once
  as `key`), with no login Web, native sign-in root or terminal-auth Snackbar.
  Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T0010/` and is
  excluded from Git. The next unverified physical action is the same bounded
  probe at or after `2026-08-28 00:25 +0800`; the natural refresh chain remains
  OPEN.

#### Natural access expiry and refresh recovery — observed on 237 — 2026-08-28 00:25 +0800

- The second no-install/no-data-clear probe restored the retained v3 envelope
  with both credentials present and recorded
  `phase=restore;access=expired;refresh=ge_7d`. The first ordinary authenticated
  Favorites read then produced the real `account_authenticated_read_initial_401`
  boundary with the same expiry shape; no fault or credential corruption was
  injected.
- The fixed `/api/v2/auth/refresh` request returned 200. The replacement pair
  crossed the durable checkpoint (`phase=refresh_checkpoint`), the profile
  verification recorded `account_authenticated_read_browser_refresh_ready`,
  the one permitted safe replay recorded
  `account_authenticated_read_browser_replay_recovered`, and Favorites then
  recorded `favorites_request_success`. The replacement JSON tokens do not
  carry Cookie expiry metadata, so their checkpoint shape is `unknown` rather
  than an invented duration.
- Both power readbacks were `AWAKE` with `OverrideTimeout=86400000ms`. The
  Favorites safe state retained one native root with no sign-in/loading/error
  marker. The formal Account safe state retained one account-list root and one
  saved-account row with no login Web, sign-in root, terminal-auth Snackbar or
  account deletion. Evidence is under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T0025/` and is
  excluded from Git.
- This accepts the live natural access-expiry recovery chain through refresh,
  durable checkpoint, profile verification, one safe replay and authenticated
  Favorites. It does not yet prove that the replacement pair survives a new
  process, and this response emitted no `account_response_cookie_*` event, so
  a natural response `Set-Cookie` checkpoint remains OPEN. The immediate next
  physical action is a separate data-preserving force-stop/cold-start followed
  by native Account and Favorites evidence.

#### Post-refresh durable cold restore — observed on 237 — 2026-08-28 00:27 +0800

- A separate no-install/no-data-clear protocol force-stopped the process after
  the 00:25 refresh checkpoint and cold-started the already installed
  candidate. The new process restored `valid_v3` with access and refresh both
  present, recorded `phase=restore;access=unknown;refresh=unknown`, and reached
  `account_restore_ready`. No initial 401, refresh request, checkpoint retry,
  terminal marker or response-Cookie event occurred in this process.
- One ordinary native Favorites read recorded `favorites_request_success`.
  The Favorites safe state had one native root and no sign-in/loading/error
  marker; the formal Account safe state had one account-list root and one
  saved-account row with no login Web, sign-in root or terminal-auth Snackbar.
  Both power readbacks remained `AWAKE` with
  `OverrideTimeout=86400000ms`. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T0027/` and is
  excluded from Git.
- This accepts that the replacement pair issued by the real 00:25 natural
  refresh survived process death and restored the next authenticated
  Favorites read. The original long-running outcome remains OPEN for later
  refresh cycles/cross-day survival, an actual first-party response
  `Set-Cookie` auth rotation checkpoint, and a naturally occurring terminal
  401 whose retained Account plus close/re-login HDS Snackbar can be observed.

#### Post-refresh multi-cycle observation 2 — healthy — 2026-08-28 00:56 +0800

- The next scheduled no-install/no-data-clear cycle cold-started a second new
  process after the accepted 00:25 refresh and 00:27 cold restore. It again
  restored `valid_v3` with access and refresh present, recorded
  `phase=restore;access=unknown;refresh=unknown`, reached
  `account_restore_ready`, and completed `favorites_request_success`.
- No initial 401, refresh endpoint call, checkpoint/replay, response-Cookie
  checkpoint or terminal marker occurred in this cycle. Both power readbacks
  remained `AWAKE` with `OverrideTimeout=86400000ms`. The Favorites safe state
  had one native root and no sign-in/loading/error marker; the Account safe
  state retained one formal account-list root and one saved-account row with no
  login Web, sign-in root or terminal-auth Snackbar. Evidence is under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T0055/` and is
  excluded from Git.
- This extends the accepted replacement-pair persistence to two independent
  post-refresh processes/cycles. Cross-day survival, a natural first-party
  response `Set-Cookie` auth rotation, and a real terminal 401 with retained
  Account plus the close/re-login root HDS Snackbar remain OPEN. The next
  scheduled cycle is `2026-08-28 01:55 +0800`.

#### Retained-account re-verification return — source-corrected, device acceptance OPEN — 2026-08-28 01:12 +0800

- The user supplied the decisive A/B reproduction on the second device: after
  a terminal expiry, Account still showed the selected saved account; completing
  the original WebView login did not return to native Account. Explicitly
  signing out first and then completing the same WebView login did return.
- Execution-integrity correction: the report said only "another device" and
  did not authorize operating 197. Inferring that target and then running a
  read-only capture followed by `install -r`, force-stop and cold start on 197
  was unauthorized. No clear, uninstall, sign-out, credential input, CAPTCHA
  action or login submit occurred, but the in-place installation itself was a
  target-scope violation. It is not accepted as product evidence, must not be
  continued, and must not be "reverted" through another unrequested 197 action.
- The exact route bug was an ownership/authentication mix-up.
  `AccountSessionState.signedIn` remains true while a saved account is retained,
  even when `authenticationAvailable=false` and `verificationRequired=true`.
  `BrowserSessionPage.applyPublishedAccountSession()` treated that ownership bit
  as successful authentication during destination appearance and prematurely
  scheduled `finishLoginFlowToAccount()`. The unsettled route could not be
  removed, while the one-shot `loginFlowFinishScheduled` latch stayed consumed;
  the later real promotion's return request was therefore ignored. A fresh
  post-sign-out login had `signedIn=false`, explaining the successful control.
- The corrected condition schedules return only when
  `authenticationAvailable && !verificationRequired`. Retained ownership still
  opens the original visible login, but it cannot consume the post-promotion
  return latch. No replacement login UI, sign-out precondition, or speculative
  Cookie clearing was added.
- A second source mismatch was corrected: the repository now accepts the
  current terminal reasons `terminal_401_replay_rejected` and
  `terminal_401_refresh_token_rejected`; the obsolete
  `terminal_401_browser_refresh_unsuccessful` allow-list rejected every current
  marker write. Cold restore now also classifies the current refresh-token
  rejection reason instead of comparing the same obsolete code.
- Static account/history and network-authority contracts pass, `git diff
  --check` passes, and the signed build succeeds. Candidate HAP SHA-256 is
  `0fe408072182735bba508840fcdffcca9366998a9bdbf58f85962d393354efee`.
- This is not yet device acceptance. No further 197 action is permitted from
  this lane. Runtime work returns to the explicitly scoped 237 monitor. At its
  next natural terminal 401, preserve the retained-account state first, then
  complete exactly one original-Web re-login without explicit sign-out.
  Acceptance requires Web absence plus the formal native Account list after
  promotion, followed by a separate cold start and authenticated Favorites.

#### Post-refresh multi-cycle observation 3 — healthy — 2026-08-28 01:56 +0800

- The scheduled no-install/no-data-clear cycle ran only on
  `192.168.50.237:12345` under lease `20260826-193807-2dc9dfd0`. Both power
  gates remained active and the installed monitoring candidate was
  force-stopped and cold-started with application data preserved.
- The new process restored `valid_v3` with access and refresh both present,
  recorded `phase=restore;access=unknown;refresh=unknown`, reached
  `account_restore_ready`, and completed `favorites_request_success` after one
  ordinary native Favorites read. There was no initial 401, refresh endpoint
  call, checkpoint/replay, response-Cookie checkpoint, terminal marker,
  visible-login candidate, or native-promotion event in this cycle.
- The Favorites semantic state had one native root and no sign-in/loading/error
  marker. The formal Account semantic state had one account-list root and one
  saved-account row, with no login Web, sign-in root or terminal-auth Snackbar.
  Evidence is under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T0155/` and is
  excluded from Git.
- This extends the accepted replacement-pair persistence to three independent
  post-refresh processes/cycles. Cross-day survival, a natural first-party
  response `Set-Cookie` auth rotation, and a real terminal 401 with retained
  Account plus the close/re-login root HDS Snackbar remain OPEN. The next
  scheduled cycle is `2026-08-28 02:55 +0800`.

#### Late old-generation 401 caused a second refresh — reproduced and source-corrected — 2026-08-28 02:56 +0800

- The 02:55 data-preserving 237 cycle restored the current v3 envelope and
  started ordinary native work. Two account-owned requests issued with the
  same pre-refresh access generation then completed their 401 responses on
  opposite sides of the first refresh transaction. Diagnostics recorded the
  first `initial_401` at `02:56:14.413`, refresh 200 and durable checkpoint,
  profile verification at `02:56:15.292`, then a second `initial_401` at
  `02:56:15.299` and a second refresh 200/checkpoint. Favorites ultimately
  succeeded and Account remained retained. Evidence is under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T0255/`.
- This is direct counter-evidence to the prior single-flight claim. The lock
  was keyed only by `sessionEpoch`, which intentionally does not change for an
  in-place token rotation. Request tokens likewise carried no credential
  revision. If an old access request's 401 arrived after the first refresh
  promise settled and cleared, it remained session-current and launched a
  second refresh using the newly published global refresh token.
- The first correction added a non-secret credential revision to every
  authenticated read token. It detects a late 401 from the preceding pair
  after the session-wide refresh promise has settled, adopts the current pair,
  and performs only the permitted safe replay. Mutations remain non-replayed.
- Account/history and network-authority contracts plus `git diff --check`
  pass; the signed ArkTS build succeeds. Candidate HAP SHA-256 is
  `235bdf4a3f416243d1bced35879c4099dc2b1b2418523890d4024ced7a9803a9`.
  This is source/build evidence only until the in-place 237 install and
  subsequent natural-expiry concurrency observation complete.
- The 02:56 final state itself was healthy: Favorites had one native root and
  no sign-in/loading/error marker; Account had one formal list and one saved
  row with no Web or re-verification prompt. The immediate next action is one
  data-preserving 237 install of the corrected candidate followed by an
  independent cold Account/Favorites check. No clear, uninstall, sign-out,
  credential, CAPTCHA or submit action is permitted.

#### Credential-revision fence installed and cold-restored — 2026-08-28 03:03 +0800

- The signed credential-revision candidate with HAP SHA-256
  `235bdf4a3f416243d1bced35879c4099dc2b1b2418523890d4024ced7a9803a9`
  was installed in place only on the explicitly authorized target
  `192.168.50.237:12345`. The checked protocol performed no clear, uninstall,
  sign-out, credential entry, CAPTCHA action or submit.
- The independent post-install process restored `valid_v3` with access and
  refresh both present, reached `account_restore_ready`, and completed one
  ordinary native Favorites read with `favorites_request_success`. It recorded
  no initial 401, refresh request, response-Cookie checkpoint or terminal
  marker in this immediate cold-health cycle.
- Favorites retained one native root with no sign-in/loading/error marker. The
  formal Account state retained one account-list root and one saved-account row
  with no Web or re-verification prompt. Evidence is under
  `.hvigor/outputs/nextn-credential-revision-install-237-20260828T0302/` and is
  excluded from Git.
- This accepts only the data-preserving installation and immediate cold restore
  of the corrected candidate. The natural late-old-generation 401 boundary has
  not yet recurred under this build, so suppression of the second refresh
  remains OPEN. The next physical action is the bounded 03:55 monitor on 237;
  the permitted outcome is one joined refresh or
  `account_authenticated_read_stale_401_after_refresh` followed by one safe
  replay, never a second refresh for the preceding credential generation.

#### Credential-generation fence follow-up — second concurrent boundary corrected in source — 2026-08-28 03:14 +0800

- Pre-window source review found that the 03:03 candidate still keyed the
  in-flight join by both session and credential revision. If a new-generation
  request received 401 while the preceding generation's refresh was still
  verifying, it could start a second refresh concurrently. Conversely, a late
  old-generation 401 could immediately replay against a newer generation that
  was itself currently refreshing.
- Terminal publication also checked only `sessionEpoch`. A replay or refresh
  rejection from a superseded credential revision could therefore persist and
  publish verification-required even though a newer pair already owned the
  same account session.
- The corrected invariant is now two-part: every in-flight refresh joins by
  session epoch across in-place credential rotation; after that promise has
  settled, credential revision distinguishes a late response. Both refresh
  rejection and replay-401 terminal publication require the response token to
  remain current for the exact credential revision. A superseded rejection is
  recorded as stale and fails only that request; it cannot withdraw the newer
  account authority.
- Account/history and network-authority contracts plus `git diff --check`
  pass, and the signed ArkTS build succeeds. The follow-up HAP SHA-256 is
  `5722b8add8315817fadb51d3c3d4b2fc61509479d2ca5687b400e0e272972b82`.
- At `03:16:58 +0800` this exact package replaced the 03:03 candidate in place
  only on `192.168.50.237:12345`. The checked protocol performed no clear,
  uninstall, sign-out, credential entry, CAPTCHA action or submit. The new
  process restored `valid_v3` with both tokens, reached
  `account_restore_ready`, and completed `favorites_request_success` at
  `03:17:01`. It recorded no initial 401, refresh, response-Cookie or terminal
  marker in this immediate cold-health cycle.
- Favorites contained one semantic native root with no sign-in/loading/error
  marker. Formal Account contained one account-list root and one saved row,
  with no Web, sign-in root or verification Snackbar. Evidence is under
  `.hvigor/outputs/nextn-credential-revision-install-237-20260828T0316/` and is
  excluded from Git. This accepts only installation and immediate cold health;
  the 03:55 natural concurrency observation remains OPEN.

#### Session-wide refresh fence — fourth independent cold cycle remained healthy — 2026-08-28 03:56 +0800

- The 03:55 checked manifest ran only on the explicitly authorized target
  `192.168.50.237:12345`, with the existing lease and HAP SHA-256
  `5722b8add8315817fadb51d3c3d4b2fc61509479d2ca5687b400e0e272972b82`.
  It force-stopped and restarted NextN without clearing or reinstalling data,
  then performed one native Favorites read and opened the formal Account route.
- The new process restored a `valid_v3` envelope with access and refresh both
  present, reached `account_restore_ready`, and recorded
  `favorites_request_success` at `03:56:19 +0800`. This process recorded no
  initial 401, refresh endpoint call, refresh checkpoint, stale-generation 401,
  replay, response-Cookie checkpoint, terminal 401 or verification-marker
  failure. The auth-expiry shape was `unknown` for both tokens, so absence of a
  401 is only an observed healthy cycle and not evidence that the expiry path
  was exercised.
- Favorites retained one semantic native root and no sign-in, session-check,
  loading or load-error marker. Formal Account retained one account-list root
  and one saved-account row, with no login Web, sign-in root or verification
  Snackbar. The final power readback remained `AWAKE` with
  `OverrideTimeout=86400000ms`.
- Evidence is under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T0355/` and is
  excluded from Git. This extends healthy data-preserving survival by one
  independent process only. The natural concurrent-401 boundary, cross-day
  survival, natural response `Set-Cookie` auth rotation, and a real terminal
  401 with retained Account plus the close/re-login root HDS Snackbar remain
  OPEN. The next bounded physical action is the 04:55 cycle on 237 using the
  fresh `...-20260828T0455/` artifact directory.

#### Saved-envelope recovery no longer depends on the compatibility jar — source correction — 2026-08-28 04:08 +0800

- A current write/delete/restore-path audit found one remaining split-authority
  condition in `restoreInternal`: when the primary envelope was absent or
  unreadable and a saved HUKS envelope remained, the saved-envelope fallback
  ran only if the regular ArkWeb jar was also empty. A readable regular jar
  therefore suppressed the more authoritative HUKS recovery and could publish
  a false verification-required state over recoverable ciphertext.
- This condition contradicted both the existing saved-envelope recovery
  contract and the current invariant that the regular ArkWeb jar is only a
  compatibility input/output boundary. The fallback now tries every saved
  HUKS envelope whenever the primary envelope cannot be restored, independent
  of `regularJarReady`. No record, Cookie, account, UI or network mutation is
  performed by the fallback itself.
- A regression contract now requires this independence and retains the fixed
  `account_restore_saved_envelope_used` diagnostic. This is source evidence
  only until tests, signed build, data-preserving 237 installation and cold
  Account/Favorites verification complete. The live 04:55 natural observation
  remains a separate request-lifecycle acceptance boundary.

#### Saved-envelope correction installed; ordinary primary restore remained healthy — 2026-08-28 04:12 +0800

- Account/history and network-authority contracts plus `git diff --check`
  passed. The normal signed build succeeded and produced HAP SHA-256
  `21f19c1619ae44cd04f610032719b12bc18048096787d15a93535130dec08e62`.
- The checked manifest resolved exactly one live Connected row for
  `192.168.50.237:12345` and used the existing lease for that same full target.
  This exact package was installed with `install -r`; no clear, uninstall,
  sign-out, credential entry, CAPTCHA action, submit or account mutation
  occurred. No other device was selected or operated.
- The new process restored the retained primary `valid_v3` envelope with both
  access and refresh present, reached `account_restore_ready`, and completed
  one ordinary native Favorites read with `favorites_request_success` at
  `04:11:56 +0800`. It recorded no initial 401, refresh request, stale-
  generation 401, replay, response-Cookie checkpoint, terminal 401 or
  verification-marker failure. This run did not need the saved-envelope
  fallback, so it accepts installation and ordinary cold non-regression only;
  it does not claim a live fallback transition.
- Favorites retained one semantic native root with no sign-in, session-check,
  loading or load-error marker. Formal Account retained one account-list root
  and one saved-account row, with no login Web, sign-in root or re-verification
  Snackbar. Both power readbacks were `AWAKE` with
  `OverrideTimeout=86400000ms`. Evidence is under
  `.hvigor/outputs/nextn-saved-envelope-recovery-install-237-20260828T0412/`
  and is excluded from Git.
- The request-lifecycle objective remains OPEN. The next bounded physical
  action is the 04:55 natural cycle on this exact HAP. The natural concurrent-
  401 fence, cross-day survival, first-party response `Set-Cookie` auth
  rotation, and a real terminal 401 with retained Account plus close/re-login
  root HDS Snackbar remain unproven.

#### Current postmortem continuation recorded without closing P0 — 2026-08-28 04:26 +0800

- The existing authoritative postmortem at
  `docs/postmortems/2026-08-10-account-persistence-p0.md` now records the
  current native request architecture and separates device-proven causes from
  source-proven vulnerabilities and still-missing natural evidence. It keeps
  the historical sections intact while explicitly superseding their removed
  ArkWeb request-transport architecture.
- The 02:56 duplicate refresh is recorded as a device-proven concurrency
  defect. Discarded ordinary-response `Set-Cookie`, obsolete terminal-marker
  reasons, retained-ownership/native-authentication conflation, and regular-
  jar suppression of saved-envelope recovery are recorded as source-proven
  defects with their exact device-evidence limits.
- The historical reason that the server rejected the retained refresh token
  remains unknown: the old response did not retain expiry, revocation, or
  missed-rotation evidence. The postmortem and P0 therefore remain OPEN. The
  next physical action is still the 04:55 237-only natural cycle; no earlier
  probe may be substituted for that window.

#### Response Cookie attributes no longer receive a second compatibility rewrite — 2026-08-28 04:34 +0800

- The pre-window source audit found that the first global response-Cookie
  candidate stored the server's raw `Set-Cookie` values and then, during the
  same auth-pair checkpoint, called the JSON-refresh compatibility sink. That
  second call rewrote access/refresh with fixed 14-day/SameSite defaults and
  saved the regular jar again, contradicting the intended preservation of
  server attributes and one-save-per-response boundary.
- `applyRefreshedApiTokens` now distinguishes an already-stored response
  Cookie path. A response rotation keeps the raw server jar write and performs
  only the HUKS/RDB pair checkpoint; a JSON token refresh without authoritative
  auth `Set-Cookie` remains the only path that synthesizes compatibility jar
  values. The network-authority and account/history regressions plus `git diff
  --check` pass, and the signed build succeeded. HAP SHA-256 is
  `3ebada0042e7edf0b2577cebade21312ce82ebd7263662000195e40c9b303814`.
- This exact HAP was installed with `install -r` only on
  `192.168.50.237:12345`; no clear, uninstall, sign-out, credential input,
  CAPTCHA action, submit or account mutation occurred. The new process
  restored `valid_v3` with access and refresh present, reached
  `account_restore_ready`, and recorded `favorites_request_success`.
  Favorites retained one native root with no sign-in/loading/retry marker;
  formal Account retained one account-list root and one saved row with no Web,
  sign-in or verification prompt. Both power gates completed successfully.
  Evidence is under
  `.hvigor/outputs/nextn-response-cookie-attributes-install-237-20260828T0431/`.
- This accepts only source/build correctness, in-place installation and
  ordinary cold non-regression. No response `Set-Cookie` occurred in this
  process, so natural attribute/rotation persistence remains OPEN. The next
  physical action remains the 04:55 natural cycle on this exact HAP.

#### First-party responses can replace/delete an existing HttpOnly Cookie — 2026-08-28 04:38 +0800

- The bundled HarmonyOS `WebCookieManager` API contract states that
  `configCookieSync`'s fourth `includeHttpOnly` argument permits replacement of
  an existing HttpOnly Cookie; it does not apply the attribute to the incoming
  Cookie. The initial global sink incorrectly derived that permission from
  whether the new response header itself contained `HttpOnly`. A server
  deletion or rotation header omitting that attribute could therefore fail to
  replace an existing HttpOnly refresh Cookie.
- The fixed first-party response sink now always permits replacement of an
  existing HttpOnly Cookie. The incoming raw `Set-Cookie` remains the sole
  source of the resulting value and attributes. Network-authority and
  account/history regressions plus `git diff --check` pass; the signed build
  succeeded with HAP SHA-256
  `a99b74cd9d7f87fee730763e6f04db083323d18566b84144e1d4b254b880f172`.
- This exact HAP was installed with `install -r` only on 237. Both power
  readbacks were `AWAKE` with `OverrideTimeout=86400000ms`; the new process
  restored `valid_v3`, reached `account_restore_ready`, and recorded
  `favorites_request_success`. Favorites retained one native root with no
  sign-in/loading/retry state. Formal Account retained one list root and one
  saved row with no Web, sign-in or verification prompt. Evidence is under
  `.hvigor/outputs/nextn-response-cookie-http-only-install-237-20260828T0437/`.
- This remains an ordinary cold non-regression; it did not receive a response
  `Set-Cookie`. Natural rotation/deletion, the corrected concurrent-401 fence,
  cross-day survival, and terminal-401/HDS/re-login remain OPEN. The 04:55
  natural cycle now targets this exact HAP.

#### Final response-Cookie candidate — fifth independent cold cycle remained healthy — 2026-08-28 04:56 +0800

- The checked no-install/no-data-clear manifest ran only on the explicitly
  authorized target `192.168.50.237:12345` under lease
  `20260826-193807-2dc9dfd0`. Run metadata records the final candidate identity
  with HAP SHA-256
  `a99b74cd9d7f87fee730763e6f04db083323d18566b84144e1d4b254b880f172`,
  the exact 237 target and 18 successful commands. It force-stopped and
  restarted NextN with application data preserved, issued one native
  Favorites read and opened the sole native Account destination; it performed
  no install, clear, uninstall, sign-out, credential input, CAPTCHA action or
  submit.
- Both power readbacks reported `AWAKE` with
  `OverrideTimeout=86400000ms`. The retained Favorites layout had one focused
  NextN root, one `nextn-favorites-root`, a native collection and no Web
  component. The Account layout had one focused NextN root, one
  `nextn-account-list-root`, one `nextn-account-saved-row`, exactly one checked
  saved-account selection and no Web component or deleted hidden native
  account root.
- The new persistent diagnostic file
  `nextn-log-20260828-045555.txt` contains only
  `account_restore_payload_shape`,
  `account_auth_expiry_shape phase=restore;access=unknown;refresh=unknown`,
  `account_restore_ready` and `favorites_request_success`. It contains no
  initial 401, refresh endpoint result, refresh checkpoint, stale-generation
  401, replay, response-Cookie stored/applied/rejected event, terminal 401,
  verification-marker failure, visible-login candidate or native-promotion
  event.
- Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T0455/` and is
  excluded from Git. This extends the final candidate by one independent
  healthy process only. It does not exercise or accept the corrected
  concurrent-401 fence or response-Cookie sink. Cross-day survival, a natural
  first-party response `Set-Cookie` rotation, and a real terminal 401 with
  retained Account plus the close/re-login HDS Snackbar and original-WebView
  auto-return remain OPEN. The next bounded physical action is the fresh 05:55
  cycle on the same installed candidate and exact 237 target.

#### Fail-closed response-Cookie candidate — corrected concurrent-401 fence exercised — 2026-08-28 05:14 +0800

- A source audit found two remaining silent-loss paths at the global response
  boundary. `NhApiHttpTransport` discarded malformed, over-limit or otherwise
  unconsumable `Set-Cookie` metadata without telling the session lifecycle, and
  `NhCookieAuthority` skipped an invalid header while the caller could still
  record the response checkpoint as stored. Extraction now carries an explicit
  rejected result, and the Cookie authority validates the complete bounded
  batch before its first jar mutation. Either failure rejects the request with
  the fixed value-free `account_response_cookie_rejected` checkpoint; it cannot
  publish a partial or false stored result.
- The network-authority and account/history contracts plus `git diff --check`
  passed. The signed build succeeded with HAP SHA-256
  `5c1ca6575e23994df3b61e90190c7b53468ba19e48cca8bc7c147e07dd75b14b`.
  A checked manifest bound its CLI target, manifest target, authorized target
  and active lease exactly to `192.168.50.237:12345`, installed this HAP in
  place, and preserved application data. Every resolved device command carried
  that exact full target; no other connected device was selected or operated.
- The new process supplied the natural concurrency evidence missing from the
  04:55 healthy cycle. At `05:13:04--05:13:07 +0800`, the redacted sequence was
  restore ready -> initial 401 -> exactly one refresh endpoint 200 -> durable
  refresh checkpoint -> browser refresh verification ready -> late old-
  credential 401 classified `account_authenticated_read_stale_401_after_refresh`
  -> recovered safe replay -> `favorites_request_success`. There was no second
  refresh-endpoint event, terminal-401 publication or response-Cookie event.
  This accepts the credential-revision fence against the reproduced late-401
  class; it does not claim a server `Set-Cookie` rotation.
- Both power readbacks were `AWAKE` with `OverrideTimeout=86400000ms`, all 18
  checked commands exited zero, and the NextN process remained present.
  Favorites retained one visible `nextn-favorites-root` and no Web component.
  Formal Account retained one visible `nextn-account-list-root`, one visible
  `nextn-account-saved-row`, exactly one checked selection and no Web component
  or removed hidden account root. Evidence is under
  `.hvigor/outputs/nextn-response-cookie-fail-closed-install-237-20260828T0510/`
  and is excluded from Git.
- The P0 remains OPEN. The next bounded physical action is the fresh 05:55
  no-install cold cycle on this exact HAP, which must prove that the 05:13
  replacement pair restores in a later process. Cross-day survival, a natural
  first-party response `Set-Cookie` rotation, and a real terminal 401 with
  retained Account plus close/re-login HDS Snackbar and original-WebView
  auto-return remain unproven.

#### NetworkKit owns response Cookies outside Axios headers — source-proven correction and 237 cold non-regression — 2026-08-28 05:40 +0800

- The previous global response-Cookie candidates still observed the wrong
  platform field. Harmony NetworkKit defines `HttpResponse.header` and
  `HttpResponse.cookies` as separate response properties. The bundled
  `@ohos/axios` 2.2.12 Harmony adapter builds `AxiosResponse.headers` only from
  `data.header` and never forwards `data.cookies`. Consequently, parsing or
  serializing `resp.headers` could never reliably own the platform's actual
  response-Cookie channel. This explains the persistent absence of
  `account_response_cookie_*` events without claiming that any particular
  historical response contained a rotation.
- Every NH request now attaches a fresh NetworkKit `FINAL_RESPONSE`
  interceptor, reads only the bounded in-memory `HttpResponse.cookies` value,
  and supplies it to the existing global session/Cookie checkpoint. The
  first-party URL fence remains in `NhApiHttpTransport`, automatic redirects
  are disabled so an intermediate response cannot escape the same boundary,
  and an unavailable or unobserved final-response interceptor rejects the
  response-Cookie checkpoint rather than silently reporting no Cookie.
  Network-authority and account/history regressions plus `git diff --check`
  passed; the signed build succeeded with HAP SHA-256
  `2135f21ccea2d279c80e306a63b0577b41feb9103da742e948312298e6532d5e`.
- A checked manifest installed this exact HAP with `install -r` only on
  `192.168.50.237:12345`, preserving application data. Run metadata records a
  completed 18-command protocol whose every resolved argv used the exact 237
  target. Both power readbacks were `AWAKE` with
  `OverrideTimeout=86400000ms`; no clear, uninstall, sign-out, credential
  input, CAPTCHA action, submit or account mutation occurred.
- The new process restored `valid_v3` with access and refresh present, reached
  `account_restore_ready`, and completed `favorites_request_success`.
  Favorites retained one `nextn-favorites-root`, one native collection and no
  Web component. Formal Account retained one `nextn-account-list-root`, one
  `nextn-account-saved-row`, exactly one checked Radio and no Web component.
  The newest redacted process log contains no initial 401, refresh, replay,
  response-Cookie stored/applied/rejected event, terminal 401, visible-login
  candidate or native-promotion event. Evidence is under
  `.hvigor/outputs/nextn-networkkit-cookie-interceptor-install-237-20260828T0533/`
  and is excluded from Git.
- This accepts only source/build correctness, in-place installation and the
  immediate cold authenticated non-regression of the real platform Cookie
  capture candidate. The successful request proves the final-response capture
  did not fail closed, but no response Cookie was exposed in this process, so
  natural rotation/deletion persistence remains OPEN. The next bounded
  physical action is the fresh 05:55 no-install cold cycle on this exact HAP
  and exact 237 target. Cross-day survival and the next natural terminal 401
  with retained Account, close/re-login HDS Snackbar and original-WebView
  auto-return also remain unproven.

#### NetworkKit Cookie encoding corrected — exact Set-Cookie first, source-defined jar fallback — 2026-08-28 06:00 +0800

- The 05:40 interpretation was still incomplete. OpenHarmony's NetStack source
  builds `HttpResponse.header['set-cookie']` as the exact response array, while
  `HttpResponse.cookies` comes from libcurl `CURLINFO_COOKIELIST`: CRLF-separated
  Netscape cookie-jar rows containing domain, tailmatch, path, secure, expiry,
  name and value. The 05:37 HAP captured the right platform property but parsed
  those jar rows as raw `Set-Cookie`; a later natural Cookie could therefore
  have been rejected even though its empty-Cookie cold check passed. That HAP
  is superseded and is not a root-cause acceptance candidate.
- The final-response interceptor now captures both bounded platform values.
  The exact `Set-Cookie` array is authoritative when present. Only if it is
  absent does the transport convert a seven-field jar row back to one Cookie;
  that fallback rejects malformed, over-limit and non-`nhentai.net` rows,
  preserves resolved path, expiry, secure and HttpOnly state, and never logs a
  value. Automatic redirects remain disabled, and an unavailable or unobserved
  interceptor still fails closed. The network-authority and account/history
  regressions plus `git diff --check` passed. The signed build succeeded with
  HAP SHA-256
  `40a17fe34e41e54b9450b6f2bd99f1c9fd97c0a2c2d7ca96d1c035452cf2a7bd`.
- A checked manifest installed that HAP in place only on
  `192.168.50.237:12345`, preserving application data. Run metadata records a
  completed 18-command protocol; every resolved command used that full target.
  Both power readbacks were `AWAKE` with `OverrideTimeout=86400000ms`; no other
  device, clear, uninstall, sign-out, credential input, CAPTCHA action, submit
  or account mutation was involved.
- The 05:57 process restored `valid_v3` with access and refresh present, reached
  `account_restore_ready`, and completed `favorites_request_success`. Favorites
  retained one native `nextn-favorites-root` and no Web component. Formal
  Account retained one `nextn-account-list-root`, one
  `nextn-account-saved-row`, exactly one checked Radio and no Web component.
  The latest redacted log contains no initial 401, refresh, replay,
  response-Cookie stored/applied/rejected event, terminal 401,
  visible-login candidate or native-promotion event. Evidence is under
  `.hvigor/outputs/nextn-networkkit-cookie-interceptor-install-237-20260828T0601/`
  and is excluded from Git.
- This is immediate cold authenticated non-regression only. No Cookie arrived
  in the observed response, so natural rotation/deletion persistence remains
  OPEN. The next bounded physical action is the fresh 06:55 no-install cold
  cycle on this exact HAP and exact 237 target. Cross-day survival and the next
  natural terminal 401 with retained Account, close/re-login HDS Snackbar and
  original-WebView auto-return also remain unproven.

#### Verification state and renewable-envelope gates corrected — 237 cold non-regression — 2026-08-28 06:19 +0800

- Exact review found two remaining false-state paths. The root HDS handler
  previously marked a verification revision handled when it merely showed the
  Snackbar. If Safe Mode or the first-party login route then suppressed it,
  the same unhandled revision could never be offered again. Displayed,
  suppressed and user-handled revisions are now separate: only the close or
  original-WebView action consumes the revision. Review also found that the
  decoder still labeled a legacy version-2 access-only envelope as valid, and
  allowed a version-3 envelope without any renewal Cookie. Both cases could
  retain a selected native account while publishing no usable request
  authority. They now retain ownership but enter explicit verification rather
  than reporting a successful restore.
- The abandoned native/API CAPTCHA configuration entry was removed; the only
  production login surface remains the original first-party `/login/` WebView.
  The account-history contract now covers HDS suppression without consumption,
  version-2 rejection and mandatory version-3 renewal. The network-authority
  contract, account/history contract and `git diff --check` passed. The signed
  build succeeded with HAP SHA-256
  `94dcffe893e0577c80a4fb9e56d130445661b5898ed46d8ce21b02e99079e366`.
- The external S0 and atomic-login coordinators were also found to hard-code
  197, 200 and a USB serial as accepted targets. That list was not user
  authorization. Both executable boundaries now accept exactly
  `192.168.50.237:12345`; direct negative invocations for 197 returned only
  `invalid_arguments` and performed no device command.
- The checked 18-command manifest installed the new HAP in place only on 237
  under lease `20260826-193807-2dc9dfd0`, with application data preserved.
  Every command exited zero. Both power readbacks were `AWAKE` with
  `OverrideTimeout=86400000ms`; no clear, uninstall, sign-out, credential
  input, CAPTCHA action, submit or account mutation occurred.
- The 06:17 process restored `valid_v3` with access and refresh present, reached
  `account_restore_ready`, and completed `favorites_request_success`.
  Favorites contained one `nextn-favorites-root` and no Web component. Formal
  Account contained one `nextn-account-list-root`, one
  `nextn-account-saved-row`, exactly one checked Radio and no Web component.
  The new process log contains no initial 401, refresh, replay,
  response-Cookie stored/applied/rejected event, terminal 401, visible-login
  candidate or native-promotion event. Evidence is under
  `.hvigor/outputs/nextn-verification-state-install-237-20260828T0618/` and is
  excluded from Git.
- This is another immediate cold authenticated non-regression, not completion.
  The next bounded action remains the fresh 06:55 no-install cycle on this new
  exact HAP and 237. Natural auth `Set-Cookie` rotation/deletion persistence,
  cross-day survival, and the next natural terminal 401 with retained Account,
  close/re-login HDS Snackbar, original-WebView promotion, native return and a
  later cold authenticated Favorites cycle remain OPEN.

#### Committed clean candidate corrected and accepted for continued 237 observation — 2026-08-28 07:01 +0800

- The account/session lane is committed as
  `701018328d9174453ffbb337924f0c558be427af`. Its first isolated-worktree HAP,
  SHA-256
  `a69c429e9a26fea9cb34c5db06457f4d2e70415fea5c1a50d34c1ecdc6535f98`,
  is rejected. Four exact 237 faultlogs at 06:39:16, 06:39:32, 06:43:52 and
  06:46:55 show a pre-`EntryAbility` `ReferenceError` for missing record
  `&@ohos/axios/index&2.2.12`; the isolated worktree's dependency symlink had
  omitted the packaged axios module. This bad package is not account/session
  runtime evidence.
- Rebuilding the same commit with a worktree-local complete dependency tree
  produced corrected signed HAP SHA-256
  `02f6c82f08b194ac17d79915fc6444a269ba70ea6a34601067d68d9b5abdf8bf`.
  Offline inspection found 133 axios module records, including the previously
  missing exact request. The checked install manifest used `install -r` only
  on `192.168.50.237:12345`, preserved application data, and performed no
  clear, uninstall, sign-out, credential entry, CAPTCHA action or submit.
- The corrected process remained alive as PID 31992 with focused window
  `nextn0`. Favorites exposed `nextn-favorites-root`; formal Account exposed
  `nextn-account-list-root` and `nextn-account-saved-row`. The new redacted
  process log records `valid_v3` with access, renewal and refresh present,
  `account_restore_ready`, and `favorites_request_success`. It contains no
  initial 401, refresh/replay, response-Cookie checkpoint, terminal 401 or
  verification event. Evidence is under
  `.hvigor/outputs/nextn-complete-clean-candidate-install-237-20260828T0700/`;
  the rejected-package faultlogs are under
  `.hvigor/outputs/nextn-clean-candidate-faultlog-readback-237-20260828T0710/`.
  Both artifact trees are excluded from Git.
- This accepts the corrected committed package as the sole candidate for
  continued observation and proves only one immediate preserve-data cold
  authenticated cycle. The outcome remains OPEN. The next bounded physical
  action is the fresh 07:55 no-install observation on exact 237. Natural
  access/refresh Cookie rotation or deletion, persistence into a later
  process, cross-day survival, and the next natural terminal 401 with retained
  Account, global HDS Snackbar, original-WebView re-login promotion, native
  return and a later cold authenticated Favorites cycle remain unproven.

#### Natural refresh checkpoint recovered Favorites — later-process restore OPEN — 2026-08-28 07:56 +0800

- The scheduled no-install/no-data-clear protocol ran only on the explicitly
  authorized `192.168.50.237:12345` under lease
  `20260826-193807-2dc9dfd0`. The CLI target, manifest `target`, manifest
  `authorizedTarget`, live Connected row and lease target all matched exact
  237. All 18 checked commands exited zero; no install, uninstall, data clear,
  sign-out, credential input, CAPTCHA action, submit or account mutation
  occurred. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T0755/` and
  is excluded from Git.
- The privacy-bounded layout summary has one focused NextN Favorites root,
  one native collection, no Web component, no sign-in/loading/error state and
  an authenticated layout candidate. Formal Account has one focused account
  list root, one saved row, exactly one selected Radio, no Web component, no
  sign-in prompt, no verification-required state and no save failure.
- The newest process supplied a real refresh lifecycle rather than another
  empty healthy check. Its fixed event order is restore payload shape ->
  restore expiry shape -> restore ready -> initial-401 expiry shape -> one
  authenticated-read initial 401 -> browser Cookie shape -> one ready refresh
  endpoint -> refresh-checkpoint expiry shape -> browser refresh ready -> one
  recovered safe replay -> `favorites_request_success`. There is no second
  refresh, replayed/final 401, verification marker failure, response-Cookie
  stored/applied/rejected event or Favorites failure.
- The `refresh_checkpoint` event proves that this process crossed the durable
  replacement-pair checkpoint before its recovered replay. Restore,
  initial-401 and refresh-checkpoint expiry classes are all `unknown`; this is
  expected for the current Cookie metadata shape and is not longevity proof.
  The next independent process must establish that the 07:55 replacement pair
  restores and serves Favorites without another immediate refresh.
- The checked observation manifest now points to the unique 08:55 artifact
  directory for that later-process test. Natural response `Set-Cookie`
  rotation/deletion, cross-day survival and the next natural terminal 401 with
  retained Account, global close/re-login HDS Snackbar, original-WebView
  promotion, native return and a later cold authenticated Favorites cycle all
  remain OPEN.

#### Refresh replacement pair cold-restored in a later process — 2026-08-28 08:56 +0800

- The no-install/no-data-clear protocol ran exactly once on the explicitly
  authorized `192.168.50.237:12345` under lease
  `20260826-193807-2dc9dfd0`. The live Connected row, CLI target, manifest
  `target`, manifest `authorizedTarget` and lease target all matched exact
  237. All 19 checked commands exited zero; both PowerManager readbacks showed
  `AWAKE` with `OverrideTimeout=86400000ms`, both window readbacks contained
  the NextN window, and the final process check retained a PID. No install,
  uninstall, data clear, sign-out, credential input, CAPTCHA action, submit or
  account mutation occurred.
- The privacy-bounded summary has one focused native Favorites root with a
  collection, no Web component, sign-in prompt, loading or error state, and
  an authenticated layout candidate. Formal Account has one focused account
  list root, one saved row, exactly one selected Radio, no Web component,
  sign-in prompt, verification-required state or save failure.
- This new process emitted only `session_start` -> restore payload shape ->
  restore expiry shape -> `account_restore_ready` ->
  `favorites_request_success`. It emitted no initial 401, refresh endpoint,
  refresh checkpoint, replay, replayed/final 401, verification-marker failure,
  response-Cookie stored/applied/rejected event or Favorites failure.
- This proves the access/refresh replacement pair durably checkpointed during
  the 07:55 refresh was restored by an independent later process and served an
  authenticated Favorites read without another immediate refresh. Evidence is
  retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T0855/` and
  is excluded from Git. It does not prove cross-day survival, a naturally
  occurring response `Set-Cookie` rotation/deletion, or the terminal-401 UI
  and original-WebView re-login branch.
- The checked observation manifest now points to the unique 09:55 artifact
  directory for the next no-install cycle. Cross-day survival, natural
  response-Cookie rotation/deletion and the next natural terminal 401 with
  retained Account, global close/re-login HDS Snackbar, original-WebView
  promotion, native return and a later cold authenticated Favorites cycle all
  remain OPEN.

#### Recurrent natural refresh recovered Favorites — next-process restore OPEN — 2026-08-28 09:57 +0800

- The no-install/no-data-clear protocol ran exactly once on the explicitly
  authorized `192.168.50.237:12345` under lease
  `20260826-193807-2dc9dfd0`. The live Connected row, CLI target, manifest
  `target`, manifest `authorizedTarget` and lease target all matched exact
  237. All 19 checked commands exited zero; both PowerManager readbacks showed
  `AWAKE` with `OverrideTimeout=86400000ms`, and the final process check
  retained a PID. No install, uninstall, data clear, sign-out, credential
  input, CAPTCHA action, submit or account mutation occurred.
- Before this observation, commit `c38622f` corrected the privacy-bounded
  summarizer so an Account verification row and the root HDS `Dialog` are
  separate signals. It reports the HDS surface, re-verification click target
  and close click target independently, and does not call retained content an
  authenticated layout candidate while that terminal surface is present.
- The 09:55 layouts have one focused native Favorites root with a collection,
  no Web, sign-in/loading/error state or verification HDS. Formal Account has
  one focused account-list root, one saved row, exactly one selected Radio, no
  Web, sign-in prompt, verification-required state, verification HDS or save
  failure. Both remain authenticated layout candidates in this non-terminal
  cycle.
- The fixed event sequence is restore payload/expiry shape -> restore ready ->
  initial-401 expiry shape -> one authenticated-read initial 401 -> browser
  Cookie shape -> exactly one ready refresh endpoint -> refresh-checkpoint
  expiry shape -> browser refresh ready -> one recovered safe replay ->
  `favorites_request_success`. There is no second refresh, replayed/final 401,
  verification-marker failure, response-Cookie stored/applied/rejected event
  or Favorites failure.
- Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T0955/` and is
  excluded from Git. This proves recovery of this natural hourly refresh cycle
  only. The next independent process must establish that the 09:55 replacement
  pair restores and serves Favorites without another immediate refresh.
  Cross-day survival, natural response-Cookie rotation/deletion and the next
  natural terminal 401 with retained Account, global close/re-login HDS
  Snackbar, original-WebView promotion, native return and a later cold
  authenticated Favorites cycle remain OPEN. The checked manifest now points
  to the unique 10:55 artifact directory.

#### 09:55 replacement pair cold-restored in the next process — 2026-08-28 10:57 +0800

- The no-install/no-data-clear protocol ran exactly once on the explicitly
  authorized `192.168.50.237:12345` under the renewed lease
  `20260826-193807-2dc9dfd0`. The live Connected row, CLI target, manifest
  `target`, manifest `authorizedTarget` and lease target all matched exact
  237. All 19 checked commands exited zero; both PowerManager readbacks showed
  `AWAKE` with `OverrideTimeout=86400000ms`, and the final process check
  retained a PID. No install, uninstall, data clear, sign-out, credential
  input, CAPTCHA action, submit or account mutation occurred.
- The privacy-bounded summary has one focused native Favorites root with a
  collection, no Web, sign-in/loading/error state or verification HDS. Formal
  Account has one focused account-list root, one saved row, exactly one
  selected Radio, no Web, sign-in prompt, verification-required state,
  verification HDS or save failure. Both are authenticated layout candidates.
- The new process emitted only `session_start` -> restore payload/expiry shape
  -> `account_restore_ready` -> `favorites_request_success`. It emitted no
  initial 401, refresh endpoint, refresh checkpoint, replay, replayed/final
  401, verification-marker failure, response-Cookie stored/applied/rejected
  event or Favorites failure.
- This proves the access/refresh replacement pair checkpointed during the
  09:55 natural refresh was restored by an independent later process and
  served an authenticated Favorites read without another immediate refresh.
  Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T1055/` and is
  excluded from Git. Cross-day survival, natural response-Cookie
  rotation/deletion and the next natural terminal 401 with retained Account,
  global close/re-login HDS Snackbar, original-WebView promotion, native return
  and a later cold authenticated Favorites cycle remain OPEN. The checked
  manifest now points to the unique 11:55 artifact directory.

#### 11:55 candidate cold-restored without another refresh — 2026-08-28 11:57 +0800

- The no-install/no-data-clear protocol ran exactly once on the explicitly
  authorized `192.168.50.237:12345` under lease
  `20260826-193807-2dc9dfd0`. The live Connected row, CLI target, manifest
  `target`, manifest `authorizedTarget` and lease target all matched exact
  237. All 19 checked commands exited zero; both PowerManager readbacks showed
  `AWAKE` with `OverrideTimeout=86400000ms`, and the final process check
  retained PID 50324. No install, uninstall, data clear, sign-out, credential
  input, CAPTCHA action, submit or account mutation occurred.
- The privacy-bounded summary has one focused native Favorites root with a
  collection, no Web, sign-in/loading/error state or verification HDS. Formal
  Account has one focused account-list root, one saved row, exactly one
  selected Radio, no Web, sign-in prompt, verification-required state,
  verification HDS or save failure. Both are authenticated layout candidates.
- The new process emitted only `session_start` -> restore payload/expiry shape
  -> `account_restore_ready` -> `favorites_request_success`. It emitted no
  initial 401, refresh endpoint, refresh checkpoint, replay, replayed/final
  401, verification-marker failure, response-Cookie stored/applied/rejected
  event or Favorites failure.
- This is another independent preserve-data cold process that restored the
  current durable access/refresh pair and served authenticated Favorites
  without an immediate refresh. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T1155/` and is
  excluded from Git. It does not prove cross-day survival, natural response
  `Set-Cookie` rotation/deletion or the terminal-401 UI and original-WebView
  re-login branch. Those outcomes remain OPEN. The checked manifest now
  points to the unique 12:55 artifact directory.

#### Global HTTP-owner commit installed; natural refresh recovered on 237 — 2026-08-28 12:15 +0800

- The final monitored code identity is now commit
  `a0950b42634f869f588add9521f93ede67887476`, which includes the committed
  account/session lifecycle and `93b64ec` global bounded HTTP-owner
  consolidation. A new detached worktree used the complete root and all nine
  per-module `oh_modules` trees plus reader-enhancement submodule commit
  `640f310ee7addb0c4eb46e55b1f7181017a653df`. Network-authority and
  account/history contracts passed, the signed build completed, and offline
  `modules.abc` inspection found the exact `@ohos/axios` 2.2.12 entry,
  `NhApiHttpTransport` and `StreamingHttpClient`.
- The resulting signed HAP has SHA-256
  `b82ad8d5df7147d7874c5efc27f08efc522a2bb3a06c293dbfb0b4ee24dca3c9`.
  A checked 20-command manifest bound the live Connected row, CLI target,
  manifest `target`, `authorizedTarget` and existing lease exactly to
  `192.168.50.237:12345`, installed it with `install -r`, force-stopped and
  cold-started with application data preserved, then used only the ordinary
  native Favorites and My-to-Account routes. No clear, uninstall, sign-out,
  credential input, CAPTCHA action, submit, internal recovery Want or account
  mutation occurred.
- Both PowerManager readbacks showed `AWAKE` with
  `OverrideTimeout=86400000ms`; installation reported success and the final
  process remained as PID 59565. Favorites retained one focused native root
  with a collection and no Web, sign-in/loading/error state or verification
  HDS. Formal Account retained one list root, one saved row, exactly one
  selected Radio and no Web, sign-in, verification-required state, HDS or save
  failure.
- The new process emitted restore ready -> one authenticated-read initial 401
  -> one refresh-endpoint 200/ready -> durable refresh checkpoint -> browser
  verification ready -> one recovered safe replay ->
  `favorites_request_success`. There was no second refresh, replayed/final 401,
  verification-marker failure, response-Cookie stored/applied/rejected event
  or Favorites failure. Evidence is retained under
  `.hvigor/outputs/nextn-network-clean-candidate-install-237-20260828T1212/`
  and is excluded from Git.
- This accepts the clean final candidate's installation and one real natural
  refresh recovery only. The replacement pair still needs an independent
  later-process restore on this HAP. Cross-day survival, a natural response
  `Set-Cookie` rotation/deletion and the next natural terminal 401 with
  retained Account, close/re-login HDS Snackbar, original-WebView promotion,
  native return and a later cold authenticated Favorites cycle remain OPEN.
  The checked observation manifest remains on the unique 12:55 artifact path
  and now records this HAP identity.

#### Replacement pair restored; response-Cookie crash window closed — 2026-08-28 13:00 +0800

- The 12:55 no-install/no-data-clear protocol ran exactly once on the
  explicitly authorized `192.168.50.237:12345` under lease
  `20260826-193807-2dc9dfd0`. The live Connected row, CLI target, manifest
  `target`, manifest `authorizedTarget` and lease target all matched exact
  237. All 19 checked commands exited zero; both PowerManager readbacks showed
  `AWAKE` with `OverrideTimeout=86400000ms`, and the final process check
  retained a PID. No install, uninstall, data clear, sign-out, credential
  input, CAPTCHA action, submit, internal recovery Want or account mutation
  occurred.
- The independent 12:55 process emitted only `session_start` -> restore
  payload/expiry shape -> `account_restore_ready` ->
  `favorites_request_success`. It emitted no initial 401, refresh endpoint,
  refresh checkpoint, replay, replayed/final 401, verification-marker failure,
  response-Cookie stored/applied/rejected event or Favorites failure. The
  native Favorites summary has one collection and no Web/sign-in/loading/error
  or verification HDS. Formal Account has one list root, one saved row and one
  selected Radio with no Web/sign-in/verification/save-failure state. This
  proves that the replacement pair checkpointed by the 12:13 refresh restored
  in a later process and served authenticated Favorites without another
  immediate refresh. Evidence is under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T1255/` and is
  excluded from Git.
- A current source audit then found one remaining two-store crash window. The
  response lifecycle wrote the raw server `Set-Cookie` batch to ArkWeb before
  the matching access/refresh pair crossed the HUKS/RDB checkpoint, while cold
  restore accepted any complete ArkWeb pair without comparing it to the sealed
  native generation. Process death between those writes could therefore leave
  a new browser refresh token beside the old native request authority, which
  is the same split-generation failure class the global owner was intended to
  remove.
- Commit `0b9c3da1fc1220fc57613189e4e6bcfb880891b6` makes the encrypted native
  generation the recoverable commit point: a successful authenticated
  response checkpoints its fenced pair before the sole raw-header ArkWeb
  sink, and cold restore accepts an existing jar only when its auth pair
  matches the sealed generation; otherwise the sealed generation repairs the
  jar. Network-authority, account/history and observation-summary regressions
  plus `git diff --check` passed. An isolated signed build with the complete
  dependency trees succeeded. Its HAP SHA-256 is
  `c48ba4594affeceab10a2a0361331c8b8648f5b7325d0a69f3a09157dbafb888`;
  offline `modules.abc` inspection found the exact axios 2.2.12 entry,
  `NhApiHttpTransport`, `NhSessionHttpClient` and both new generation-fence
  symbols.
- A checked 20-command manifest installed that HAP with `install -r` only on
  exact 237 and preserved application data. Every command exited zero; both
  PowerManager readbacks were `AWAKE` with `OverrideTimeout=86400000ms`, the
  final process check retained a PID and the final window remained NextN.
  The 12:58 process again emitted only restore payload/expiry shape ->
  `account_restore_ready` -> `favorites_request_success`, with no refresh,
  replay, terminal 401 or response-Cookie event. Favorites and formal Account
  retained the same authenticated native summaries and no Web, sign-in,
  verification HDS or save failure. Evidence is under
  `.hvigor/outputs/nextn-cookie-crash-candidate-install-237-20260828T1258/`
  and is excluded from Git.
- This accepts the source/build correction and one preserve-data cold
  non-regression on the new candidate. It does not manufacture the event that
  exercises the new order. Natural response `Set-Cookie` rotation/deletion,
  persistence into a later process, cross-day survival and the next natural
  terminal 401 with retained Account, close/re-login HDS, original-WebView
  promotion, native return and a later authenticated cold Favorites cycle all
  remain OPEN. The checked natural monitor advances to 13:55 on this exact
  candidate.

#### Cookie crash candidate multi-cycle observation — healthy — 2026-08-28 14:02 +0800

- The scheduled 13:55 observation did not start inside the sandbox because its
  HDC child could not see the host daemon. No manifest action or artifact was
  created by those rejected dry-runs. After the same checked wrapper received
  host HDC access, its mandatory dry-run matched exactly one live Connected row
  for `192.168.50.237:12345`; the active lease, CLI target, manifest `target`
  and `authorizedTarget` all matched exact 237. The protocol then ran exactly
  once from 14:02:10 to 14:02:38. All 19 checked commands exited zero. No
  install, uninstall, data clear, sign-out, credential input, CAPTCHA action,
  submit, internal recovery Want or account mutation occurred.
- The independent process emitted only `session_start` -> restore payload and
  expiry shape -> `account_restore_ready` -> `favorites_request_success`. It
  emitted no initial 401, refresh endpoint, refresh checkpoint, replay,
  replayed/final 401, verification-marker failure, response-Cookie
  stored/applied/rejected event or Favorites failure. The native Favorites
  summary retained one collection with no Web, sign-in, loading, error or HDS.
  Formal Account retained one list root, one saved row and one selected Radio
  with no Web, sign-in, verification-required state, HDS or save failure.
  Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T1355/` and is
  excluded from Git.
- This accepts another preserve-data cold authenticated cycle on commit
  `0b9c3da1fc1220fc57613189e4e6bcfb880891b6`; it does not exercise the repaired
  response-Cookie commit order. Natural response `Set-Cookie` rotation or
  deletion and its later-process restore, cross-day survival, and the next
  natural terminal 401 with retained Account, close/re-login HDS,
  original-WebView promotion, native return and a later cold authenticated
  Favorites cycle remain OPEN. The checked old-candidate monitor advances to
  14:55 pending the planned preserve-data installation of the clean HEAD
  candidate.

#### Clean HEAD candidate installed with data preserved — 2026-08-28 14:05 +0800

- The signed HAP produced by the clean ten-module rebuild at source commit
  `cadf534` was rechecked immediately before installation; SHA-256 remained
  `93e6cfa1c87e66f5ae67c396c3b0b91f8e58bfc58bc5dc95dda74fff69f965be`.
  The checked manifest, CLI target, active lease and exactly one live Connected
  row all matched `192.168.50.237:12345`. The 20-command protocol ran exactly
  once from 14:05:27 to 14:05:57. It used `install -r`, preserved application
  data, and all commands exited zero. No uninstall, data clear, sign-out,
  credential input, CAPTCHA action, submit, internal recovery Want or account
  mutation occurred.
- The first process on this candidate emitted only `session_start` -> restore
  payload and expiry shape -> `account_restore_ready` ->
  `favorites_request_success`. There was no initial 401, refresh endpoint,
  refresh checkpoint, replay, replayed/final 401, verification-marker failure,
  response-Cookie stored/applied/rejected event or Favorites failure. Native
  Favorites retained one collection with no Web, sign-in, loading, error or
  HDS. Formal Account retained one list root, one saved row and one selected
  Radio with no Web, sign-in, verification-required state, HDS or save failure.
  Evidence is retained under
  `.hvigor/outputs/nextn-clean-head-cadf534-install-237/` and is excluded from
  Git.
- This accepts installation and one preserve-data cold authenticated cycle on
  the complete source candidate. It does not close the long-running outcome.
  The 14:55 no-install monitor now starts this candidate's multi-cycle and
  cross-day baseline. A natural response `Set-Cookie` auth rotation or deletion
  and its later-process restore, and the next natural terminal 401 with retained
  Account, close/re-login HDS, original-WebView promotion, native return and a
  later cold authenticated Favorites cycle remain OPEN.

#### Cross-process diagnostic observation window closed — 2026-08-28 14:17 +0800

- A current host-tool audit found that the privacy-bounded observation
  summarizer selected only the newest retained diagnostics file. The hourly
  protocol force-stops and cold-starts the app before Favorites, so an auth
  Cookie rotation or terminal 401 appended to the preceding process file
  between observations would be hidden by the newer cold-start file. Repeated
  reports of no response-Cookie event were therefore trustworthy only for the
  newest process, not for the full interval.
- The summarizer now accepts the manifest's fixed
  `context.diagnosticWindowStart`, parses only the logger's fixed local
  millisecond timestamp prefix, scans all retained diagnostics files, and
  consumes only lines from that baseline through the checked protocol's
  `metadata.endedAt`. It still returns only allowlisted stage counts, event
  order, booleans, the next fixed capture-boundary timestamp and coarse expiry
  shapes; it never returns a raw line,
  Cookie, token, URL, account value or arbitrary message. Same-second retained
  file suffixes such as `-01` are included. Artifacts without a baseline retain
  the old latest-file behavior for historical reproducibility; once a manifest
  declares a baseline, an invalid start/end window rejects the summary instead
  of silently falling back to the latest file.
- A two-file regression proves that a response-Cookie event appended after the
  baseline to the older process file is retained alongside the later cold-start
  events, while a pre-baseline rejection is excluded. The observation-summary,
  network-authority and account/history tests, JSON validation and
  `git diff --check` pass. To avoid a gap between the diagnostics receive and
  later postflight commands, the next manifest baseline is the successful
  `receive-redacted-*` command's `startedAt`, not the whole protocol's end; a
  missing or invalid capture boundary rejects the windowed summary. The 14:55
  baseline is `2026-08-28T14:05:57.133530+08:00`; no app build, install or
  device action was performed by this host-tool correction.

#### Clean HEAD later-process refresh recovery — 2026-08-28 14:58 +0800

- The scheduled 14:55 artifact was still absent after its full same-minute
  startup window. A host-side gate then proved that the active lease, manifest
  `target`, manifest `authorizedTarget`, CLI target and an exact live Connected
  row all matched `192.168.50.237:12345`, and that no matching observation
  process was already running. The checked 19-command protocol ran exactly
  once from 14:58:28.160418 to 14:58:55.684254. Every command exited zero. No
  install, uninstall, data clear, sign-out, credential input, CAPTCHA action,
  submit, internal recovery Want or account mutation occurred.
- The privacy-bounded summary scanned 12 retained process logs from the fixed
  `2026-08-28T14:05:57.133530+08:00` baseline through the successful diagnostics
  receive. In the new cold process it observed `session_start` -> restore
  payload/expiry shape -> `account_restore_ready` -> one authenticated-read
  initial 401 -> browser Cookie shape -> one refresh-endpoint status/ready ->
  durable refresh checkpoint -> browser refresh ready -> one recovered safe
  replay -> `favorites_request_success`. There was no terminal 401, second
  refresh, response-Cookie stored/applied/rejected event or Favorites failure.
- Native Favorites retained one focused root and a collection with no Web,
  sign-in, loading, error or verification HDS. Formal Account retained one
  list root, one saved row and exactly one selected Radio with no Web, sign-in,
  verification-required state, HDS or save failure. This is a second real
  refresh recovery on the clean candidate and proves the bounded refresh and
  replay path survived a later process while preserving native account
  ownership. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T1455/` and is
  excluded from Git.
- This does not prove a natural response `Set-Cookie` auth rotation, because no
  response-Cookie stage occurred in the captured window, and it is not a
  terminal-401 acceptance because refresh recovered. Cross-day survival,
  response-Cookie rotation/deletion with later-process restore, and the next
  natural terminal 401 with retained Account, close/re-login HDS,
  original-WebView promotion, native return and a later cold authenticated
  Favorites cycle remain OPEN. The next no-install observation advances to
  15:55, with the overlap-safe diagnostics baseline set to the successful
  receive command's `startedAt`, `2026-08-28T14:58:54.810527+08:00`.

#### Original silent-expiry mechanism confirmed — 2026-08-28 15:14 +0800

- The 14:58 clean-candidate process supplied the missing live boundary: a
  restored account can retain both auth cookies and native selected-account
  state while its first authenticated read receives a real 401. The current
  implementation exchanged the retained refresh token at the fixed
  `/api/v2/auth/refresh` endpoint, checkpointed the replacement pair, verified
  it and recovered the original safe Favorites read with one replay.
- Git baseline `d8291aa` did not perform that exchange. Its bounded 401 helper
  called `recoverRegularArkWebCookieJarAfterAuthenticated401()`, which took the
  same sealed access token and forced it back into ArkWeb before repeating the
  GET. No refresh endpoint was called in that path. Once the access token had
  actually expired, replaying the identical credential necessarily produced a
  second 401 even though the saved account row and local encrypted envelope
  still existed.
- The visible symptom was also structurally local. Baseline authenticated
  mutations deliberately did not replay, but on 401 only threw a request-local
  “refresh in Settings” error. Gallery favourite-status enrichment caught its
  request failure and returned an unknown status; `saveFavorite()` caught its
  mutation failure and showed only a page-local Toast. The baseline root had
  no `AccountAuthNoticeState` or global HDS Snackbar host. This combination
  explains the reported sequence: the native Account page remained selected,
  no global expiry prompt appeared, and the stale server credential became
  visible to the user only when a favourite action failed.
- Later partial fixes added browser refresh and Cookie synchronization, but
  still split request authority and persistence across ArkWeb, native HTTP and
  separate checkpoints. The clean candidate replaces that class of behavior
  with one session HTTP owner, an actual single-flight refresh exchange,
  encrypted readback-verified token checkpoint, one safe replay and a root
  terminal-401 notice while retaining Account ownership. The 14:58 device
  chain proves refresh recovery; later-process restore of this exact pair,
  natural response `Set-Cookie`, cross-day survival and the terminal-401 HDS
  plus original-WebView return path remain OPEN.

#### External NH-client authentication comparison — 2026-08-28 (read-only research)

- The closest public comparison is Kuron/nhasixapp. Its nhentai configuration
  declares a `tokenApi` flow with the original WebView login URL, explicit
  `/api/v2/auth/login`, `/api/v2/auth/refresh` and `/api/v2/auth/logout`
  endpoints, access/refresh token fields and an `access_token` WebView-cookie
  promotion boundary. Its release history separately records malformed
  `Set-Cookie` handling, duplicate CookieManager-interceptor prevention,
  standardized authentication UA, bounded retry and rate-limit handling.
  Sources: [config](https://github.com/shirokun20/nhasixapp/blob/master/assets/configs/nhentai-config.json),
  [releases](https://github.com/shirokun20/nhasixapp/releases).
- NClientV3 publicly lists OkHttp and PersistentCookieJar. That library makes
  cookies survive process restarts, but its documented scope does not imply a
  server-invalidated cookie can refresh itself. NClientV3's release history
  also says login was not fixed in 4.2.0 before the project migrated v2
  onboarding toward an API key. Sources: [README](https://github.com/yosefario-dev/NClientV3),
  [PersistentCookieJar](https://github.com/franmontiel/PersistentCookieJar),
  [releases](https://github.com/maxwai/NClientV3/releases).
- NHViewer Universal's public README documents Flutter/Dio and local
  collection features but no comparable online-auth lifecycle, so it is not
  acceptance evidence for this lane. Source:
  [README](https://github.com/ttdyce/nhviewer-universal).
- This comparison does not prove any other client is problem-free, nor does it
  replace device evidence. It reinforces the current NextN contract to keep
  WebView as the login carrier, one native NH request owner, one CookieManager
  bridge, encrypted access/refresh persistence, single-flight refresh, one
  safe replay and an explicit terminal-401 HDS path. Natural response
  `Set-Cookie` rotation, cross-day restore and terminal-401 return-to-WebView
  acceptance on 237 remain OPEN.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-28 16:58 +0800

- After the scheduled 15:55 artifact was absent, the host-side gate confirmed
  the active lease, manifest target, authorized target, live Connected row and
  CLI target all matched `192.168.50.237:12345`; no same-manifest process was
  running. The checked 19-command protocol then ran exactly once. It performed
  only wake/timeout, data-preserving cold start, native Favorites, native
  Account inspection and redacted diagnostics; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want or account mutation occurred.
- The privacy-bounded summary completed with the candidate foregrounded. It
  observed one native Favorites root with a collection and no Web, sign-in,
  loading, error or verification HDS, plus one native Account list with one
  saved and selected account and no Web/sign-in/verification HDS. The retained
  diagnostics contained `session_start`, restore payload shape,
  `account_restore_ready`, one restore expiry-shape record and
  `favorites_request_success`; there was no terminal 401, refresh event or
  response-Cookie stored/applied/rejected event.
- This is a later-process authenticated Favorites restore observation, not
  evidence of natural Cookie rotation or refresh behavior. Cross-day survival,
  natural response-Cookie persistence and the next terminal-401 HDS plus
  original-WebView return path remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T1555/` and
  the next manifest window advances from the successful diagnostics receive
  boundary `2026-08-28T16:58:58.456866+08:00`.

#### Clean HEAD later-process refresh recovery — 2026-08-28 17:58 +0800

- At the next scheduled boundary, the host-side gate again confirmed the exact
  authorized target and active lease, with no same-manifest process running.
  The checked 19-command protocol ran exactly once and performed only the
  declared data-preserving cold-start, native Favorites/Account inspection and
  redacted diagnostics capture; no install, clear, sign-out, credential,
  CAPTCHA, submit, recovery Want or account mutation occurred.
- The privacy-bounded summary observed native Account and Favorites roots with
  one saved/selected account and a populated collection. Diagnostics recorded
  restore, one authenticated-read initial 401, a successful refresh endpoint
  check, browser-refresh readiness, one recovered replay and
  `favorites_request_success`; no terminal 401 or response-Cookie
  stored/applied/rejected event occurred. The refresh path therefore recovered
  again in a later process, but the server did not expose a response-Cookie
  rotation in this window.
- This is a third observed refresh recovery, not cross-day acceptance and not
  proof of natural Cookie rotation persistence. Cross-day survival, natural
  response-Cookie persistence and the next terminal-401 HDS plus
  original-WebView return path remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T1655/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-28T17:58:26.729944+08:00`.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-28 18:57 +0800

- At the scheduled boundary, the checked protocol ran exactly once against the
  exact authorized target under the active lease. It performed only the
  declared wake/timeout gate, data-preserving cold start, native Favorites and
  Account inspection, and redacted diagnostics capture; no install, clear,
  sign-out, credential input, CAPTCHA, submit, recovery Want, or account
  mutation occurred.
- The privacy-bounded summary observed native Account and Favorites roots with
  one saved/selected account and a populated collection. Diagnostics recorded
  restore, one expiry-shape record, and authenticated Favorites success; there
  was no terminal 401, refresh event, or response-Cookie stored/applied/
  rejected event.
- This is another later-process authenticated restore observation, not proof
  of cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T1755/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-28T18:57:16.350142+08:00`.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-28 19:59 +0800

- After renewing the existing lease because its TTL had elapsed, the checked
  protocol ran exactly once against the exact authorized target. It performed
  only the declared wake/timeout gate, data-preserving cold start, native
  Favorites and Account inspection, and redacted diagnostics capture; no
  install, clear, sign-out, credential input, CAPTCHA, submit, recovery Want,
  or account mutation occurred.
- The privacy-bounded summary observed native Account and Favorites roots with
  one saved/selected account and a populated collection. Diagnostics recorded
  restore, one expiry-shape record, and authenticated Favorites success; no
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is another later-process authenticated restore observation, not proof
  of cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T1855/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-28T19:59:10.699681+08:00`.

#### Clean HEAD later-process refresh recovery — 2026-08-28 20:58 +0800

- After acquiring a fresh lease for the exact target because the prior TTL had
  expired, the checked protocol ran exactly once against
  `192.168.50.237:12345`. It performed only the declared wake/timeout gate,
  data-preserving cold start, native Favorites and Account inspection, and
  redacted diagnostics capture; no install, clear, sign-out, credential input,
  CAPTCHA, submit, recovery Want, or account mutation occurred.
- The privacy-bounded summary observed native Account and Favorites roots with
  one saved/selected account and a populated collection. Diagnostics recorded
  a later-process authenticated-read initial 401, browser refresh readiness,
  refresh-endpoint status/readiness, a recovered safe replay, and
  `favorites_request_success`; no terminal 401 or response-Cookie
  stored/applied/rejected event occurred.
- This is another observed refresh recovery, not proof of cross-day survival,
  natural response-Cookie rotation persistence, or the terminal-401 HDS plus
  original-WebView return path. Those acceptance boundaries remain OPEN.
  Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T1955/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-28T20:58:24.492557+08:00`.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-28 21:56 +0800

- After acquiring a fresh lease for the exact target because the prior TTL had
  expired, the checked protocol ran exactly once against
  `192.168.50.237:12345`. It performed only the declared wake/timeout gate,
  data-preserving cold start, native Favorites and Account inspection, and
  redacted diagnostics capture; no install, clear, sign-out, credential input,
  CAPTCHA, submit, recovery Want, or account mutation occurred.
- The privacy-bounded summary observed native Account and Favorites roots with
  one saved/selected account and a populated collection. Diagnostics recorded
  restore, one expiry-shape record, and authenticated Favorites success; no
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is another later-process authenticated restore observation, not proof
  of cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T2055/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-28T21:56:46.990423+08:00`.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-28 22:56 +0800

- After acquiring a fresh lease for the exact target because the prior TTL had
  expired, the checked protocol ran exactly once against
  `192.168.50.237:12345`. It performed only the declared wake/timeout gate,
  data-preserving cold start, native Favorites and Account inspection, and
  redacted diagnostics capture; no install, clear, sign-out, credential input,
  CAPTCHA, submit, recovery Want, or account mutation occurred.
- The privacy-bounded summary observed native Account and Favorites roots with
  one saved/selected account and a populated collection. Diagnostics recorded
  restore, one expiry-shape record, and authenticated Favorites success; no
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is another later-process authenticated restore observation, not proof
  of cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T2155/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-28T22:56:43.230970+08:00`.

#### Clean HEAD later-process refresh recovery — 2026-08-28 23:57 +0800

- After acquiring a fresh lease for the exact target because the prior TTL had
  expired, the checked protocol ran exactly once against
  `192.168.50.237:12345`. It performed only the declared wake/timeout gate,
  data-preserving cold start, native Favorites and Account inspection, and
  redacted diagnostics capture; no install, clear, sign-out, credential input,
  CAPTCHA, submit, recovery Want, or account mutation occurred.
- The privacy-bounded summary observed native Account and Favorites roots with
  one saved/selected account and a populated collection. Diagnostics recorded
  an authenticated-read initial 401, refresh-endpoint status/readiness,
  browser refresh readiness, a stale 401 after refresh, a recovered safe
  replay, and `favorites_request_success`; no terminal 401 or response-Cookie
  stored/applied/rejected event occurred.
- This is another observed refresh recovery, not proof of cross-day survival,
  natural response-Cookie rotation persistence, or the terminal-401 HDS plus
  original-WebView return path. Those acceptance boundaries remain OPEN.
  Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T2255/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-28T23:57:12.875114+08:00`.

#### Rejected 237 foreground precondition — 2026-08-29 00:58 +0800

- The prior artifact was absent at the scheduled boundary. The existing lease
  had expired, so a fresh lease was acquired for the exact authorized target.
  The live target was initially TCP Offline; one bounded `hdc tconn` recovery
  restored `192.168.50.237:12345` to Connected and a lease-wrapped shell echo
  succeeded. The checked 19-command protocol then ran exactly once.
- The protocol exited successfully at the command level, but its retained
  Account and Favorites layouts did not prove a focused NextN `EntryAbility`:
  both safe summaries returned `foregroundNextn=false`, no native roots, and
  no authenticated-state markers. Diagnostics contained no stages or auth
  events. This is an evidence/precondition failure, not evidence of logout,
  terminal 401, or Cookie behavior; the chain is rejected and no login action
  was taken.
- Cross-day survival, natural response-Cookie rotation persistence, and the
  terminal-401 HDS plus original-WebView return path remain OPEN. Evidence is
  retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260828T2355/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T00:58:37.872902+08:00`. The next cycle must re-establish the
  foreground precondition before any account-state interpretation.

#### Clean HEAD later-process refresh recovery — 2026-08-29 01:59 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore, an authenticated-read initial 401, refresh
  endpoint status/readiness, browser refresh readiness, safe replay recovery,
  and `favorites_request_success`; no terminal 401 or response-Cookie
  stored/applied/rejected event occurred.
- This is an observed later-process refresh recovery, not proof of cross-day
  survival, natural response-Cookie rotation persistence, or the terminal-401
  HDS plus original-WebView return path. Those acceptance boundaries remain
  OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T0055/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T01:59:47.765494+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-29 02:57 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore and `favorites_request_success`; no 401,
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is an observed later-process authenticated restore, not proof of
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T0155/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T02:57:55.620357+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-29 03:58 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore and `favorites_request_success`; no 401,
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is an observed later-process authenticated restore, not proof of
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T0255/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T03:58:22.263552+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process refresh recovery — 2026-08-29 04:57 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded an authenticated-read initial 401, refresh endpoint
  status/readiness, browser refresh readiness, safe replay recovery, and
  `favorites_request_success`; no terminal 401 or response-Cookie
  stored/applied/rejected event occurred.
- This is an observed later-process refresh recovery, not proof of cross-day
  survival, natural response-Cookie rotation persistence, or the terminal-401
  HDS plus original-WebView return path. Those acceptance boundaries remain
  OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T0355/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T04:57:21.599988+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-29 05:58 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore and `favorites_request_success`; no 401,
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is an observed later-process authenticated restore, not proof of
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T0455/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T05:58:26.689600+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-29 06:57 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore and `favorites_request_success`; no 401,
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is an observed later-process authenticated restore, not proof of
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T0555/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T06:57:25.672471+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process refresh recovery — 2026-08-29 07:58 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded an authenticated-read initial 401, refresh endpoint
  status/readiness, browser refresh readiness, safe replay recovery, and
  `favorites_request_success`; no terminal 401 or response-Cookie
  stored/applied/rejected event occurred.
- This is an observed later-process refresh recovery, not proof of cross-day
  survival, natural response-Cookie rotation persistence, or the terminal-401
  HDS plus original-WebView return path. Those acceptance boundaries remain
  OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T0655/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T07:58:28.031126+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-29 08:57 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore and `favorites_request_success`; no 401,
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is an observed later-process authenticated restore, not proof of
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T0755/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T08:57:04.352137+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-29 09:58 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore and `favorites_request_success`; no 401,
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is an observed later-process authenticated restore, not proof of
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T0855/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T09:58:34.129604+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-29 11:58 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore and `favorites_request_success`; no 401,
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is an observed later-process authenticated restore, not proof of
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T1055/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T11:58:36.051986+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-29 12:58 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore and `favorites_request_success`; no 401,
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is an observed later-process authenticated restore, not proof of
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T1155/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T12:58:09.479787+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process refresh recovery — 2026-08-29 13:58 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded an authenticated-read initial 401, refresh endpoint
  status/readiness, browser refresh readiness, safe replay recovery, and
  `favorites_request_success`; no terminal 401 or response-Cookie
  stored/applied/rejected event occurred.
- This is an observed later-process refresh recovery, not proof of cross-day
  survival, natural response-Cookie rotation persistence, or the terminal-401
  HDS plus original-WebView return path. Those acceptance boundaries remain
  OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T1255/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T13:57:46.449977+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process refresh recovery — 2026-08-29 10:59 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded an authenticated-read initial 401, refresh endpoint
  status/readiness, browser refresh readiness, safe replay recovery, and
  `favorites_request_success`; no terminal 401 or response-Cookie
  stored/applied/rejected event occurred.
- This is an observed later-process refresh recovery, not proof of cross-day
  survival, natural response-Cookie rotation persistence, or the terminal-401
  HDS plus original-WebView return path. Those acceptance boundaries remain
  OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T0955/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T10:59:12.626236+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process refresh recovery; Account capture anomaly — 2026-08-29 21:57 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed authenticated native Favorites and the
  full initial-401 → refresh readiness/status → safe replay recovery sequence.
  The Account capture did not expose a list root or saved/selected account in
  this run (`listRootCount=0`, `savedAccountCount=0`); this is an acceptance
  anomaly, not evidence of account deletion, because diagnostics still recorded
  restore readiness and no terminal 401. No response-Cookie
  stored/applied/rejected event occurred.
- This run is not an accepted Account-state result and does not prove
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T2055/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T21:57:34.641803+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-29 20:57 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore and `favorites_request_success`; no 401,
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is an observed later-process authenticated restore, not proof of
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T1955/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T20:57:06.574888+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process refresh recovery — 2026-08-29 19:57 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded an authenticated-read initial 401, browser/refresh
  readiness, refresh endpoint status, safe replay recovery, and
  `favorites_request_success`; no terminal 401 or response-Cookie
  stored/applied/rejected event occurred.
- This is an observed later-process refresh recovery, not proof of cross-day
  survival, natural response-Cookie rotation persistence, or the terminal-401
  HDS plus original-WebView return path. Those acceptance boundaries remain
  OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T1855/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T19:57:37.340572+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-29 18:58 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore and `favorites_request_success`; no 401,
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is an observed later-process authenticated restore, not proof of
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T1755/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T18:58:02.895926+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process refresh recovery — 2026-08-29 17:57 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded an authenticated-read initial 401, browser/refresh
  readiness, refresh endpoint status, safe replay recovery, and
  `favorites_request_success`; no terminal 401 or response-Cookie
  stored/applied/rejected event occurred.
- This is an observed later-process refresh recovery, not proof of cross-day
  survival, natural response-Cookie rotation persistence, or the terminal-401
  HDS plus original-WebView return path. Those acceptance boundaries remain
  OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T1655/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T17:57:11.456637+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-29 16:57 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore and `favorites_request_success`; no 401,
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is an observed later-process authenticated restore, not proof of
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T1555/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T16:57:40.943796+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process refresh recovery — 2026-08-29 15:57 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded an authenticated-read initial 401, browser/refresh
  readiness, refresh endpoint status, safe replay recovery, and
  `favorites_request_success`; no terminal 401 or response-Cookie
  stored/applied/rejected event occurred.
- This is an observed later-process refresh recovery, not proof of cross-day
  survival, natural response-Cookie rotation persistence, or the terminal-401
  HDS plus original-WebView return path. Those acceptance boundaries remain
  OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T1455/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T15:57:16.843857+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.

#### Clean HEAD later-process restore and Favorites observation — 2026-08-29 14:57 +0800

- The scheduled artifact directory was absent, so the checked 19-command
  protocol ran exactly once after acquiring a fresh lease for the exact
  authorized target `192.168.50.237:12345`. It performed only the declared
  wake/timeout gate, data-preserving cold start, native Favorites and Account
  inspection, and redacted diagnostics capture; no install, clear, sign-out,
  credential input, CAPTCHA, submit, recovery Want, or account mutation
  occurred.
- The privacy-bounded summary observed a focused native NextN Account root with
  one saved and selected account, plus a populated native Favorites collection.
  Diagnostics recorded restore and `favorites_request_success`; no 401,
  terminal 401, refresh event, or response-Cookie stored/applied/rejected event
  occurred.
- This is an observed later-process authenticated restore, not proof of
  cross-day survival, natural response-Cookie rotation persistence, or the
  terminal-401 HDS plus original-WebView return path. Those acceptance
  boundaries remain OPEN. Evidence is retained under
  `.hvigor/outputs/nextn-natural-refresh-observation-237-20260829T1355/`; the
  next manifest window starts at the successful diagnostics receive boundary
  `2026-08-29T14:57:38.961621+08:00`. This observation is intentionally left
  uncommitted under the current no-periodic-commit control.
## Reader mode-owned settings and automatic page-border cropping — 237 — 2026-09-01

- The signed main candidate and signed `entry@ohosTest` candidate both built successfully. The main HAP was
  installed in place on exact authorized target `192.168.50.237:12345`; no uninstall or data clear was used.
- Root Reader settings show separate Paged and Continuous groups. The in-Reader sheet shows only the active mode:
  RTL showed Paged, while true Continuous vertical showed Continuous. Temporary Paged `L 形` and Continuous
  `Kindle` values survived a cold start independently.
- On Gallery `663205`, exact page `3 / 40`, enabling crop removed its uniform top white band; disabling on the same
  current page restored the band. An unframed page was observed only before the final independent-edge detector
  revision and is therefore not claimed as final-candidate device evidence.
- The device was left with its original state restored: direction `从右到左`, both tap-zone values `左右`, and both
  crop switches disabled. A final data-preserving cold start reconfirmed those values. Evidence is under
  `.hvigor/outputs/device-237__unknown/unknown/portrait-1320x2120/reader-mode-crop/`, especially
  `reader-sheet-continuous-20260901T033`, `bug-bite-independent-edge-on-20260901T028`,
  `bug-bite-independent-edge-off-clean-20260901T030`, and `cold-restored-preferences-20260901T036`.

## Gallery multilevel rotation and Split-return matrix — accepted on 197/103/237 — 2026-09-01

- The exact installed candidate was `c6a9c4aa+working-tree+hap-sha256-c6061bc0dc42`. On each authorized target
  197, 103 and 237, both `封面展开` and `一镜到底` ran with tablet layout disabled and `仅横屏`. Every run built the
  six-level route chain `A list -> B detail -> C search -> D detail -> E search -> F detail`, mixed portrait and
  landscape states, then continuously recorded the full `F -> E -> D -> C -> B -> A` unwind at normal speed.
- The 12 accepted recordings decoded to 10,919 frames: 197 contributed `1196/1151/1147/1356`, 103 contributed
  `517/509/521/561`, and 237 contributed `969/981/990/1021` frames for Cover-off, Cover-landscape, Seamless-off and
  Seamless-landscape. All decoded frames were reviewed chronologically through 309 contact sheets; original frames
  were also inspected around the critical custom returns and the final rotation/Split handoffs.
- Every route returned to its declared parent. Stack detail returns retained the selected custom transition and used
  the live post-rotation list/card target; no stale portrait layout, wrong Gallery, first-frame lateral jump, white
  flash, post-landing reflow or default-slide replacement was observed. Search-to-parent-detail routes retained their
  ordinary route transition. When a Stack-opened detail migrated to physical Split, the live list remained visible
  while the right detail pane closed to `选择一项以查看详情`, which is the established native Split contract rather
  than a missing custom flight. NextN remained foreground throughout.
- Raw recordings, decoded frames, contact sheets, semantic layouts and manifests are retained under the three
  device-specific `.hvigor/outputs/.../gallery-transition-full-matrix/` roots and excluded from Git. A later commit
  `3644216` changed Reader crop/settings code but not the Gallery list-detail transition implementation; the current
  combined dirty tree still passes the Gallery/Reader transition contract, `git diff --check`, a zero-match V1
  decorator inventory and the signed build. Device acceptance above remains tied to the exact installed candidate.

## Local user tags — accepted on 197/103; cleanup pending — 2026-09-02

- User outcome: local tag color, weight and explicit Hidden coexist. The soft-filter score is the sum of all matched
  configured tag weights and filters only when that sum is strictly below the threshold. Global Search and each
  custom Search Subtab own persistent, independent bypass switches that skip only the local tag gate.
- Static/device evidence: six focused contracts pass; the 197 ohosTest run completed
  `Tests run: 32, Failure: 0, Error: 0, Pass: 32, Ignore: 0`. The final main HAP was rebuilt from committed
  `88bec05`, installed in place on `192.168.50.197:12345`, and cold-started without uninstall or data clear.
- Runtime filtering: a gallery matching `+5` and `-8` tags was retained at threshold `-3` and hidden at `-2`,
  proving aggregate scoring and strict `<`. Hidden remained a separate hard gate. Global Search immediately
  reprojected retained raw results when its bypass changed, and a Subtab-specific bypass remained effective while
  the global value was off and after cold start.
- Presentation: a blue `artist:asanagi` tag was stably moved ahead of ordinary tags in Waterfall, List and Compact
  Waterfall. Detail applied the custom color without changing namespace grouping or order.
- WebDAV evidence: the configured sync page shows the `本地用户标签` dataset enabled, and a successful 197 sync log
  contains `webdav_dataset_start`/`webdav_dataset_done` for `dataset=local-user-tags` across five shards. This
  proves real single-device remote transport, not two-device convergence.
- Restoration: all test tag rules and the temporary Search Subtab were deleted through product UI, threshold was
  restored to `0`, and global Search bypass was restored to off. After installing the final clean HAP, one cold
  start showed `尚未设置本地标签` and threshold `0`; a second showed the Search bypass still off.
- Evidence root: `.hvigor/outputs/local-user-tags-197-20260902/`, especially
  `install-tests-anchor`, `threshold-equal-minus-three`, `threshold-below-minus-two`,
  `global-bypass-result`, `cold-subtab-bypass-result-corrected`, `colored-list`,
  `colored-compact-waterfall`, `open-angie-detail-at-minus-five`, `read-webdav-evidence`,
  `final-clean-manager-state`, and `final-clean-search-bypass-cold`.
- Device 103 was subsequently authorized as device B on the same configured WebDAV endpoint. A-to-B rule pull and
  data-preserving cold-start recovery retained threshold `-5`, negative weight `-8`, explicit Hidden and color.
  A clean later B record (`15`, Hidden, `#3377FF`, clock `1788313371566`) won as one whole record on A; A's later
  tombstone (`1788313798230`) then removed it on B without resurrection.
- A temporary Search Subtab with its own ignore-local-tag-filter switch enabled synchronized through the already
  enabled `home-subtabs` dataset. After B cold-started without clearing data, its manager contained
  `标签同步验收`; the B editor's `忽略本地标签过滤` Toggle was `checked=true`.
- Runtime old-client compatibility also passed: signed commit `f3623c5`, which predates the `local-user-tags`
  WebDAV dataset, completed a full known-dataset sync and manifest upload on B. After reinstalling the current
  client, the remote manifest still exposed all five local-user-tag shards (four skipped by matching state, one
  downloaded for a hash difference), the scheduled sync completed successfully, and active rules remained visible.
- Ownership correction: after confirming that `settings-tables` covers four whole settings tables, the user
  explicitly removed the WebDAV “应用设置” option. The global Search switch and its `catalog_preferences` table
  remain device-local and locally backed up; old persisted `settingsTables=true` must be ignored. The Subtab switch
  still belongs to the Subtab record and its cross-device recovery through `home-subtabs` is accepted above.
- Final removal acceptance passed on both authorized devices with committed candidate `7850bdc`. In-place install
  preserved data. The Storage summary no longer claims application settings are synchronized; both synchronization
  overviews contain seven retained user-data rows and no “应用设置” row. Current-process startup sync completed with
  `ok=true` on 197 (PID 51121) and 103 (PID 24139), while each current-process log contains zero
  `settings-tables` events. Local `settingsTables` backup/restore remains covered by the static backup contract.
- Final cleanup also converged. Device 197 restored threshold `0`, removed the temporary rules and deleted
  `标签同步验收` through product UI, then successfully synchronized `home-subtabs` and `local-user-tags`. Device 103
  pulled that state; after a no-clear cold start its local-tag manager shows threshold `0` and
  `尚未设置本地标签`, and the temporary Subtab is absent. The local-user-tags goal is now complete.
- New evidence roots are `.hvigor/outputs/local-user-tags-webdav-197-103/` and
  `.hvigor/outputs/matepadpro-lab103__MLR-AL00/not-applicable/portrait-1600x2560/local-user-tags-webdav/`.
  Removal evidence is under `.hvigor/outputs/remove-settings-sync/` and the corresponding 103
  `remove-settings-sync/` directory. The final main candidate rebuilt successfully in 9 s 271 ms.

## Local user-tag Gallery detail and shared editor — accepted on 103 — 2026-09-02

- The signed candidate was installed in place only on authorized target `192.168.50.103:12345`; no uninstall or
  data clear was used. The focused host contracts and signed build passed before device acceptance.
- In landscape, a 500 ms long press on `标签:巨乳` opened the shared API 26 material tag-detail Sheet with exactly
  two controls: explicit Hidden and local-tag management. Hidden toggled on and back off; management opened the same
  `LocalUserTagEditorSheet` used by the local-tag manager. In portrait, the same parent contract resolved to the
  bottom half-modal and its nested editor retained the shared row geometry and right inset. Ordinary single tap still
  opened exact query `tag:\"big breasts\"`.
- Chinese query `朝` returned translated candidates with namespace prefixes, canonical raw identities and positive NH
  IDs. `character:aoi asahina #14982` accepted weight `100010` and a pink custom color. The weight row displayed no
  subtitle and imposed no EH `-99..99` cap; the existing threshold description and threshold value were unchanged.
- The save recording shows the editor Sheet completing its close transition before the manager row refreshed. A
  no-clear cold start and same-page reopen both restored `角色:朝日奈葵`, the canonical identity, ID, weight, color and
  default-color-off state. Temporary rules `#2937` and `#14982` were then deleted through the product UI. The final
  portrait and restored-landscape manager captures show threshold `0` and `尚未设置本地标签`; target 103 was returned
  to its initial landscape orientation and its device lease was released.
- Evidence is under `.hvigor/outputs/matepadpro-lab103__MLR-AL00/not-applicable/` in the
  `landscape-2560x1600/local-tag-detail/` and `portrait-1600x2560/local-tag-detail/` trees, especially
  `save-animation-20260902T145100`, `cold-manager-20260902T145800`, `reopen-tag-corrected-20260902T150300`,
  `gallery-long-press-20260902T150900`, `gallery-manage-20260902T151400`,
  `gallery-manage-20260902T151800`, `single-tap-search-20260902T152000`,
  `cleanup-confirmed-final-20260902T154000` and `cleanup-restored-20260902T154300`.

## Gallery translation-library tag detail body — ACCEPTED on 197 — 2026-09-03

- User counter-evidence invalidates the prior body semantics: the requested NextE tag detail displays the selected
  tag's EhTagTranslation introduction, links and eligible images. The accepted candidate instead displayed local
  Hidden/weight/color. Prior evidence remains valid only for the long-press host, two adapted controls, nested shared
  editor and portrait/landscape Sheet form.
- The current candidate preserves those hosts and actions while extending the local dictionary import/RDB/lookup
  chain with `intro` and `links`, inline tag translation, image filtering, and the NextE body structure. The existing
  tag-translation settings group now owns the persistent four-level intro-image policy.
- Target 103 remained TCP `Offline`; the user explicitly authorized substituting `192.168.50.197:12345`. The final
  signed candidate was installed in place without clearing data. Its current translation database remained
  `v7.27868.1 2026-09-03T00:13:34Z`, `44059` rows.
- The first 197 attempt showed an empty body for `big breasts` and was rejected. Current EhTagTranslation source data
  demonstrated that NH's generic tag maps to female/male rows with the same translated name, image-free introduction
  and links but different examples. The final service merges only such equivalent definitions and all unique images;
  true textual/link conflicts remain unresolved.
- In the final `1260×2720` portrait run, `巨乳 / tag:big breasts · #2937` rendered the complete translated
  introduction and inline `超乳 (huge breasts)` reference. At the restored default `隐藏 H 图片` level it rendered
  no R18 examples. The shared settings menu displayed all four levels; the temporary third level rendered the same
  tag's two-column R18 images, after which the row was restored to `隐藏 H 图片`.
- The device's original system Rotation lock was observed on. It was temporarily disabled for this requested check;
  the real NextN window changed to `2720×1260`, where the same body rendered in the centered wide Sheet. A 28-frame
  stream shows the Sheet entrance transition. The device was then restored to `1260×2720`, the Rotation lock tile
  was restored blue/on, and the control center was closed.
- Evidence is under `.hvigor/outputs/local-user-tags-translation-info/197/merged-content-portrait-20260903T0400/`,
  `image-menu-20260903T0416/`, `r18-content-20260903T0419/`, `restore-nonh-20260903T0426/`,
  `landscape-gallery-20260903T0446/`, `landscape-long-press-20260903T0454/`, and
  `restore-rotation-lock-20260903T0458/`. The selected source tag has no links, so no link was fabricated or tapped;
  the link parser/presenter/open action is covered by the source mapping and focused contract. Existing 103 evidence
  remains authoritative for the unchanged two controls, shared editor, and single-tap search.

## Shared settings text-field and tag-color Hex-field parity — 197 accepted, 103 supplementary — 2026-09-04

- The tag color picker's Hex field now uses current NextE's
  `sys.color.ohos_id_color_button_normal` resource instead of the opaque app cover-placeholder token. NextE's complete
  shared `SettingsTextField` owner was ported and now replaces the duplicated labeled inputs in the LLM source,
  manga rendering service and WebDAV settings implementations. The active untracked API-key page worktree owner also
  consumes the component but remains in its separate account lane. Advanced-search fields and the shared inline
  list-row editor remain unchanged because they have separate established owners.
- The exact scoped diff and `git diff --check` pass. The complete signed build finished with `BUILD SUCCESSFUL` in
  16 seconds. On exact target `192.168.50.103:12345`, the signed HAP was installed in place without uninstall or data
  clear. The portrait add-local-tag sheet was opened as an unsaved draft, default color was disabled at the measured
  Toggle bounds, and the picker was scrolled to the Hex row.
- The rendered Hex `TextInput` measured `[356,1161][1314,1266]` and reported background `#0C000000`, confirming the
  system translucent input layer rather than the former opaque cover-placeholder color. A read-only existing LLM
  source detail then rendered its name, URL and password inputs at `[65,437][1535,551]`, `[65,633][1535,747]` and
  `[65,829][1535,943]`; all three reported the same `#0C000000` dynamic system background and preserved the reference
  full-width alignment. No field was edited.
- The add-tag draft was closed without invoking save and returned to the local-tag manager. The device was restored
  to the landscape orientation observed before this run and the 103 lease was released. Portrait evidence is under
  `.hvigor/outputs/matepadpro-lab103__MLR-AL00/not-applicable/portrait-1600x2560/settings-text-field-parity/`; the
  restored landscape capture is under
  `.hvigor/outputs/matepadpro-lab103__MLR-AL00/not-applicable/portrait-1600x2560_to_landscape-2560x1600/settings-text-field-parity/`.
- The user then explicitly requested 197 and authorized immediate takeover of its occupied lease. The same signed HAP
  was installed in place on exact target `192.168.50.197:12345` without uninstall or data clear. In the portrait
  add-local-tag draft, the measured default-color Toggle was disabled without saving. The visible Hex input measured
  `[174,2433][1182,2576]` and reported `#0C000000`. A read-only existing LLM source detail rendered name, base-URL and
  masked API-key inputs at `[91,581][1169,737]`, `[91,849][1169,1005]` and `[91,1118][1169,1274]`; all three reported
  `#0C000000` and retained consistent full-width insets. This makes 197 the primary device acceptance for the current
  task; the earlier 103 result remains supplementary tablet evidence.
- No tag, color, LLM value, credential or other setting was saved during the 197 protocol. The unsaved tag draft was
  discarded, the read-only LLM detail was left normally, the app was returned to Advanced settings, and the 197
  lease was released. Evidence is under
  `.hvigor/outputs/mate60pro-lab197__ALN-AL80/not-applicable/portrait-1260x2720/settings-text-field-parity/`.
