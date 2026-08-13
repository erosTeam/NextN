# NextN active device-acceptance queue

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
- A bounded Gallery Detail compact-viewport review found no new visible
  defect in that one frame. It is not a whole-page or same-state-reference
  visual acceptance claim. The temporary screenshot was deleted from the
  host; its device-side counterpart was already absent.
- Account persistence has been raised to P0. A fresh read-only S0 check found
  native Favorites sign-in prompt, visible Account login surface, and fixed
  cold-start stage `account_restore_record_absent`. No record-present
  HUKS/decrypt/payload/replay failure was observed, no credential action was
  taken, and all temporary layouts were deleted. Source hardening is in
  progress before any future authentication attempt.
- The final account P0 hardening added a durable verification-required marker,
  authenticated-read transition ownership, and stale-response fencing. It
  preserves the encrypted record and ArkWeb identity on every network failure;
  only explicit sign-out deletes them. The complete static suite and signed
  Debug build passed, and the HAP was installed with `install -r` then
  force-stopped/cold-started without login. The app was foreground, but the
  bounded fixed account-tag read yielded no new stage, so no fresh
  record-absent or record-present device claim is made from that deployment.
- The latest P0 build additionally makes `restore()` a cold-start path only:
  an already authenticated runtime session no longer re-reads RDB/HUKS and
  cannot be visibly downgraded by a transient local-read failure. A rebuilt or
  repaired RDB with an absent sealed row now enters the native explicit
  verification boundary instead of being treated as a fresh install. The HAP
  passed the full static suite and signed build, then was installed with
  `install -r` and force-stopped/cold-started without credentials. A fresh
  native root summary had no visible Web; one safe root-tab selection produced
  the native Favorites sign-in prompt with no loading, empty, or error state.
  Account/login was not opened, no credential action occurred, and all raw
  temporary layouts were deleted from host and device. This remains a
  no-record S0 observation, not record-present retention acceptance.
- That same signed update contains the Detail rail corrections. It was reached
  from a fresh native root summary through one safe Browse-tab selection and
  one safe public gallery-card selection. The app is left on that public
  Detail for later same-state visual comparison; no account, login, preference
  or gallery mutation occurred. No visual-parity claim is made without a
  corresponding reference capture, and the temporary raw navigation layouts
  were deleted from both host and device.
- The single-owner account-state build was installed with `install -r` and
  force-stopped/cold-started on the selected TCP device without clearing data
  or entering credentials. The application returned to the foreground. This
  is deployment evidence only: the device has no sealed session record, so it
  cannot prove record-present restoration. No login attempt was made.
- A subsequent bounded P0 cold-start diagnostic used the same selected TCP
  target, current signed Debug HAP, and no credential/UI action. The fixed
  non-secret stage was again `account_restore_record_absent`. This confirms
  only that the current durable envelope is absent; it is not presented as a
  record-present restoration result or a cause attribution.
- The signed P0 follow-up, which restricts verification-required publication
  to an actually issued replay that also returns `401` and prevents sealing a
  candidate that changed during its visible-browser probe, was installed with
  `install -r` and cold-started without clearing data or entering credentials.
  Its fixed non-secret startup stage remained `account_restore_record_absent`.
  This is deployment/no-record evidence only; record-present Favorites
  restoration remains open.
- A final P0 follow-up was then installed with `install -r` and cold-started
  on the same selected target without credential input or data clearing. It
  additionally confines best-effort gallery favourite enrichment so it cannot
  retire the global account state. The fixed non-secret stage remained
  `account_restore_record_absent`; this does not substitute for record-present
  cold-start and authenticated Favorites proof.
- The latest signed P0 build was installed with `install -r` and cold-started
  without clearing data or entering credentials. It also confines Profile
  refresh to an observational failure path, leaving only authenticated
  Favorites as the account-state authority. The startup stage remained
  `account_restore_record_absent`; no record-present claim is made.
- A subsequent P0-only check renewed the selected-device lease, re-established
  the awake/24-hour timeout gate, and performed one data-preserving
  force-stop/cold-start. The fixed non-secret stage was again
  `account_restore_record_absent`. Installed package metadata still reports
  one continuous in-place application identity; this rules out a current
  update-identity switch, but cannot reconstruct the historical deletion.

## Latest completed physical evidence — Content Filters ordinary re-entry

- 2026-08-11: the signed Debug HAP was installed with `install -r` on the
  selected TCP device only. Native Settings → Advanced → Content Filters was
  entered once, returned once with native Back, and entered again. Both
  terminal states showed the retained native content with no loading or error
  surface. No filter rule, account, preference, queue, or gallery data was
  changed. The local screenshot/layout evidence is retained outside Git; only
  this ordinary re-entry boundary is accepted.

## Current transport state

- 2026-08-10 11:12-11:20 +0800: sandboxed HDC invocations returned `Connect
  server failed`; a local loopback probe then established that the sandbox,
  not the selected device, was denying the HDC client-server connection. This
  period establishes no device-state result.
- 2026-08-10 11:30 +0800: the same HDC commands outside that sandbox confirmed
  `192.168.50.237:12345` Connected and returned `ok`; the existing lease was
  renewed and the wake/24-hour timeout gate was re-established. P1 continues
  from the already-known direct Gallery Detail terminal review.
- The selected TCP target `192.168.50.237:12345` is currently Connected and
  remains the only device used; the USB target was not used as a substitute.
- 2026-08-10 12:48-12:55 +0800: the retained completed-download Reader path
  was observed in its hidden-chrome canvas state. `uitest uiInput keyEvent 4`
  did not close that overlay and is rejected for future use. After reading the
  selected device's `uiInput` help, the literal `uitest uiInput keyEvent Back`
  returned exactly to the retained Downloads route. No Reader preference,
  page position, account state, or download state was changed.
- 2026-08-10 13:02-13:20 +0800: one ordinary History → Browse → History root
  transition retained the visible local-history rows and day grouping with no
  first-page clear or refresh indicator. This covers only that normal
  root-tab return; it is not a cold-start, mutation, search, or pagination
  claim.
- The current lease is renewed. The latest wake gate readback is `AWAKE` with
  `OverrideTimeout=86400000ms`.
- 2026-08-10 12:28 +0800: one direct Gallery Detail review reached Related and
  made one horizontal mid-list swipe. The retained local capture shows the
  list viewport extending through the section's internal horizontal boundary;
  the partially visible side cards are scroll clipping, not parent-inset
  clipping. This is a current-device geometry observation only, not a
  same-state reference-parity claim and not grounds for a size or hierarchy
  change.
- The latest Debug HAP was installed with `install -r` only; no uninstall,
  application-data clear, or broad data deletion was performed.
- 2026-08-10 15:50 +0800: the signed Debug HAP for the narrow Comments
  keyboard-inset correction was installed with `install -r` on the selected
  TCP target. The existing direct zero-comment route was allowed to load, then
  its empty native TextArea was focused once. With the system keyboard visible,
  the fixed page-footer input and disabled send control were fully above the
  keyboard; the TextArea's visible and original heights both measured 104px.
  No text was entered and no comment mutation was sent. This is a real-device
  result for that keyboard state only, not a full same-state reference-parity
  claim.
- 2026-08-10 16:18 +0800: the existing direct Gallery `471768` route reached
  native Detail, then the one current visible Read action opened the Reader
  overlay. Its terminal state was a native hidden-chrome continuous canvas
  without an extra top or bottom content reserve. No reading setting, page
  navigation, account state, or content mutation occurred. The local capture
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
