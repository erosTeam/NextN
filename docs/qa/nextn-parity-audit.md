# NextN parity audit — active continuation

This is a source-grounded continuation queue, not a completion claim.

## Completed or already evidenced

- Native ArkWeb account sign-in, sealed persistence, cold start, and an
  authenticated native Favorites result have physical evidence on the selected
  device. Credential redaction never changes the autonomous-submit rule.
- Browse has retained Latest/Popular sources and the supported list, grid,
  waterfall, compact-waterfall, and cover-wall presentations with persisted
  density. Real-device runs verified Cover wall and Cover grid across cold
  starts.
- Theme, app language, tablet policy, Reader overlay/thumbnail navigation,
  downloads, local history, comments, favourite mutation, torrent export, and
  four-locale fixed UI copy have corresponding source contracts.
- Downloads now use a local lifecycle projection: active, paused, retry, and
  complete task groups are newest-first inside the existing private queue.
- Gallery detail now has route-local refresh, compact comments/page-preview
  peeks, title disclosure, local Read/Continue semantics, and state-aware
  download/favourite actions. Its virtual thumbnail overview now supports
  HDS first-page and bounded page-jump actions without changing canonical
  Reader indices. Reader uses lazy vertical pages, fitted-image zoom bounds,
  a progress scrubber, thumbnail strip, tap zones, mode menu, and a compact
  overflow for existing share/external/settings actions.
- Search has an HDS-safe suggestion/history surface, persisted local
  language/sort defaults, canonical gallery-link direct open, and explicit
  local single-entry history removal. Favorites has an authenticated,
  request-snapshot-bound text search; Downloads has local search/sort,
  cover-to-detail, single-task actions, and visible filtered bulk pause/resume
  commands.
- Settings root destinations use sibling replacement and HDS split-selection
  state instead of accumulating stale peer routes.
- History now uses local RDB keyset paging and stable lazy day groups rather
  than eagerly materialising the full table. Confirmed favourite removal is
  applied to the visible Favorites projection before its background reconcile,
  so it no longer blanks the retained list.
- History primary cards now enter Gallery detail; their explicit 48vp
  Read/Resume affordance alone enters Reader at the stored local index.
- Downloads now use real lifecycle `ListItemGroup`s with an HDS-pinned current
  group mirror. Visible batch pause/resume preserves already-applied local
  results and reports partial completion instead of hiding it behind a generic
  queue failure.
- The combined source set has passed the full static-contract suite and both
  signed Debug and Release Hvigor builds. Device visual and transition
  evidence remains queued only for the selected 237 target.

## Direct next implementation — no external authority needed

- Keep reducing only source-grounded parity gaps found in the current Gallery,
  Reader, History, Downloads, Settings, Home, and Search surfaces. Do not
  invent E-Hentai-only request parameters or controls for unsupported NH v2
  behavior; device evidence decides the next visual correction.

## Explicitly not portable as NH features

- NextE/E-Hentai `favcat`, Toplist, archive, and their PHP/HTML query
  parameters have no equivalent in the NH v2 API. Do not add inert controls
  or send invented query parameters.
- ErosN title/comment translation depends on a user-configured external
  provider URL, key, and model. NextN currently provides the safe local tag
  dictionary only. Selecting a provider or sending gallery/comment text needs
  separate product authority; it is not a local UI parity patch.

## Remaining device evidence

- Exercise a non-destructive Browse loading/error/empty-state boundary.
- When device 237 returns, install the current Debug HAP with `install -r`
  only, then verify the new Gallery/Reader/History/Downloads/Settings/Search
  transitions plus the redacted native Favorites summary. This does not mean
  manual login or user presence is required.
