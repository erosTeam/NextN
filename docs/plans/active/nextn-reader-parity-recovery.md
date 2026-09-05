# NextN Reader parity recovery

Status: `PARTIAL DEVICE PASS / THUMBNAIL OPEN — 2026-09-05`

## Active outcome

Restore the complete NextN Reader behavior contract to the current NextE Reader
parent tree, while retaining only NH-specific data/source leaves. Completion
requires same-state, same-viewport device evidence for every affected Reader
mode; source similarity and a successful build are intermediate evidence only.
The selected acceptance target for this recovery is
`192.168.50.237:12345`; no sibling device evidence can close a row.

## Why the previous audits are reopened

The earlier parity inventory counted top-level structures and feature names, and
the later latent-hazard pass checked for obvious absent entry points. Neither
proved that each mode reached an equivalent layout owner or that shared
components received mode-safe constraints. The current counterexample disproves
that shortcut:

- NextE gives paged and continuous reading separate image components and
  separate geometry contracts.
- NextN routes both through `ReaderImagePage` and distinguishes them with
  `fillViewport` / `continuous` flags.
- commit `33a2941b834bd836af881f7ccfcd8db18a85ab9f` added an unconditional
  `aspectRatio` to that shared component to reserve continuous-mode height.
- in paged mode the same component also receives `width('100%')` and
  `height('100%')`; ArkUI resolves the height from width and aspect ratio, so a
  tall strip becomes taller than the fixed-height pager and its off-viewport
  content cannot be reached.

Therefore the old broad implication that the Reader had no remaining safe
missing behavior is invalid. Every row below must be classified from current
source and then, for visible behavior, judged on a real device.

## Reference parent tree

```text
Reader route / lifecycle owner
└── ReaderPage
    ├── fixed canvas and opening/closing transition proxies
    ├── ReaderContent
    │   ├── continuous scroll owner -> ReaderVerticalImage
    │   ├── single-page pager -> ReaderImagePage
    │   └── double-page pager -> ReaderSpreadSurface -> image layers
    ├── per-page loading / failure / enhancement / translation states
    ├── tap, swipe, pinch, double-tap and zoom arbitration
    ├── preload / cache-warm ownership
    ├── top chrome and overflow actions
    ├── thumbnail strip, progress row and bottom toolbar
    └── window, fullscreen, keep-screen-on and route lifecycle
```

NH gallery IDs, page URLs, authentication, translation providers and download
storage are product data leaves. They may adapt at the edge; they do not change
the parent ownership or Reader behavior contract.

## Audit matrix

Each row has exactly one disposition:

- `MISSING`: confirmed NextE behavior is absent or observably degraded in NextN;
- `NH-LEAF`: intentional NH data/source substitution under the same parent;
- `SPLIT-OWNER`: equivalent behavior exists under a different documented owner;
- `FALSE-POSITIVE`: apparent source difference does not change the contract;
- `PENDING`: not yet proven either way.

| Area | Current evidence | Disposition | Required action / proof |
| --- | --- | --- | --- |
| paged image geometry | shared NextN image leaf receives continuous-only aspect ratio; tall pages are clipped by the fixed pager | `MISSING` | restore a page-sized `Contain` surface with no continuous aspect-ratio constraint; device-test tall and ordinary pages |
| continuous image geometry | NextE owns reserved-height layout in `ReaderVerticalImage`; NextN folded it into the shared leaf | `MISSING` | restore an explicit continuous image geometry owner and retain stable intrinsic-ratio placeholders |
| double-page geometry | separate spread surface exists in both products, but NextN hard-coded `[0,1]`, `[2,3]` and fixed `+2` navigation | `MISSING` | implemented odd/even spread starts, cover singleton, adjacency navigation and complete-spread preload; verify ordering, crop, zoom and viewport changes on 237 |
| reader modes and direction | NextN retained all four renderers but changed its missing/invalid default from NextE's LTR single-page mode to continuous vertical | `MISSING` | default and normalization now use `PAGED` while preserving explicitly stored `VERTICAL`; verify persistence, transitions, vertical paging and RTL/LTR on 237 |
| per-gallery double-page alignment | NextE persists `columnMode`; NextN had no owner or one-page alignment action | `MISSING` | implemented gallery-keyed pairing persistence plus the one-page toolbar action; verify restore after close/cold start on 237 |
| image loading / retry | both readers expose inline staged loading and page-local explicit retry; NextE's alternate-source retry is EH-only | `SPLIT-OWNER` | regression-test ordinary failure/retry on 237; retain alternate-source selection as `NH-LEAF` absent |
| cache warming / preload | NextE uses hidden warm-image leaves; NextN uses `ReaderImageCacheService` with shared in-flight requests and bounded ahead destinations | `SPLIT-OWNER` | static contract now warms both halves of odd/even spreads; prove no visible ownership gap on 237 |
| crop, interpolation and decoded size | both products contain page/continuous/spread crop and interpolation under different leaves, but NextN omitted the direct Reader crop action | `MISSING` | restored current-mode crop toggle without changing the accepted enhancement event ABI; verify all modes on 237 |
| pinch / pan / double tap | both use one transform owner per page/spread, anchored zoom, fitted pan bounds and pager suppression while zoomed | `SPLIT-OWNER` | compare anchors, bounds, page-swipe suppression and reset lifecycle on 237 |
| translation and enhancement | NextN intentionally uses NH services while preserving Reader image-leaf replacement | `NH-LEAF` | verify that service adaptation does not change page geometry, progress or zoom |
| image information | NextE exposes current-image information; NextN had no Reader action despite already owning page dimensions, format, local file and enhancement state | `MISSING` | restored page/spread information menus from parent-owned state without widening the image-leaf event ABI; verify on 237 |
| save current image / spread | NextE exposes save current/left/right/both; NextN had no Reader save action | `MISSING` | restored local-file-backed photo creation and spread selection; verify system save flow on 237 |
| share current image / gallery | NextN exposed only gallery sharing in overflow while NextE separates a direct current-image top action | `MISSING` | restored current displayed file/image URL sharing while retaining gallery share as an NH route action; verify payload chooser on 237 |
| original/resampled source toggle | tied to E-Hentai source alternatives in NextE | `NH-LEAF` | do not port unless NH has an equivalent alternate source |
| image-block / source-reload actions | tied to E-Hentai source and account behavior | `NH-LEAF` | retain only if an NH equivalent is source-proven |
| chrome / thumbnail / progress | NextN chrome omitted portable save/share/double/one-page controls and used a two-step spread Slider | `MISSING` | restored the action hierarchy and source-page Slider step; compare ordering, visibility and page mapping on 237 |
| Reader thumbnail geometry | metadata plumbing no longer reads full-page dimensions, but current user counter-evidence says the long-strip Reader thumbnails still render with the wrong visible proportion | `MISSING` | reproduce the current rail on 237, identify the exact asset/container/fit mismatch, and device-verify against the compact detail rail before closure |
| fullscreen / status bar / return transition | existing NextN route-specific implementation has accepted constraints and rejected alternatives | `SPLIT-OWNER` | regression-check without reopening `REJ-READER-001` through `004` |
| keep-screen-on / app lifecycle | NextN has route-scoped window policy, timer/key cleanup, request generations and progress publication under different state owners | `SPLIT-OWNER` | compare foreground/background, route leave and abnormal-load cleanup on 237 |

## Closure result

The complete current Reader parent tree was reclassified against NextE before
device acceptance. Every portable row classified `MISSING` above except Reader
thumbnail geometry has current accepted evidence;
source-specific alternate-original, source-reload and image-block actions remain
intentional `NH-LEAF` exclusions because NH has no equivalent source contract.
No shared NextE/NextN component extraction was attempted in this recovery.

The exact signed candidate installed in place on
`192.168.50.237:12345` has SHA-256
`cc5229681cd8105367c4e77548768052d2e63eab438f809a4508c7dedff72a82`.
The executable Reader contract passed with the following structural result;
its thumbnail checks cover metadata plumbing only and are not visual
acceptance:

`OK reader contract passed (mode/default, geometry, thumbnails, spread pairing, actions, cache, preload)`

Current 237 evidence under
`.hvigor/outputs/reader-parity-237-20260905/` proves:

- gallery `678049` page 1 (`720x9245`) and page 2 (`720x9980`) are fully
  contained from top to bottom in the fixed single-page viewport; the same page
  becomes full-width and vertically reachable only after selecting continuous
  mode;
- the prior `200x364` thumbnail capture was incorrectly treated as acceptance.
  Current user counter-evidence says the rendered rail proportion remains
  wrong, so asset/container/fit ownership is reopened on 237;
- LTR, RTL, top-to-bottom paging and continuous vertical modes preserve source
  page identity while changing only their documented direction/scroll owner;
- odd-left and even-left double-page pairing, page-one and page-fourteen
  singletons, one-page alignment, full-spread navigation/preload and RTL visual
  reversal are coherent; even-left `2-3 / 14` survived a data-preserving
  force-stop/cold reopen;
- double-page save and image-information menus identify the visual left and
  right source pages, while single-page save reached the system media-creation
  dialog and current-image share reached the system chooser;
- paged crop toggles on and off with the menu check state, double-tap cycles
  zoom, a zoomed vertical pan changes only the visible slice, and page 12 remains
  page 12 while panning;
- the Reader settings sheet opens without forcing a page turn and retains its
  reading-mode, direction, spread, animation, tap-zone, screen, enhancement,
  auto-page, volume-key and preload controls;
- RTL thumbnails show pages 14 through 8 in source order around selected page
  12, and tapping the visibly labeled page-10 thumbnail updates content,
  selection, header and progress to page 10.

The direct gallery route, status-bar/fullscreen owner and Reader return
transition were regression-observed without reopening `REJ-READER-001` through
`004`. Loading/retry, cache warming, enhancement replacement and lifecycle
cleanup retain their already separate documented owners; successful cold and
loaded page paths plus the executable structural contract found no missing
parent ownership.

### Reader chrome follow-up — 2026-09-05

User feedback after the device pass exposed one ambiguous chrome duplication:
the new NextE-aligned top-bar action shared the current image, while NextN's
older overflow action shared the gallery, but both appeared simply as Share.
The overflow Share item was removed and the direct current-image action kept.
Signed HAP `6f6649e0e390e48e8830e142f40319fc523c29019bf8c1db0ac4ef13a60a46d7`
was installed in place on device 237. Current `chrome-run/`, `overflow-run/`
and `final-run/` evidence under
`.hvigor/outputs/reader-share-affordance-237-20260905/` proves the top-bar
action remains, the complete overflow has no Share item, and the menu dismisses
back to the same Reader page without changing settings or invoking Share.

## Implementation order

1. Separate continuous and paged geometry ownership and remove the confirmed
   cross-mode constraint leak.
2. Complete mode/spread/index/gesture parity before touching chrome actions.
3. Complete loading/failure/preload/cache/lifecycle parity.
4. Restore only portable missing actions; document source-specific exclusions.
5. Review the exact scoped diff, run the signed build, then execute the device
   matrix. A failure in any sibling mode reopens the shared parent.

## Device acceptance matrix

Use one current full target under the repository lease/protocol controls. For
each visible comparison, prove foreground bundle, root bounds, orientation,
Reader mode, gallery/page identity and matching viewport before judging it.

- single-page horizontal LTR and RTL: ordinary page and extreme tall strip;
- single-page vertical paging: ordinary page and extreme tall strip;
- continuous scroll: cold loading placeholders, loaded geometry, retry and
  scrolling across multiple pages;
- double page: first/last spread, odd/even count, both reading directions and
  one-page alignment if supported;
- all modes: pinch, pan, double tap, page-turn suppression while zoomed, crop,
  translation/enhancement replacement, ordinary/extreme-strip thumbnail geometry,
  thumbnail jump and progress restore;
- lifecycle: settings change without forced page turn, background/foreground,
  fullscreen chrome toggle, Reader close and return target.

This matrix remains open only for Reader thumbnail geometry. A future Reader
geometry change is not allowed to reuse a mode-specific width/height or
aspect-ratio constraint in another mode without same-content evidence for every
consuming mode.
