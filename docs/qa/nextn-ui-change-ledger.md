# NextN UI change ledger

This register records visible-change boundaries and their evidence. It does not
authorize an edit, replace a device comparison, or define product completion.

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
