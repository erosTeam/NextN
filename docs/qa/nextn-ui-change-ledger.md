# NextN UI change ledger

This register records visible-change boundaries and their evidence. It does not
authorize an edit, replace a device comparison, or define product completion.

## OPEN — Settings wording reference correction — 2026-08-15

- **Why newly actionable:** the user identified opaque, self-authored Chinese
  copy in Settings, including `图库展示方式`, `显示标签译名`, and `HDS 材质`,
  plus explanatory subtitles that expose implementation detail instead of a
  setting's operation. The faulty assumption was that a locally paraphrased
  term was acceptable when a same-function reference already supplied user
  copy. It was not: the wording changed the meaning and made ordinary controls
  difficult to understand.
- **Whole parent-tree boundary:** preserve the existing Settings root and all
  route, sheet, section, row, menu, and state owners. The directly affected
  leaves are `Settings → Layout → BrowsePresentationGroup` (view, card tags,
  tag translation, and Read-button-style rows) and the shared Reader
  presentation rows used by both the routed page and Reader sheet. No list,
  reader, download, search, account, or settings navigation tree is rebuilt.
- **Reference boundary:** use current NextE wording verbatim where its
  function and choice semantics match: `List view`, `Compact`, `Grid`,
  `Filled accent`, `HDS material`, and the equivalent Reader vocabulary.
  For the NH card-tag visibility switch, use ErosN's direct `Show Tags`
  wording and retain a short, factual statement of the NextN card modes it
  affects. The user explicitly rejected the invented noun `translated label`;
  `Tag Translation` is a wording correction for the existing separate
  display-label switch, not a claim that it has ErosN's download-on-enable
  behavior. This changes no dictionary state, search grammar, or request.
- **Exact change:** replace only reference-backed or explicitly user-directed
  labels and values; remove the routine subtitle for view selection because
  title plus selected value already communicates the operation. Preserve the reference-backed
  Read-button subtitle because it identifies the Gallery Detail floating
  control whose appearance changes. Replace the card-tag subtitle's internal
  `resolved` terminology with only its actual List/Waterfall display scope.
  Do not introduce an implementation explanation.
- **Supplemental direct-reference audit:** the same parent-tree review found
  exact NextE counterparts for the cover-background-blur title and behavior
  description, Japanese-title explanation, Reader direction values, `Auto
  page interval`, `Volume key page turn`, and Download's `Retry count`. These
  leaf values may be copied without a behavior or hierarchy change. Point-zone
  action labels, double-page availability/status, grid-width terminology, and
  any new explanatory line remain excluded until their distinct behavior has a
  separate decision.
- **Explicit exclusions:** do not rename the Advanced dictionary-management
  row into a second ambiguous `Tag Translation` control; do not change the
  relationship between dictionary availability and the existing display
  switch; do not rewrite the grid-density `vp` summary, download policy,
  technical translation-source, cache-status, or other behaviorally
  non-equivalent rows until each has an exact source or a separate user
  decision. No persistent setting, request, cache, tag lookup, route,
  interaction, or visual geometry is changed except the natural row height
  after removal of the view-selection subtitle.
- **Verification plan:** inspect the scoped resource and Settings diff, parse
  all four locale JSON files, and build the exact commit. Then install in
  place, observe the current Layout rows and menus on a foreground-confirmed
  native Settings route, and restore any temporary preference used to expose a
  value. A same-state, same-viewport NextE comparison is still required before
  any visual-parity claim; source wording and a build alone do not accept this
  visible lane.
- **Observed 2026-08-15:** `39fba26` passed the signed build and was installed
  in place on the selected `.237` device. A foreground-confirmed native
  `Settings → 界面` observation showed `列表视图 / 网格`, `显示标签` with its
  factual List/Waterfall scope, and `标签翻译`; no former opaque label appeared.
  The `阅读按钮样式` row and its non-mutating menu observation showed the exact
  reference-backed description plus `实心主色` and `光感材质`. This is bounded
  NextN wording evidence only; the broader audit and same-state NextE visual
  comparison remain OPEN.
- **Supplemental observation:** `50cfac0` also passed the signed build and was
  installed in place on the selected `.237` device. The foreground-confirmed
  Reader direction menu showed `从左到右 / 从右到左 / 从上到下 / 连续纵向`; the
  Interface tail showed the direct-reference cover-background and
  Japanese-title explanations, all within the observed viewport. No preference
  value changed. This remains bounded NextN wording evidence only; the broader
  audit and same-state NextE visual comparison remain OPEN.
- **Download leaf observation:** `d366aac` passed the signed build and was
  installed in place on the selected `.237` device. The foreground-confirmed
  native Download Settings page displayed `重试次数` together with its current
  value inside the viewport; no setting or other user state changed. This is
  bounded rendered-wording evidence only, not a download-behavior or
  visual-parity acceptance.

## OPEN — Search structured advanced conditions — 2026-08-14

- **Why newly actionable:** the user asked to adopt the useful search
  capabilities found in NClientV3 rather than limit discovery to tag
  autocomplete. A bounded anonymous contract probe against the same public
  v2 search family returned the ordinary pagination envelope for typed tag
  inclusion/exclusion, page-count comparisons, and uploaded-age comparisons;
  page and tag controls also produced distinct aggregate result counts. This
  establishes a current transport/behavior candidate, not a permanent or
  officially documented upstream grammar guarantee.
- **Whole parent-tree boundary:** `Index.pushSearch → SearchRouteParams /
  route-local SearchChromeState → HdsNavDestination(SearchPage) → HDS title
  menu plus cached bottom SearchTitleField → one state-selecting Column →
  root-hosted LARGE SearchOptionsSheet → NextNModalScaffold → one
  searchOptionsScroller → ListItem → SearchOptionsPanel`. The existing
  panel owns saved Language and Order defaults; the advanced condition leaf
  must precede those two sections without adding another route, sheet,
  scroller, title input, or result-list wrapper.
- **Reference boundary:** the closest NextE tree is its pushed gallery Search
  page with a root-owned filter sheet and one sheet scroll owner. Its
  category/rating/torrent filter state is EH-specific and persistent, so only
  the parent ownership and sheet relationship transfer to NextN; NextN's
  conditions remain route-local raw-query edits.
- **Visual correction — 2026-08-15:** the user rejected the first composer
  presentation. Its faulty assumption was that a centered `高级条件` caption,
  explanatory sentence, and further centered `页数` / `上传时长` captions could
  create hierarchy inside the modal. They were locally authored, not in the
  reference tree, and the default centered `Column` alignment made the
  title-to-control gap conspicuous. The previous NextN-only panel capture is
  rejected as visual evidence. Keep the shared
  `NextNModalScaffold → HdsNavigation(MODAL) → List` owner intact: it matches
  NextE and has no local top padding. Rebuild only the panel leaf as direct,
  left-aligned HDS grouped condition controls: tag fields, a compact page
  range, and a compact upload-age range, each with its existing explicit add
  action. Remove the invented preamble and do not introduce another route,
  sheet, scroller, or explanatory copy.
- **Copy correction — 2026-08-15:** the user also rejected the range-field
  placeholder `正整数` / `Positive whole number`. That was an internal input
  validation rule incorrectly exposed as user-facing copy, not a reference
  term. Empty range fields mean no bound, so use NextE's exact `filter_any`
  wording (`不限` / `Any` / `指定なし`). Keep `InputType.Number` and its existing
  digit-only filter, but disable each Add row until either bound parses as a
  positive value; remove the visible `range_required` error instead of adding
  instructional prose. Range-order feedback remains a separate, unchanged
  validation boundary.
- **Exact change:** add a short-lived condition composer for typed
  `tag/parody/character/artist/group/category` include-or-exclude terms plus
  page-count and uploaded-age lower/upper comparisons. Applying a valid
  condition appends its canonical token to the existing editable query and
  synchronizes the existing HDS field; it does not submit automatically.
  The raw query remains the only history, quick-search, submit, and paging
  value. Existing saved Language and Order controls retain their owners and
  are not emitted again by the composer.
- **Input correctness boundary:** tag autocomplete must recognize only known
  tag namespaces, preserve a leading exclusion marker for `-tag:`, and not
  probe tag suggestions for `pages:` or `uploaded:` operators. The composer
  does not parse, reorder, de-duplicate, delete, or claim ownership of user
  text; users edit existing generated conditions in the HDS field itself.
- **Explicit exclusions:** do not change Index routing, HDS chrome, direct
  gallery-link recognition, suggestion/result/landing branch order,
  `GalleryCollectionBody`, Search result summaries, Quick Search/History
  persistence, Browse/Search Settings ownership, account scope, cache,
  filters, or the global LIST surface. Do not add a static tag corpus, full
  tag-directory page, random gallery entry, or any automatic search request.
- **Verification plan:** inspect the scoped diff, JSON resources, and signed
  build. On a foreground-confirmed Search route, observe the existing filter
  menu, prefilled query, empty draft, valid tag inclusion/exclusion,
  page/upload range insertion, manual field edit after insertion, submitted
  results, suggestion behavior for `-tag:` versus `pages:`/`uploaded:`, and
  keyboard-open sheet state. Restore any temporary query/defaults. A current
  same-state, same-viewport NextE comparison is still required before any
  visual-parity claim; source/build checks do not accept this visible lane.
- **Current NextN device observation — 2026-08-15:** the signed HAP was
  installed in place on only `192.168.50.237:12345`, following the live
  target, lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms` gate. No
  data clear, uninstall, account action, preference change, or search submit
  occurred. A foreground-confirmed native `1320×2120` Search options sheet
  showed the new panel before the existing saved defaults. One typed tag
  condition appended to the HDS field; an empty page attempt showed its
  scoped inline error; equal page bounds compiled as one exact token; the
  complete five-unit upload menu was visible; equal upload bounds compiled
  as one exact token; and an exclusion-mode tag condition preserved its
  leading minus marker. A keyboard screenshot is retained, but its paired
  layout export was empty, so it cannot establish foreground identity,
  resized-window bounds, or keyboard usability; that state remains OPEN.
  This is a bounded NextN interaction observation only: manual HDS-field
  edits after composition, result/refresh behavior, suggestion results for
  raw `-tag:`/operator input, every error branch, and a same-state NextE
  visual comparison remain OPEN. Local raw artifacts are retained under
  `.hvigor/outputs/advanced-search-20260814T1540/` and are excluded from
  source control.
- **Range-control correction — 2026-08-15:** the prior empty-range inline
  error was a visible exposure of an internal parser rule. The signed HAP
  from `882c381` was installed in place on the same selected device after a
  fresh lease, wake, and power-state gate. In the foreground-confirmed native
  Search options sheet, empty page and upload ranges rendered `不限` and both
  Add rows were visibly unavailable; entering an unsubmitted page lower bound
  of `1` made only the page Add row available. No Add action, query submit,
  history write, preference change, account action, data clear, or uninstall
  occurred, and force-stopping NextN discarded the route-local draft. This
  observes only these two current NextN states; range ordering, submission,
  keyboard usability, accessibility announcement, and visual parity remain
  OPEN. Local raw artifacts are retained under
  `.hvigor/outputs/search-range-control-20260815T0708/` and are excluded from
  source control.

## OPEN — Browse/Search option-policy footnotes — 2026-08-15

- **Why newly actionable:** the user explicitly rejected implementation and
  storage-policy prose being placed beneath routine controls. Both current
  option panels append a trailing caption about local storage, public GET, or
  anonymous search after their actual Language and Order choices. The captions
  do not change either control's action or outcome.
- **Whole parent-tree boundary:** Browse is `Index root HDS menu → HomePage →
  GalleryCollectionBody → LARGE BrowseOptionsSheet → NextNModalScaffold → one
  scroller → ListItem → BrowseOptionsPanel`; Search is `Index.pushSearch →
  HdsNavDestination(SearchPage) → LARGE SearchOptionsSheet →
  NextNModalScaffold → one scroller → ListItem → SearchOptionsPanel`. Each
  panel's language and order groups remain in their current order and retain
  their current state owners.
- **Reference boundary:** the closest NextE search filter sheet retains the
  same HDS modal/scroller ownership and ends with controls, not a policy
  caption. No NH data or action requires an extra explanatory leaf here.
- **Exact change:** remove only the two trailing caption leaves and their four
  locale resource keys. Do not alter any row, selection, persistence,
  request, query, Quick Search/History, sheet detent, title, or padding.
- **Verification plan:** inspect the scoped diff, resources, and signed build.
  On foreground-confirmed Browse and Search option sheets, observe that the
  Language and Order groups remain available and no policy caption remains.
  A same-state, same-viewport reference comparison remains required before a
  visual-parity claim.
- **Bounded device observation:** the signed HAP from `0e0840e` was installed
  in place on only `192.168.50.237:12345` after the live target, lease, wake,
  and power-state gate. Browse options retained Language and Order without its
  trailing caption. Search options retained its existing condition controls,
  Language, and (after one non-selecting scroll) Order without its trailing
  caption. No selection, query submission, history write, data clear,
  uninstall, account action, or preference change occurred. This is not a
  same-state reference comparison; visual parity and unobserved sheet states
  remain OPEN. Raw artifacts are local-only under
  `.hvigor/outputs/option-policy-footnotes-20260815T0900/`.

## OPEN — Search recent-history presentation — 2026-08-15

- **Why newly actionable:** the user repeated an earlier, unresolved objection
  to the Search landing's recent-history design. The existing leaf had not
  been visually reworked since the baseline; later history work only
  serialized RDB writes. Treat the prior omission as a correction, not as a
  new feature request.
- **Whole parent-tree boundary:** `SearchPage → HdsNavDestination + cached
  title-field → active query empty → SearchGuide → Scroll(historyScroller) →
  QuickSearchesPanel / RecentSearchesPanel → wrapping history chips`. Keep the
  HDS, landing-branch order, one scroll owner, Quick Search section,
  `SearchHistoryRepository`, raw submitted query, and result flow unchanged.
- **Reference boundary:** NextE uses the same history header then wrapping
  chip relationship: raw query, optional local display translation below it,
  whole-chip re-search, and long-press single-item deletion. Its separate
  history-translation preference is a broader product decision. NextN must
  not copy that new preference or write translated text into its history RDB.
- **Exact change:** rebuild only the history-chip leaf: remove the permanent
  per-chip `x` button and its forced single-line height; retain the existing
  direct re-search action and long-press deletion. Add a short-lived local
  query-to-display-translation cache driven by existing dictionary revision
  and the existing global tag-display choice. Original query syntax remains
  primary and unchanged; only recognized tag clauses may add a display line.
  Operators such as `pages:` and `uploaded:` remain raw and are never
  rewritten, submitted, or persisted differently.
- **Correction — landing calculation and parent tree:** the earlier hypothesis
  that `layoutSafeArea.topAvoidHeight` was an extra inset was wrong and is
  rejected. Keep the complete NextE calculation, with no measured-pixel
  offset: `layoutSafeArea.topAvoidHeight + TITLE_BAR_HEIGHT +
  SEARCH_TITLE_FIELD_BOTTOM_HEIGHT + SPACE_MD`. Match the relevant hierarchy:
  `HdsNavDestination → Stack → full-height Column → Scroll(height: 100%) →
  content Column → Quick Search / Recent Search`. The Scroll child has no
  fixed or maximum height. Use the minimum-height portion of NextE's existing
  scroll-page pattern: short local history gets the same top origin while long
  history can still expand beyond the viewport and scroll.
- **Header-flow correction:** use the reference `SPACE_LG` horizontal inset
  and compact `28vp` clear action, not the unrelated `48vp` list-row target.
  Render `SPACE_SM` between Quick Search and Recent Search only when both
  actually render, while retaining the existing error-to-content rhythm.
  An empty Quick Search builder must not create a phantom gap above Recent
  Search. Match the reference bottom equations too: history uses
  `bottomAvoidHeight + SPACE_LG`; the empty guide uses `SPACE_LG`.
- **Explicit exclusions:** do not add a new history preference, change
  history retention/deduplication, change quick-search chips, alter click to
  append-only behavior, change Search routing, search requests, suggestions,
  content filters, result presentation, or the new advanced-condition sheet.
- **Verification plan:** inspect the scoped diff and signed build; then on a
  foreground-confirmed native Search landing with a current same-viewport
  reference, observe short and long raw queries, a raw-versus-localized tag
  query, whole-chip re-search, long-press removal, clear-all, dictionary
  revision refresh, and a cold reopen. Do not claim parity from source/build
  alone.

## OPEN — Account verification-marker cold-restore gate — 2026-08-14

- **Why newly actionable:** a terminal authenticated Favorites double-401
  persists the explicit verification marker while deliberately retaining the
  sealed session and ordinary ArkWeb cookies. Current cold restore can then
  hydrate those old materials after reading the marker and publish the
  impossible combination `signedIn=true` plus `verificationRequired=true`.
  Account and Favorites prioritize the signed-in branch, so the native visible
  state can mask the durable verification requirement.
- **Whole owner tree:** `NhApiClient authenticated GET terminal replay 401 →
  NhAccountSessionService.requireVisibleVerificationAfterAccountGet401 →
  AccountSessionRepository verification marker → EntryAbility account restore
  → NhAccountSessionService.restoreInternal → AccountSessionState →
  Settings RootAccountSection / BrowserSessionPage / FavoritesPage`. The
  Account service is the sole owner of this projection; pages must not add
  separate defensive checks.
- **Exact change boundary:** immediately after restore loads a required marker,
  retain the sealed envelope and ArkWeb cookie jar but use the existing
  signed-out/verification projection and stop before every regular-jar or
  sealed-envelope hydration branch. Only the existing atomically verified
  promotion may replace the envelope and clear the marker. This changes the
  affected Account state to its existing native verification-required leaf and
  Favorites to its existing sign-in prompt; it creates no WebView, login,
  copy, route, or geometry branch.
- **Explicit exclusions:** do not delete cookies/session records, change
  account transport/retry policy, modify Account/Favorites parent trees,
  create a new login UI, touch credentials, alter any authenticated mutation,
  or infer that a current healthy session has failed. The current safe S0
  observation is accepted separately and does not prove this exceptional
  marker state.
- **Verification plan:** inspect the owner-only diff, run the signed build,
  and retain current native S0 only as a non-regression check. Do not induce a
  terminal 401 or re-login merely to manufacture evidence. A future naturally
  occurring marker state must show the existing verification-required Account
  and signed-out Favorites leaves after a NextN-only cold start before runtime
  acceptance can be claimed.

## OPEN — Reader background preference — 2026-08-14

- **Lifecycle-correction boundary — 2026-08-14:** the initial implementation
  allowed an asynchronously restored Reader presentation to reach `Index`
  before its private Reader destination was shown, then unconditionally
  overwrote that state with the default dark/fullscreen policy. A late Reader
  callback during route close could likewise enqueue a status-bar request
  after the host had restored the app policy; an already-disappeared Reader
  could finish restoring and re-enable its keep-screen-on policy. Retain the
  same Reader/Index ownership and all visible UI. Cache only the latest child
  presentation while the host is not yet shown, replay it once the destination
  is visible, ignore child presentation after close begins, and give the
  Reader's async settings restore a route-lifetime generation. This does not
  change settings values, canvas palette, Chrome, system-bar API ownership,
  route structure, gestures, or copy. Source review and a signed build are
  static verification checkpoints only; the existing device observations do
  not prove this lifecycle race or its correction, which remains OPEN for a
  safe future runtime observation.
- **Why newly actionable:** current NextE has a local Reader background mode
  (`Black`, `Gray`, `White`, `Automatic`) as the first leaf of its existing
  Display group. NextN currently hard-codes one Reader canvas color and has
  no equivalent presentation preference. This is a bounded Reader capability
  gap, separate from the already-open image-scaling and page-number leaves.
- **Whole reference tree:** `ReaderSettingsPage → Display
  GroupedListSection → background value menu → image-scaling-quality value
  menu → page-number switch → fullscreen switch → keep-screen-on switch →
  ReadMode settings/state → ReaderPage canvas/loading/failure surfaces →
  Reader status-bar policy`. The reference resolves `Automatic` from the
  effective app theme, keeps Reader chrome as its dark overlay, and uses the
  resolved canvas darkness for hidden-chrome status-bar icon contrast.
- **Current NextN tree:** `SettingsPage(READER) → SecondaryListScaffold →
  ReaderPresentationListItems → ReaderDisplayGroup`, shared unchanged by the
  routed Settings page and Reader-owned sheet. `ReaderPage` owns the vertical,
  paged, and spread canvas leaves, while `Index` retains the private Reader
  overlay and is the only Window/status-bar owner. The current fixed canvas
  color is repeated by every image, letterbox, loading, and recovery leaf.
- **Exact change boundary:** add the device-local default-`Black` preference
  through `NhReaderPresentation → ReaderPresentationState →
  ReaderSettingsRepository → ReaderPresentationService`; insert one
  no-prefix, no-subtitle value row before image scaling in the existing Display
  group; and use one resolved background/foreground palette only for Reader
  canvases and their loading/error/retry affordances. `Gray` is `#303030`,
  `White` is `#FFFFFF`, and `Automatic` resolves to black for an effective dark
  app theme and white otherwise. Reader keeps its existing dark chrome,
  thumbnail rail, translation status, and gesture layers. The Reader callback
  supplies the resolved canvas-dark value to `Index`; the existing serialized
  Window owner uses `chromeVisible || canvasDark` for status-bar icon contrast.
- **Explicit exclusions:** do not change the Reader sheet parent tree, section
  ownership/order other than this first Display leaf, leading-icon policy,
  image scaling, page number, fullscreen semantics, Reader modes, spread
  pairing/geometry, page-turn animation, tap overlay, zoom, progress/history,
  cache/download, translation, enhancement pipeline, global app theme, gallery
  cover letterbox setting, or screen-orientation policy.
- **Verification plan:** inspect the scoped diff and build the signed Debug
  HAP. On one foreground-confirmed Reader route, verify the new row and all
  four values in both existing Settings entry points; observe black/gray/white
  canvas and contain letterboxes, persistence after a NextN-only cold start,
  and `Automatic` under each effective app theme. Also verify a non-fullscreen,
  hidden-chrome Reader state uses dark status icons over white and light icons
  over black/gray, plus readable loading/retry/failure leaves where each can be
  safely reached. A current same-state, same-viewport NextE capture remains
  required before any visual-parity claim; no UI static contract is permitted.
- **Additional bounded device observation — 2026-08-14:** in the routed root
  Settings entry, `自动` plus fullscreen-off were rendered again after one
  NextN-only force-stop/start without a data clear or uninstall. The
  documented direct Gallery route then reached a foreground Reader overlay
  with initial chrome hidden;
  the system status bar remained visible and its retained icon styling was
  dark for that one current Automatic state. Both temporary values were
  restored to their observed originals (`黑色`, fullscreen on) and read back
  after another NextN-only force-stop/start without a data clear or uninstall.
  The local artifact directory retains layouts and a terminal screenshot but no
  protocol-runner command ledger, so
  this is evidence of one bounded current run, not independently replayable
  cold-start acceptance. Automatic under the other effective theme, all
  chrome/fullscreen combinations, Reader-sheet entry, other canvas states, and
  reference parity remain OPEN.

## OPEN — Reader double-page layout preference — 2026-08-14

- **Why newly actionable:** the current NextE Reader keeps the existing
  double-page request separate from a local `Joined`/`Split` geometry choice.
  NextN already renders a joined two-page surface but offers no durable way to
  choose equal-width panes. The default must remain `Joined`, so existing
  NextN reader presentation is unchanged until the user explicitly selects
  `Split`.
- **Whole reference tree:** `ReaderSettingsPage → Layout
  GroupedListSection → double-page switch → double-page-layout value menu →
  page-turn-animation switch → ReadMode settings/state → ReaderPage →
  ReaderSpreadSurface`. The reference uses the same paired pages and visual
  order for both choices: joined sizes panes by their image ratios, while split
  gives a two-page spread two equal-width full-height panes.
- **Current NextN tree:** `SettingsPage(READER) → SecondaryListScaffold →
  ReaderPresentationListItems → ReaderLayoutGroup`, shared unchanged by the
  routed Settings page and Reader-owned sheet. Its `ReaderDoublePagedFlow →
  ReaderSpreadSurface` already owns one transform/gesture surface around the
  paired pages, but always uses ratio-sized joined geometry.
- **Exact change boundary:** add the local default-joined preference through
  `NhReaderPresentation → ReaderPresentationState →
  ReaderSettingsRepository → ReaderPresentationService`; insert one
  no-prefix, no-subtitle value row between `双页模式` and `翻页动画` in the
  existing Layout group; and pass it only to `ReaderSpreadSurface`. `Split`
  may affect a currently active two-page spread only: it uses two equal-width
  full-height panes with the existing `ImageFit.Contain`; a final singleton
  keeps its current one-page geometry. Changing between joined and split
  resets that spread's existing local zoom/pan state rather than retaining an
  offset calculated for a different frame. Split pan bounds follow the two
  contained image extents rather than their letterboxed pane rectangles.
- **Explicit exclusions:** do not change the existing double-page switch,
  mode eligibility, wide-canvas fallback, `ReaderSpreadResolver`, fixed
  `[0,1] [2,3]` pairing, RTL row order, source/display mapping, progress,
  thumbnail, Slider, auto-read, volume keys, page-turn animation, prefetch,
  caches, download, translation, enhancement, or Reader-sheet parent tree.
  NextE's gallery-specific odd/even pairing and page-focused zoom/hit-testing
  are known separate differences. In particular, NextN retains its current
  whole-spread zoom and 50%-canvas double-tap target rule; this selector does
  not claim to make those behaviors equivalent.
- **Verification plan:** inspect the scoped diff and build the signed Debug
  HAP. On a real wide Reader canvas, verify the row appears in both existing
  Settings entry points; switch joined/split in LTR and RTL with differently
  proportioned pages; verify source index/progress, visual order, final
  singleton behavior, and cold-reopen persistence; then confirm a layout
  change while zoomed resets only the current spread transform. A same-state,
  same-viewport NextE capture remains required before any visual-parity claim;
  no UI static contract is permitted.

## OPEN — Reader page-turn animation preference — 2026-08-14

- **Why newly actionable:** the current NextE Reader has a default-on local
  page-turn-animation preference, while NextN has no equivalent preference and
  unconditionally asks its Swiper controller to animate every programmatic
  paged move. This is a Reader presentation capability; it does not affect
  gallery data, downloads, cache, translation, enhancement, or history.
- **Whole reference tree:** `ReaderSettingsPage → Layout
  GroupedListSection → page-turn animation switch → ReadMode state/settings →
  ReaderPage.shouldAnimateAdjacentTurn → SwiperController.changeIndex`. The
  reference animates only an adjacent Pager destination in a non-continuous
  mode. Its slider and thumbnail routes deliberately use their non-animated
  jump path; direct Swiper gestures retain their component-owned motion.
- **Current NextN tree:** `SettingsPage(READER) → SecondaryListScaffold →
  ReaderPresentationListItems → ReaderLayoutGroup`, while `ReaderPage` owns
  the shared `turnToReaderPage()` controller route for tap zones, volume keys,
  auto-read, Slider commits, and thumbnails. Before this change, it passed
  `true` to `SwiperController.changeIndex` for every paged route.
- **Exact change boundary:** add the default-on, device-local
  `pageTurnAnimation` preference through `NhReaderPresentation →
  ReaderPresentationState → ReaderSettingsRepository →
  ReaderPresentationService`; insert one no-prefix, no-subtitle switch after
  `双页模式` in the existing Layout group. `ReaderPresentationListItems` is
  already shared by the routed Settings page and the Reader-owned sheet, so
  the same row appears in both existing entry points without changing either
  parent tree or sheet interaction. Centralize the decision at the existing
  Reader turn entry: a non-continuous paged target may animate only when the
  preference is on and its displayed Pager index is adjacent to the current
  one. This uses existing source-to-display mapping so RTL and double-page
  spreads retain their current canonical navigation behavior.
- **Explicit exclusions:** continuous vertical scrolling remains unchanged;
  user Swipe motion remains owned by Swiper; Slider commits and thumbnail
  selection remain explicit non-animated jumps; no Reader mode, spread-layout,
  tap overlay, zoom, page/progress persistence, cache, Reader-sheet parent
  tree or interaction, image scaling, page-number, background, translation,
  enhancement, or frozen settings-group behavior may change.
- **Bounded component observation — 2026-08-14:** a temporary, non-visible
  Reader-only Hilog hook was armed only for the volume-key route, then removed
  from source after one foreground-confirmed paged LTR on/off run. A clean
  signed HAP was rebuilt and reinstalled in place without further Reader input.
  Its tag carried only
  fixed request/lifecycle stages, not gallery, page, title, URL, image,
  exception, or account data. With the preference enabled, one volume-down
  request recorded `request_animated → animation_start → change →
  animation_end`; with it disabled, one volume-up request recorded
  `request_instant → change` in its bounded filtered-log window. Both actions
  settled through the ordinary source-index/progress owner and the initial
  page was restored. The original continuous-vertical mode, enabled animation
  preference, and disabled volume-key preference were re-read after a
  NextN-only force-stop/cold start. This is component-event evidence for the
  adjacent volume-key subset only, not a visual-motion or full feature
  acceptance; no Reader canvas/menu/Back input was used.
- **Remaining verification:** the scoped diff and clean signed build are
  complete. The controlled component observation covers only the adjacent
  volume-key path. Without clearing data, a loaded multi-page Reader still
  needs on/off evidence for an adjacent tap or auto transition, a
  non-animated Slider/thumbnail jump, existing vertical and direct
  Swiper-swipe behavior, persistence after reopening, and the shared row in
  both existing Settings entry points. Preserve the current source of truth
  for visible index/progress and do not use the known-exception menu zone. A
  same-state, same-viewport NextE capture remains required before any
  visual-parity claim; no UI static contract is permitted.

## OPEN — Reader image-scaling quality preference — 2026-08-14

- **Why newly actionable:** static mapping after the user reopened Reader
  Settings found that NextN always relies on ArkUI Image's default sampling,
  while the current NextE Reader exposes a local low/medium/high sampling
  preference. This is a Reader rendering capability, not an NH API, download,
  cache, translation, or super-resolution capability.
- **Whole reference tree:** `ReaderSettingsPage → Display & screen
  GroupedListSection → Image scaling quality value-menu → ReadMode
  state/settings → ReaderPage → ReaderInterpolatedImage → ArkUI
  Image.interpolation`. The one final-image leaf is shared by the vertical,
  single-page, and double-page Reader render paths; navigation thumbnails are
  outside that tree.
- **Current NextN tree:** `SettingsPage(READER) → SecondaryListScaffold →
  ReaderPresentationListItems → ReaderDisplayGroup`, while `ReaderPage` owns
  two final-image leaves: `ReaderImagePage` for vertical/single-page modes and
  `ReaderSpreadImageLayer` below `ReaderSpreadSurface` for a two-page spread.
  Both currently call `Image(this.imageSource)` without an interpolation
  preference. The existing thumbnail rail is a separate navigation owner.
- **Exact change boundary:** add the default-medium local preference through
  `NhReaderPresentation → ReaderPresentationState →
  ReaderSettingsRepository → ReaderPresentationService`; add one no-prefix,
  no-subtitle value-menu before `显示页码`; and pass that value only to the two
  final-image leaves so each applies the same ArkUI interpolation mapping.
  It must preserve the existing source URI, local image cache, translated
  image artifact, super-resolution result, zoom state, gestures, spread
  pairing, and thumbnail rendering.
- **Explicit exclusions:** do not add the NextE explanatory subtitle; the
  user-directed NextN Reader settings rule is title plus current value only.
  Do not alter Reader groups, sheet ownership, pagination, page-turn animation,
  background color, spread layout, source/download/cache keys, translation,
  super-resolution, thumbnails, or frozen enhancement-height behavior.
- **Verification plan:** inspect the scoped diff and build the signed Debug
  HAP. Then, without clearing data, use one loaded static Reader page in
  vertical/single-page and wide double-page states to switch all three values;
  verify the preference restores after reopening, changes neither page index
  nor zoom/gesture ownership, and leaves the thumbnail rail untouched. A
  same-state, same-viewport NextE capture remains required before any visual
  parity claim; no UI static contract is permitted.

## OPEN — Reader hidden-chrome page-number preference — 2026-08-14

- **Why newly actionable:** after the user reopened the Reader Settings page
  for its missing and under-designed behavior, source mapping found that NextN
  already computes the canonical single-page and double-page range, but drops
  it whenever Reader chrome is hidden. NextE keeps this as an independent,
  default-on local display preference; it is not an NH website capability.
- **Whole reference tree:** `ReaderSettingsPage → Display & screen
  GroupedListSection → Show page number switch → ReadMode state/settings →
  ReaderPage(Stack) → hidden-chrome ReaderPageStatusOverlay`. The same overlay
  combines the optional page text with the existing enhancement status, is
  bottom-safe-area anchored, and has no hit-test ownership.
- **Current NextN tree:** `SettingsPage(READER) → SecondaryListScaffold →
  ReaderPresentationListItems → ReaderDisplayGroup`, while `ReaderPage` owns
  `visiblePageText()` and a hidden-chrome, enhancement-only persistent status
  overlay. There is no page-number preference, durable key, or hidden-chrome
  page-text leaf. Chrome-visible ReaderHeader already owns its existing page
  text and must remain unchanged.
- **Exact change boundary:** add one default-on, device-local
  `showPageNumber` preference through `NhReaderPresentation →
  ReaderPresentationState → ReaderSettingsRepository →
  ReaderPresentationService`; insert one no-prefix, no-subtitle switch before
  the existing fullscreen row; and turn the existing enhancement-only status
  overlay into one non-hit-test page-status overlay. It must reuse
  `visiblePageText()` so RTL and double-page ranges stay canonical, retain the
  existing bottom safe-area anchor and enhancement glyph, and render no second
  page label while chrome is visible.
- **Explicit exclusions:** do not change the six Reader settings groups,
  row-prefix rule, menus, Reader sheet owner, tap overlay, Reader canvas,
  progress persistence, cache, translation, page-turn behavior, or the frozen
  enhancement-height leaf. Do not add image scaling, background, animation,
  or spread-layout controls under this change.
- **Verification plan:** inspect the scoped diff and build the signed Debug
  HAP. Then, without clearing data, review the native Reader Settings switch
  and a loaded Reader with chrome hidden at the selected viewport; verify a
  single/single-page or double-page range is visible when on, absent when off,
  enhancement status still remains noninteractive, and the original setting
  is restored. A same-state NextE Reader capture is still required before any
  pixel-parity claim; no UI static contract is permitted.

## FROZEN — Gallery Detail public cache boundary — 2026-08-13

- **Why newly actionable:** the user reported that opening a Gallery Detail
  repeatedly feels like a full reload and asked for a durable detail cache
  that does not turn account, favorite, comment, related, or read-progress
  state into a single blob.
- **Root cause under audit:** `GalleryDetailPage.loadDetail()` still goes
  straight to `NhApiClient.detail()`, and `NhApiClient.detail()` always
  uses the default public NetworkKit GET path. That leaves no app-owned cache
  for the public detail DTO itself.
- **Whole affected tree:** `shared/network/NhApiClient.detail →
  feature/gallery/GalleryDetailPage.loadDetail/requestDetailRefresh →
  shared/model/NhGalleryDetail + LocalDataStore`.
- **Exact change:** add a narrow app-private cache for the public detail DTO
  only, with a bounded in-memory entry and an RDB row keyed by gallery id.
  Initial route loads may satisfy from cache; explicit refresh paths must
  bypass the HTTP cache and revalidate the current gallery directly. Public
  related/comment endpoints, favorite/account state, read progress, tag
  translations, and Settings UI stay on their existing owners.
- **Minimality and risk:** no visible hierarchy or copy change is intended.
  The page still owns its own load state; only the detail payload source is
  allowed to change. The only visible effect should be that reopening an
  already-seen gallery detail can reuse the stored DTO instead of painting a
  fresh network-only reload.
- **Verification plan:** build the signed Debug HAP, install in place without
  clearing data, open the same gallery detail twice on the selected device,
  and confirm the second entry uses the cache boundary while the explicit
  refresh path still bypasses it. Preserve raw device artifacts locally and do
  not use a UI static contract.
- **Runtime evidence boundary:** fixed diagnostics may report only
  `stored`, `hit=memory`, `hit=persisted`, or `bypass=explicit-refresh`.
  They never include gallery identity, titles, URLs, payload values, account
  state, or user content; the persisted-hit event is required for the
  cold-start proof instead of inferring cache use from timing.
- **Accepted device result — 2026-08-13:** after an in-place signed Debug
  install, a data-preserving NextN-only force-stop and cold start of the
  existing Detail route emitted `hit=persisted`, then settled to native loaded
  Gallery Detail at the `1320×2120` root viewport. The current semantic
  overflow `重新加载` action emitted `bypass=explicit-refresh`, then returned to
  the same native loaded Detail owner. These accept only public primary-DTO
  cache reuse and explicit-refresh bypass; they do not assert cache behavior
  for related galleries, comments, favorite/account state, tag labels, or
  read progress. Preserve the retained local evidence at
  `.hvigor/outputs/gallery-detail-cache-20260813T0645/`; do not revisit this
  boundary without new user feedback or a source change inside it.

## OPEN — Gallery Detail smart-grip Read-action alignment — 2026-08-13

- **Why newly actionable:** the user explicitly identified that NextN still
  lacks the existing NextE `智感握姿` capability. Current NextN keeps the
  Detail Read action fixed on the right; this is an omitted client capability,
  not an NH API or website limitation.
- **Whole reference tree:** `DETECT_GESTURE manifest declaration → EntryAbility
  restores the persisted alignment mode → MotionHandStateService is the sole
  resolver of a reactive left/right edge → Gallery Detail's existing full-width
  transparent floating Read rail`. The Layout settings row writes only the
  user-selected mode. Detail content reports only a verified scroll-like touch
  start to the resolver; the rail measures the existing intrinsic Read button
  and translates that one default-hit child between the two existing edges.
- **Current NextN tree:** `SettingsPage(LAYOUT) → BrowsePresentationGroup →
  Read-button-style row`; `GalleryDetailPage → DetailWorkspace(Stack) →
  transparent ReadFabRail → default-hit inner Row → existing Filled/HDS
  ReadFab`. The current rail is right-aligned and has no alignment state,
  sensor subscription, follow-operation touch owner, or unavailable-device
  branch.
- **Exact change:** preserve the current Detail stack, floating overlay,
  default-hit inner Row, HDS/Filled buttons, Reader route, right-side default,
  bottom reserve, compact/wide workspace, and frozen Read/Continue copy.
  Add only the reference-owned shared mode/state/resolver chain, its manifest
  declaration, a title-plus-current-value Layout row immediately before the
  existing Read-button-style row, and the measured Start-anchored rail
  translation. The setting does not add explanatory subtitle copy, a new
  grouping, or a runtime permission prompt. The adjacent `doc_plaintext`
  alignment icon and `paintbrush` style icon remain distinct reference leaves:
  they are same-level settings with different capability semantics, not a
  reason to split or normalize the group.
- **Mode and degradation boundary:** supported hardware offers `智感握姿`,
  `跟随操作`, `固定左侧`, and `固定右侧`. A failed holding-hand subscription
  keeps the existing right edge, hides `智感握姿`, and treats a previously
  stored smart-grip choice as `跟随操作`; it never blocks opening Reader.
  Follow-operation changes sides only once for a clearly vertical drag whose
  start lies outside the center safe zone. Its observation is attached only to
  the actual metadata List and wide-preview Grid, never to the floating rail
  or a workspace wrapper; it resets on lift/cancel or multi-touch. Fixed modes
  take effect immediately. Holding-hand subscription is active only while the
  UIAbility is foregrounded and is stopped with any pending debounce on
  background.
- **Affected visible states:** Layout row/menu before and after selecting a
  fixed edge; Detail's compact and wide workspace with the existing Filled and
  HDS buttons; a follow-operation left/right vertical scroll; cold-start
  restoration; and, only if the selected device actually supports the API, the
  delayed left/right holding-hand result. The existing right-side action state
  remains the control state, not a reason to re-audit the frozen Read copy.
- **Verification plan:** inspect the exact scoped diff, build a signed Debug
  HAP, install it in place on only `192.168.50.237:12345`, and retain raw local
  artifacts. Record the original alignment preference before any selection and
  restore it after verification. Compare the native NextN setting/rail against
  a same-viewport, same-mode NextE capture where available; do not use a UI
  static contract or manufacture sensor support. An unsupported-device result
  may accept only the documented follow-operation degradation, not smart-grip
  sensing itself.
- **Runtime device evidence — 2026-08-13:** commit `bee5a59` was built as a
  signed Debug HAP and installed in place on only
  `192.168.50.237:12345`; no data clear, uninstall, account action, or login
  action occurred. The original `智感握姿` selection was observed before the
  temporary fixed-edge and follow-operation checks. All retained captures are
  foreground-confirmed native NextN `EntryAbility/pages/Index` at the
  `1320×2120` root viewport. `固定左侧` moved the default-hit Read action to
  the left edge, `固定右侧` restored it to the right edge, and the transparent
  full-width rail remained an overlay in both states. In `跟随操作`, one
  vertically deliberate scroll beginning on the left side of the metadata
  List moved the action left; a subsequent right-side vertical scroll moved it
  right. The original `智感握姿` selection was restored, NextN alone was
  force-stopped, and the cold-started Layout row still reported `智感握姿`.
  Raw local evidence is retained under
  `.hvigor/outputs/smart-grip-alignment-20260813T0830/` and is excluded from
  Git.
- **Current device follow-up — 2026-08-13:** after the above result, the
  same selected device still shows the restored `智感握姿` layout row on
  cold-started Layout. This run did not induce or observe a real
  `holdingHandChanged` callback, so the sensor-triggered branch remains
  evidence-only and open; the fixed-edge, follow-operation, and preference
  restoration branches stay accepted and must not be re-proved without a new
  source change or user request.
- **State mapping clarification — 2026-08-13:** the adjacent
  `doc_plaintext` alignment icon and `paintbrush` style icon are same-level
  reference leaves with different semantics, not a signal to merge, reorder,
  or hide one of them. The accepted boundary here is the action-alignment
  leaf plus the button-style leaf remaining side by side in the Layout group.
- **Unaccepted boundary:** the device exposed the `智感握姿` menu option, but
  this run did not induce or observe a real `holdingHandChanged` event. The
  only retained NextE smart-grip captures are `1080×2444`, not this run's
  `1320×2120` viewport, so they are rejected as a visual comparison pair.
  Keep this record OPEN only for an actual sensor-event observation or a valid
  same-viewport reference pair; do not re-run the already evidenced fixed,
  follow-operation, or preference-restoration checks without a source change
  or new user feedback.

## FROZEN — Gallery Detail Japanese-title preference copy scope — 2026-08-13

- **Why newly actionable:** the user asked whether the `优先使用日文标题`
  setting is supported by NH and observed that its displayed scope is unclear.
  NH v2 already supplies both list `japanese_title` and Detail
  `title.japanese`; this is a local display preference, not a website write.
- **Reference/current scope:** NextE calls the matching preference
  `详情页优先显示日文标题` and applies it only to the Detail header's existing
  primary/secondary-title leaves. NextN does the same in
  `GalleryDetailPage`; collection cards deliberately retain their existing
  English-primary plus optional Japanese-secondary grammar. The current NextN
  copy instead says `画廊页`, which overstates that detail-only scope.
- **Exact change:** change only the four localized title/hint pairs to say
  `Gallery Detail` / `详情页` (and localized equivalents). Preserve the
  existing settings row, icon, switch, persistence key, startup restore,
  Detail title ordering, collection-card title leaves, History schema, and
  all network DTOs. Do not add a list-wide title preference or alter card
  geometry under cover of a copy correction.
- **Verification result — 2026-08-13:** commit `6965ae9` passed the four
  resource-JSON checks and signed Debug build, then was installed in place on
  only `192.168.50.237:12345`; no data clear, uninstall, account action, or
  login action occurred. The native `1320×2120` Layout row displayed the
  corrected Detail-only title and hint. Its original switch value was `off`.
  It was enabled only for this check; the current native Detail for the
  existing public route rendered the Japanese source title as primary and the
  English title as secondary, then the switch was restored and re-read as
  `off`. Raw local artifacts remain under
  `.hvigor/outputs/japanese-title-scope-20260813T0938/` and are excluded from
  source control.
- **Frozen boundary:** this accepts the copy scope and existing Detail-header
  behavior only. It does not claim a list-wide title preference, a History
  schema migration, or a collection-card title redesign; do not reopen those
  unrelated leaves without a new user direction or source change.

## OPEN — Browse Presentation Japanese-title icon distinction — 2026-08-14

- **Why newly actionable:** the user questioned whether repeated leading
  prefixes should be removed or split into different levels. Before this
  correction, the Browse Presentation tree had one semantic collision for
  review: the Detail-only Japanese-title switch and the Read-button alignment
  selector both used `sys.symbol.doc_plaintext`, despite different semantics.
  Other repeated symbols retain their separate leaf contexts and are outside
  this boundary. This reopens only the Japanese-title row's icon under the new
  user feedback; it does not reopen the frozen copy or behavior boundary above.
- **Whole reference tree:** `NextE LayoutSettingsPage → ListItem →
  GroupedListSection → view selector → conditional column-width leaf →
  fixed-height switch → cover-background switch → Japanese-title switch →
  home-tab switch → Read-button alignment selector → Read-button style
  selector`. The reference keeps every row in this section as a sibling with
  its existing divider and leading icon. Its Japanese-title row uses
  `sys.symbol.textformat`; Read-button alignment retains `doc_plaintext` and
  Read-button style retains `paintbrush`.
- **Current NextN tree:** `SettingsPage(LAYOUT) → SecondaryListScaffold →
  ListItem → BrowsePresentationGroup → NextNGroupedListSection → browse-mode
  selector → gallery-tag switch → translated-label switch → conditional
  column-width leaf → cover-background switch → Japanese-title switch →
  home-tab switch → Read-button alignment selector → Read-button style
  selector`. View/browse mode, conditional column width, cover background,
  Japanese title, home-tab behavior, alignment, and style are the seven
  semantically shared leaves. NextN additionally owns two tag-display leaves.
  At the time of this icon correction, NextE's fixed-height switch had no
  NextN equivalent; the later global LIST-height record below owns that
  separate capability. After those differing leaves, the
  five target rows—cover, Japanese title, home tab, alignment, and style—keep
  their shared relative order, switches/selectors, divider owner, and actions.
  Before this correction, only the Japanese-title row differed by using
  `doc_plaintext`.
- **Exact change:** replace only that row's leading symbol with the existing
  `sys.symbol.textformat` resource. Preserve its title, hint, switch,
  persistence key, Detail-only behavior, row order, divider, and all other
  Browse Presentation icons. Do not remove leading icons or split the sibling
  settings into new groups: icon presence is not hierarchy.
- **Verification plan:** inspect the one-leaf diff, build the signed Debug
  HAP, install it in place without clearing data, and inspect the native
  Layout/Browse Presentation group at its current viewport. A valid
  same-state, same-viewport NextE capture remains required before any visual
  parity claim; no UI static contract is permitted.
- **Current device observation — 2026-08-14:** the signed Debug HAP was
  installed in place on only `192.168.50.237:12345` after the live target,
  lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms` gate. No data clear,
  uninstall, account action, download action, or preference write occurred.
  The native `1320×2120` Layout/Browse Presentation group showed the
  Detail-only Japanese-title switch with the `Aa` text-format symbol; the
  Read-button alignment selector remained a document symbol and the
  Read-button style selector remained a paintbrush. This observes the one-leaf
  icon distinction only. A current same-state NextE capture was not obtained,
  so visual parity remains OPEN. Raw local artifacts are retained under
  `.hvigor/outputs/japanese-title-icon-20260814T.Hytu2E/` and excluded from
  source control.

## OPEN — Global LIST fixed-height toggle — 2026-08-14

- **Why newly actionable:** the user explicitly chose “全局生效”. The active
  Browse layout now needs one global LIST-height preference, not another
  source-specific override.
- **Whole reference tree:** `NextE LayoutSettingsPage → SecondaryListScaffold
  → ListItem → GroupedListSection → view selector → conditional column-width
  leaf → fixed-list-row-height switch → cover-background switch →
  Japanese-title switch → home-tab switch → Read-button alignment selector →
  Read-button style selector`. The reference keeps the height switch visible
  even when the selected view is not LIST; it is an orthogonal LIST-only
  preference.
- **Whole current tree:** `SettingsPage(LAYOUT) → SecondaryListScaffold →
  ListItem → BrowsePresentationGroup → NextNGroupedListSection → browse-mode
  selector → gallery-tag switch → translated-label switch → conditional
  column-width leaf → fixed-list-row-height switch → cover-background switch
  → Japanese-title switch → home-tab switch → Read-button alignment selector
  → Read-button style selector`. The two tag leaves remain NextN-specific;
  the new switch belongs after the conditional column-width leaf and before
  cover background. Its consumer tree is `GalleryCollectionBody →
  GalleryMediumCard`, shared by Home, Popular, Search, and Favorites whenever
  their effective presentation is `LIST`.
- **Current NextN state:** the LIST renderer is still the fixed
  `143×204` medium card by default. Home keeps its independent per-source
  presentation override, but that override only chooses the renderer and must
  not own this global height preference. Search, Popular, and Favorites all
  reach the same LIST card path through `GalleryCollectionBody`.
- **Exact change:** add one persisted global Browse-presentation boolean that
  defaults to the current fixed `143×204` behavior, surface the reference
  `rectangle_grid_1x2` switch with a title and state only (no explanatory
  subtitle), and make `GalleryMediumCard` choose a fixed or adaptive branch.
  Fixed mode preserves the current dimensions. Adaptive mode obtains the list
  content width from the existing list scaffold, gives the text column a
  cover-ratio minimum height, lets wrapped tags grow that column, and matches
  the cover slot to the settled content height before recalculating
  contain/cover fit.
  The setting is global across every LIST consumer but has no renderer effect
  on Simple List, grid, waterfall, compact waterfall, or cover wall.
- **Minimality rationale:** this is the narrowest change that makes the user
  choice global without touching source selection, non-LIST presentations, or
  request paths. It keeps existing installs visually unchanged until the user
  opts out of fixed height. Do not fold in the pre-existing cover corner-radius
  or cover-to-text-spacing differences from NextE; they are separate leaves.
- **Verification plan:** build the signed HAP, install in place without
  clearing data, first preserve the current Browse presentation values, then
  inspect the Settings switch and a loaded LIST card with tags disabled and
  with wrapped tags enabled. Toggle fixed → adaptive → fixed in the same
  loaded collection; cold-start and read back the saved value; then restore
  the prior presentation values. Cover Home, independent Popular, Search, and
  Favorites only when their effective renderer is LIST. A same-state,
  same-viewport reference capture is still required before any visual-parity
  claim.
- **Unresolved risk:** adaptive LIST height may change title wrapping and tag
  growth enough to expose layout edge cases on long titles or dense tag sets.
  Tags-disabled, Home/Search/Favorites effective-LIST, cover-loading, failed,
  absent, contained-extreme-ratio, and selected states remain OPEN.
- **Current device observation — 2026-08-14:** the signed Debug HAP was
  installed in place on only `192.168.50.237:12345` after the live target,
  lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms` gate. No data clear,
  uninstall, account action, download action, or content mutation occurred.
  Native Layout Settings placed `固定列表行高` after the conditional width leaf
  and before the cover-background leaf. The observed original values were
  enabled fixed height and `封面网格`; both were restored after the run.
- In a loaded native Popular collection temporarily switched to global LIST,
  fixed rows measured `612px` (`204vp` at this device density). With the
  switch off, the first two fully visible rows—including wrapped-tag content—
  each settled at `593px` with matching visible/original bounds; their cover
  slots stayed aligned with the content columns and did not reproduce the
  earlier viewport-height overflow. A NextN-only cold start read back the
  disabled value. The original fixed-height and cover-grid values were then
  restored, and a second NextN-only cold start read both back again.
- This accepts only the observed Settings placement/writeback/cold-start path.
  The Popular fixed/adaptive geometry is a current device observation; the
  visible LIST surface remains OPEN pending a valid same-state,
  same-viewport NextE comparison. Other global consumers, tags-disabled, and
  failure/cover edge cases also remain unaccepted. Raw local artifacts remain
  in `.hvigor/outputs/global-list-height-20260814T.postfix.lXkEmm/` and are
  excluded from source control.

## FROZEN — Cache and History tab icon visual-weight correction — 2026-08-13

- **Why newly actionable:** the user identified two current icon inconsistencies:
  the Reader-page-cache row used a solid folder while the corresponding cache
  leaf is a document, and the History root tab used an outline clock while the
  other root tabs use filled symbols.
- **Whole-parent boundary:** preserve `SettingsPage(CACHE) →
  SecondaryListScaffold → PrivateCacheGroup → NextNListRow` and the root
  `HdsTabs → MainTabIcon` owner exactly. These are leaf resource substitutions;
  no cache action, title, subtitle, state, route, tab order, padding, or icon
  geometry changes.
- **Reference/source evidence:** NextE's Page-cache `CacheRow` uses
  `sys.symbol.doc_text`. NextN's History tab has local-history rather than
  NextE's ranking semantics, so it retains a clock rather than copying NextE's
  ranked-list glyph; the local SDK confirms `sys.symbol.clock_fill` exists and
  restores the filled weight shared by the other four NextN tabs.
- **Exact change:** Reader-page-cache `folder_fill → doc_text`; History-tab
  `clock → clock_fill`. Build the signed Debug HAP, install in place without
  clearing data, and inspect only the cache row and root tab strip at the same
  native viewport. Retain raw local artifacts; do not use a UI static contract.
- **Verification result — 2026-08-13:** the signed Debug HAP built successfully
  and was installed in place on only `192.168.50.237:12345`; no data clear,
  uninstall, account action, cache-clear action, or content mutation occurred.
  The native `1320×2120` Cache page showed the Reader-page-cache document leaf
  inside its unchanged group. After a NextN-only data-preserving cold start,
  the root tab strip showed the History clock at the same filled visual weight
  as its sibling root tabs. Raw artifacts are retained under
  `.hvigor/outputs/icon-leaves-20260813T0958/` and are excluded from source
  control.
- **Frozen boundary:** no cache group, tab owner, title, action, preference,
  data, or layout behavior was changed. Do not treat either leaf correction as
  authorization to redesign Settings or the root tab bar.

## OPEN — Reader Settings parent-tree and icon correction — 2026-08-13

- **Why newly actionable:** the user reported that the current Reader Settings
  screen has repeated identical icons, one undifferentiated run of switches,
  and a missing divider. This reopens the earlier copy-only correction: removing
  explanatory subtitles did not restore the reference parent tree.
- **Faulty prior assumption:** commit `90cd161` treated the problem as prose
  density only. It preserved one `ReaderPresentationGroup` card and its
  invented leading icons, so it left page-turning, tap zones, display,
  enhancement, controls, and loading visually indistinguishable.
- **Whole reference tree:** `NextE ReaderSettingsPage →
  SecondaryListScaffold → [ListItem → Column(space XS) → SectionHeader →
  GroupedListSection]` repeated for `Layout`, `Tap zones`, `Display & screen`,
  `Image enhancement`, `Reading controls`, and `Loading`. Ordinary reference
  rows are title/value/switch rows; they do not add leading icons.
- **Current NextN tree before:** `SettingsPage(READER) →
  SecondaryListScaffold → one ListItem → one NextNGroupedListSection → every
  ReaderPresentation row`. The same local `rectangle_split_2x1` and
  `lightbulb` icons are repeated across unrelated rows; the enhancement-model
  selection and model-management rows lack their intervening divider.
- **Exact change:** introduce the matching NextN section-header leaf, split
  only the existing Reader rows into the six reference-owned grouped sections,
  remove their invented leading icons, and restore the one missing enhancement
  divider. Restore the reference down-arrow affordance on existing value-menu
  rows only; preserve every existing title, current value, menu, switch,
  enabled gate, persistence call, and Reader-sheet owner. The former separate
  comic-translation entry is superseded by the parent-owner correction below.
- **Minimality and risk:** no Reader setting is added, removed, or reinterpreted.
  The change affects only grouping and row prefix/divider leaves. The
  same-page device review must check all six groups, row ordering, values,
  disabled enhancement states, and absence of a translation-capability entry.
- **Verification plan:** inspect the exact diff, build the signed Debug HAP,
  install in place without clearing data, then perform one current native
  Reader Settings review on the selected device. Preserve raw artifacts and
  do not use a UI static contract.
- **Build result — 2026-08-13:** the signed Debug HAP builds successfully with
  the new section-header leaf and the six-group Reader Settings tree. This is
  compilation evidence only; the native layout review remains pending.
- **Pre-commit source review — 2026-08-13:** the seven existing value-menu
  rows still exposed generic navigation chevrons. The reference marks the
  same controls as dropdowns. This is an inherited leaf mismatch within the
  declared boundary, so the correction is limited to `trailingDropdown: true`
  on those rows; it changes no menu owner, value, or action.
- **Current-device whole-page observation — 2026-08-13:** the current signed
  Debug build was reviewed in place on only `192.168.50.237:12345`, without a
  data clear, uninstall, account action, or Reader-preference mutation. The
  native `1320×2120` Reader Settings page showed separate `翻页与布局`,
  `点击区域`, `显示与屏幕`, and `图像增强` surfaces on the first viewport, then
  the separate `阅读控制` and `加载` surfaces after one ordinary vertical scroll.
  Ordinary rows had no leading icon; value selectors showed a down-arrow,
  switches had no navigation arrow, and every adjacent pair inside the image
  enhancement group retained its divider. The raw local artifacts are under
  `.hvigor/outputs/reader-settings-current-20260813T0912/` and are excluded
  from Git.
- **Reference limit:** the retained NextE Reader Settings artifact that shares
  the `1320×2120` viewport is actually a Download page, so it is rejected as a
  same-state comparison. This current observation accepts the repaired NextN
  parent tree and its visible sibling regions; it does not claim pixel-level
  NextE visual parity. Do not reopen the six Reader groups or their no-prefix
  row rule without a source change, new user feedback, or a valid same-state
  reference pair.

### Parent-owner correction — 2026-08-13

- **New user evidence:** after the grouped Reader page was rendered, the user
  identified the remaining icon-bearing `漫画翻译` card as visually inconsistent
  with the six no-prefix Reader setting groups.
- **Faulty inference:** the earlier change treated a separate configuration
  destination as sufficient reason for it to remain at the end of Reader
  Settings. That conflated route destination with parent ownership.
- **Reference parent tree:** NextE keeps Reader Settings to Reader-specific
  groups. It places comment translation, comic translation, tag translation,
  and source management together in one translation-capabilities group under
  its site/advanced settings owner; comic translation uses the `picture` leaf,
  not the ordinary Reader-row grammar.
- **Exact correction:** remove the comic-translation ListItem from the Reader
  surface. In Advanced, place comment translation, comic translation, the
  existing tag-dictionary status/update leaves, and the existing shared
  translation-source destination in one translation-capabilities group. No
  translation source, model, dictionary, or persistence behavior changes.
- **Build result — 2026-08-13:** signed Debug compilation succeeded for commit
  `3b6f806`; this is compilation evidence only.
- **Current device/reference observation — 2026-08-13:** after an in-place
  install on the selected device, the native `1320×2120` Advanced page showed
  one continuous translation card in the order `评论翻译 → 漫画翻译 → 本地标签翻译
  → 更新 → 翻译来源`, with the expected capability icons and internal dividers.
  The current Reader tail showed only its Reader-specific Display, Image
  enhancement, Controls, and Loading groups—no translation entry. The retained
  same-viewport NextE `EH` reference at
  `.hvigor/outputs/translation-local-model-pack-20260811T0344/nexte-route-eh/`
  shows its corresponding continuous `评论翻译 → 漫画翻译 → 标签翻译 → LLM 源` card.
  The extra NextN `更新` row is the existing NH local-dictionary update leaf;
  it does not split the translation capability parent. These artifacts support
  this exact parent-owner correction only, not a whole-Settings acceptance.

## OPEN — Reader Settings scan-first copy — 2026-08-13

- **Why newly actionable:** the user explicitly reported that the current
  Reader Settings page treats ordinary choices as if each requires a teaching
  paragraph. The current native page shows a subtitle below every visible
  layout, control, cache, display, enhancement, and translation row.
- **Historical pre-correction tree:** `SettingsPage(READER) →
  SecondaryListScaffold → ReaderPresentationListItems →
  [ReaderPresentationGroup, ReaderComicTranslationGroup] →
  NextNGroupedListSection → NextNListRow`. The later parent-owner correction
  removes `ReaderComicTranslationGroup`; this copy-density record now applies
  only to the Reader-specific rows. It leaves the scaffold,
  section ownership, ordering, icons, menus, switches, accessibility labels,
  persistence, and destination actions unchanged.
- **Reference basis:** the corresponding NextE `ReaderSettingsPage` keeps its
  settings rows scan-first: title plus switch or current trailing value. Its
  optional subtitles are exceptional capability detail, not a paragraph under
  every ordinary row.
- **Exact change:** remove the explanatory `subtitle` from the Reader Settings
  rows. Each item continues to expose its selected value, switch state, or
  destination affordance. No setting value, feature behavior, model state,
  or translation configuration changes.
- **Minimality and risk:** this is a copy-density correction only. Removing a
  subtitle makes the list shorter; the post-build device check must confirm
  that rows remain individually legible and that no action or state label was
  lost.
- **Verification plan:** build, install in place without data clearing, route
  once to the native Reader Settings page, and retain a current same-viewport
  capture for whole-page review. No UI static contract will be used.
- **Build result — 2026-08-13:** the signed Debug build succeeded. Device
  review initially remained pending because the selected `192.168.50.237:12345`
  target was absent; no alternate target was used. It was then reconnected,
  woken with the required 24-hour timeout, and received the signed HAP in
  place without clearing data.
- **Current device observation — 2026-08-13:** the native `1320×2120` Reader
  Settings foreground displays one scanable line per row: title plus the
  active value, switch, or destination. The visible layout/control/cache and
  enhancement rows have no explanatory subtitle. The retained final layout
  and screenshot are in `.hvigor/outputs/reader-settings-copy-20260813/` and
  are excluded from Git. The attempted same-viewport NextE route reached its
  Download page rather than Reader Settings, so that capture pair is rejected
  and retained locally; it is not used for a comparison or claim. This
  remains a same-app device observation rather than whole-page reference
  parity.

## OPEN — Settings root browse/search ownership split — 2026-08-12

- **User evidence:** the user reopened the Settings root after reporting that
  its wording was arbitrary and unaligned. Current native NextN and NextE
  screenshots were captured on the selected device at the same `1320×2120`
  portrait root viewport and retained locally in
  `.hvigor/outputs/settings-root-audit-20260812T2338/`.
- **Whole reference tree:** `NextE Settings root → account card → one grouped
  main list → EH (site-specific) → Interface → Reading → Download → Search →
  History → Storage → Advanced → About`. Search is a distinct navigation
  owner, not text inside a combined catalog row.
- **Current NextN tree before:** `NextN Settings root → account card → one
  grouped main list → Interface → Browse & Search → Reading → Download → Cache
  → Advanced → About`. Its existing `catalogSettings` destination already
  owns four semantically separate local defaults: Browse language/order and
  Search language/order.
- **Exact, bounded change:** replace the one root `Browse & Search` entry and
  `catalogSettings` destination with adjacent existing-capability entries
  `Browse` and `Search`. Each owns one normal HDS destination, one existing
  pair of local defaults, its own root-selection state, and its own title.
  Preserve preference keys, menus, stored values, request behavior, cache,
  account state, reader/download/cache/advanced/about rows, and the root card
  grammar. Do not add EH, a duplicate History settings page, a storage/backup
  feature, or any new data source.
- **Minimality rationale:** this restores the actual Browse/Search ownership
  already present in NextN and removes the ambiguous combined label observed
  on the root. It does not use the reference's unavailable EH/history/storage
  leaves to fill visual space.
- **Verification plan:** build, install in place without clearing data, route
  once to the native Settings root, and review the whole root against the
  retained same-viewport NextE screenshot. Then open each new destination to
  verify that only its existing local controls are present. Keep the raw
  screenshots locally; do not use a UI static contract.
- **Unresolved risk:** the root card becomes one row taller. Acceptance depends
  on the actual floating-tab clearance and whole-page hierarchy, not on source
  shape or a synthetic layout match.
- **Device result — 2026-08-12:** the signed Debug HAP was installed in place
  on the selected device with no data clear. The native `1320×2120` Settings
  root now renders `Interface → Browse → Search → Reading → Download → Cache
  → Advanced → About`; its final row remains wholly above the floating root
  tab. The separate native Browse destination rendered only Browse language
  and Browse order; the separate Search destination rendered only Search
  language and Search order. No menu value, account, content, or cache action
  was invoked.
- **Reference boundary retained:** NextE still has EH, History, and Storage
  root owners that are not interchangeable with NextN's existing product
  surface. This change does not claim those capabilities or full Settings
  parity.
- **Status — FROZEN:** freeze this root Browse/Search ownership boundary. Do
  not re-audit or alter it without new user feedback or same-state
  counter-evidence.

## SUPERSEDED — Settings-root taxonomy and copy review — 2026-08-11

- **Why newly actionable:** the user explicitly reported that the Settings
  entry copy and hierarchy read as arbitrary despite an available NextE
  reference. History has now been isolated as a separate completed source
  change; this review covers the Settings root only and does not reopen that
  page or any frozen Settings destination.
- **Reference parent tree:** NextE owns `SettingsPage →
  SecondaryListScaffold → [Account ListItem, Main ListItem] →
  GroupedListSection → ConciseListRow`. Its root taxonomy is account, then
  EH (where supported), Layout, Reader, Download, Search, History, Cache,
  Advanced, and About; each row has one icon, title, and root-destination
  action.
- **Current NextN parent tree:** `SettingsPage(ROOT) →
  SecondaryListScaffold → [RootAccountSection ListItem, RootMainSection
  ListItem] → NextNGroupedListSection → NextNListRow`. Its explicit NH
  differences are no EH source, a root floating History tab rather than a
  duplicate Settings route, and a `Catalog` destination that combines the
  available NH browse/search preferences.
- **Review boundary:** verify, at one same-size portrait viewport, title
  hierarchy, row order, terminology, grouping, icon/action alignment, and
  the account-to-main-section transition. Preserve the existing source-owned
  NH boundaries unless current reference/device evidence proves a particular
  title, ordering, or grouping is wrong. No destination form or setting
  value is in scope.
- **Verification plan:** capture current native NextN and NextE Settings
  roots at the same root window dimensions, verify foreground identity for
  each, compare the whole root tree, and record either a concrete minimal
  correction or a no-change result. Raw captures stay local outside Git.
- **2026-08-11 device result:** both roots were captured as native
  `EntryAbility` foregrounds with the same `[0,117][1320,2120]` portrait root
  bounds. They share the HDS title, standalone account card, one grouped main
  card, icon/title/chevron row grammar, dividers, and floating root tabs.
  The NextN labels map directly to its actual owners: `浏览与搜索` covers its
  merged NH browse/search preferences; `历史记录` is already a root tab rather
  than a duplicate Settings destination; `缓存` represents NextN's private
  cache owner; and no EH row is rendered because NextN has no EH settings
  owner. No current reference/device evidence supports a copy, ordering, or
  grouping edit. The reference/implementation captures are retained locally
  in `.hvigor/outputs/settings-root-review-20260811/` and excluded from Git.
  That no-change conclusion is superseded by the user's later feedback and the
  2026-08-12 same-viewport evidence above: the combined Browse/Search owner
  concealed two already-separate NextN settings surfaces. It must not be used
  to reopen or revert the current split.

## EVIDENCE-ONLY — Reading History fixed-row metadata baseline — 2026-08-13

- **Why this boundary is newly actionable:** the user explicitly rejected the
  whole History surface after the compact-row change. The current native
  capture retained at `.hvigor/outputs/history-compact-20260813T0040/`
  exposes the concrete leaf defect: for a one-line title, the title and local
  metadata sit at the top of the 60×84 frame while the rest of the row is
  empty. The prior change removed the flexible information-column space and
  placed the footer immediately below the title; that was the faulty
  assumption.
- **Whole reference tree:** NextE owns `ViewedHistoryPage →
  PullRefreshListScaffold → ListItemGroup(day header) → ListItem →
  GallerySimpleCard`, with a fixed-height information column and footer
  baseline. NextN remains a root tab rather than NextE's secondary destination,
  so its root HDS, pinned-date bridge, and floating-tab reserve remain its
  explicit host boundary. ErosN's local-history `HistoryItem` confirms the
  valid narrower leaf data shape: an 84dp row with a 60dp cover, title, and
  local time; it does not justify fabricating remote gallery metadata.
- **Current NextN tree:** `HistoryPage → PullRefreshListScaffold →
  ListItemGroup → ListItem → HistoryListRow`. Its page-level scroll owner,
  local RDB cursor, pull refresh, pagination, confirmation deletion, day
  grouping, HDS pinned-date mirror, and one whole-row Gallery action are
  retained.
- **Exact change:** retain the 60×84 local cover frame and up-to-three-line
  title, but restore one flexible interval between the title and the existing
  progress/time row. This anchors local metadata to the fixed row bottom for
  both short and long titles. Divider, insets, actions, persistence, loading,
  and root-tab geometry do not change.
- **NH data boundary:** `NhReadingHistoryItem` has title, cover, page count,
  local read index, and viewed time. No uploader, rating, category, favourite,
  remote fetch, or stored field is added.
- **Verification plan:** build, install in place without clearing data, then
  capture the current native History foreground. Review the whole viewport:
  HDS, day headings, one-line and multiline row baselines, metadata legibility,
  divider rhythm, tail reserve, and floating root tabs. Retain raw local
  captures; do not reopen frozen Detail, Comments, or Settings surfaces.
- **Unresolved risk:** the retained reference and NextN histories contain
  different records, so runtime review can establish hierarchy and geometry,
  not text-for-text equality.
- **Current device observation — 2026-08-13:** the signed Debug HAP was
  installed in place on the selected `237` device without clearing data. The
  native `EntryAbility` History root remained at `1320×2120`. In the current
  one-line record, title bounds end at `y=532` while the local progress/time
  row ends with the 60×84 cover at `y=724`; multi-line rows retain their own
  corresponding bottom baseline. HDS, day headings, dividers, and the floating
  root tabs stayed in their existing owners. Raw local evidence is retained in
  `.hvigor/outputs/history-fixed-baseline-20260813T0530/` and is excluded from
  Git.
- **Evidence boundary:** this is an observed correction of the fixed-row
  metadata baseline only. There is no new same-host full-page NextE reference
  pair, so it does not assert complete History-page visual parity.

## OPEN — System screen-orientation policy — 2026-08-12

- **User outcome and source evidence:** NextN should retain the mature,
  NH-applicable system-orientation capability already owned by NextE. Current
  NextN exposes a separate tablet split-layout preference, but it deliberately
  never calls the main-window orientation API, so it cannot substitute for a
  system rotation policy.
- **Reference parent tree:** NextE owns `LayoutSettingsPage →
  PullRefreshListScaffold → [Appearance group, Screen-orientation group,
  Tablet-layout group]`. The orientation leaf is one concise menu row with
  `System default` and `Auto-rotate`; `EntryAbility` alone applies the chosen
  policy to the existing main window.
- **Current NextN parent tree:** `SettingsPage(LAYOUT) →
  SecondaryListScaffold → [AppearanceGroup, TabletLayoutGroup,
  BrowsePresentationGroup]`. `EntryAbility` already retains the main window,
  so it is the corresponding one-owner bridge. `TabletLayoutSettings` remains
  a geometry-only split policy and must not be repurposed to rotate the device.
- **Exact change:** insert a new grouped orientation row between the existing
  Appearance and Tablet-layout groups. Persist only `unspecified` or
  `autoRotationUnspecified`, bind an EntryAbility-owned applier after the main
  window exists, restore before content mounts, and call the official
  `setPreferredOrientation` API through that bridge. Default is system
  default; no reader/page-specific lock is added.
- **Reference and platform boundary:** the official HarmonyOS window guidance
  distinguishes startup manifest orientation from runtime
  `setPreferredOrientation`; this is the latter. The state must remain local,
  use no account/network/data mutation, and leave existing tablet split,
  theme, language, Reader fullscreen, and safe-area owners intact.
- **Verification plan:** build, install in place on the selected 237 device,
  observe both menu choices and the restored initial choice from the native
  Settings path, and retain raw local artifacts. Rotation may be device- and
  posture-dependent, so only an observed orientation transition is claimed;
  menu selection or command success alone is not treated as rotation proof.
- **Unresolved risk:** a portrait-held device may not visibly rotate after
  `Auto-rotate`; the value must therefore be restored even if the physical
  transition cannot be observed in this run.
- **Device result — 2026-08-12:** on the selected `237` device, the native
  Settings row initially rendered `System default`; its live menu showed
  exactly `System default` and `Auto-rotate`. Selecting `Auto-rotate` updated
  the native row to that exact value while NextN remained foreground. The
  captured root viewport remained `1320×2120` portrait, so the device did not
  supply an observed physical rotation in this posture. The row was then
  reopened through fresh live bounds and restored to `System default`, again
  with NextN foreground. Raw captures are retained locally under
  `.hvigor/outputs/screen-orientation-20260812T0240/` and are excluded from
  Git.
- **Status — EVIDENCE-ONLY:** the exact native selection and restoration path
  is observed; a same-state, same-viewport NextE reference capture is still
  absent, so this is not visual-reference acceptance and must not be reopened
  merely to repeat the same portrait selection sequence.
- **Reopened evidence — 2026-08-12:** a current `1320×2120` portrait NextE
  capture now provides the matching Interface-settings state with
  `Auto-rotate` selected. The new NextN row has the correct group/order/value
  but renders a navigation chevron, while the reference uses the standard
  menu down-triangle. The source owner confirms the distinction:
  `ConciseListRow.trailingDropdown` is used by every value menu in the
  reference Layout page.
- **Sibling boundary and exact correction:** review of the complete local
  Layout surface found the same action mismatch only on the seven value rows
  that open a `Menu`: theme, immersive material, language, gallery
  presentation, Read-button style, tablet layout, and screen orientation.
  Extend `NextNListRow` with the opt-in reference suffix and apply it to those
  seven rows only. Switch rows and the column-width navigation row retain
  their current owners; Reader, Advanced, and other Settings destinations are
  out of scope. The before/after is only
  `SuffixTextAndArrow` navigation chevron → text plus down-triangle menu
  indicator; menu values, persistence, and actions are unchanged.
- **Verification plan for this correction:** build and install in place,
  capture the same `Auto-rotate` Interface state against the retained matching
  NextE viewport, then restore `System default` before leaving the device.
- **Final device result — 2026-08-12:** the signed Debug HAP was installed
  in place on the selected 237 device. Current NextE and corrected NextN
  captures both had a `1320×2120` portrait root, native Interface settings,
  and the `Auto-rotate` value. The corrected NextN value rows now render the
  same text-plus-down-triangle menu affordance as the reference; the real
  NextN menu still opened and selected `Auto-rotate`. The existing value was
  then restored through a fresh menu to `System default`, with NextN still
  foreground. Raw captures remain local in
  `.hvigor/outputs/screen-orientation-reference-20260812T0247/` and are not
  committed.
- **Independent observed gap:** NextE's Appearance group also has a theme-color
  capability that current NextN does not expose. This correction neither
  treats that capability as accepted nor changes it; it requires a separate
  owner/data-path assessment before any future UI work.
- **FROZEN — Layout menu affordance:** do not revisit, recapture, or restyle
  these seven down-triangle menu rows without new user feedback, a source
  change in their shared component, or same-state counter-evidence. This
  freeze is limited to menu-vs-navigation signaling and does not imply that
  the entire Interface page or the separate theme-color capability is closed.

## OPEN — Global theme-color presets — 2026-08-12

- **User outcome and source evidence:** current same-viewport Interface
  comparison proves that NextE exposes a theme-color row within the Appearance
  group, while NextN has no corresponding state, preference, or visible leaf.
  This is not merely a swatch: NextE persists the choice, restores it before
  content mounts, and its shared brand-token getter recolors existing brand
  consumers. ErosN independently supports a dynamic/system color default plus
  named theme colors, so the capability is applicable to NextN rather than an
  EH-domain feature.
- **Reference parent tree:** `LayoutSettingsPage → Appearance group → [theme
  mode, theme color, immersive material, language]`. The theme-color row owns
  its color-dot suffix and one menu of named colors; selection persists and
  all `ThemeConstants.BRAND_PRIMARY` consumers read the reactive state.
- **Current NextN boundary:** `SettingsPage(LAYOUT) → AppearanceGroup → [theme
  mode, immersive material, language]`; `ThemeTokens.BRAND` is a fixed system
  resource used by existing global controls. `EntryAbility` already restores
  appearance preferences before first content, so it is the matching startup
  owner.
- **Exact first change:** add one `system` value to preserve the current
  platform accent by default, plus the seven named NextE presets. Persist only
  the normalized color identifier in the existing `nextn_appearance` store;
  make `ThemeTokens.BRAND` a reactive getter; insert the one reference-owned
  color-dot/dropdown row between theme mode and immersive material. Do not
  change any existing preference value during installation.
- **Explicit boundary:** the reference custom-color path depends on its full
  color-picker, favorites, and modal owner set. It is not represented as a
  disabled or partial menu item here. It remains a separate capability
  assessment after the preset path has real device evidence.
- **Verification plan:** signed build, in-place install on the selected device,
  temporary selection of the reference's Huawei-red preset to verify the row
  and an existing native brand surface update, then restore `system` and
  confirm the original state. Capture the matching reference/current roots;
  never infer global recoloring from a persisted value alone.
- **Risk:** wide reactive-brand reach is intentional but must remain confined
  to existing `ThemeTokens.BRAND` consumers; `BRAND_CONTAINER`, tag colors,
  favorite-category colors, and reader image overlays stay unchanged.
- **Device result — 2026-08-12:** the signed Debug HAP was installed in place
  on the selected 237 device. The native Interface page showed the inserted
  theme-color row in the Appearance group, with the system color dot and
  down-triangle suffix. Its menu showed the system option and the seven named
  presets. Selecting Huawei red updated both the row's dot/value and the
  existing selected root Settings tab to the same red accent. The value was
  then restored through the same native menu to Follow system; no account,
  Favorites, content, or other preference was touched. Raw screenshots and
  layouts are retained locally in
  `.hvigor/outputs/theme-color-20260812T0315/` and are excluded from Git.
- **Status — EVIDENCE-ONLY:** the exact NextN selection, global accent update,
  and restoration path are observed. This run did not retain a current
  same-state NextE reference root, so it does not establish visual-reference
  parity; do not repeat this selection sequence merely to produce another
  implementation capture.
- **Reopened by current same-state counter-evidence — 2026-08-12:** the
  retained fresh `1320×2120` NextE Interface capture now matches the red
  theme-color state. Its Appearance parent tree is the same four-row group,
  but its first leaf is `深色模式` / `Dark mode` / `ダークモード`, and the
  theme-color leaf has the source-owned `sys.symbol.paintbrush` prefix.
  NextN still renders `主题` / `Theme` / `テーマ` and
  `sys.symbol.paintpalette`. This reopens only those two reference-owned
  leaves despite the earlier Settings copy freeze.
- **Exact correction and limit:** replace the four `settings_theme` locale
  values with the current NextE values and replace only the theme-color row's
  prefix symbol with `paintbrush`. Preserve the Appearance parent tree, row
  order, trailing color-dot/dropdown owner, color identifiers, menu, default,
  persistence, and every other Settings string/icon. Rebuild, install in
  place, compare the current red reference to a new red NextN capture, then
  restore NextN to `system`.
- **Correction fault found before acceptance — 2026-08-12:** the first icon
  patch matched the first `paintpalette` occurrence in `SettingsPage`, which
  belongs to the root `settings_layout` route, not the Appearance theme-color
  row. The Interface capture therefore still showed the palette icon, while
  the root-route icon was unintentionally changed outside the declared
  boundary. Revert that root icon immediately and target the sibling whose
  title is exactly `settings_theme_color`. Prevention: icon edits must include
  their title/action context in the patch and be checked against the complete
  occurrence list before a build or device run.
- **Suffix alignment correction — 2026-08-12:** the current red same-viewport
  comparison showed the corrected NextN leaf still beginning slightly farther
  right than NextE. Source confirms the cause: the reference arrow has
  `{ left: 4, right: 12 }` padding inside the same `Row({ space: 4 })`, while
  NextN retained only the right padding. Add that missing 4vp left inset to
  the existing arrow only. Do not change the row, dot size, font, menu,
  color, persistence, or neighboring Settings leaves.
- **Final device evidence — 2026-08-12:** the signed Debug HAP was installed
  in place on the selected 237 device. Current NextE and NextN Interface
  captures share the `1320×2120` portrait viewport and the reviewed two-leaf
  state: `深色模式` with `跟随系统`, then `主题色` with Huawei red selected.
  The corrected NextN theme-color row renders the paintbrush prefix, red dot,
  value, and down-triangle suffix in the corresponding positions to the
  reference. Other visible Interface preference values were not made equal
  and are outside this two-leaf comparison. The temporary red value was
  restored through the native menu to `跟随系统`; the final layout remains
  native NextN. The local raw artifacts are retained outside Git in
  `.hvigor/outputs/theme-color-reference-20260812T0325/` and
  `.hvigor/outputs/theme-color-copy-20260812T0330/`.
- **FROZEN — Appearance theme-mode copy and theme-color leaf:** do not
  revisit, recapture, or alter these two leaves without new user feedback,
  a source change in their owner path, or same-state counter-evidence. This
  freeze covers the existing system/preset menu, color-dot suffix, and
  row-owned dropdown behavior only; it does not close a separately scoped
  custom-color capability.

## OPEN — Appearance custom theme color — 2026-08-12

- **Newly actionable evidence:** the frozen NextN theme-color leaf currently
  supports the system accent and seven named colors only. The complete NextE
  reference has one additional capability in the same menu: `Custom` opens a
  large modal color picker. Its picker owns grid, sliders, hexadecimal input,
  and persisted favorites; edits preview the accent live, closing reverts the
  prior accent, and confirmation is the only persistence point. This is a
  mature general appearance capability, not an EH-domain feature.
- **Whole reference tree:** `LayoutSettingsPage → Appearance grouped section
  → theme-color row → existing color menu → Custom item → large Sheet →
  AppModalScaffold → ListItem → AppColorPicker`. The picker is a contained
  card with its preview swatch, Grid/Sliders switch, color-grid or HSB
  sliders, Hex input, and favorites grid. The HDS modal title owns close and
  confirm actions.
- **Whole NextN tree before / after:** retain `SettingsPage(LAYOUT) →
  SecondaryListScaffold → AppearanceGroup → NextNGroupedListSection →
  NextNListRow(theme color) → Menu` and every existing system/preset item.
  Add only the final `Custom` menu item and the reference-shaped large sheet
  on that row. The sheet uses existing `NextNModalScaffold`; the new shared
  picker, favorite-color state, and persistence are its leaf owners.
- **Exact state boundary:** `ThemeColorSettings` accepts one normalized
  `#RRGGBB` custom value in addition to the frozen existing identifiers. A
  custom draft updates the reactive brand token without writing preferences;
  close restores the captured prior identifier; confirm writes the normalized
  custom value. Favorites persist separately and never alter the active
  accent merely by being restored.
- **Minimality:** no theme-mode, preset option, Appearance row order,
  color-dot suffix, default `system` behavior, or global brand consumer is
  changed. No new navigation destination, account, network, content, or
  download state is involved.
- **Verification plan:** build, install in place on the selected device, and
  compare the Custom menu item and picker at the same portrait viewport with
  NextE. Exercise one reversible draft preview and close to prove rollback,
  then one custom confirmation and app restart to prove restoration; finally
  restore the pre-run theme value. Retain raw captures locally outside Git.
  The frozen preset leaf is not recaptured or recomputed beyond the necessary
  common menu context.
- **Unresolved risk:** picker geometry, system-sheet behavior, preview reach,
  and preference restore are unproven until that exact device sequence.
- **Implementation evidence — 2026-08-12:** the complete reference-shaped
  picker/state boundary is implemented in source and signed Debug build
  succeeded. Commit `0321bbb` contains only this capability and its required
  ledger record. The selected target was absent before installation, so no
  alternate device, app install, screenshot, preference write, or visual
  claim was made. The verification plan above remains the next action.
- **Pre-device lifecycle correction — 2026-08-12:** the first source version
  used the sheet binding boolean to decide whether `onDisappear` should
  restore the prior accent. A swipe dismissal can clear that binding before
  the callback, leaving a live draft applied. The sheet now owns a distinct
  in-memory preview flag: all non-confirm close paths restore the captured
  original value exactly once; confirmation clears that flag before it writes
  the chosen custom value. This changes no picker geometry, menu item,
  persisted preset, or neighboring Appearance leaf. Signed build succeeded;
  the same selected-device rollback observation remains required.
- **Selected-device evidence — 2026-08-12:** on `192.168.50.237:12345`, the
  installed signed Debug build rendered the Custom menu item and the complete
  picker at `1320×2120`. One unconfirmed grid draft visibly changed the
  picker preview and its Hex value; the sheet close restored the original
  system theme. One confirmed custom value survived a force-stop/cold start
  without data clearing, after which the original system theme was restored
  and re-observed. No account, Favorites, gallery, download, or content
  mutation occurred. Local raw evidence is retained at
  `.hvigor/outputs/theme-color-custom-20260812T1645/` outside Git.
- **Route correction:** the first Custom navigation click selected the
  neighbouring existing `青草绿` preset. It was immediately reset to the
  pre-run `跟随系统` value; Custom was then selected from the current menu's
  explicit item bounds. This was a route-coordinate mistake, not a picker
  result, and it did not leave a temporary preference at the end of the run.
- **Valid reference pair — 2026-08-12:** after rejecting the initial unrelated
  NextE service-form foreground, a clean NextE restart reached its native
  Settings → Interface → Theme Color → Custom picker at the same `1320×2120`
  portrait viewport. It was compared with the retained current NextN Custom
  picker at the same root bounds. The HDS modal chrome, sheet inset, preview
  swatch, Grid/Sliders selector, color-grid bounds, Hex row, and favorites
  grid match. NextE's existing red selection and NextN's original system-blue
  seed are intentionally different values, not geometry or hierarchy
  differences. The NextE picker was closed without selecting or confirming a
  value, so its existing red theme remained unchanged.
- **FROZEN — Appearance custom theme color:** do not recapture, restyle,
  recompute, or alter this menu/picker/preview/persistence boundary without
  new user feedback, a source change inside its owner path, or same-state
  counter-evidence. The frozen boundary does not cover unrelated Appearance
  rows or a future new color-model capability.

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

## OPEN — Reader Real-ESRGAN x2plus model capability — 2026-08-12

### Installed-model selector projection repair — 2026-08-12

- **Why newly actionable:** current selected-device evidence disproved the
  existing state handoff: after the user-visible Real-ESRGAN download reached
  the installed/remove state in the normal model-manager destination, the
  existing Reader-settings model selector still rendered only the prior
  Waifu2x-art choice. This is a functional state mismatch, not a visual
  restyle or a request to revisit the frozen model-manager surface.
- **Parent-tree boundary:** preserve `SettingsPage(READER) →
  SecondaryListScaffold → ReaderPresentationGroup → NextNGroupedListSection
  → [enable, installed-model selector, model-manager, height policy]` and
  `Index → HdsNavDestination → ReaderSuperResolutionModelsPage →
  SecondaryListScaffold → NextNGroupedListSection → model rows`. The manager
  remains the exclusive owner of explicit downloads/removals; the selector
  remains the exclusive owner of choosing from already-installed models.
- **Exact before/after:** before, only the manager's local install list was
  refreshed after a successful file mutation, while the retained Settings
  destination held its previous installed-model array. After, a non-sensitive
  shared revision is published only after a successful install or completed
  removal; the Reader settings destination observes that revision and reloads
  its installed-model projection. No row order, label, geometry, menu shape,
  download policy, model preference, native runtime, or Reader canvas changes.
- **Risk and verification:** the existing selection fallback remains untouched:
  it applies only if the selected model is no longer installed. Build and
  install in place, then observe the existing normal route: the selector must
  list the installed Real-ESRGAN model, selecting it must update the existing
  selected-model row, and a later Reader run must remain a separately observed
  processing path. Raw evidence remains local and is not committed.
- **Device result — 2026-08-12:** after a signed in-place Debug install on the
  selected device, the existing native selector showed both installed choices.
  Selecting Real-ESRGAN updated the existing selected-model row, and the
  original Waifu2x-art value was restored through the same selector. The
  manager's files, Reader processing path, account, gallery data, and all
  other preferences were untouched. Freeze this projection boundary; model
  processing is a separate OPEN boundary.
- **Runtime observation — 2026-08-13:** on the selected device, the existing
  installed-model selector was changed from Waifu2x-art to Real-ESRGAN photo
  2×. The documented direct Gallery `471768` route then entered the native
  Reader overlay; its terminal overlay layout and locally retained screenshot
  showed the existing applied HD state. That state is emitted only after a
  nonempty private derivative has been promoted. The selector was restored to
  Waifu2x-art immediately afterward; no model file, account, gallery data, or
  other setting changed. This verifies one applied Real-ESRGAN run, not
  image-quality parity for other pages or a same-state reference comparison.

- **Why newly actionable:** the existing Waifu2x model boundary is frozen for
  its reviewed rows and ordering. NextE separately exposes Real-ESRGAN x2plus
  as a user-available private model, while current NextN already contains the
  matching ncnn native model kind and crop path but has no durable model ID,
  verified compatible-runtime pack, or selectable definition for it.
- **Reference and current parent tree:** retain the existing NextN tree
  `SettingsPage(READER) → SecondaryListScaffold → ReaderPresentationGroup →
  NextNGroupedListSection → [enable, installed-model selector, model-manager,
  height policy]` and the existing modal model manager
  `ReaderSuperResolutionModelsPage → NextNModalScaffold → ListItem →
  NextNGroupedListSection → model rows`. The new definition is one additional
  explicit-download row in the existing manager and appears in the existing
  selector only after installation. The Reader canvas remains outside this
  boundary.
- **Exact source/data change:** add only durable
  `REAL_ESRGAN_X2PLUS` preference normalization, its native kind-1 x2
  configuration, and the NextE-compatible private asset installer. The
  installer verifies immutable source param/model hashes, transforms the
  source PixelUnshuffle prelude to the Harmony ncnn-compatible Reorg graph,
  removes only the verified 40-byte source-model prelude, verifies both
  derived runtime hashes, and promotes only verified private files. Existing
  Waifu2x paths, defaults, selection behavior, and cache-key model identity
  remain unchanged.
- **Explicit exclusions:** no Reader canvas/chrome/gesture/layout change; no
  automatic download, background request, model removal, account action,
  gallery mutation, cache deletion, or CUNET/other internal NextE model is in
  scope. Download is still an explicit action on the model-manager row.
- **Verification plan:** build and install in place, then compare the current
  uninstalled model-manager state against the same NextE state at the same
  native viewport. Do not download the roughly 67 MB model merely to create
  visual evidence. A later explicit download needs separate runtime/hash and
  Reader-processing evidence before any processing claim.
- **Unresolved risk:** the compatibility transformation is required because
  the original Real-ESRGAN graph uses a dynamic PixelUnshuffle prelude not
  loadable by the Harmony ncnn runtime. A build establishes only source
  integration; it does not establish a device download or image-processing
  outcome.
- **Current device result — 2026-08-12:** the signed Debug HAP was installed
  in place on the selected device without clearing data. At the verified
  `1320×2120` native NextN viewport, the existing model manager retained its
  installed Waifu2x-art remove row and uninstalled Waifu2x-photo download row;
  the third Real-ESRGAN photo 2× row rendered as uninstalled with its own
  explicit download action. No model action, preference, account, content, or
  application-data mutation occurred. The current native screenshot remains
  local in `.hvigor/outputs/reader-realesrgan-model-uninstalled-20260812T/`.
- **Reference status:** the current NextE foreground was a different,
  configured service form rather than its model manager, so it is rejected as
  a comparison sample. No state was changed to manufacture a matching
  reference. The uninstalled-model manager is therefore device-observed but
  remains OPEN for a valid same-state NextE comparison; download and Reader
  processing are also OPEN.

### Parent-tree correction — 2026-08-12

- **Counter-evidence and faulty assumption:** a retained current NextE
  model-manager capture exposes the complete reference tree: one rounded
  grouped surface of detailed model rows, each with a neutral identity,
  scope/performance/size line, multi-line traits text, and a suffix-only
  circular download or delete affordance; a separate caption warns about
  tiling limits. The prior NextN implementation treated “three rows with an
  explicit action” as sufficient and used icon-prefixed, two-line generic
  rows with text actions. That ignored the reference's information hierarchy
  and made the large Real-ESRGAN capability appear like a small settings
  toggle rather than a locally managed model.
- **Exact correction:** preserve `ReaderSuperResolutionModelsPage →
  NextNModalScaffold/SecondaryListScaffold → ListItem →
  NextNGroupedListSection` and all install/remove/selection semantics. Within
  that existing parent, render the three model rows without the invented
  lightbulb prefix, with the reference-derived title/scope/performance/actual
  private-download size/traits hierarchy, up to six subtitle lines, and a
  custom circular suffix icon. Keep the risk text outside the grouped surface.
  The exact NextN ncnn-only file sizes remain authoritative rather than
  copying NextE's optional accelerator-inclusive totals.
- **Explicit exclusions:** do not change the frozen Reader settings leaf
  order, selector copy/state, model URLs, install/remove side effects, native
  runtime, Reader canvas, or download policy. This is the existing manager
  surface only.
- **Verification plan:** build and install in place, then obtain a fresh
  NextE model-manager foreground at the same viewport before comparing the
  matching installed/uninstalled rows. The retained NextE capture establishes
  the parent tree but is not a same-state acceptance sample. Do not download
  or remove a model to force a matching state.

### Observed surface correction — 2026-08-12

- **New current evidence and missed parent owner:** the committed current NextN
  manager was observed on the selected device at `1320×2120`, then reviewed
  beside the retained same-viewport NextE manager. The detailed rows and
  circular suffix actions now match the intended hierarchy, but NextN renders
  its modal content on the same white surface as `NextNGroupedListSection`.
  The group therefore loses its visible rounded boundary. NextE keeps the
  modal content on the semantic sub-background and its white grouped surface
  is visibly distinct. The earlier correction changed row leaves but failed
  to carry the reference's page-surface owner through the complete parent
  tree.
- **Exact correction:** add an opt-in `contentBackgroundColor` parameter to
  `NextNModalScaffold`, retaining its current default for every existing
  caller. `ReaderSuperResolutionModelsPage` alone supplies the existing
  app-level `surface` resource, while `NextNGroupedListSection` continues to
  own the white rounded group. No row geometry, copy, model state, action,
  runtime, or other modal is changed.
- **Verification plan:** rebuild, install in place, and recapture only this
  same model-manager state. Compare the visible page/background-to-group
  separation against the retained NextE capture; do not alter model files or
  settings to create a matching installed state.
- **First-result correction:** the first rebuild was installed and the same
  state was recaptured, but the visible result remained white. The new capture
  disproves the assumption that the outer `Stack` is the painted content
  owner: `HdsNavigation` contains a full-height `List` that remains above it.
  The next delta applies the already-scoped `contentBackgroundColor` to that
  inner List; no value, model row, action, or other page changes.
- **Second-result correction and exact owner:** the List-level color remains
  opaque because the model manager still supplies the app `surface` resource.
  The same NextE modal scaffold resolves its content background to transparent
  on API 26 so the system sheet material remains the page surface, while
  retaining the supplied solid fallback on older API levels. Add that exact
  behavior as an explicit opt-in on `NextNModalScaffold`, then enable it only
  for this manager. The grouped section continues to own the white rounded
  card. This changes neither the row hierarchy nor any model action, state,
  copy, geometry, or other modal; verification remains one fresh current
  model-manager capture beside the retained reference.
- **Host correction after route evidence:** that second correction targeted
  the wrong presentation. The current device route was the normal Settings
  destination, where `ReaderSuperResolutionModelsPage.modal` is false; the
  API-26 opt-in affects only the separate Reader-overlay sheet branch and
  therefore cannot change this capture. Remove that unsupported opt-in. The
  normal NextE page owns `HdsNavDestination → SecondaryListScaffold` and sets
  the semantic sub-background on the destination. NextN's corresponding
  owner is `Index.readerSuperResolutionModelsDestination`; add the same
  `ThemeTokens.SURFACE` there. The model page, list, rows, data, actions and
  the Reader-overlay sheet stay otherwise untouched. Rebuild, install in
  place and repeat only the already-established normal destination route for
  one fresh visual comparison.
- **Device result — 2026-08-12:** `9313044` was built and installed in place
  on the selected 237 device. The verified native NextN `EntryAbility` model
  manager route and retained NextE manager both used the same `1320×2120`
  portrait viewport. The revised NextN page background samples at the exposed
  left and lower content surface are `(241,243,245)`, exactly matching the
  retained NextE samples; the group remains a separate white surface. This
  accepts only the destination/background-to-group ownership correction. The
  reference and implementation have different installed-model states, so row
  content is not claimed as same-state visual parity and is not to be recaptured
  without a materially matching state or new feedback. Freeze this surface
  boundary; model download/removal and Reader processing remain separate OPEN
  capabilities.

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

## OPEN — Downloads startup-restore failure ownership — 2026-08-13

- Why newly actionable: source mapping found that `EntryAbility` performs the
  first durable queue restore, but its `Promise.all(...).finally(...)` still
  mounts the root when that restore rejects. The first `DownloadQueuePage`
  appearance then previously treated itself as uninitialized and invoked a
  second durable restore. Commit `422b533` prevents further retries after a
  page-owned failure, but does not cover this startup-owner-to-page handoff.
- Parent-tree boundary: `EntryAbility -> retained HdsTabs ->
  DownloadQueuePage -> existing PageLoadingState/PageErrorState or queue
  List`. This correction does not change the tab, HDS chrome, list owner,
  page-state tree, geometry, or any visible copy.
- Exact correction: `DownloadQueueService` retains only non-sensitive
  bootstrap attempted/pending/failed state while rethrowing the original
  startup error. A page observes a pending startup task without invoking its
  own restore, projects an already-restored queue, renders its existing
  `LOAD_FAILED` state for a known startup failure without another storage
  read, and retains its local bootstrap only where no startup result exists.
  The existing error Retry remains the sole durable retry. After a successful
  retry, this page resolves immediately; a later page appearance or recreated
  page projects the restored queue instead of preserving the old bootstrap
  error.
- Minimality and risk: no queue records, task/file state, worker scheduling,
  notification behavior, settings, or user-visible strings are changed. The
  special local-storage failure transition has not been induced on a device;
  source/build evidence alone must not be presented as runtime acceptance.

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
- **Source-proven recovery-completion correction — 2026-08-13:** the ordinary
  worker already publishes after its durable `COMPLETE` write, but `resume()`
  and the paused-worker reconciliation can independently discover that the
  already-promoted private file set is complete. Both persist that same new
  completion without publishing. Reuse the existing notification service only
  after each successful recovery write and only for a non-complete-to-complete
  transition. Keep cold-start `restoreInternal()` silent so retained completed
  tasks never re-emit, and do not change the settings tree, permission flow,
  notification content, task/file state, or network behavior.
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
- Newly actionable runtime-identity correction: the persistent comic-render
  pipeline already keys a rendered artifact by target language, bound source
  revision, and model, but this mounted Reader currently retains only
  `pageIndex → URI` and starts every request with `zh-CN`. Keep the same three
  existing image leaves, More-menu action, status overlay, and session auto
  scheduler; record a non-secret target/source-revision/model key beside each
  mounted URI instead. A URI, toggle, auto-settled result, failure marker, or
  status overlay is current only when that key still matches the active
  language and manga binding. A late request whose snapshot no longer matches
  must clear its running state without publishing an old result or poisoning
  the new runtime's automatic retry state. This does not clear private
  artifacts, alter the persistent cache protocol, or add a Reader setting.
- Verification boundary for that correction: inspect the exact source diff and
  build the signed HAP. A real source/language change during a configured
  translation remains EVIDENCE-ONLY until it can be observed without changing
  private source credentials or the established Reader canvas/chrome state.
- **Source-language correction — 2026-08-13:** the NH detail response already
  retains each canonical `language` tag, but Reader requests had unconditionally
  sent `auto`. This made a non-Japanese source select the wrong OCR/profile
  branch and record that incorrect source language in the existing document
  and rendered identities. Keep the same Reader canvas, More-menu action,
  image leaves, source binding, cache owners, and request timing. At the sole
  Reader request call site, choose the first raw `language`/`languages` tag
  whose value is neither empty nor `translated`; otherwise retain `auto`.
  Do not use translated display labels or extend Download/History persistence:
  a downloaded local detail without raw tags remains safely on the existing
  `auto` fallback. This changes no visible layout or copy. Build and exact
  diff review are the source boundary; an enabled Reader translation remains
  EVIDENCE-ONLY until a real configured source produces an output.
- **Source-only API-key identity correction — 2026-08-14:** replacing an
  OpenAI-compatible key previously wrote the HUKS value first while leaving
  the profile request identity unchanged. The comment cache, comic document/
  rendered cache, and process-local comic translator all key from the existing
  source revision, so a replacement could reuse old output and an in-memory
  translator that still held the old key. Keep the source form, consumer
  bindings, Reader canvas, comments UI, cache owners, and all diagnostics
  unchanged. Store only the SHA-256 of the vault-canonical key in the existing
  non-secret `accountIdentityHash` field before writing the replacement key;
  the existing repository then advances source revision. The resolver must
  re-resolve the binding after its vault read and reject a changed resolution
  or a key/hash mismatch. Thus a metadata-first interruption is fail-closed,
  while a completed replacement has a new revision and cannot address an old
  comment/comic cache or translator. Legacy empty hashes remain usable only
  for existing pre-identity records; a new typed key always records a hash.
  This changes no visible layout or copy. Exact diff review and a signed build
  are the source boundary; a real configured key replacement remains
  EVIDENCE-ONLY because no private source is configured on the selected device.
- **Source-only self-hosted identity correction — 2026-08-13:** the optional
  manga-rendering-service route previously keyed its long-lived orchestrator
  only by fixed protocol/profile plus the text source. Changing the selected
  endpoint, detection/inpainting JSON, or account could therefore retain an
  old backend; its durable rendered/document identities also kept the fixed
  protocol revision and described the result with the local renderer profile.
  Keep the existing Reader action, canvas, status overlay, source binding, and
  settings form unchanged. Give the allowed sidecar profile a full SHA-256
  suffix derived from the canonical endpoint and pinned sidecar JSON, so the
  existing document and rendered identities change without storing that raw
  configuration. Store only a monotonic credential generation alongside the
  protected credential record and use it as the existing durable region
  revision; credentials and their hashes remain process-local only. Select a
  dedicated self-hosted render profile, restore one canonical non-secret state
  before Reader actions are enabled, and use its local selection epoch solely
  to invalidate a mounted Reader's transient result. No endpoint, account,
  password, token, or credential fingerprint enters reactive UI state,
  persistent cache metadata, diagnostics, or the source tree. Exact diff
  review and a signed build are the source boundary; a configured sidecar run
  after changing its settings remains EVIDENCE-ONLY.
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
- Reopened on 2026-08-12 by materially different current evidence: the fresh
  native Detail layout at the current Read-action point contains both the
  floating Button and an underlying clickable tag leaf. The observed injected
  action remained on Detail, rather than taking the prior unrelated Settings
  terminal. Official ArkUI guidance confirms that `Transparent` allows masked
  siblings to participate in hit testing. Exact delta: restore only the
  already-mapped default-hit inner Row at `readFabOuterHeight()` under the
  transparent rail; leave the floating position, overlay geometry, reserve,
  HDS/filled choice, and callbacks untouched. The next evidence is one fresh
  same route/action after a data-preserving install; if it does not reach
  Reader, retain that result and remove this correction rather than retuning
  the floating surface.
- Result, 2026-08-12: the first injected point was above the actual button
  bounds, so it is recorded as a non-action rather than evidence against this
  change. A new current native layout then established the Button bounds and
  one center activation entered the NextN Reader overlay. This accepts only
  the interaction owner: the rail remains floating, its geometry and reserves
  are unchanged, and no additional hit-test or layout tuning is authorized.

## OPEN — Reader image information leaf, revised state boundary

- The first attempt is rejected: extending the Reader image event from three
  values to four coincided with a reproducible Reader foreground regression;
  the complete uncommitted branch was removed and the signed baseline remained
  foreground on the matched control run.
- Revised state boundary: keep the existing `pageIndex, processing, applied`
  event ABI unchanged. The existing enhancement service already owns request
  owners; it will retain only the current fixed result reason per owner, while
  Reader derives the same owner key that it already passes into the service.
  Reader will use that value only after its existing completion event.
- The visible parent tree and data boundary remain the already-mapped NextE
  `ReaderHeader → More Menu → Image information → alert` leaf. No canvas,
  toolbar, touch-zone, page, preference, private path, URL, or image-content
  change is allowed.
- Device check: one new-build current Reader path must remain native NextN
  through its existing processing settle before More is opened. Only then may
  the new Image information leaf be invoked once and compared against the
  reference dialog tree.
- **2026-08-12 control result:** the side-channel build was installed in place,
  then the already-established direct Gallery Reader action was activated once.
  After a twelve-second settle, the ability-manager mission state remained
  `com.erosteam.nextn` foreground. This accepts the ABI-preserving state
  boundary as free of the prior foreground regression. It does not yet accept
  the visible More-menu leaf or an enhancement outcome; the unchanged route
  will not be repeated merely to reconfirm this control.
- **2026-08-12 menu-route result:** the uncommitted menu leaf and its copy
  were removed after no Image-information action could be reached. A later
  focused boundary run established that `NextN root → direct Gallery →
  Continue/Reader` remains `nextn0` in WindowManager; the cross-app transition
  occurs only after the Reader menu-zone single tap, when the actual focus
  becomes `nexte0`. The NextN single-tap source path has no external-launch
  call. Do not recreate the leaf or repeat the menu-zone input until that
  focused-window transition is separately explained.
- **2026-08-12 focus-routing precondition:** the retained Reader was current
  native NextN at `1320×2120`, with its overlay mounted and Chrome hidden; the
  More control was consequently absent from the current native tree. The
  canvas menu zone depends on the persisted tap-layout and inversion settings,
  which were not exposed by that state. No canvas input was injected, so this
  observation neither repeats nor attributes the prior cross-app transition.
  A selected-device shell query then confirmed that the package-private reader
  settings RDB is not accessible through the device shell, so that is not a
  valid replacement for a native semantic setting read. No canvas input,
  preference, page, or content action occurred. Leave this leaf OPEN; select
  a different non-frozen boundary rather than trial menu-zone input.

## OPEN — Reader overlay root-title isolation — 2026-08-12

- **Why newly actionable:** a retained current NextN layout from
  `.hvigor/outputs/reader-image-info-20260812/reader-before-menu.json` proves
  two sibling navigation trees in the same `1320×2120` root. The Reader
  overlay navigation is mounted, but the underlying root `Navigation →
  NavDestination → TitleBar → HdsTitleBar → HdsMenuNode →
  hdsNavigationMoreButton` remains visible and clickable at the top right.
  The earlier menu-zone result therefore cannot be attributed to Reader's own
  More control and is not usable evidence for the Image-information leaf.
- **Whole tree before:** root `Stack → HdsNavigation(root stack, title bar,
  root destination)`, followed by `HdsNavigation(reader overlay stack,
  hideNavBar, Reader HdsNavDestination)`. The root title bar remains an
  independently hit-testable platform layer while the private Reader
  navigation is visible.
- **Exact minimal after:** retain both stacks, Reader destination, Reader
  canvas, Reader chrome, root route, and every action. Bind only the existing
  root HDS `hideTitleBar` property to `readerOverlay.visible`, so the root
  title/menu leaves leave the visible and hit-test tree for the exact lifetime
  of the Reader overlay and return automatically on close.
- **Reference/API basis:** the NextE parent tree also preserves a root stack
  below a private Reader overlay; it does not authorize a structural rewrite.
  HarmonyOS HDS documents `hideTitleBar(boolean, animated?)` as the supported
  title-bar visibility control. The NextN-only additional binding is required
  by the observed concurrently clickable root title leaf.
- **Verification plan:** signed in-place install on the selected device; one
  existing direct Detail-to-Reader route; retain one Reader layout and require
  the overlay navigation plus absence of the root HDS title/menu button before
  any Reader More action. Compare only after foreground identity and viewport
  are current. The retained older cross-app artifacts remain rejected and are
  not deleted.
- **Unresolved risk:** HDS dynamic title hiding may interact with the root
  scroll binding. The patch must be removed rather than widened if the root
  title fails to return after Reader close or if the Reader route no longer
  remains native NextN.
- **Counter-evidence and correction — 2026-08-12:** the first built,
  installed run retained native NextN Reader at `1320×2120`, but its current
  layout still contained the root `hdsNavigationMoreButton`. This disproves
  the faulty assumption that `HdsNavigation.hideTitleBar` controls an already
  mounted destination title bar. The actual owner is the retained Gallery
  `HdsNavDestination`, whose HDS title bar contains that button. The root
  binding is removed; the same boolean is bound only to
  `galleryDestination(...).hideTitleBar(readerOverlay.visible)`. No Reader
  canvas, overlay structure, floating action, menu, scroll binding, or
  unrelated destination is changed. The next device check is the same one
  direct route after installation; it must show the overlay with neither the
  Gallery title bar nor its More button, and must show the title again after
  Reader closes.
- **Corrected device result — 2026-08-12:** after the corrected build was
  installed in place, the same direct `471768` Detail route and one current
  Read action produced native NextN at `1320×2120` with the Reader overlay
  navigation present and no Gallery `TitleBar`, `HdsTitleBar`, or
  `hdsNavigationMoreButton` in the current layout. This observes the intended
  isolation during the overlay, not the Image-information menu itself. One
  established `uiInput keyEvent Back` then foregrounded
  `com.huawei.hmsapp.books` rather than retained NextN Detail. That terminal
  layout is retained at
  `.hvigor/outputs/reader-overlay-root-title-20260812T2204/nextn-detail-return.json`;
  it rejects the title-restoration half of this chain. Do not repeat Back or
  change title geometry from this result. The next boundary is source-backed
  Reader back-dispatch ownership, followed by a single state-specific return
  route only if that owner is corrected or independently proven.
- **Return-owner correction boundary — 2026-08-12:** the source comparison now
  isolates a complete parent-tree difference. NextE has
  `readerOverlayRouterMap → ReaderPage → HdsNavDestination → Reader canvas`
  and the page's own destination handles system Back before calling the shared
  overlay close. NextN currently has
  `readerOverlayRouterMap → Index.readerDestination → HdsNavDestination →
  ReaderPage → Reader canvas`; the canvas has no destination-level Back owner.
  The minimal correction moves this one existing `HdsNavDestination` wrapper,
  its `hideTitleBar`, shown/will-hide/disappear forwarding, and its existing
  Back callback into `ReaderPage`. Index continues to own the private overlay
  stack and its status-bar/close callback; Reader continues to invoke that
  callback and owns no root route or external launch. The canvas Stack,
  header, toolbar, touch zones, floating controls, page layout, preferences,
  and data paths are unchanged. Build, install in place, then make one new
  direct Reader run and one established Back only if the terminal Reader
  foreground is current. The required result is native NextN Detail with the
  Gallery title/menu restored; otherwise retain evidence and remove rather
  than widen this hierarchy correction.
- **Rejected correction result — 2026-08-12:** the built ownership migration
  reached native NextN Reader on the same direct route, but its one established
  Back event again foregrounded `com.huawei.hmsapp.books` rather than NextN
  Detail. It therefore does not establish destination ownership as the cause
  and is removed in full: `ReaderPage` returns to a canvas component and
  `Index.readerDestination` again owns the existing HDS destination, lifecycle,
  and close callback. The earlier verified Gallery-title isolation remains;
  this rejected hierarchy experiment authorizes no further Reader geometry,
  menu, canvas, or Back retries. The next source-only question is whether the
  selected device's `uiInput keyEvent Back` is delivered as a single Reader
  destination event at all; only an event-delivery observation may reopen a
  code correction.
- **Baseline restoration — 2026-08-12:** commit `e19b3eb` removes the rejected
  ownership migration in full and restores the previously observed title-isolation
  structure. After the selected `.237` device was re-resolved as Connected,
  leased, woken, and read back as `AWAKE` with
  `OverrideTimeout=86400000ms`, its signed Debug HAP was installed in place
  with `-r`. This records only installation of the restored baseline; no
  Reader route, Back event, account, preference, content, or data-clear action
  followed. The independent event-delivery question remains OPEN.
- **Independent menu-delivery observation — 2026-08-12:** the current Reader
  settings path was traversed without writing any value and read
  `left / menu / right` with `no inversion`. A fresh direct `471768` route
  then reached native NextN Reader with its private overlay navigation. The
  resulting center-zone action was therefore a source-defined MENU action,
  not a guessed page turn. Its terminal layout nevertheless foregrounded
  `com.huawei.hmsapp.books:MainAbility`. This reproduces the cross-app focus
  transition after the root-title isolation correction, but establishes no
  causal receiver inside NextN. The route is rejected after this one result:
  do not retry a canvas/menu/back input, alter Reader geometry, or recreate
  the Image-information leaf from it. The local evidence is retained under
  `.hvigor/outputs/reader-more-owner-20260812T2220/`; a future action needs a
  distinct platform event-delivery observation rather than another tap.
- **Read-only source/history forensic boundary — 2026-08-14:** the latest
  lifecycle-smoke Reader was foreground-confirmed native NextN, but one
  literal system Back ended with a `com.ohos.sceneboard` root. Current source
  maps a complete local close chain: `HdsNavDestination.onBackPressed →
  Index.closeReaderDestination → ReaderOverlayNavigationState.close → private
  stack pop → onWillHide/onDisAppear → finishClose`; neither that chain nor
  Reader exposes an external Want or link launch. Cause is therefore not
  established, and neither the previous destination-owner experiment nor a
  new close-semantic change is authorized. Do not retry Back, canvas input, or
  the Reader device route from this boundary. A future platform-level
  observation would need to prove that its capture mechanism can represent the
  relevant input/window transition before one bounded direct Reader route and
  one literal Back could be considered. Unsupported categories, a failed
  capture, or an absent record are inconclusive rather than evidence that Back
  was not delivered, because the earlier app-HiLog route-marker channel was
  itself rejected for missing markers. Retain this as OPEN until a distinct,
  independently proven platform observation is available.
- **Trace-control precondition — 2026-08-14:** the selected `.237` device's
  read-only `hitrace --list_categories` probe currently lists the official
  `multimodalinput`, `window`, and `ability` categories. Category availability
  does not establish that a trace will carry a usable input or foreground
  transition. Before the rejected Reader path can be considered, one
  non-Reader control may use an already foreground-confirmed native Gallery
  Detail with no Reader overlay, one bounded trace containing exactly those
  categories, and one literal Back. Its sole purpose is to determine whether
  this device/trace path can positively retain the ordinary system input and
  window/ability transition. It changes no application source, preference,
  account, content, Reader route, or canvas input. If that control lacks a
  positive relevant sequence, it is inconclusive and the Reader Back route
  remains prohibited; do not substitute a second control or a Reader retry.
- **Trace-control result — 2026-08-14:** the one bounded ordinary native
  Gallery Detail control retained a positive system sequence: the literal Back
  was injected, dispatched, consumed by NextN, and followed by Window/Ability
  activity, while the before/after roots remained native NextN. This proves
  only that this device/trace combination can represent one ordinary Back
  delivery; it does not prove a Reader close semantic or attribute the
  rejected SceneBoard terminal. It permits exactly one same-category Reader
  trace after a fresh native Reader precondition, with one literal Back and no
  other input. An absent or ambiguous Reader record remains inconclusive and
  permits no second Reader trace or source change.
- **Bounded Reader trace result — 2026-08-14:** the one permitted trace began
  only after a fresh native Reader precondition retained
  `reader-overlay-navigation`; it injected exactly one literal Back and
  completed manifest-owned trace cleanup/receive. Its local markers are
  temporally ordered as synthesized input, system dispatch, and an abbreviated
  NextN process-tag `eventConsume`, followed by Window/Ability activity. The
  synthetic and dispatch records carry no stable shared event identity, so the
  trace establishes temporal delivery evidence rather than a specific
  callback trace. The no-input postflight layout retained only
  `com.ohos.sceneboard` windows, not a foreground NextN root or Reader overlay.
  This rules out only the simple "Back never reached NextN" explanation; it
  neither proves which Reader/HDS close stage ran nor attributes why SceneBoard
  became foreground. The one Reader trace allowance is consumed: retain the
  raw ignored artifacts under
  `.hvigor/outputs/reader-back-platform-trace-20260814T0820.yCoWqs/`, make no
  source correction from this result, and do not inject a second Reader Back
  from this boundary.

## FROZEN — Reader enhancement input-height preference UI

- **User outcome:** the existing on-device enhancement must expose the same
  bounded image-size choice as NextE instead of silently fixing every request
  to its largest decode budget.
- **Reference parent tree:** `ReaderSettingsPage → HdsNavDestination →
  SecondaryListScaffold → ListItem → GroupedListSection`; inside the existing
  enhancement group, the enable switch is followed by model selection, model
  management, then a disabled-when-off `Maximum original image height` menu row offering
  `1000px`, `1500px`, and `2000px`.
- **Current NextN parent tree:** `SettingsPage(READER) →
  SecondaryListScaffold → ListItem → NextNGroupedListSection → NextNListRow`.
  It already owns the same enable/model/model-manager sequence, while
  `ReaderSuperResolutionService` passes a fixed `2000` maximum edge to the
  native decoder.
- **Exact change boundary:** persist only one normalized local choice from
  the three reference values; pass it to the already-existing native decoder;
  include it in the private derived-image cache identity; and insert one row
  after model management. It must be disabled when enhancement is off and may
  not alter model installation, Reader chrome, page navigation, source files,
  downloads, account state, or network behavior.
- **Verification plan:** build and install in place, compare the unchanged
  Reader-settings enhancement group against the same NextE viewport, then
  select no value during the initial visual review. A real altered-height
  enhancement result remains a separate Reader-runtime acceptance path.
- **Current same-viewport counter-evidence (2026-08-12):** the first NextN
  build placed the new row before model management because the source reading
  was treated as sufficient for leaf order. The current native NextE capture
  at `1320×2120` instead shows `enable → selected model → model management →
  maximum source height`; with enhancement off, the last row stays visible but
  disabled. Correct only the row position to follow that observed hierarchy.
  Preserve its copy, values, disabled predicate, menu, cache identity, and
  every other Reader setting.
- **Current device evidence (2026-08-12):** after the narrow reorder, a signed
  Debug HAP was installed in place on the selected device. At the same
  `1320×2120` portrait viewport, NextN shows model selection → model
  management → maximum source height with the existing `2000px` value. The
  selector menu shows only `1000px`, `1500px`, and `2000px`, with `2000px`
  selected; no option was chosen. The current NextE capture has enhancement
  off and therefore shows the same last row disabled. NextN's pre-existing
  enhancement preference was then temporarily disabled once: the row stayed
  in place and became disabled at the same value, then the original enabled
  state and `2000px` value were restored and independently captured. The
  input-height row's visible hierarchy, copy, values, disabled state, and
  restoration are accepted for this observed settings path. A processed
  altered-height image remains a separate Reader-runtime boundary.
- **Freeze rule:** do not revisit this settings group, re-open its menu, or
  change its geometry/order/copy without new user feedback, a source change in
  this boundary, or same-state counter-evidence. The separate enhancement
  processing path is not permission to modify this frozen settings surface.

## OPEN — Gallery Comments full-page hierarchy — 2026-08-12

- **Why newly actionable:** the user explicitly reopened the full Comments
  destination after observing that its current cards, bottom input area, and
  loading/scroll ownership are visually incoherent. A fresh selected-device
  observation reached native NextN Comments through the established
  `nextn_gallery_id=471768` + `nextn_gallery_destination=comments` route at
  `1320×2120`; the foreground was `com.erosteam.nextn`. The retained image
  shows full-width oversized cards and a flat footer composer rather than one
  page-level scroll/overlay composition. This is new device evidence for this
  boundary, not a reason to alter Gallery Detail, its comment peek, Related,
  or any other page.
- **Faulty prior assumption and impact:** the previous implementation treated
  `Column → list → footer composer` as equivalent to the reference page and
  tuned individual card padding inside that incorrect parent. It also omitted
  the reference-owned list header. That made the input surface a permanent
  page subdivision instead of a floating page child, distorted the visible
  card rhythm, and left the list tail without the compositor reserve. Do not
  repair this with isolated padding literals or another card-height heuristic.
- **Reference parent tree:** NextE owns `HdsNavDestination → Stack(bottom) →
  PullRefreshListScaffold(top reserve → CommentsHeader → one ListItem per
  GalleryCommentsCard → bottom reserve)`, with `CommentComposer` as the
  fixed sibling overlay. `CommentsHeader` is a page-content heading with the
  visible count; it is distinct from the HDS destination title. Each card is
  author header, body, and compact date/action footer with the same rounded
  card grammar. The reference's votes, replies, editing, scores, formatted
  spans, and inline-image leaves are not assumed available in NH.
- **Current NextN parent tree:** `Index.commentsDestination` already owns the
  HDS destination/title and `GalleryCommentsPage` currently owns
  `Column → state branch → PullRefreshListScaffold → CommentCard`, followed
  by a sibling footer composer. The page already has a snapshot-first route,
  one explicit reload action, pull refresh, content filtering, optional
  translation, and authenticated posting. Preserve those owners and their
  request/mutation semantics.
- **Exact correction boundary:** replace only the loaded Comments page host
  with the reference-shaped `Stack(bottom)` relationship. The list gets the
  page heading and a composer-height bottom reserve; the composer becomes a
  rounded overlay with symmetric outer/inner spacing. Rebase the existing NH
  comment card to the reference's supported author/body/date grammar and its
  ordinary card inset. Keep the existing empty/error state owners unchanged.
  Do not add EH actions or fields, change the HDS title/menu, alter Gallery
  Detail, change the comment request lifecycle, or submit a comment during
  review.
- **Verification plan:** build, install in place on the selected `.237`, and
  return through the same direct 471768 Comments route. Inspect the loaded
  native page alongside the retained `1320×2120` NextE Comments reference:
  heading/card hierarchy, body padding, list tail under the composer, overlay
  geometry, and the preserved direct-route loaded state. Retain raw local
  captures outside Git. This remains OPEN until that current comparison is
  recorded.
- **Prevention rule:** a visible parent-tree mismatch must be corrected at its
  scroll/overlay owner before any leaf geometry is changed. A user-reported
  Comments page defect never authorizes edits to Detail preview, Related,
  comment data, or an unrelated page.
- **Build and device result — 2026-08-12:** signed Debug build succeeded and
  was installed in place on the selected `.237` device without clearing data.
  The same direct Comments route for gallery `471768` foregrounded native
  `com.erosteam.nextn` at `1320×2120`. In its loaded state the HDS title is
  followed by the page-level `评论 (11)` header, each supported NH
  author/body/date record is its own rounded card, and the disabled composer
  is a rounded overlay rather than a full-width footer subdivision. One
  current-list upward swipe reached the final `nfsnowball` card; it remained
  fully above the overlay, with the list's terminal reserve below it. The
  floating HDS continued to cover transient scrolled content as intended and
  was not changed. Local evidence is retained at
  `.hvigor/outputs/gallery-comments-471768-20260812T1750/`.
- **Reference review — EVIDENCE-ONLY:** the retained NextE loaded Comments
  capture has the same `1320×2120` portrait viewport and confirms the page
  heading, individual-card, and bottom-overlay parent grammar. Its single
  EH record and action leaves differ from the current NH 11-record,
  signed-out surface, so this establishes the corrected hierarchy and tail
  behavior only; it does not claim content-level parity or invent EH action
  leaves. Reopen only for new user feedback, an actual change inside this
  boundary, or a current same-state counter-evidence.
- **Reopened correction — 2026-08-12:** the current loaded NextN device
  capture exposed an already-rejected duplication: HDS owns `评论` and the
  added page header rendered `评论 (11)` immediately below it. The faulty
  assumption was treating the NextE page-header leaf as transferable even
  though NextN's HDS title already supplies the same semantic heading. Remove
  only the duplicate page header; retain the list, card, overlay-composer,
  and tail-reserve ownership. The count is not moved elsewhere and does not
  justify a new title treatment.
- **Correction device result — 2026-08-12:** commit `dd842d5` was installed
  in place on the selected `.237` device with `install -r`, after the device
  gate read `AWAKE` and `OverrideTimeout=86400000ms`; no data was cleared.
  The same direct `471768` Comments route foregrounded native
  `com.erosteam.nextn` at `1320×2120`. The HDS now supplies the sole visible
  `评论` heading: the first rounded author/body/date card begins below it and
  no page-level `评论 (11)` header is present. The rounded composer remains a
  sibling overlay. This verifies only removal of the duplicate heading; the
  remaining page-level card, type, spacing, and composer review remains OPEN.
  Local evidence is retained at
  `.hvigor/outputs/gallery-comments-471768-20260812T2039/` and is excluded
  from Git.
- **Initial-load observation — 2026-08-12:** one data-preserving force-stop
  followed by the same direct Comments Want intentionally omitted a Detail
  snapshot. At the first captured native terminal state the page was already
  loaded, with the same HDS-only heading, card list, and composer overlay;
  this one run did not reproduce a pull-style or non-centred loading state.
  It neither proves nor disproves the no-snapshot request timing path. Do not
  repeat this unchanged route to manufacture a transient frame. Reopen only
  after a source change to the route/request owner or new current feedback.
- **Reopened card-inset correction — 2026-08-13:** new user feedback and the
  current native `471768` Comments capture both show that the full-page
  cards' author/body/date stack sits too close to the 24vp rounded corners.
  The preceding host/overlay correction remains intact: the defect is only
  the vertical leaf inset inside each supported NH card. The faulty
  assumption was carrying the generic 12vp top and 8vp bottom values into a
  visibly taller full-comments card. Change only the vertical inset to
  16vp top and 12vp bottom. Keep the existing 12vp horizontal inset, 24vp
  radius, body font/line height, translation action, composer, list spacing,
  loading, filtering, and posting owners unchanged. Build, install in place,
  and review the same direct native route once; no UI static contract. The
  2026-08-13 build and in-place install succeeded. The direct route was
  started, but its one terminal capture was rejected by the host execution
  policy before a device result could be recorded; this correction remains
  OPEN and unaccepted.
  Local evidence is retained at
  `.hvigor/outputs/gallery-comments-initial-load-20260812T2041/`.

## OPEN — Gallery Detail compact rail proportion repair — 2026-08-12

- **New user feedback and current evidence:** the user reopened the compact
  Detail rails because their proportions had drifted through unrelated-looking
  one-value adjustments. The retained current native `471768` lower Detail
  capture shows three independent leaves: 150vp page previews, Related cards
  with 190vp covers plus 80vp titles, and 240×120 comment-preview cards.
  The current Related cards remain readable but their total visual weight is
  disproportionate to the compact preview; the comment cards are compressed
  below their supported author/date/body presentation.
- **Reference and NH boundary:** ErosN's compact Detail owns distinct leaves:
  `ThumbListView` is a 200-high page rail, `MoreLikeListView` is 280 high with
  an aspect cover and 80-high title, and `CommentsListView` is a 190-high rail
  of 280-wide padded cards. NextN's compact preview has a different,
  user-reviewed 150vp page-rail role and remains frozen at that height. Its
  Related endpoint and NH comment DTO retain the corresponding cover/title and
  author/body/date leaves; no EH avatar, vote, reply, or network behavior is
  added.
- **Exact minimal correction:** leave the compact preview's 150vp height,
  header, all-pages action, tile aspect, and head/tail rail margins unchanged.
  Set the Related cover exactly to the existing 175vp Detail-hero cover height
  while retaining its 80vp title, and restore the external comment preview to
  280×190 with the existing 12vp padding and current type values. Preserve
  the full-bleed horizontal viewport, headings, routing callbacks, list order,
  and floating Read overlay.
- **Faulty assumption and prevention:** prior edits treated these three
  independent leaves as one "compactness" knob: preview was raised then
  reverted, Related cover was assigned an arbitrary 190vp value, and comment
  cards were reduced from their complete-card scale to 120vp. Never couple
  their geometry again. A future change must identify which leaf, its data
  affordance, and its reference parent owns the requested adjustment.
- **Verification plan:** build and install in place on the selected `.237`,
  launch only the existing numeric Detail route, and review the three rails in
  one current native Detail path. Retain raw captures locally. The prior
  second-swipe terminal reached Settings rather than the Detail comment rail;
  that route is rejected and must not be reused as a layout sample.
- **Current device observation (not visual-reference acceptance):** the signed
  Debug HAP was installed in place on `192.168.50.237:12345` after the device
  gate read `AWAKE` with `OverrideTimeout=86400000ms`. The current native
  `471768` Detail route reached Preview, Related, and the external comment
  preview after the one established upward list swipe. The captured result
  keeps the short page-preview rail distinct from Related; Related exposes a
  cover plus its separate multi-line title leaf; comment-preview cards now
  show author/date/body at the intended complete-card scale. The floating Read
  overlay was not changed. Evidence is retained locally at
  `.hvigor/outputs/gallery-detail-rail-proportions-20260812T2107/`.
- **Unresolved boundary:** no current same-state, same-viewport reference
  capture exists for this exact gallery and loaded Related/comment content.
  This observation therefore verifies only the installed NextN result, not
  full visual-reference parity. Do not reopen the frozen 150vp Preview geometry
  or change these three leaf values without new user feedback or a valid
  counter-evidence pair.

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

### Raw-versus-translated label preference correction — 2026-08-13

- **Why newly actionable:** the user reported that tag translation appears
  ineffective. Source review establishes that NextN currently conflates two
  separate choices: whether supported collection cards render tags at all and
  whether a resolved tag uses its canonical raw name or its optional local
  dictionary label. ErosN exposes the latter as an independent persisted
  display preference; NextN's existing dictionary display is already separate
  from its Advanced dictionary download/status owner.
- **Reference and current parent boundary:** ErosN keeps `showTags`, tag
  layout, and `isTagTranslate` as adjacent List Style leaves; its tag chips
  and Detail chips select translated text only while that preference is on.
  NextN retains `SettingsPage(LAYOUT) -> SecondaryListScaffold ->
  BrowsePresentationGroup -> NextNGroupedListSection`. Its existing
  `showGalleryTags` leaf controls only the three existing `GalleryTagStrip`
  card leaves, while Gallery Detail owns its already-grouped metadata tags.
- **Exact change:** add one persisted Browse-presentation boolean for showing
  translated tag labels. Place its title-plus-switch row directly after
  `显示画廊标签`; it changes only `GalleryTagStrip` text and Gallery Detail
  tag-member text between existing raw names and already-resolved dictionary
  labels. No card/detail parent tree, tag visibility rule, catalog/API request,
  local dictionary update, cache write, search query, routing, or tag ordering
  changes.
- **Compatibility rule:** ErosN initially defaults its independent display
  preference off, but existing NextN already displays dictionary labels when
  available. An absent key must therefore restore as on so an installed user
  does not silently lose the current translated-label presentation on upgrade;
  an explicit saved choice always wins.
- **Verification plan:** inspect the exact diff, build the signed Debug HAP,
  install it in place without clearing data, and use a current Detail tag set
  that has a dictionary label distinct from its raw name to observe the two
  label states while restoring the original preference. The collection card
  leaf remains separately open for a same-state ErosN comparison; no
  dictionary update or tag-data mutation is manufactured for this preference
  check.
- **Current evidence:** signed Debug build succeeded and was installed in
  place. On the selected device the new Layout row restored on by default,
  switched off, and was restored on. The initial Detail sample contained only
  raw-fallback/equal labels despite the existing local dictionary being ready,
  so it was not used to claim a substitution. Current Browse captures taken
  after the off state and after restoration show matching visible card
  identities with their affected chips respectively using canonical raw labels
  and existing local dictionary labels. This establishes the persisted
  collection-card display choice after route return; it does not claim an
  in-place, no-navigation repaint of one mounted list. No dictionary update or
  tag-data mutation was used. A same-state ErosN visual comparison and an
  in-place reactivity capture remain separately OPEN.

### Global tag presentation and effective dictionary lookup correction — 2026-08-15

- **Why reopened and corrected again:** the user reported that the prior tag
  treatment was still ineffective and then identified a concrete visual
  regression: the attempted correction put a generic, wrapping tag strip into
  every SIMPLE_LIST row and exposed a global wrap/single-line setting. That
  was an unsupported generalization. It treated four different reference card
  trees as one leaf, enlarged a compact fixed-height row, and used a 24vp
  detail-style chip where the corresponding NextE list chip is not 24vp.
  The first device sample therefore is **rejected**, not acceptance evidence:
  it showed the over-tall SIMPLE_LIST tags; original Browse presentation was
  restored and the raw layout artifacts were deleted.
- **Prevention rule:** before changing a tag leaf, map the complete parent
  tree for every active card mode. A shared data lookup may be reused, but a
  shared visual strip must not be introduced unless each reference tree uses
  the same scroll owner, line budget, chip geometry, and clipping contract.
  A user-wide visibility preference does not imply that every card grammar
  gains a tag leaf.
- **Proven cause:** public NH collapses common attributes to `tag` and some
  classifications to `category`, while the installed dictionary retains
  `female/male/mixed/other` and `reclass`; exact `type` lookup therefore
  misses those labels and silently falls back to raw text. A cross-namespace
  result may be ambiguous, so it must not choose a gender-specific translation
  by row order.
- **Corrected reference boundary:** keep `GalleryCollectionBody` and every
  collection scaffold unchanged. The exact card trees are distinct:
  `SIMPLE_LIST → GalleryListItem → Row(72×102 cover, fixed 102vp information
  column, metadata)` stays tag-free, matching NextE's compact simple row;
  `LIST → GalleryMediumCard → fixed/adaptive information column → bounded,
  eight-item tag middle region` retains its leaf; `WATERFALL →
  GalleryWaterfallCard → metadata → title → optional NH secondary title →
  horizontal two-row tag scroll` gets its own fixed 48vp / eight-item leaf;
  and `WATERFALL_COMPACT → GalleryWaterfallCompactCard → clipped cover Stack →
  bottom gradient → one-row tag scroll → title` gets its own fixed 24vp /
  eight-item text leaf. `COVER_GRID` and `COVER_WALL` remain tag-free.
  There is no global tag-layout setting. An absent tag-visibility preference
  defaults to visible for the supported tag-bearing modes, while an explicit
  saved off choice still wins.
- **Geometry contract:** normal LIST tags use NextE's neutral filled caption
  chip geometry (12vp, horizontal 6vp, vertical 3vp, radius 6vp, max width
  160vp) inside the existing bounded region. Regular Waterfall uses the same
  neutral NH fallback but max width 150vp and two 4vp-spaced rows. Compact
  Waterfall uses bare 12vp normal white text, no chip padding/background,
  max width 150vp, 4vp gaps and no extra strip inset. It contains no compact
  page-count line, preserving the reference overlay budget. NH has no safe
  per-tag colour/action data, so neutral light chips and plain compact text
  are the only justified leaf substitutions.
- **Dictionary rule:** exact namespace wins. Only unresolved `tag` checks
  `female/male/mixed/other`, and only unresolved `category` checks `reclass`.
  A fallback is accepted only if every found candidate has one identical
  display label; otherwise the raw public name remains visible. This changes
  no query, remote request, catalog policy, cache schema, or Detail namespace
  group.
- **Verification status:** only the lookup rule and the rejected bad sample
  have been observed so far. After the corrected implementation is reviewed
  and built, device acceptance remains OPEN for a current same-viewport
  NextN/NextE comparison of LIST, regular Waterfall, and compact Waterfall,
  plus one existing dictionary label whose raw and translated forms differ.
  SIMPLE_LIST must instead be checked for its unchanged fixed 102vp/no-tag
  grammar. Dictionary download remains user-triggered; no automatic startup
  fetch or fabricated data mutation is permitted.

### Reactivity and catalog-resilience correction — 2026-08-13

- **Why newly actionable:** the user reported that enabling the existing tag
  display can appear intermittent and that an updated tag dictionary does not
  change tags already visible in a Gallery or collection. Source tracing
  establishes two independent data-projection failures inside the already
  accepted tag-leaf boundary.
- **Causal boundary:** all public collection endpoints return only `tag_ids`.
  `NhTagCatalogService` resolves names before the page receives its snapshot,
  but previously discarded successfully fetched names when private catalog
  persistence or its subsequent cache read failed. Separately,
  `TagTranslationRepository.replace` and `clear` change the dictionary RDB
  without publishing a display revision; collection cards retain their old
  `NhTag.displayName`, and Gallery Detail retains its one-time local
  `tagTranslationLabels` projection.
- **Whole parent tree preserved:** `GalleryCollectionBody` remains the sole
  collection/scaffold owner and keeps the existing Medium/List, Waterfall, and
  Compact Waterfall tag leaves. Gallery Detail retains its existing grouped
  metadata tag owner. SIMPLE_LIST, COVER_GRID, COVER_WALL, related-gallery
  cards, card geometry, filters, routes, API pagination, and the existing
  default-off display switch remain outside this correction.
- **Exact change:** retain a fetched public tag in the current in-memory
  catalog even if its optional durable-cache write or reread fails. Publish a
  non-sensitive dictionary display revision only after a successful committed
  replacement or clear. Existing mounted collections re-label only their
  already-resolved nested tags from the local dictionary and reapply their
  existing filter projection; Gallery Detail re-labels only its current raw
  tags. These paths make no gallery/detail request, no `/tags/ids` request,
  no raw-ID fallback, and no change to tag ordering or card layout.
- **Verification plan:** inspect the exact diff, build the signed Debug HAP,
  install in place without clearing data, and review one current native tag
  presentation through the existing opt-in route while restoring its prior
  presentation preference afterward. A real dictionary replacement/clear is a
  user-data mutation and is not manufactured solely for visual evidence; that
  particular revision transition remains explicitly unaccepted until it is
  observed through an ordinary permitted update or cache-clear action.
- **Unresolved risk:** a list that originally has no resolved names because
  every catalog request failed cannot invent them from a dictionary revision;
  it remains unchanged until its ordinary next list request. This correction
  removes the proven loss of names already returned by the public endpoint and
  the proven stale-label path only.
- **Response and suggestion race correction:** review of the first source
  change found two remaining stale-display paths. A collection request can
  begin under one dictionary revision, receive already-enriched cards, then
  land after a committed replacement while the revision monitor is still
  re-labeling its former snapshot. Each accepted page-one or appended response
  now compares its request-start revision to the current revision and invokes
  the same strictly local re-label projection only when they differ. Search
  also clears and epochs-fences visible tag suggestions on a committed
  revision. This is necessary because dictionary replacement can change a
  suggestion's membership and ranking, not merely its label; retaining it and
  rewriting its text would still show removed or stale candidates. The next
  ordinary edit repopulates suggestions through the established flow. The
  correction does not restart a gallery request, call tag autocomplete, change
  the query, or change any collection/card parent tree. This closes the
  source-proven arrival race while preserving the existing unresolved-name and
  no-manufactured-dictionary-mutation limits above.
- **Build and current-device observation — 2026-08-13:** commits `73e504f`
  and `b9efa27` built as the signed Debug HAP and were installed in place on
  the selected `.237` device after the awake / `86400000ms` gate. The
  documented native numeric Detail route for the existing verification gallery
  settled to `com.erosteam.nextn:EntryAbility`, `pages/Index`, at the
  `1320×2120` root viewport. Its existing grouped Detail tag leaf remained
  mounted with resolved-name chips; no dictionary replace/clear, tag update,
  account action, gallery mutation, or preference write was performed. The
  retained terminal layout/screen are
  `.hvigor/outputs/tag-reactivity-20260813T1100/` and are excluded from Git.
  This is installation/current-leaf evidence only. It does not accept the
  deliberately uninduced dictionary-revision transition, or broaden the
  frozen presentation scope.

### Passive Detail tag-catalog learning — 2026-08-14

- **Why newly actionable:** an NH v2 collection provides only `tag_ids`, while
  a successfully parsed Detail response already provides the complete public
  canonical tag records. NextN previously discarded that Detail-side catalog knowledge,
  so a later collection still depended on another `/tags/ids` response and
  could omit the same tags during a transient lookup failure. ErosN passively
  learns verified Detail tags into its local NH catalog on this exact boundary.
- **Exact data boundary:** after `NhApiClient.detail` has successfully parsed a
  public Detail DTO, queue a best-effort copy of only its `id/type/name/count`
  tags through the existing serialized `NhTagCatalogService` and a private
  fallback-only catalog insert. An allowed transport-cached Detail response
  must never overwrite a catalog item already learned from a later collection
  response. The next collection keeps a Detail fallback renderable but treats
  it as unresolved and may promote only an actual `/tags/ids` result to an
  ordinary catalog record. Do not await it from Detail, start a request,
  change the Detail/cache/collection parent tree, re-render the current
  collection, alter a tag preference, or persist display translations. A
  catalog write failure leaves the parsed Detail response unchanged.
- **Preserved unresolved boundary:** this does not invent a retry/status UI,
  turn a missing current list tag into a raw id, or select a TTL/forced
  revalidation policy for an already cached canonical tag. Those are separate
  data-policy decisions and remain OPEN until independently evidenced.
- **Verification limit:** exact diff review and a signed build establish only
  the source path. Proving a later list uses an earlier Detail-learned tag
  requires an ordinary same-device Detail → collection sequence; no network
  failure or tag-data mutation is manufactured for this correction.

### Tag-catalog transport-cache freshness correction — 2026-08-14

- **Why newly actionable:** the fallback provenance correction makes a later
  collection ask `/api/v2/tags/ids` again, but that endpoint still inherited
  NetworkKit's process-local transport cache. A cached response could
  therefore be promoted to an ordinary catalog record and receive a new local
  `updated_at` value without a fresh transport observation.
- **Exact data boundary:** only the existing `tagsByIds` call now passes
  `allowTransportCache=false` through the existing bare-array JSON helper.
  Popular and every other bare-array endpoint retain their existing cache
  policy. The change starts no extra request, changes no batch size, and
  preserves the existing serialized catalog read → request → merge → upsert
  owner, fallback names, partial-response behavior, and non-fatal failure
  handling.
- **Preserved unresolved boundary:** this establishes only that an already
  needed catalog request bypasses this process's transport cache. It does not
  choose a TTL, periodically revalidate ordinary catalog rows, bypass an
  upstream cache, add retry/status UI, or alter a card/detail tree. The policy
  for when a normal positive-timestamp catalog row should be rechecked remains
  OPEN pending separate evidence.
- **Verification limit:** exact diff review and a signed build can establish
  the request option path. A live network inspection is required to observe a
  particular request; no tag mutation, rate-limit condition, or failure is
  manufactured for this narrow correction.

### Accepted explicit-Detail tag-catalog promotion — 2026-08-14

- **Why newly actionable:** a Detail request made by the existing title reload
  or top-pull path already bypasses both the app Detail snapshot and
  NetworkKit's process-local transport cache. It returns complete public tag
  records, but NextN previously kept every Detail result at fallback-only
  provenance, even after the page had accepted that explicit refresh.
- **Exact data boundary:** ordinary Detail requests still queue only the
  fallback `INSERT ... DO NOTHING` path. Once `GalleryDetailPage` has passed
  its current generation and gallery-ID checks for a `forceNetwork` response,
  it queues that response's copied public tags through the existing serialized
  catalog owner for its normal upsert. The promotion remains best-effort and
  cannot delay, replace, or fail the Detail UI. A stale route response can at
  most leave its existing non-overwriting fallback; it cannot promote.
- **Reference boundary:** ErosN's Detail refresh bypasses its HTTP cache and
  then uses the same passive catalog-learning path as its ordinary Detail.
  NextN retains the stronger local route-acceptance gate because its network
  client otherwise receives a Detail result before the page can reject an old
  generation.
- **Preserved unresolved boundary:** this establishes only an accepted Detail
  response that bypassed this process's transport cache as a normal catalog
  observation. It does not assert server/CDN freshness, pick a TTL, revalidate
  arbitrary existing catalog rows, add a list request, retry/status UI, or
  change a Detail/card parent tree.
- **Verification limit:** exact diff review and a signed build establish the
  gated source path. Observing an actual title reload or top-pull response and
  a later ordinary collection is required to accept the runtime data outcome;
  no tag-data mutation or forced failure is manufactured for that evidence.

### Dictionary update-source fallback — 2026-08-13

- **Why newly actionable:** the existing explicit local-dictionary update
  requested exactly one GitHub release asset. A direct transport, redirect,
  rate-limit, or availability failure ended the operation before parsing or
  the already-transactional replacement path, leaving the user with the prior
  dictionary and one generic update error.
- **Exact bounded change:** retain the existing direct GitHub asset as the
  first source and retry the identical public release asset through the
  existing NextE mirror only when that direct download fails. Each attempt
  retains the current streaming size limits, private `.part` cleanup, strict
  gzip/JSON parsing, and all-or-nothing RDB replacement. No settings row,
  copy, automatic update, catalog request, card/layout, dictionary contents,
  or displayed-tag preference changes.
- **Source and data boundary:** the mirror is an availability fallback, not a
  new authority for dictionary semantics. The committed dictionary remains
  untouched until the selected artifact passes the existing parser and RDB
  transaction. If both sources fail, the previous dictionary remains active;
  the user-visible Settings error remains the current generic safe message and
  does not expose URLs, server bodies, or response details.
- **Verification limit:** build and exact-diff review can verify the new
  fallback path compiles. A real direct-source failure followed by mirror
  success is not manufactured solely for evidence; that branch remains
  EVIDENCE-ONLY until an ordinary explicit dictionary update reaches it.
- **Follow-up version boundary — 2026-08-13:** before a non-forced update,
  read only the fixed direct-or-mirror Release metadata. Its bounded
  `tag_name`, `published_at`, and SHA-256 key can skip gzip only when the
  preceding import matched that metadata's fixed `db.raw.json.gz` byte count
  and SHA-256. If a metadata source or fixed asset lags a persisted verified
  nonempty Release, NextN retains the known dictionary rather than replacing it
  with an unverifiable or older payload; a metadata/asset mismatch is not
  saved as a verified Release version.
  Metadata never supplies an asset URL; a mismatched fixed asset tries the
  next source and never changes the committed RDB. When metadata is unavailable,
  legacy `bytes-*` state still uses the fixed-asset fallback; a persisted
  verified Release accepts only an asset with its existing SHA-256. The first
  successful legacy import still downloads once before later same-Release
  updates can skip. This changes no Settings surface, automatic scheduling,
  dictionary data, or card rendering.
- **Failure-explanation boundary — 2026-08-13:** a bounded public metadata
  probe observed direct GitHub `403` rate limiting and mirror `403` rejection;
  current Settings discards terminal dictionary-update phase/source/status and
  renders the same generic failure note for every outcome. Metadata failure is
  deliberately not terminal because the fixed dictionary asset may still
  succeed. Preserve the existing Advanced translation-capabilities card and
  its existing `GroupNote` error position. Replace only a terminal failure's
  error text with a localized, bounded phase/source/status summary derived from
  a structured service failure; no URL, response body, raw exception, new row,
  action, automatic update, or layout change is allowed. Build and exact-diff
  review verify the source boundary. The rendered failure note remains
  EVIDENCE-ONLY until an ordinary explicit update naturally reaches a terminal
  error state; no dictionary mutation is manufactured for it.
  A private file-system failure is terminal for this action and must not consume
  the mirror retry; after a successful dictionary transaction, return the
  known committed status instead of performing a second fallible status read.

## OPEN — Reader enhancement interaction yield

- User outcome: local Reader super-resolution must never compete with a
  foreground reading gesture or the existing Reader settings sheet.
- Reference and current parent tree: both apps keep one full Reader canvas
  with content first, a transparent tap surface, and conditional overlay
  chrome. NextE binds the canvas touch lifecycle to its existing
  super-resolution service. NextN now does the equivalent through its Reader
  owner.
- Implemented source boundary: `ReaderPage` owns transient pause/resume state
  and timers, forwards foreground down/move/up/cancel plus settings
  open/close to `ReaderSuperResolutionService.setInteractionPaused`, and the
  service forwards to the existing native pause owner. The implementation is
  recorded in `02bd60a`; do not duplicate it with a second interaction path.
  Page data sources, List/Swiper ownership, image leaves, tap-zone semantics,
  chrome geometry, settings contents, model storage, and network behavior are
  unchanged.
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
  that evidence remains OPEN. The source reconciliation above is not a reason
  to repeat this unchanged device route; reopen it only for a new enabled,
  stable Reader interaction state.

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
- New device counterevidence, 2026-08-11: the current signed build entered
  native NextN Detail through the existing numeric Gallery direct route, then
  its one current `Continue` action left no NextN Reader foreground; the
  terminal foreground was NextE. A source-limited experiment deferred
  enhancement until the original Image `onComplete`, but the same route still
  terminated outside NextN. That uncommitted experiment was removed
  immediately. The next diagnosis must not revisit Reader chrome, layout,
  settings, queueing, decode size, or source-file ordering; it must distinguish
  the remaining PixelMap input/lifetime boundary. The retained local evidence
  is outside Git at `.hvigor/outputs/reader-enhancement-runtime-20260811T1253/`.
- Follow-up classification: the current NextN `Image enhancement` preference
  was observed disabled without changing it. A temporary build bypassed only
  the local completed-download URI and used the existing public Reader cache
  source; the same direct route still terminated outside NextN. That source
  branch was removed immediately. The open failure therefore cannot be
  attributed to the disabled enhancement branch or local-download source
  selection. The next diagnostic must isolate Reader route mount versus its
  baseline rendered-image lifecycle; no Reader UI surface is reopened.
- **Current baseline result — 2026-08-12:** after the temporary branches were
  removed and the current signed Debug HAP was installed, one documented
  numeric Gallery route and one freshly resolved native `Continue` activation
  stayed in `com.erosteam.nextn` Reader after an eight-second settle. The
  terminal native canvas is retained locally in
  `.hvigor/outputs/reader-baseline-20260812T0355/`. This disproves the prior
  claim that the unchanged Detail-to-Reader route itself currently leaves
  NextN. No enhancement setting, model, page, account, or content data was
  changed. It does not prove an enhanced derivative or image-quality parity;
  without a newly reproducible failure or a result-state boundary, no further
  enhancement-runtime patch is justified.
- **Result-state correction — 2026-08-12:** a later fresh native `Continue`
  activation was initially read as still being on Detail because the retained
  Detail tree, including its `Continue` leaf, remains beneath the transparent
  Reader overlay. The terminal layout also contains the foreground
  `reader-overlay-navigation` and Reader canvas; the associated screenshot
  shows the current Reader's green applied-state HD leaf. This is a real
  current-page derivative result, not a route failure. It accepts neither
  image-quality parity nor any broader model/page class. The raw capture is
  retained locally at
  `.hvigor/outputs/reader-enhancement-result-20260812T0429/`; no Reader source
  or visible UI value changed from this observation.
- **Reference discovery — 2026-08-12:** one current NextE foreground capture
  was collected only to establish a valid quality-comparison precondition. It
  is not Reader state and its root viewport is `2120×1320`, whereas the NextN
  applied-result capture is native Reader at `1320×2120`. The pair is retained
  locally and rejected, not compared. No setting, content state, orientation,
  source, or UI value was changed to manufacture equivalence. A real current
  same-state/same-viewport reference remains the sole next verification
  boundary.
- **Restoration:** the retained NextN Reader foreground was restored after the
  rejected reference discovery. Its root again reports the original
  `1320×2120` viewport and Reader overlay; no preference, content, account,
  or Reader action changed in the restoration.
- **Runtime-owner reconciliation — 2026-08-12:** the former ArkTS
  `ImageSource → PixelMap` path is no longer current: `bae0e94` moved decode
  to `ReaderNativeSuperResolution.decodeImageRgba`, where every async task
  owns its fd, native image source, native pixel map, and releases them before
  completion. The native inference bridge already serializes its shared ncnn
  state with `gInferenceMutex`. The earlier ArkTS-wide queue was built and
  rejected before this replacement; restoring it now would repeat an
  inapplicable fix without evidence of a shared native-image resource. The
  current applied-result observation remains the only accepted runtime result;
  the sole remaining enhancement boundary is a valid same-state/same-viewport
  quality comparison, not another decode, queue, or Reader-route rewrite.
- **Source-only derivative-cache identity correction — 2026-08-13:** the
  current private derivative name uses only model id, source-height policy,
  and source bytes. A future model asset/config or native output-pipeline
  change could therefore reuse an old rendered image. Include the existing
  immutable model contract and one output-pipeline revision in a hashed cache
  identity only. Do not delete or migrate existing files, add a setting/model,
  alter the Reader canvas, or change download policy; old derivatives simply
  stop matching and age out under the existing cache limit. Exact-diff review
  and signed build establish this source boundary; a future enabled Reader run
  is required for runtime evidence.
- **Source-only derivative-file race correction — 2026-08-14:** a forced
  Reader source retry can atomically replace its private source file after the
  enhancement service derives the content-addressed output key but before
  native decode completes. Recheck the source hash immediately after decode;
  a mismatch or failed recheck falls back to the original rather than
  promoting decoded bytes under an earlier key. Also preserve a `.part` file
  whenever its exact final derivative path still has an in-flight owner, so
  one completed derivative's cache prune cannot unlink another task's output
  while it packs or promotes. This changes only private service failure and
  cleanup behavior: no Reader UI, source/cache identity, model, download,
  route, setting, or cache-retention policy changes. Exact-diff review and a
  signed build establish this source boundary; a real forced-retry plus
  concurrent-enhancement observation remains OPEN.

## OPEN — Optional self-hosted staged manga translation

- User outcome: make NextE's mature self-hosted `manga-translator-ui` rendering
  route available in NextN as an explicit, optional Reader translation provider,
  while retaining the existing local renderer and private OpenAI-compatible
  text source unchanged.
- Reference parent tree: NextE keeps the provider outside the Reader canvas:
  `Settings → Reader → Manga rendering service → HdsNavDestination →
  SecondaryListScaffold → ListItem → GroupedListSection`. Its form owns the
  service URL, service account/password, detection and inpainting profiles,
  and an explicit connection check; Reader dispatches only after a provider
  route has been selected.
- Current NextN tree: `Settings → Reader → Comic translation →
  ComicTranslationSourcePage → SecondaryListScaffold → ListItem →
  NextNGroupedListSection`. The current page owns the private text source and
  local model pack only. `ComicWholePageRenderBackend` already exists in
  shared code, but no provider, selection state, or whole-page orchestrator
  reaches it.
- Exact boundary: add the reference-owned provider configuration destination
  and a persisted provider selection. The self-hosted route owns its own
  non-secret endpoint/preferences and HUKS-backed service credential; it is
  disabled until a successful explicit configuration. The Reader keeps its
  one canvas and current action ownership; local rendering remains the default.
- Verification plan: build first, then compare the unconfigured provider form
  with the same NextE route at the same viewport. Provider connection, upload,
  rendering, and result acceptance require an actual configured service and a
  separate real Reader run; no source-shape check is visual evidence.
- Unresolved risk: the selected device has no declared self-hosted endpoint or
  service account, so this implementation must not invent one, make a network
  request, or claim rendered output during the unconfigured path.

### Active implementation boundary — 2026-08-11

- Newly actionable boundary: the optional provider has its non-visible
  transport, persistence and Reader dispatch implementation, but no native
  settings destination through which a person can review, check, and select
  it. This is the only visible boundary being opened here.
- Whole tree before: `Settings → Reader → Comic translation →
  HdsNavDestination → ComicTranslationSourcePage → SecondaryListScaffold →
  ListItem → NextNGroupedListSection`.
- Whole tree after: retain that text-source route unchanged and add the
  sibling `Settings → Reader → Manga rendering service → HdsNavDestination →
  MangaRenderingServiceSettingsPage → SecondaryListScaffold → ListItem →
  NextNGroupedListSection`. The new page follows the NextE service-form order:
  fixed service profile, detection/inpainting choices, URL/account/password,
  then a separate connection and provider-selection group.
- Exact behavior boundary: editing any service field makes the in-memory
  selection unavailable; `Check connection` stores the candidate with the
  provider disabled and performs the pinned capability/account check; only a
  successful current-page check enables the persisted self-hosted provider.
  The existing local renderer and OpenAI-compatible text-source route are not
  modified.
- Visual verification remains OPEN: after the build, compare this
  unconfigured destination with the same NextE service route at the same
  device viewport. Do not treat this ledger, source similarity, or a build as
  visual acceptance.

### Parent-tree correction — 2026-08-11

- Faulty assumption: the initial source mapping placed `Manga rendering
  service` as a sibling of `Comic translation` in Reader Settings. The actual
  NextE route owner is `ComicTranslationSettingsPage`; its self-hosted row
  opens `MangaRenderingServiceSettingsPage` from inside the comic-translation
  destination.
- Correction: remove the new Reader-Settings sibling row and move the one
  service-navigation row into NextN's existing
  `ComicTranslationSourcePage`. The configuration destination and all form
  leaves remain unchanged. This restores `Settings → Reader → Comic
  translation → Manga rendering service → HdsNavDestination` and avoids a
  competing parent tree.
- Impact: the captured direct-sibling form is retained as rejected local
  evidence only. It is not an acceptance sample and must not justify a
  visual claim.
- Device route result: the first post-correction traversal reused a
  post-scroll coordinate and opened Reader model management rather than Comic
  translation. The resulting native layout is retained locally as rejected
  route evidence. No preference, model, account, service field, or provider
  state was changed. The recovery action is to return to Reader Settings,
  capture its current semantic entry once, and continue only from that fresh
  route state.
- Corrected device result: a fresh native traversal on the selected device
  reached `Settings → Reader → Comic translation → Manga rendering service`.
  The inner row showed `Not configured`; its destination showed the fixed
  profile, detection/inpainting choices, URL/account/password fields,
  connection check, and a disabled provider switch. No field, check, switch,
  preference, service request, account, or content action was invoked.
- Visual status: route and unconfigured state are observed in NextN. The
  installed NextE reference was confirmed at the same root viewport, but its
  service page was not reached through its separate comic-translation owner
  in this run. The same-page visual comparison therefore remains OPEN.

### Source-boundary correction — 2026-08-12

- The entry's earlier “whole-page provider” premise is incorrect. NextE's
  `MangaTranslatorUiSidecarBackend` implements the established staged
  `ComicRegionRenderBackend`; its separate whole-page orchestrator belongs to
  another backend family. NextN's `MangaRenderingServiceBackend` implements
  that same staged backend interface, and
  `ComicTranslationRuntimeService.backendFor()` already selects it only when
  the endpoint, HUKS-backed credential, and explicit enabled state are valid.
- No parallel whole-page route, selector, or Reader action is authorized.
  The remaining open outcome is one explicitly configured self-hosted service
  completing the existing staged Reader request. Until that external service
  configuration exists, no source change or network request is justified.

### Connection-state correction — 2026-08-12

- **New source evidence:** the complete current NextE service form ends its
  second grouped section with `Check connection`; successful verified
  configuration is the service-availability boundary. NextN added a second,
  disabled `Enable` switch after that check. There is no NH-only data or
  privacy boundary requiring that extra visible state.
- **Exact correction:** keep NextN's private disabled candidate write before
  the check. Only after a successful check, persist the same candidate as
  enabled and remove the extra switch row. Failed or edited candidates remain
  disabled. Preserve the form order, input ownership, profile menus,
  secret-store boundary, connection action, local renderer fallback, and
  Reader action. Build and compare the unconfigured same-viewport form with
  NextE; do not enter a URL, account, password, or run a connection check.
- **Build and comparison boundary — 2026-08-12:** the signed Debug build
  succeeded and was installed in place on the selected device. The current
  NextE route resumed a retained Interface destination; its Settings → Reader
  surface did not expose the recorded manga-rendering entry during the
  bounded route recovery, so no valid same-page reference pair exists. The
  comparison is rejected rather than inferred from a different page. The
  selected device was returned to native NextN root with no service field,
  connection, credential, provider, account, or content change. This source
  correction remains **EVIDENCE-ONLY** until the exact NextE form route is
  re-established; do not repeat the same Reader-scroll chain as a substitute.

### Corrected reference-route result — 2026-08-12

- The exact reference route was then established once: `Settings → EH →
  Comic translation → Self-hosted`. Its terminal native service form and the
  NextN terminal native form both had foreground identity proved and the same
  `1320×2120` portrait root viewport. The local raw evidence remains outside
  Git in `.hvigor/outputs/manga-rendering-form-20260812T0414-reference-retry/`.
- The pair is **rejected for visual comparison**: the existing NextE service
  was configured, while the current NextN service was unconfigured. No
  field, connection check, provider state, account state, content data, or
  application data was changed to manufacture equivalence. The NextN form was
  only observed to contain its profile fields and the connection-check group;
  this is not a visual-parity acceptance.
- Status remains **EVIDENCE-ONLY**. Do not repeat either route or alter either
  service configuration merely to create a comparison. A future same-state
  reference precondition is required before this narrow form surface can be
  visually accepted.

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
- Result: with normal page images and cache work restored but only enhancement
  invocation suppressed, native NextN Reader remained foregrounded. The
  current observed exit is therefore in the enhancement invocation boundary,
  not routing, detail/history/data loading, normal image rendering, or cache
  transfer. The suppression is removed immediately; the implementation must
  now repair the enhancement decode/processing boundary rather than retain a
  feature disable.
- Current-source retry: with no temporary Reader source change retained, one
  fresh native Detail `继续` activation again ended with the NextE root in the
  foreground. The local 500-line app/core warning-and-error tail contains no
  Reader, PixelMap, ImageSource, or fatal marker that can attribute the
  transition. This counterevidence reopens the prior enhancement-only
  conclusion: it establishes only an un-attributed Reader-entry failure in
  the current normal build. The raw local evidence is retained at
  `.hvigor/outputs/reader-route-baseline-log-20260811T2123/` outside Git.
  Do not repeat the same route; the next evidence must change one
  non-visible execution boundary.
- Follow-up result: the non-visible boundary was changed to continuous
  app/core logging before route activation. Temporary fixed stage calls were
  tried at both info and error severity, yet neither live capture contained a
  stage marker or a NextN-attributable error/fatal record while the observed
  terminal remained NextE. This logging channel is therefore rejected as a
  route-stage discriminator. The temporary source was removed and the normal
  signed Debug HAP reinstalled; no visual surface, preference, account, or
  content data changed.
- Version-boundary result: the isolated `12aa2f8` baseline HAP reproduced the
  same NextE terminal from the same one-activation Reader route. Current HEAD
  was reinstalled immediately afterward. This rules out the post-`12aa2f8`
  Reader settings/self-hosted-renderer commits as the cause of this observed
  exit, but does not establish an older code or platform cause. The temporary
  worktree and copied signing configuration were removed; local device
  evidence remains outside Git.
- Deeper boundary result: the isolated `c4c1627` HAP also reproduced the same
  NextE terminal after one current native Detail Continue action. Current HEAD
  was restored immediately with `install -r`. This rules out the full
  `c4c1627..12aa2f8` Reader-model/settings range and makes the earlier
  temporary-isolation conclusions non-authoritative for the present device
  state; they cannot be used to name enhancement, image cache, or route mount
  as the cause. No data, preference, account, or content action occurred.
- Pre-enhancement boundary rejected: isolated `cc0c40a` reached native Gallery
  Detail but did not surface a semantic Reader action after its current ready
  state. No coordinate was inferred, no Reader action was taken, and that
  revision is not a comparable Reader-route sample. Current HEAD was restored
  immediately with `install -r`.

### Process-body discriminator — 2026-08-11

- Newly actionable boundary: the unresolved route had already been separated
  from the Detail callback and Reader mount, but not from service-module
  loading versus the actual enhancement work. This one-run diagnostic changed
  no visible geometry, hierarchy, action, preference, or stored content.
- Exact temporary delta: retain the existing `process()` call, then return the
  original image before model lookup, cache/file work, image decoding, PixelMap
  work, and the native upscale invocation.
- Observed result: with the enabled preference left unchanged, the same direct
  Gallery route and one current `继续` action ended on native NextN Reader. The
  temporary return was removed immediately; the signed normal Debug HAP was
  rebuilt and reinstalled in place. A lazy-import experiment was also removed
  because it did not prevent the enabled path from exiting.
- Impact and prevention: the evidence narrows the fault to actual processing,
  but it does not identify a specific operation or justify a feature disable.
  The next diagnostic must split one source-owned processing boundary and must
  remove its temporary code before any other Reader or UI work.

### Decode execution repair boundary — 2026-08-11

- Newly actionable source basis: current device evidence isolates the first
  unsafe window to source PixelMap creation/release inside `processNow()`. The
  existing NextE codebase already uses an `@Concurrent` ImageKit decode leaf
  for private image work, and the official TaskPool guidance supports returning
  `ArrayBuffer` to the UI runtime.
- Exact change: preserve Reader image ownership, source file selection, model
  readiness, cache identity, native upscale API, output packing, and all UI
  geometry. Move only source `createPixelMap` / pixel-buffer extraction into a
  top-level `@Concurrent` worker that reopens the same path and returns a
  tightly packed RGBA `ArrayBuffer`; the caller keeps the already validated
  source dimensions and invokes the existing native request unchanged.
- Minimality and risk: this is not a decoder option or model change. It
  removes the proven UI-runtime coexistence boundary while retaining the
  existing fallback on worker failure. The worker must verify decoded
  dimensions and normalize stride before returning; no unverified decoded
  buffer may enter the native API.
- Verification plan: signed in-place install, one existing direct Gallery
  route and one current Reader action. Require native NextN Reader terminal
  with normal enhancement enabled; then inspect the existing applied-state
  leaf separately. A build or worker return alone is not acceptance.
- Result: the signed build was installed in place and the one current Reader
  route still ended with NextE foreground. This rejects the worker migration
  as a corrective change; it does not prove whether the worker itself failed
  or completed before the terminal exit. The code was removed immediately and
  the normal signed Debug build is being restored before any further work.

### File-descriptor decoder-source boundary — 2026-08-11

- Newly actionable source basis: retaining the post-decode `ImageSource` and
  `PixelMap` still reproduced the exit, so early release is not the cause.
  The platform ImageSource API documents a direct file-descriptor constructor;
  the current path-string constructor is the remaining input-construction
  variable at the proven PixelMap boundary.
- Exact change: open the same verified private source path read-only and pass
  its descriptor to `image.createImageSource`; retain the descriptor until the
  ImageSource has been released. No byte, cache, model, PixelMap option,
  native-inference, Reader, or UI change is included.
- Verification plan: one signed in-place run of the existing direct Gallery
  route and one current Reader action. A native NextN Reader terminal is the
  required corrective signal; otherwise remove the descriptor change and do
  not retry this route unchanged.
- Result: the signed build was installed in place. After a NextN-only
  force-stop, the same direct Gallery route, one freshly resolved native
  `继续` action, and an eight-second settle, WindowManager foreground was
  `nexte0`, not NextN. The descriptor construction change is rejected and was
  removed immediately; this route will not be retried unchanged.

### In-memory decoder-source boundary — 2026-08-11

- Basis: the documented descriptor constructor did not alter the terminal
  process exit, while the repository already has an `ArrayBuffer → ImageSource`
  leaf for verified local image bytes. This isolated the third supported source
  construction form without changing decode options, dimensions, native
  inference, output packing, Reader behavior, or UI.
- Result: the same single direct-Gallery Reader action again ended with
  WindowManager foreground `nexte0`. The in-memory construction code was
  removed immediately and the normal Debug build is being restored. With path,
  descriptor, and in-memory inputs all rejected, the remaining boundary is
  `createPixelMap` execution itself, not ImageSource input construction.

### Minimum-size PixelMap boundary — 2026-08-11

- Basis: all three supported ImageSource constructors had failed, leaving the
  decode allocation path as the last bounded ImageKit split. The diagnostic
  requested only a 1×1 RGBA PixelMap and returned before pixel-buffer access,
  inference, output PixelMap creation, or packing.
- Result: the same single Reader action still ended with WindowManager
  foreground `nexte0`. The diagnostic was removed immediately. The device
  exit is therefore not explained by source construction, requested pixel-map
  size, downstream pixel reads, native inference, or output packing; it occurs
  during this ArkTS ImageSource `createPixelMap` invocation itself.

## OPEN — Gallery Comments full-page composer and supported client actions — 2026-08-13

- **Why newly actionable:** current user feedback identifies two concrete
  regressions in the already-open full Comments destination: a duplicate HDS
  header menu exposes both a redundant composer focus command and a duplicate
  reload command despite the page's persistent composer and pull-to-refresh;
  and the empty/filtered-empty branch mounts its composer outside the
  keyboard-aware overlay that the loaded branch uses. The user also requires
  the supported client-side reply, quote, translation, and API-26 material
  leaves to be retained rather than reduced to a data-source-only page.
- **Reference parent tree:** NextE owns `HdsNavDestination(title/menu) →
  Stack(bottom) → PullRefreshListScaffold(all settled list states, including
  empty) + CommentComposer overlay`. The composer owns its outer safe-area
  padding and selects API-26 system material with a same-geometry solid
  fallback. Each full comment card is author → resolved quote(s) → body →
  date/actions. Refresh remains the pull owner; there is no compose or reload
  title action. The reference title's uploader-only filter cannot transfer
  because the NH DTO has no uploader/filter capability.
- **Current NextN parent tree and capability boundary:** `Index` supplies the
  HDS title plus invented compose/reload versions. `GalleryCommentsPage`
  correctly uses a Stack overlay only for nonempty comments, but bypasses it
  for empty/filtered-empty content. `NhComment` provides numeric ID, author,
  date, and plain body; those fields support this client's own encoded reply
  prefix and quote lookup. It does not provide score, vote, uploader, edit
  capability, rich spans, links, or images, and the known NH write API only
  posts a new body. Existing `CommentTranslationService` remains the source
  of translation.
- **Exact correction:** remove only the redundant HDS compose/reload actions,
  version propagation, and monitors; keep the sole HDS title. Make every
  settled list state share the Stack/PullRefresh/composer owner, with the
  composer owning its existing outer keyboard-safe padding. Port the existing
  client reply syntax (`@author` plus four-symbol encoded comment ID), resolve
  only that self-generated syntax against the current comment set, show its
  compact quote above the body, and provide reply/translation actions in the
  compact footer. Add the reference-shaped API-26 material branch and exact
  solid fallback with unchanged composer geometry. Do not add vote, score,
  uploader filtering, editing, rich spans, images, Detail changes, automatic
  translation, or a new request lifecycle.
- **Faulty assumption and prevention:** earlier changes treated a persistent
  composer as an isolated footer leaf and accepted source-shape similarity as
  sufficient. That hid the state-tree split and permitted duplicated commands.
  A full-page comments change must trace all loaded and empty states through
  the same scroll/overlay owner before changing a card leaf; a client-side
  capability is not removed merely because an NH server field is unavailable.
- **Verification plan:** inspect the exact diff, run the signed Debug build,
  install in place on the selected `.237` device without clearing data, then
  use the existing direct `471768` Comments route once. Review the loaded page
  and one semantic composer-focus/keyboard state against the retained
  same-viewport NextE reference. Retain the resulting local captures outside
  Git and record exactly what is and is not visually observed. This boundary
  remains OPEN until that current comparison is recorded.

- **Current device observation — 2026-08-13:** the signed Debug build
  succeeded and was installed in place on the selected device without a data
  clear. The direct `471768` Comments destination foregrounded native NextN
  at the same `1320×2120` effective viewport as the retained NextE reference.
  The loaded NextN result has one HDS `评论` title and no duplicate compose or
  reload command. A single layout-derived composer focus action changed its
  field bounds from `[36,1920][1151,2024]` to `[36,1038][1151,1142]` while it
  remained focused, visible, and fully above the resized application window;
  no text was entered and no comment or account state changed. The local
  evidence is retained under
  `.hvigor/outputs/gallery-comments-full-page-20260813T030124/`.
- **Comparison boundary:** the non-keyboard pair has matching foreground
  identities and viewport, but not identical comment data or account state.
  It accepts only the observed single-title/chrome result and loaded-state
  composer avoidance. The empty/filtered-empty keyboard state, a reply quote
  rendered from real returned data, and a configured translation action remain
  unobserved. The reference count heading is deliberately not restored: the
  user froze the single HDS title for NextN. Votes, scores, and uploader-only
  filtering remain unavailable NH data leaves. This boundary remains **OPEN**;
  the next action is to resolve the observed translation-action availability
  condition before any further UI edit.

- **Newly actionable card-rhythm correction:** the current same-viewport
  loaded capture shows the short-comment cards looser than the reference, but
  the returned comment bodies and unsupported action leaves differ, so the
  screenshot-height delta is not a numeric target. A direct source-tree map
  instead isolates the three reference-owned values: NextN uses top/bottom
  card insets `16/12` and a `32vp` action, while NextE's full CommentRow uses
  `12/8` and a `30vp` footer action. List spacing, horizontal content inset,
  font sizes, and line height already match. The correction is limited to
  those three values; it does not compress body text, change card width,
  alter the floating composer, or touch the Detail-page comment peek.
- **Post-change evidence status:** the narrowed signed Debug build succeeded
  and was installed in place on the selected device. The established direct
  Comments route was launched. The required new local screenshot/layout
  receive operation was then rejected by the current execution policy before
  it ran. No prior capture is reused as evidence for these three new values.
  This is an **EVIDENCE-ONLY** state, not visual acceptance; retain the source
  checkpoint and resume exactly one same-route capture when that operation is
  available.
- **Post-change device result — 2026-08-13:** the pending exact same-route
  capture subsequently completed on the selected device. Its native root is
  `com.erosteam.nextn:EntryAbility`, `pages/Index`, with effective viewport
  `[0,117][1320,2120]`, matching the retained NextE portrait viewport. The
  first short-comment card now measures `[36,303][1284,579]` (276px), versus
  the prior current capture's 306px. The visible result retains the same card
  width, 6px list gap, body typography, floating composer, and single HDS
  title; its 12/8/30 source correction therefore moved only the intended
  vertical rhythm. The NextE reference contains different content and
  server-owned vote/score leaves, so it is not used as a pixel-height target.
  The retained local pair is
  `.hvigor/outputs/gallery-comments-card-rhythm-20260813T0314/` and is not
  committed. This accepts the loaded-card rhythm correction for that current
  route. The page remains **OPEN** only for the separately unobserved
  configured-translation, real reply-context, and empty/filtered keyboard
  states; do not retest the unchanged loaded rhythm.

- **Reopened reply-with-keyboard correction — 2026-08-13:** current user
  feedback and the retained raw native reply capture reopen only the
  composer/IME state. In
  `.hvigor/outputs/gallery-comments-reply-context-20260813T0320/post.png`,
  the lower edge of the reply composer and the send control are visibly cut
  at the keyboard boundary. Its layout records the actual app root ending at
  `y=1178`, while the reply `TextArea` and send row have original bounds to
  `y=1190` and visible bounds cut at `y=1178`. This is a real crop, not a
  `visible`-flag success. The earlier ordinary-focus observation only covered
  a one-line composer (`[36,1038][1151,1142]`); treating it as evidence for
  the reply-prefilled multiline state was the faulty inference.
- **Reference and whole-parent boundary:** retained NextE reply-plus-keyboard
  evidence keeps its entire composer—including context, input, and send
  action—inside its resized destination. Its source owner is
  `GalleryCommentsPage: HdsNavDestination -> Stack(bottom) ->
  PullRefreshListScaffold + CommentComposer`. Current NextN instead keeps
  `HdsNavDestination` in `Index` and renders
  `GalleryCommentsPage: Column -> Stack(bottom)`. The accumulated local
  reconstruction began when the original modal was replaced (`85ff833`), was
  changed into a docked footer (`f5826ed`), then partly reconstructed
  (`5f95310`/`95a730d`). `95a730d` added the reply context and prefilled
  multiline state without device evidence for that state. The extra ownership
  split is a source-proven reference divergence; it is not claimed to be the
  sole cause until the corrected route is observed.
- **Exact correction and limits:** move the existing Comments HDS destination
  owner from `Index` into `GalleryCommentsPage`, where the reference owns it,
  and remove the page's otherwise unnecessary outer `Column` so the settled
  list/composer `Stack` is the direct destination child. Preserve the one HDS
  title, existing snapshot/loading/request semantics, pull refresh, floating
  composer, reply protocol, all card geometry accepted for the loaded route,
  and all unsupported NH leaves. Do not add a compensating arbitrary bottom
  padding or alter Detail, Related, translation configuration, or posting.
- **Verification plan and prevention:** build, install in place without data
  clearing, use the established direct `471768` Comments route, invoke one
  existing reply action without submitting, and retain one raw post-reply
  keyboard screen/layout. Review the complete reply composer against the
  actual resized root, including the send control. Future visible composer,
  overlay, or IME edits must list ordinary focus and every changed contextual
  focus state separately in this ledger; `visible=true` or an unchanged-state
  screenshot cannot accept another state. No UI static contract is used.

- **Post-change device result — 2026-08-13 04:20 +0800:** the signed Debug
  HAP was installed in place on the selected `.237` device after its awake /
  `86400000ms` timeout gate, with no data clear. The documented direct
  `471768` Comments route reached native `com.erosteam.nextn:EntryAbility`.
  One current-layout-derived reply action was invoked; no text was entered
  and no comment was posted. With the IME open, the actual application root
  ended at `y=1178`. The reply composer outer surface was
  `[0,746][1320,1178]`, its material surface was `[24,746][1296,1154]`, the
  prefixed reply `TextArea` was `[36,926][1151,1142]`, and the send control
  was `[1175,1034][1284,1142]`. Each of those composer bounds equals its
  original bound and stays inside the resized root. The raw screen also shows
  the complete reply context, editor, and send control above the keyboard.
- **Same-state reference check:** the retained NextE reply-plus-IME capture
  has the same `1320×2120` portrait root and the same effective resized
  application bottom. Its reply `TextArea` and send control occupy the same
  `[36,926][1151,1142]` and `[1175,1034][1284,1142]` bounds, respectively,
  with matching original bounds. This accepts only the prior reply-composer
  crop correction; it does not reopen the frozen loaded-card rhythm or make a
  whole-page parity claim. Raw local evidence is retained at
  `.hvigor/outputs/gallery-comments-reply-ime-owner-20260813T0417/` and is
  excluded from Git.
- **Freeze:** the `reply + prefilled multiline + IME` state is now FROZEN.
  It must not be revisited, recomputed, or altered without new feedback or
  same-state counter-evidence. The causal correction remains limited to
  restoring the reference destination/overlay ownership; no compensatory
  padding was introduced.

## FROZEN — Gallery Comments initial no-snapshot successful-load owner — 2026-08-13

- **Why newly actionable:** the user reports that entering the Comments page
  visibly becomes a loading/refresh state. When a direct Comments route has
  no Detail snapshot, `aboutToAppear()` starts `loadComments()`, which sets
  `isLoading=true`. Current `build()` then replaces the entire destination
  child with `PageLoadingState` (and similarly replaces it with
  `PageErrorState` on the first failure), unmounting both the List refresh
  owner and the persistent composer.
- **Reference parent tree and exact boundary:** NextE keeps
  `HdsNavDestination -> Stack(bottom) -> PullRefreshListScaffold +
  CommentComposer` mounted for initial empty, loaded, and refresh-failure
  states; only the List content changes. This correction concerns the direct
  no-snapshot initial-load and first-failure branches only. It excludes the
  FROZEN reply/IME state, comment-card geometry, title, translation, posting,
  Detail, and any request/API behavior.
- **Exact correction:** keep `SettledCommentsPage()` as the destination child
  for every request state. Render initial loading and initial error as a
  single content row within its existing `PullRefreshListScaffold`, using the
  existing page-state leaves and retry callback. Keep the composer mounted as
  the reference-shaped Stack sibling, but retain its disabled leaf state until
  the route is resolved. Disable top-pull interaction while that same initial
  request is in flight; ordinary pull refresh remains the only explicit
  refresh path after it settles. No programmatic pull is added.
- **Device observation — 2026-08-13 04:46–04:47 +0800:** the signed Debug HAP
  was installed in place on the selected `.237` device with `install -r`, then
  NextN alone was force-stopped and cold-started through the existing direct
  `471768` Comments Want. No app data was cleared and no account, preference,
  comment, or content action occurred. The immediate native NextN root was
  `EntryAbility / pages/Index` at `1320×2120`; it retained one
  `NavDestination`, one scrollable `List`, three `ListItem`s, one centered
  loading leaf, and one mounted-but-disabled composer `TextArea`. The later
  settled capture retained the same one destination, one List, and one
  composer; the loading leaf was replaced by comments and the composer became
  enabled. The initial layout is decisive for the owner boundary, while its
  separately collected screenshot crossed the network completion and is
  retained as a settled-state artifact rather than mislabeled as an initial
  screenshot.
- **Reference boundary and remaining evidence limit:** NextE source keeps the
  same destination/Stack/List/composer ownership for a no-snapshot route, but
  its own controller intentionally animates a programmatic top pull. NextN
  intentionally retains caller-owned initial state rather than importing that
  animation. A system `viewData` attempt on the selected device routed the
  public EH URL to the system browser instead of native NextE; its raw
  artifacts are retained and rejected as a reference pair. Therefore this is
  accepted only for NextN's observed no-snapshot owner transition, not a
  same-viewport visual-parity claim for the reference animation. No UI static
  contract was created or used.
- **Freeze:** this no-snapshot loading-owner correction is FROZEN. Do not
  revisit it without new user feedback or same-state counter-evidence.
  The first-request error row is implemented in source under the same owner,
  but was not induced on the device and is therefore EVIDENCE-ONLY rather
  than visually accepted; do not manufacture a failure solely to retest it.

## OPEN — Gallery Detail primary Read action ownership and metadata copy — 2026-08-13

- **Why newly actionable:** the user reports that the floating Read action is
  visibly left-aligned, that an existing resume page value is duplicated in
  metadata instead of being part of the Continue action, and that a heart
  metadata cell redundantly says “favourites” after its heart icon.
- **Whole affected tree:** `GalleryDetailPage -> DetailWorkspace(Stack) ->
  DetailMetadataList(PullRefreshListScaffold) + ReadFabRail(transparent
  overlay) -> ReadFab(Filled/HDS)`. `GalleryInformation` remains the existing
  metadata `NextNGroupedListSection -> Flex` owner. This boundary excludes
  Detail list spacing, preview/related/comment rails, scroll reserve, FAB
  floating behavior, Reader restore semantics, favourite mutation, and all
  other metadata cells.
- **Source/reference evidence:** NextE keeps an intrinsic-width Read button
  inside a full-width transparent rail and gives a saved page to the Read
  action label (`Resume P<n>`), rather than adding a resume metadata row.
  NextN commit `7d78e45` inserted a full-width inner `Row` between its rail
  and `ReadFab`; the outer End alignment can no longer position the actual
  action. Its retained reader marker already distinguishes page zero from no
  progress, so only presentation changes are needed.
- **Exact correction:** remove only that inner row's full width; retain its
  transparent rail, hit-test owner, overlay position, and existing tail
  reserve. Change the existing Continue label to include the marker-backed
  one-based page; remove only the duplicate metadata row.
  Keep the heart icon and render its count directly, without a redundant
  semantic label. Both Filled and HDS Read leaves consume the same label; HDS
  width becomes the smallest bounded content width necessary for that label.
- **Device comparison — 2026-08-13 13:15 +0800:** commit `1e555be` was built
  as the signed Debug HAP, then installed on the selected
  `192.168.50.237:12345` target using `install -r` after the live-target,
  lease, wake, and `AWAKE` / `OverrideTimeout=86400000ms` gate. No data clear,
  uninstall, account, preference, favourite, Reader-marker, or content action
  occurred. The established `nextn://gallery/471768` route settled to native
  NextN `EntryAbility / pages/Index` at `[0,117][1320,2120]`. Its visible
  saved-progress action is `继续 P1` at `[1078,1979][1224,2028]`; its visible
  and original bounds match, and it is fully in the right-side floating rail.
  The detail information card now has the heart icon plus direct numeric count
  only, without a separate resume metadata row.
- **Comparable reference:** retained native NextE Detail evidence at the same
  `[0,117][1320,2120]` viewport is
  `/Users/honjow/git/NextE/.hvigor/outputs/reader-thumbnail-ratio-fix/237/detail/screen.png`
  with `layout.json`: foreground `com.erosteam.nexte:EntryAbility`,
  `gallery-detail-pane`, and saved-progress action `继续 P6` at
  `[1070,1979][1216,2028]`. The reference content is a different Gallery, so
  only the shared action rail, saved-progress copy, and metadata-cell grammar
  were compared. Both actions share the same vertical bounds and right-side
  floating placement. Raw NextN evidence is retained locally at
  `.hvigor/outputs/gallery-detail-read-action-20260813T0515/` and is excluded
  from Git.
- **Freeze:** the corrected Read-action ownership, saved-progress label, and
  heart-count presentation are FROZEN. Do not reopen them without new user
  feedback or same-state counter-evidence. No UI static contract was created
  or used.
