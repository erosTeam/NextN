# NextN UI change ledger

This register records visible-change boundaries and their evidence. It does not
authorize an edit, replace a device comparison, or define product completion.

## OPEN — Reader selectable Waifu2x enhancement models

- User outcome: Reader enhancement should let the user choose between the two
  mature, same-native-contract Waifu2x models already available in NextE,
  while preserving the current private, opt-in model-download boundary and
  the established Reader canvas.
- Reference parent tree: NextE owns this in `ReaderSettingsPage →
  HdsNavDestination → SecondaryListScaffold → Reader settings
  GroupedListSection`: enable switch, installed-model selector, model-manager
  route leaf, then its existing height policy. Its manager is a separate
  `HdsNavDestination → SecondaryListScaffold → ListItem → GroupedListSection`
  with one concise row per user-selectable private model. A selector exposes
  only locally installed models; downloads and removal remain explicit row
  actions.
- Current NextN parent tree: `SettingsPage(READER) →
  SecondaryListScaffold → ListItem → ReaderPresentationGroup →
  NextNGroupedListSection` currently has a Models manager row and an enable
  switch, but no selected-model state. `ReaderSuperResolutionModelsPage →
  SecondaryListScaffold → ListItem → NextNGroupedListSection` owns only one
  waifu2x-art row. The Reader itself owns a full-screen canvas and must remain
  unchanged.
- Exact change boundary: order the existing enhancement leaves as the reference
  does: enable switch, installed-model selector, then model-manager route;
  make the existing model destination render a concise row for Waifu2x art and
  Waifu2x photo; persist only a normalized selected model identifier. A prior
  single-model installation must migrate to the art model selection without
  download, deletion, or a changed default. No Reader canvas/chrome/gesture/
  progress layout, automatic download, background model request, account data,
  gallery data, or cache deletion is permitted.
- Rationale: the native NextN enhancement runtime and its existing Waifu2x
  model pair already support the corresponding art/photo definitions, but
  current settings and model storage expose only one fixed definition. This is
  a source-backed capability gap, not a visual restyle. The reference
  RealESRGAN package has a different compatibility-conversion path and stays
  out of this delivery until that path is independently ported and verified.
- Visual verification plan: compare the same Reader-settings and
  model-management states against the current NextE pages at the same native
  viewport. Verify grouped ownership, row order, selected installed-model
  menu, each explicit download/remove action, and the preserved disabled
  enable state. Do not download a new model merely to create evidence; retain
  raw local captures outside Git.
- Unresolved risk: the photo model is available only through an explicit user
  download and must never be fetched during migration, restore, or Reader
  rendering. RealESRGAN remains deliberately unavailable here until its
  separate compatibility conversion is verified.
- New device counter-evidence before acceptance: on 2026-08-11, the first
  same-viewport NextN Reader-settings capture showed both sibling leaves
  titled `增强模型`. The initial implementation reused the old manager label
  for the new selected-model leaf, obscuring the different actions. The
  minimal correction is source-backed: retain `增强模型` / `Model` for the
  selector and use NextE's `模型管理` / `Model management` for the route leaf.
  No geometry, row order, state, or model action changes are permitted by
  this copy correction.
- New same-viewport reference counter-evidence before acceptance: NextN marked
  an installed model row as `destructive`, which coloured its title and prefix
  red. The current NextE manager keeps the model identity neutral and confines
  the destructive affordance to its suffix trash action. The faulty assumption
  was that a row-level danger flag represented a suffix-only delete control.
  Correct it by adding the existing HDS `SuffixButton` capability as an
  opt-in leaf of `NextNListRow`, then use that leaf only for model download and
  removal. Do not alter other list rows, model files, or Reader state.
- Device result, 2026-08-11: the signed Debug HAP was installed in place on
  the selected device and the verified `com.erosteam.nextn` foreground reached
  the model manager at the same `1320×2120` portrait viewport. The installed
  Waifu2x art identity and prefix icon are neutral; only the `移除` suffix
  button is red, while the uninstalled photo model exposes a blue `下载`
  suffix button. This matches the relevant current NextE hierarchy: neutral
  model identity with a suffix-only destructive affordance. Neither button,
  the selector, nor the enhancement switch was activated. Raw local evidence
  remains under `.hvigor/outputs/reader-model-settings-20260811T1004/` and is
  excluded from Git. The photo download and Reader processing remain OPEN;
  this observation accepts only the corrected manager-row hierarchy.
- New same-viewport counter-evidence before the next edit: the selector menu
  correctly contained only the installed art model and no preference changed,
  but the surrounding NextN group was ordered model manager → selector →
  enable. Current NextE is enable → selector → model manager. The faulty
  assumption was preserving NextN's preexisting manager-first order instead
  of the complete reference parent-tree order. Correct only those three
  existing leaves and their dividers; do not alter their labels, actions,
  enabled states, model storage, or any neighboring Reader setting.
- Device result, 2026-08-11: after an in-place signed Debug install, the
  selected device showed the corrected order at the verified
  `1320×2120` viewport: image enhancement switch → selected Waifu2x model →
  model manager. The current switch state, selected art model, and installed
  model set were observed but not changed. This accepts the three-leaf order
  for the current settings state; photo-model download and Reader processing
  remain OPEN.

## FROZEN — Unified private-cache management (category-page visual boundary)

- User outcome: the existing Cache destination should let a user inspect and
  deliberately remove every app-private, regenerable cache category without
  exposing files, URLs, credentials, downloaded galleries, reading history, or
  account data.
- Reference parent tree: NextE owns this as `CacheSettingsPage →
  HdsNavDestination → SecondaryListScaffold → ListItem → Column → total
  summary → GroupedListSection → one cache row per category → Clear all`.
  Every leaf uses the shared list-row grammar; individual and aggregate clears
  require an explicit confirmation and act only on their named cache owner.
- Current NextN parent tree: `Index cacheSettingsDestination →
  HdsNavDestination → SettingsPage(CACHE) → SecondaryListScaffold → ListItem
  → NextNGroupedListSection → Reader-cache status row + Reader-cache clear
  row`. The existing private owners are `ReaderImageCacheService`,
  `CommentTranslationService`, `ComicTranslationRuntimeService`, and
  `TagTranslationRepository`.
- Exact change boundary: retain the destination, HDS chrome, scroll owner,
  surrounding Settings surfaces, Reader-cache retention policy, and every
  cache's existing private storage boundary. Replace only the Cache surface's
  two-row Reader-only group with one grouped private-cache section containing
  Reader pages, comment translations, comic translations, and the optional
  tag dictionary; each row presents aggregate count/byte state and a named,
  confirmed clear action. Add the same confirmed aggregate clear at the end.
  Do not include Downloads, History, Favorites, account records, source
  credentials, remote content, backup, sync, or a fabricated image cache.
- Rationale: this carries the reference's storage ownership to the four
  concrete NextN cache owners already present in source. It does not invent a
  new storage class or convert user data into cache.
- Visual verification plan: compare the default empty/nonempty private-cache
  page in the same native HDS viewport with NextE's cache-category group;
  verify the category ordering, total-summary placement, row hierarchy,
  confirmation boundary, and disabled empty-cache action. Retain local raw
  captures outside Git. Exercise only a disposable/generated cache clear;
  never clear the user's downloads, history, account, or preferences.
- Unresolved risk: NextN has no reference-equivalent sync, backup, or image
  cache owner. Those NextE groups are explicitly out of this change rather
  than being represented by inert rows.
- Current same-viewport evidence: on 2026-08-11, current native NextN and
  NextE Cache/Storage destinations were captured at `1320×2120` portrait on
  the selected device. Both show the HDS destination, a caption-level total
  usage summary, and one grouped cache-card whose category rows carry count,
  size, and a right-side clear leaf. NextE has sync, backup, and image-owner
  siblings that NextN does not own; those were not copied. The first NextN
  capture exposed only a naming mismatch: the reference calls each category a
  cache, while three NextN labels had dropped that noun. The labels above are
  corrected before final recapture; no geometry or clear action was changed.
- Final device result: the signed Debug HAP was installed in place on the
  selected device. The final NextN foreground was verified as
  `com.erosteam.nextn:EntryAbility` at the same `1320×2120` portrait viewport
  as the current NextE Storage capture. It showed `缓存占用`, four cache-named
  category rows, per-row count/size summaries, disabled zero-entry actions,
  and the destructive `清除全部缓存` row. No clear row was activated; existing
  reader pages, dictionary entries, downloads, history, account state, and
  preferences were preserved. The locally retained comparison artifacts are
  `.hvigor/outputs/private-cache-settings-20260811T1705/` and are excluded
  from Git.
- Freeze rule: keep this category-page hierarchy, the four concrete owner
  boundaries, row order, and labels unchanged unless new user feedback or a
  same-state counterexample reopens it. The uninvoked confirmation dialogs
  remain **EVIDENCE-ONLY**; do not clear an existing cache merely to repeat
  this visual verification.

## OPEN — Gallery Detail full-title translation

- User outcome: a user who has explicitly configured the existing private text
  translation source can translate either source title from the existing
  Gallery Detail full-title sheet, then toggle that translated text without
  altering the gallery record or Detail layout outside the sheet.
- Reference parent tree: NextE keeps the feature inside `GalleryDetailPage →
  GalleryHeaderCard → existing full-title modal → ListItem →
  GroupedListSection → title read block`. Each block has its source-title
  label and text, then one compact translate leaf; its result expands directly
  beneath that same source title. The service is a title-named boundary over
  the existing private short-text translation/cache pipeline.
- Current NextN parent tree: `GalleryDetailPage → GalleryHero → existing
  FullTitleSheet → NextNModalScaffold → ListItem →
  NextNGroupedListSection → Column(primary title, optional secondary title)`.
  `CommentTranslationService` already provides the only supported private
  text-source resolution, request fence, cache, and locale policy.
- Exact change boundary: retain the Hero, title preference, sheet route,
  scaffold, ListItem, grouped surface, and source-title text. Align the sheet
  header to the reference's stable `Full title` caption, then split the
  existing two title texts into corresponding read blocks; add a compact,
  source-bound translation action and result directly beneath each block. The
  action is disabled until the existing comment/text source is configured. It
  may not add an automatic request, change source bindings, alter cards, the
  floating Read overlay, related/comments, Reader, or Detail request lifecycle.
- Rationale: this ports a mature generic translation leaf using NextN's
  existing private provider/cache instead of creating another service or
  altering the already reviewed Detail surface.
- Visual verification plan: with no text source configured, compare the
  existing full-title sheet against the same-state NextE sheet and confirm the
  two source-title blocks and disabled action remain contained inside the
  modal. With an authorized configured source, compare one running, completed,
  toggled, and failed translation in the same gallery/viewport. Retain the
  local captures and do not use source-shape checks as acceptance.
- Unresolved risk: the selected device currently has no configured text source,
  so only the unconfigured-sheet state can be exercised without creating or
  exposing a provider secret.
- Current device observation: the signed Debug HAP was installed in place on
  the selected device. A first post-install hot Want was rejected because it
  retained the prior Download-settings foreground; after force-stopping only
  NextN, the same documented numeric Gallery Want reached a native NextN
  Detail root. One fresh unique title action opened the updated full-title
  sheet, which showed the stable sheet caption, separate source-title blocks,
  and both disabled translation leaves. No provider request, source/profile
  change, account action, preference write, or gallery mutation occurred.
  The named local audit directory is
  `.hvigor/outputs/gallery-title-translation-20260811T0454/` and is excluded
  from Git. A current same-state NextE title-sheet capture is not available
  without altering reference data, so visual-reference acceptance and every
  configured translation result remain OPEN.

## OPEN — Private-download completion notifications

- User outcome: a user who explicitly enables it can receive one system
  notification when a private gallery download has durably completed; the
  default remains silent.
- Reference parent tree: NextE owns this setting in `DownloadSettingsPage →
  HdsNavDestination → SecondaryListScaffold → ListItem → GroupedListSection`.
  Inside its existing download-policy group, `Completion notifications` is a
  concise switch row following retry policy. Enabling writes the durable
  preference and then asks the system to enable notifications. Its queue
  publishes one basic-text notification only after a normal gallery/archive
  completion.
- Current NextN parent tree: `SettingsPage(DOWNLOAD) →
  SecondaryListScaffold → ListItem → NextNGroupedListSection → NextNListRow`.
  The group currently owns gallery concurrency, page concurrency, and failed
  page retries. `DownloadQueueService` owns the durable final transition from
  `DOWNLOADING` to `COMPLETE`.
- Exact change boundary: add one default-off switch after failed-page retries;
  persist only its boolean in the existing `download_settings` store; request
  system notification enable only when the user turns it on; and publish one
  fixed-ID basic-text notification only after the final COMPLETE task write
  succeeds. No notification path may mutate task status, queue state,
  progress, files, network work, account state, or re-emit for restored
  completed tasks.
- Rationale: this ports an existing mature NextE ownership path while keeping
  NextN's local-only queue and its user privacy boundary intact. The switch is
  opt-in because notification content can be visible outside the app.
- Visual verification plan: build and install in place on the selected device;
  compare the native Download settings row with the same-state NextE row, then
  restore the setting after the permission branch. A completion notification
  requires a genuine future task completion; no existing task will be started,
  paused, deleted, or fabricated merely to obtain it.
- Unresolved risk: system-level notification permission and a genuine new
  completion are separate device states. Until both are observed, this entry
  remains OPEN regardless of source or build evidence.
- Current device/reference result: the signed Debug HAP was installed in place
  on `192.168.50.237:12345`. Both NextN and NextE were captured in the same
  `1320×2120` portrait Download-settings state with the switch initially off.
  The common leaf is a bell-prefixed, full-width HDS switch row with title and
  one caption line. NextE's additional auto-retry/speed/archive settings are
  unsupported NextN siblings and were not imitated. In NextN, turning the row
  on reached the genuine system notification permission dialog; it was denied
  to preserve the device's existing system permission state, then the app
  preference was returned to off. No existing task was started, paused,
  deleted, exported, or otherwise changed. This accepts the initial row and
  permission-request transition only; a real future completion notification
  remains unproven.

## OPEN — Reader per-page comic translation

- User outcome: bring the mature, NH-applicable Reader comic-translation
  capability into NextN without changing the established Reader canvas or
  existing navigation/reading controls.
- Reference parent tree: NextE `ReaderPage` owns one full-screen canvas. Its
  content surface remains first; the transparent tap surface remains above it;
  transient translation status is an overlay; Reader chrome is conditionally
  overlaid; the per-page translation action belongs in the existing top More
  menu alongside reload/image information, with an explicit optional automatic
  mode. A rendered translation only replaces the selected page image leaf; it
  does not create a second Reader, a new card, or change the chrome geometry.
- Current NextN parent tree: `ReaderPage` owns the same full-screen canvas,
  reader content, transparent tap layer, conditional top header, and one
  bottom control stack. Its existing top More menu currently owns Share,
  external open, and Reader settings. Source pages are rendered by the same
  three leaf families: vertical `ReaderImagePage`, paged `ReaderImagePage`,
  and double-page `ReaderSpreadSurface -> ReaderSpreadImageLayer`.
- Proven NH boundary: NextN source pages may be downloaded at render time by
  `ReaderImageCacheService`, while the existing parent does not retain the
  resulting app-private local path. The translation runtime requires that
  local path. The next source change must add only a leaf-to-parent local-file
  readiness projection, then route a rendered page URI back through the three
  existing image leaves. It must not alter List/Swiper/Stack ownership,
  gestures, chrome position, Reader settings, or page-progress semantics.
- Implemented source behavior: one explicit "Translate current page" item is
  added to the existing top More menu when the current page has a local source
  file. Its run uses the existing full-canvas status-overlay role from the
  reference; a successful render replaces only the current image leaf and the
  same action toggles back to the original. The source-page local-file callback
  and translated URI projection were added equally to vertical, paged, and
  double-page image leaves. Automatic translation is not included in this
  first visible boundary.
- Availability refinement: the existing Reader menu leaf now also requires a
  configured manga-source binding with the responses and image-input
  capability. A rendered result remains toggleable without rechecking source
  configuration. This prevents the unconfigured path from presenting a
  clickable action that can only fail; it does not move or add any Reader
  control.
- Before/after rationale: the runtime, local vision backend, provider bridge,
  private rendered-image cache, and private document cache now exist outside
  the Reader UI. The smallest missing connection is the existing per-page
  overflow action and image-leaf source selection. Adding a new toolbar,
  panel, list, or route would be unsupported by the reference tree.
- Visual verification plan: after an actual rendered result exists, capture
  the same gallery/page, viewport, orientation, and chrome-visible state for
  NextE and NextN. Review the More-menu placement, running/error overlay,
  original/translated toggle, single-page flow, double-page flow, and hidden
  chrome canvas. Retain raw local captures; no source-shape or synthetic UI
  check is evidence.
- Unresolved risk: current NextN does not expose a loaded remote page's local
  path to its parent, so the leaf callback must be implemented and observed
  before the translation action can be enabled for non-downloaded pages. The
  callback is now implemented in source but has not been observed on device.
  A source/provider configuration surface is also still required before an
  ordinary user can produce a translation result.
- Current device observation: after the latest signed Debug HAP was installed
  in place on the selected device, the documented direct Gallery route opened
  the native Reader and its existing overflow menu. With no configured manga
  source, the native `Translate current page` menu item was present but
  disabled. No translation was requested; no source, account, preference, or
  content data was changed. Local terminal layout and screenshot evidence is
  retained outside Git. This observes the unconfigured availability boundary
  only, not a configured translation result or visual-reference acceptance.

## OPEN — Reader comic-translation source

- User outcome: make the Reader's existing per-page comic-translation action
  configurable with one private OpenAI-compatible source and model, rather
  than leaving the action dependent on an inaccessible stored binding.
- Reference parent tree: NextE keeps source configuration outside Reader:
  Settings route → `HdsNavDestination` → `SecondaryListScaffold` →
  `ListItem` → `GroupedListSection`. Its source-detail group is ordered as a
  read-only source-type row followed by name, base URL, and password input
  leaves; the comic-translation settings owner binds a compatible source and
  model separately.
- Current NextN parent tree: the Reader settings destination already uses
  `HdsNavDestination` → `SettingsPage(READER)` → `SecondaryListScaffold` →
  `ListItem` → `NextNGroupedListSection` → `NextNListRow`. Shared code already
  owns `LlmSourceProfileRepository`, `LlmSourceSecretVault`, and the manga
  consumer binding, but no current Settings route reaches them.
- Proven NH boundary: the current runtime supports only an
  OpenAI-compatible Responses source. The new destination therefore exposes
  that supported source type and its manga binding only; it does not present
  NextE's Codex OAuth, catalog, comment-translation, Torii, or self-hosted
  leaves as if NextN implemented them.
- Before/after rationale: a single Reader-settings navigation row and one
  focused destination preserve the root Settings and Reader parent trees. The
  form writes metadata through the existing profile repository, a key only to
  the existing HUKS vault, and the selected model through the existing manga
  binding; it must never place a key in reactive shared state or diagnostics.
- Visual verification plan: compare this destination against the same-state
  NextE source-detail screen on device. Review the Reader-settings row,
  route/title chrome, grouped-form hierarchy, input insets, error treatment,
  and configured/unconfigured state. Retain raw captures locally; no
  source-shape or synthetic UI check is evidence.
- Implemented source behavior: Reader settings now owns one navigation row to
  a dedicated source destination. The destination presents the supported
  OpenAI-compatible type and the four source leaves (name, base URL, API key,
  model), then saves through the existing private repository, HUKS vault, and
  manga binding. An existing key is represented only as "stored securely";
  neither it nor any input is added to shared reactive state or diagnostics.
- Current device observation: on the selected device, the new Reader-settings
  row opened the native source destination and showed the unconfigured form
  with a masked empty key field. No field was edited and no source, model,
  account, preference, gallery, or content data was changed. Local raw
  captures are retained outside Git. This is routing/form-render evidence,
  not a same-state reference comparison or feature acceptance.

## OPEN — Reader local comic-translation model pack

- User outcome: expose the optional local detection, OCR, source-treatment,
  and rendering model pack that already exists in NextN, so a user can choose
  the mature on-device translation path instead of the current invisible
  fallback.
- Newly actionable basis: `ComicTranslationModelService` already owns one
  checksum-verified, atomic model-pack installer and remover, but its only
  current caller is the runtime's read-only readiness probe. No Settings or
  Reader owner can start the install or disclose its optional local role.
- Reference parent tree: NextE keeps local-model management inside its
  translation settings route as a `SecondaryListScaffold → ListItem →
  GroupedListSection → ConciseListRow` group. The row reports readiness, asks
  for confirmation before a download or removal, and never downloads from the
  Reader canvas.
- Current parent tree: NextN's existing translation-source route is
  `HdsNavDestination → ComicTranslationSourcePage → SecondaryListScaffold →
  ListItem → NextNGroupedListSection → NextNListRow`. Its source form,
  consumer bindings, and save group already own remote-provider configuration.
- Exact change boundary: add one optional local-model group to that same
  scaffold, after the consumer-binding group and before source save. It may
  query, install, or remove only `ComicTranslationModelService`; it must not
  alter source metadata, secret handling, consumer bindings, Reader canvas,
  automatic scheduling, or fallback behavior.
- Before/after rationale: the current runtime uses a basic local backend when
  the pack is absent, so this is a user-controlled quality upgrade rather than
  a prerequisite or hidden background download. The existing service validates
  every installed asset and writes it outside the HAP.
- Visual verification plan: on the selected device, compare the native
  translation-source route with the same-state NextE translation settings
  route. Review grouped-section order, row hierarchy, unavailable/installing/
  installed treatment, confirmation wording, and error placement. Retain raw
  local captures; no source-shape or synthetic UI check is evidence.
- Unresolved risk: the selected device has not yet shown this new group or a
  configured translation run. A build can establish only compilation, not
  visual or model-download acceptance.
- Current device observation: the signed Debug HAP was installed in place on
  the selected device, then the native path `Settings → Reader → Comic
  translation` reached the existing translation-source route. The local-model
  group rendered between the consumer bindings and save group, with its
  initial Download state visible. No source field, key, consumer switch,
  save action, model download, account, or content data was changed. Raw
  local evidence is retained in
  `.hvigor/outputs/translation-local-model-pack-20260811T0344/` and excluded
  from Git. This is native route/render evidence only, not a same-state NextE
  visual comparison or local-model processing acceptance.
- Same-device reference counterevidence: NextE was temporarily switched from
  its prior self-hosted route to its local route, captured at the same
  viewport, then restored to self-hosted with its own confirmation path. Its
  model leaf uses the established `on-device manga model → install status →
  79.0 MB/license metadata` grammar. NextN's initial `Download` trailing
  action and generic explanatory subtitle were therefore not reference
  faithful. The next edit is limited to that leaf's title, state text, and
  metadata copy; its group position, click/confirmation behavior, and
  download/remove owner remain frozen.
- Current NextN recheck counterevidence: the revised metadata was placed in
  `NextNListRow.subtitle`, so the trailing install status constrained it to a
  narrower column and produced an earlier wrap than the same-viewport NextE
  capture. NextE owns this metadata as a full-width caption *after* its model
  row. The next edit moves only that note to the sibling leaf immediately
  following the row, preserving text, row height, trailing status, action,
  confirmation, and group order.
- Final device/reference result: after the narrow sibling-caption correction,
  the selected device showed the NextN uninstalled leaf as `端侧漫画模型 →
  未安装`, followed by the complete two-line `79.0 MB` and license notice at
  the section width. The same-device NextE capture establishes the matching
  installed leaf grammar (`端侧漫画模型 → installed model name → the same
  full-width notice`). This accepts the local-model row's uninstalled visual
  state in NextN's existing translation-source parent. Model download,
  installed-state presentation, and translation processing remain OPEN.

## OPEN — Reader comic-translation automatic session mode

- User outcome: carry the existing, configured Reader comic translation from a
  one-page manual action to NextE's explicit, session-only automatic mode,
  without changing the Reader canvas or making an unconfigured source perform
  any network work.
- Newly actionable basis: the current Reader already has the same private
  local-file callback, one in-flight translation state, rendered-page leaf
  replacement, and More-menu owner needed by NextE. Source review now shows
  the missing behavior is limited to session state and work scheduling.
- Reference parent tree: NextE keeps one Reader canvas with content first,
  transparent tap surface above it, conditional chrome, and a top More menu.
  The More menu keeps the existing manual translation action and adds one
  checked automatic-translation item. Enabling opens a confirmation dialog;
  the setting lives only for the Reader session. The owner translates the
  current ready page, then at most the next ready page, serially; its rendered
  output replaces only the corresponding image leaf.
- Current parent tree: NextN has the same canvas/content/tap/chrome order and
  owns manual translation in `ReaderOverflowMenu`. Source-file readiness flows
  from all three image-leaf families to `ReaderPage`; `ReaderPage` already
  owns one in-flight translation and per-page rendered URI projection.
- Exact change boundary: add a session-only checked More-menu item and its
  confirmation dialog; add a serial current-then-next scheduler driven by
  source-file readiness, settled page navigation, and run completion. Keep
  the existing source binding gate, manual action, local cache, image leaves,
  reader gestures, progress, and chrome geometry unchanged.
- Visual verification plan: with a configured private source, compare an
  enabled More menu, confirmation dialog, current-page render, next-page
  serial handoff, failure behavior, and route exit against same-state NextE
  captures at the same viewport. Retain raw local captures. An unconfigured
  device can establish only that the new item remains disabled.
- Unresolved risk: no private manga source is currently configured on the
  selected device, so a real rendered translation and serial handoff remain
  unproven after implementation.
- Current runtime evidence: the signed Debug build was installed in place,
  then force-stopped before the documented direct Gallery route. Its visible
  Read/Continue action ended outside NextN, so the chain is rejected before
  any local Reader menu or translation behavior. No source/profile/account,
  preference, or gallery data was changed. The route failure is recorded
  separately in the active device queue; it does not establish a fault in the
  automatic-translation scheduler.

## OPEN — Gallery Detail floating Read hit-test ownership

- User outcome: the floating Read control remains an overlay and may visually
  cover the scrolling Detail content; it must nevertheless own its own tap.
  This change adds no bottom margin, content spacer, or change to its visible
  position.
- Newly actionable basis: a current fresh native Detail action point intersects
  both the floating Read control and a lower searchable tag leaf. The outer
  rail is `HitTestMode.Transparent`; the official ArkUI contract states that a
  transparent top component lets lower overlapping nodes participate in touch
  testing. The observed terminal leaves NextN, so the action chain is rejected.
- Reference parent tree: NextE uses `Detail Stack → full-width transparent
  Read rail → inner default-hit-test Row → Read button`. The inner Row owns the
  button's measured activity height and prevents the transparent rail itself
  from becoming the only parent around the action.
- Current parent tree: NextN has `Detail Stack → full-width transparent Read
  rail → Read button`. It omitted the neutral inner Row when it intentionally
  removed NextE's unsupported smart-grip translation behavior.
- Exact change boundary: restore only that inner Row with the existing
  `readFabOuterHeight()` measurement. Keep outer rail width, padding, bottom
  position, transparency, HDS/filled choice, activity height, scroll reserve,
  and all Read routing callbacks unchanged.
- Verification plan: after a data-preserving signed Debug update, use the
  documented direct Gallery route and one fresh semantic Read action. Require
  a NextN Reader terminal before making any Reader feature claim. If it still
  leaves NextN, preserve the result and do not tune geometry or repeat taps.
- Unresolved risk: the source correction establishes the reference interaction
  boundary, but the prior terminal cannot by itself prove that hit-test
  propagation was the sole cause.
- Counterevidence: the source change was built, installed in place, and
  force-stopped before the same direct route. The fresh NextN layout changed
  as expected, but one semantic Read activation still ended outside NextN.
  The inner Row was therefore reverted rather than retained as a speculative
  fix. The faulty assumption was that restoring that one reference boundary
  would determine delivery on its own; it did not. Do not alter the floating
  geometry, reserve, or hit-test tree again without a new event-delivery
  observation that distinguishes the actual owner.
- New current evidence: on 2026-08-11 the direct Gallery Want was
  force-stopped into a verified native NextN Detail root. Its one current
  HDS-material `继续` action, resolved from fresh bounds, again terminated on
  native Download settings rather than Reader. This removes the earlier
  foreground ambiguity but does not prove which receiver won the event. The
  current source still differs from the complete NextE parent tree: its
  transparent full-width rail mounts the HDS capsule directly, while NextE
  inserts one default-hit-test inner Row with the exact capsule activity
  height. The newly actionable correction is only that missing inner Row. It
  preserves the existing floating position, visible capsule, outer transparent
  rail, activity dimensions, and scroll reserve. The prior mistake was
  treating a rejected route with ambiguous foreground as enough to discard the
  reference-owned event boundary; this run establishes the route precondition
  before the same failure. The exact inner-owner correction was then built,
  installed, and exercised once through that same fresh NextN Detail route;
  it still ended on Download settings, so it was immediately removed rather
  than left as an unproven UI change. The next evidence is fixed route-stage
  logging at the platform's visible diagnostic level, not another geometry or
  hit-test change.

## OPEN — Gallery comment translation

- User outcome: bring the mature optional comment-translation capability to
  NextN without reopening the already reviewed Comments layout, composer, or
  loading lifecycle.
- Reference parent tree: NextE owns the policy and source binding outside the
  discussion page. Its full route is `HdsNavDestination → Stack →
  PullRefreshListScaffold → ListItem → GalleryCommentsCard`; translation is a
  card-local action/state leaf. It can show cached or translated text in that
  same card, while the fixed composer remains owned by the page-level Stack.
- Current NextN parent tree: `Index` owns the existing Comments destination;
  `GalleryCommentsPage` owns `Column → PullRefreshListScaffold → ListItem →
  CommentCard`, plus its existing fixed page-footer composer. It currently
  renders the author, body, and timestamp but has no translation state or
  action. `LlmSourceProfileRepository` already owns a separate, private
  comment consumer binding; current Reader source configuration intentionally
  binds only the image-capable manga consumer.
- Proven NH boundary: comments are public NH DTO text without EH votes,
  replies, or rich span data. The new capability may add only a card-local
  translated-text/action leaf and an explicit private text-source binding. It
  must not import EH voting/reply behavior, change card/list/composer parent
  ownership, auto-submit requests, or replace the frozen Comments chrome.
- Before/after rationale: a bounded OpenAI-compatible Chat Completions
  provider and a private cache make translation optional and deterministic for
  one configured source.
  An unconfigured source keeps the action unavailable and sends no request.
- Visual verification plan: with a configured source and an existing native
  Comments route, compare the same gallery/comment viewport to NextE only for
  the card-local action, pending state, and translated-text expansion. Review
  the sibling card, list inset, and fixed composer in the same frame. Retain
  raw local captures; no source-shape or synthetic UI check is evidence.
- Unresolved risk: the selected device currently has no configured text
  translation source, so real provider execution and translated-card visual
  acceptance remain unproven. No credential, comment, or source record may be
  fabricated to obtain that state.

## OPEN — Shared translation-source configuration

- User outcome: one user-controlled private OpenAI-compatible source can be
  explicitly assigned to Reader comic translation, Gallery comment
  translation, or both; configuring one consumer must never silently enable
  the other.
- Reference parent tree: NextE keeps the entry in its settings translation
  section as a `ConciseListRow`, then owns sources through `LlmSourceManager`
  and its detail destination: `HdsNavDestination → SecondaryListScaffold →
  ListItem → GroupedListSection`. The detail form owns source type, name,
  base URL, secret input, and explicit supported-consumer capability leaves;
  consumer binding stays outside the content page.
- Current NextN parent tree: Reader Settings owns a single navigation row to
  `HdsNavDestination → ComicTranslationSourcePage →
  SecondaryListScaffold → ListItem → NextNGroupedListSection`. The profile
  repository already owns exactly two durable consumer bindings, while the
  existing form declares only Reader's Responses/image capability.
- Exact change boundary: retain the existing HDS route, list scaffold,
  grouped form and private HUKS key handling. Rename that form's semantic
  purpose to a shared translation source, add only the two explicit consumer
  switches and their durable bindings, and add one Comment Translation row to
  the existing Advanced Settings list that opens the same destination. The
  card change is restricted to the existing comment header's local action
  leaf and translated body; it must not alter the list, composer, refresh,
  route snapshot, card geometry, or comment network request.
- NH boundary: NextN supports only one OpenAI-compatible source type and no
  model catalog, Codex OAuth, Google fallback, auto-translation, or display
  mode policy. The same model string is intentionally bound only to consumers
  the user selects in this supported single-source form.
- Visual verification plan: with no source configured, compare Settings and
  a comments page against their prior same-viewport state to confirm no card
  action or layout changes are introduced. With a deliberately configured
  private source, compare the shared source form, the configured consumer
  rows, and a single translated-comment action/pending/result state against
  the corresponding NextE screens. Retain raw local captures; no source-shape
  or synthetic UI check is evidence.
- Unresolved risk: the selected device has no configured text source. The
  configured request/result path remains unproven until an existing authorized
  private source can be entered without exposing its secret.
- Current device observation: after the signed Debug update was installed in
  place on the selected device, the native Settings → Advanced → Comment
  Translation route reached this shared source form. Its default unconfigured
  fields and the explicit comment-use selection rendered without any field
  input, save, provider request, account action, preference write, or comment
  mutation. The retained local capture is route/form evidence only; it is not
  a same-state NextE comparison or a configured-provider acceptance.

## OPEN — Collection-card tag display

- User outcome: gallery listings may show the tags already supplied by the NH
  v2 list response, with the same opt-in, presentation-specific semantics as
  ErosN; raw tag ids must never be rendered as a substitute for names.
- Newly actionable basis: the user explicitly identified ErosN's gallery-tag
  display as a mature NH capability to audit against NextN. Current source
  confirms that NextN keeps each list item's `tag_ids`, but exposes only the
  three language ids; ErosN resolves those ids in a bounded local catalog and
  then renders up to ten resolved names.
- Reference parent trees: ErosN's setting is an opt-in (`showTags`, default
  off). Its regular list is `Gesture → fixed Card → Row(cover, information
  Column(title, tag leaf))`; its regular waterfall is `Gesture → Card →
  Column(cover, title, wrapping tag leaf)`; its compact waterfall is
  `Gesture → cover Stack → bottom gradient → horizontal single-line tag leaf
  → title`. Its grid card intentionally leaves the tag leaf absent.
- Current NextN parent trees: `GalleryCollectionBody` owns the refresh
  scaffold and selects `GalleryMediumCard` for LIST, `GalleryWaterfallCard`
  for WATERFALL, `GalleryWaterfallCompactCard` for WATERFALL_COMPACT,
  `GalleryGridCard` for COVER_GRID, and `GalleryCoverWallCard` for COVER_WALL.
  Its SIMPLE_LIST owner remains the independently reviewed NextE simple-row
  grammar. Layout Settings owns `SettingsPage(LAYOUT) →
  SecondaryListScaffold → BrowsePresentationGroup →
  NextNGroupedListSection → NextNListRow`.
- Exact change boundary: add a private, bounded id-to-name catalog cache and
  enrich only loaded `NhGallerySummary` snapshots. Add an explicit
  default-off display switch in the existing Browse presentation group. Add a
  tag leaf only to LIST, WATERFALL, and WATERFALL_COMPACT: wrapping tags in
  the first two and a single horizontal line in the compact cover overlay.
  Do not change collection scaffolds, request/cursor ownership, card routing,
  SIMPLE_LIST, COVER_GRID, COVER_WALL, cover geometry, language badges, or
  page-count leaves.
- Minimality rationale: resolving one de-duplicated page batch through a
  private local catalog prevents per-card requests and preserves valid list
  data if the public catalog cannot supply a name. The setting remains off
  until the user elects the denser card treatment.
- Visual verification plan: after the feature is configured on the selected
  device, compare the same loaded list and waterfall gallery set with ErosN
  at the same viewport. Review the Settings row, disabled/default-off state,
  resolved-name state, wrapping card rhythm, compact single-line overlay,
  grid/cover-wall absence, and unchanged SIMPLE_LIST/card navigation. Retain
  raw local captures; no source-shape or synthetic UI check is acceptance.
- Unresolved risk: the v2 list endpoint supplies only ids. The public catalog
  may rate-limit or omit names, so absence of resolved names must leave the
  card's existing layout intact rather than fail, block, or retry a listing.
- Current device observation: on the selected device, the default-off control
  was observed before the temporary validation change. Enabling it rendered
  resolved-name leaves in the native regular-waterfall, compact-waterfall,
  and list cards. The control was then restored to off and the presentation
  to Cover grid, both in Settings and on the terminal Gallery surface. This
  confirms the bounded native state and restoration path only; no
  same-gallery, same-viewport ErosN capture exists yet, so visual-reference
  parity remains OPEN.
- Follow-up source alignment: ErosN's existing list tag leaf selects a
  downloaded dictionary display name when available; NextN Detail already
  applies the same optional local-dictionary fallback, but the new collection
  leaf always renders the raw catalog name. The exact correction is a
  presentation-only `NhTag` display label populated from the existing local
  dictionary during the already serialized catalog enrichment. It changes no
  setting, request, cache schema, card geometry, tag query, or raw tag name;
  dictionary absence continues to show the raw name. Device review must use
  an already installed dictionary when available, otherwise this translated
  substate remains unaccepted rather than downloading a dictionary merely for
  validation.
- Current device observation for that follow-up: the installed build was
  exercised with the existing local data only. Latest initially retained an
  independent Cover-grid source override, so changing the global Setting to
  List alone did not change its renderer; after its existing source menu was
  set to Follow global, the native List showed its tag leaves. The displayed
  values were the raw-fallback form; no local dictionary substitution was
  observable in this run. Global presentation, Latest override, and the tag
  control were restored to their pre-run Cover-grid, Cover-grid, and off
  values. This is raw-fallback and restoration evidence only; the optional
  translated-label state and same-state ErosN visual comparison remain OPEN.

## OPEN — Reader enhancement interaction yield

- User outcome: local Reader super-resolution must never compete with a
  foreground reading gesture or the existing Reader settings sheet.
- Reference and current parent tree: both apps keep one full Reader canvas
  with content first, a transparent tap surface, and conditional overlay
  chrome. NextE binds the canvas touch lifecycle to its existing
  super-resolution service; NextN already exposes the same native pause API
  but does not call it from the Reader owner.
- Exact boundary: add only transient pause/resume state and timers to
  `ReaderPage`, forwarding foreground down/move/up/cancel and Reader settings
  open/close to the existing service. Do not alter page data sources, List or
  Swiper ownership, image leaves, tap-zone semantics, chrome geometry,
  settings contents, model storage, or any network request.
- Verification plan: build first. With an installed local enhancement model,
  compare a reader interaction and immediately subsequent settled page against
  NextE at the same mode and viewport; retain raw captures locally. No
  source-shape or synthetic UI check is acceptance.
- Current device observation: the selected device reported the local model as
  installed and enhancement as disabled. The compiled build was installed in
  place, but the bounded direct-gallery run did not retain a stable Reader
  terminal after the native Detail action; its terminal native state was a
  settings surface. The enhancement switch was confirmed disabled afterward
  and Browse was restored. This is not processing or interaction acceptance;
  that evidence remains OPEN.

## OPEN — Reader enhancement runtime migration

- User outcome: an enabled, installed Reader enhancement must preserve the
  native Reader route and produce a local derivative without terminating the
  application.
- Current evidence: with the enhancement preference enabled and the legacy
  MindSpore asset present, one fresh direct Gallery action exited NextN.
  The same route remained in the NextN Reader when the actual NNRT upscale
  request alone was bypassed; a direct no-op native pause call also remained
  safe. This isolates the current failing boundary to the MindSpore upscale
  request, not Reader routing, the floating Read action, or native module
  loading. Raw device evidence is retained locally outside Git.
- Reference boundary: NextE owns one user-installed model definition with an
  ncnn param/bin runtime pair and an optional MindSpore accelerator asset.
  Its service attempts the accelerator only as an optimization and retains
  the ncnn pair as the portable runtime. NextN currently treats its optional
  `.ms` asset as the sole runtime, which is the unsupported substitution.
- Exact change: retain the existing Reader settings route, model-management
  page, toggle, local storage root, and explicit install/remove actions.
  Replace only the model asset contract and processing leaf so the verified
  ncnn pair is required for installed state and is used for image processing.
  A legacy `.ms` file is retained untouched but is not treated as executable
  runtime state; no Reader route, chrome, image geometry, setting layout, or
  automatic network fetch may change.
- Verification plan: after a signed data-preserving update, the pre-existing
  legacy asset must leave the Reader stable but unenhanced. A separately
  explicit model-install action may fetch and verify the ncnn pair, after
  which the same direct Reader route must remain native NextN and show an
  accepted processed-page result. Compare the settings leaf and Reader state
  to the same reference state; no source-shape or synthetic UI check is
  acceptance.
- Unresolved risk: the affected device has not yet run the ncnn pair, so this
  record does not claim model-processing acceptance.
- New device evidence: the explicit ncnn-pair download completed and the
  model page entered its installed/remove state. With the existing enhancement
  preference still enabled, the same fresh native Detail action again exited
  NextN; the terminal foreground root was NextE rather than Reader. A
  20-second PID- and native-tag-filtered log capture produced no module line,
  so it does not establish a GPU, model-load, or output-encoding cause. The
  next single-variable runtime experiment was CPU-only invocation that did
  not initialize Vulkan; its terminal foreground was still NextE. That
  disproves Vulkan initialization as the isolated cause, so the CPU override
  was removed rather than retained. No Reader layout or setting geometry was
  changed.
- 2026-08-11 runtime isolation: an ncnn `prepareModel()`-only temporary
  branch remained in native NextN. A separate branch that continued through
  model-ready/cache preflight and source pixel read, but returned before
  `upscaleRgba`, still reached NextE. This does not attribute the exit to
  decoding: the latter branch covers multiple post-prepare operations. Both
  temporary branches were removed immediately after their one-run result; raw
  layouts remain in the local Reader-enhancement audit directory. The next
  diagnostic must isolate one remaining operation rather than promote either
  observation into a root-cause claim.
- Follow-up: a return immediately after model-ready/hash/cache preflight also
  remained in native NextN. Therefore the observed exit begins only after
  `processNow()` enters image-source handling; that temporary branch was also
  removed after its one-run result.
- A return immediately after `image.createImageSource()` also remained in
  native NextN. The remaining untested image operations are `getImageInfo`,
  pixel-map creation, and pixel read; the temporary source-creation branch
  was removed after its one-run result.
- A return immediately after `getImageInfo()` also remained in native NextN.
  The remaining image operations are now PixelMap creation and pixel read;
  the temporary image-info branch was removed after its one-run result.
- A return immediately after `source.createPixelMap()` reached NextE. The
  exact first unsafe operation in this device path is therefore ArkTS PixelMap
  creation, not ncnn model preparation, cache preflight, ImageSource creation,
  or source image-info lookup. The temporary PixelMap branch was removed after
  one run. This is a causal device observation for the current implementation,
  not a claim about the platform API in general; the remediation must move or
  bound pixel decoding instead of retrying this call.
- Reference reconciliation before the next edit: NextE owns one serialized
  enhancement queue (`pendingTasks`/`activeTask`) before it enters the same
  PixelMap API. NextN's current per-output in-flight map starts every page's
  `processNow()` immediately, so multiple Reader-mounted pages may decode at
  once. Exact change boundary: retain NextN's model, cache, owner and native
  leaves, but introduce one service-owned serialized processing chain plus
  an owner check before queued decoding. Do not change Reader geometry,
  settings, source size, model choice, download behavior, or page routing.
- Verification plan: one signed, data-preserving build; same direct Gallery
  route and one native Reader entry; then require a native NextN terminal
  without using an early-return diagnostic. A stable terminal alone does not
  accept output quality; derivative display and same-state Reader review stay
  required afterward.
- Rejected by the resulting device run: the serialized chain still reached
  NextE on the same real Reader path. It did not fix the proven PixelMap
  boundary, so the queue and pre-decode owner guard were removed rather than
  retained. The remaining root-cause inquiry must target the decode strategy
  or this Reader's image-lifetime boundary, not concurrency alone.
- Next diagnostic boundary: use the platform-supported `desiredSize` only for
  one temporary 256×256 PixelMap decode, then return the original image before
  pixel read or ncnn. It differentiates the current full-resolution decode
  resource budget from an ImageSource/PixelMap lifetime failure; it does not
  alter any accepted image output or Reader presentation.
- Rejected by the resulting device run: the 256×256 PixelMap branch still
  reached NextE. Pixel dimensions and the earlier queue hypothesis are not
  sufficient explanations. The temporary size constraint and early return
  were removed; the next investigation is limited to the native module / image
  decoder linkage boundary.
- Newly actionable source basis: `ReaderImageCacheService` accepted any
  positive stream-write count, so a short write could promote incomplete image
  bytes without a full-file integrity check. Header lookup can still succeed
  on such a file while full PixelMap decode enters the system image failure
  path. Exact change boundary: write each received chunk sequentially at the
  active file pointer and reject a short write. Move only new Reader cache
  identities from `v1` to `v2` so a corrected build obtains clean bytes
  without deleting existing private cache entries. Do not alter network
  request policy, Reader layout, model settings, account, or user content.
- Device result: the signed v2-cache build was installed with `install -r` on
  the selected device. The same direct Gallery route entered native Reader and
  remained foregrounded by NextN at both 10-second and 30-second observations;
  the prior immediate process exit did not recur. This accepts the crash-path
  repair only. The evidence proves that a fresh v2 source survived the prior
  failing decode path; it does not identify which historical v1 write was
  malformed, establish that a derivative was produced, or establish visual
  quality against the reference.
- Follow-up device observation: the current Reader's existing enhancement
  status leaf reached its applied state after the stable run. That leaf is
  driven only by `ReaderSuperResolutionResult.applied`, which is returned only
  after the private derivative is atomically promoted and verified non-empty.
  This is native processing/output-state evidence for the observed page. Raw
  content remains only in the local audit artifact and was not added to Git.
  Same-state visual-quality comparison against NextE remains OPEN.

## EVIDENCE-ONLY — Reader route mount/data split — 2026-08-11

- New device evidence: after a data-preserving NextN-only cold start and the
  documented Gallery `471768` route, one semantic `继续` action moved the
  foreground from native NextN Detail to NextE instead of NextN Reader. The
  fixed route logs were unavailable from the device buffer, and no second
  coordinate or alternate route was used.
- Whole affected tree: Detail Read button → `GalleryDetailPage.openReader` →
  `Index.pushReader` → `ReaderOverlayNavigationState` → overlay HDS
  navigation → `ReaderPage.loadReaderSettings` → `ReaderPage.loadReader` →
  local detail/history/data-source/image-cache leaves.
- Exact temporary delta: before any detail, history, page-data, image-cache,
  translation, enhancement, or network work begins, Reader will show its
  existing native inline error canvas. This is a one-run route-mount
  discriminator only; it does not change Reader hierarchy, geometry, actions,
  preferences, or stored data.
- Verification plan: install in place, force-stop only NextN, launch the same
  numeric Gallery route, and activate the same unique Read action once. If
  native Reader remains foregrounded, remove the temporary guard and diagnose
  only the skipped load path; otherwise diagnose the overlay/Reader mount.
- Status: EVIDENCE-ONLY. It is not a visual acceptance or a product change.
- Result: after the same NextN-only cold start, direct route, and one semantic
  Read action, the terminal root remained native NextN Reader. This excludes
  the Detail callback, overlay navigation, Reader destination, and Reader
  component mount from the observed failure window. The mount guard is removed
  immediately; the next one-run discriminator keeps normal detail/history/data
  loading but suppresses only visible-page and opportunistic preload image
  cache requests.
- Result: with normal detail, history, and page-data loading retained while
  visible-page and preload image/cache work was suppressed, native NextN
  Reader again remained foregrounded. The failing window is therefore limited
  to the normal image/cache/enhancement chain. This guard is removed
  immediately; the next discriminator retains normal page images and cache
  work but suppresses only the existing enhancement invocation.
