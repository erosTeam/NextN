# Shared reader original-image interpolation — 2026-09-12

## Scope and boundary

This is an optional/debug-reader checkpoint, not a default-reader replacement. The change adds one UI-only `ImageInterpolation` parameter along the existing shared reader composition. It does not change Core policy, page/resource identity, geometry, decode ownership, transitions, gestures, persistence, defaults, or app routing.

- Paged: `ReaderSurface` → `ReaderPagerSurface` → `ReaderNativePager` → `ReaderPagedViewport` → `ReaderPagedCell` → `ReaderPagedImage`.
- Continuous: `ReaderSurface` → `ReaderContinuousSurface` → `ReaderContinuousList` → `ReaderContinuousCell` → `ReaderContinuousZoomImage` → `ReaderPagedImage`.
- Ordinary and cropped original bodies use the canonical host value.
- Thumbnail, sprite, rail and entry-preview sampling remain Low/current and are not coupled to the body setting.
- NextN, NextE and Koma Lab hosts map their already observable `low` / `medium` / `high` state. No new setting or writeback exists.

## Source and build gates

- `node --test tests/*.test.cjs` in reader-kit: 302/302 pass. The guards fail if any paged/continuous/cropped original hop drops the parameter, if the ordinary thumbnail branch stops retaining Low sampling, or if a continuous original row stops deriving its full-width height from intrinsic image dimensions.
- NextN main: final success 9.286 s; signed HAP 47,057,076 bytes; SHA256 `60878cdd574975b0fa77c06ef0089d24be7dc90b2323f42978d2c79b89614f5f`. This final build also shortens the localized quality hint so the value suffix no longer reads as part of the explanatory sentence.
- NextN native: success 8.578 s; signed HAP 43,617,171 bytes; SHA256 `ccaea693dcd3bbadfea70dc1271ce356a045ff1528f20d552246e781442743f5`.
- NextE matching main: success 12.858 s; signed HAP 62,704,487 bytes; SHA256 `2a064ef1ca356f23271671429ae58f6ab237219d80e63b7f4d24c3dde070755e`.
- Koma matching main: success 10.547 s; signed HAP 14,532,830 bytes; SHA256 `561646c04be952c36ce5d2688007f19cf46d2248458f55c451abd2a124f4ea6a`.

## Device 197 — actual native leaf

Target `192.168.50.197:12345`, ALN-AL80, portrait 1260×2720. No device 237 action occurred.

The first scoped Inspector attempt requested only `id`; it retained actual body/page/exit evidence but omitted `interpolation`, so the test deliberately ended `samplingUNVERIFIED`. That run is a retained counterexample, not a pass. The corrected read-only probe omitted the Inspector attribute filter, kept the raw tree in process, and serialized only safe attribute names plus whitelisted enum values.

Corrected run `05-unfiltered-native`:

- Native report: 1 run, 0 failure, 0 error, 1 pass; 13.443 s.
- Source index 2: actual Image node 723, canonical `medium`, exposed `interpolation=ImageInterpolation.Medium`, `samplingVerified=true`; body bounds 204.53×2720.
- Source index 3 after the real page turn: actual Image node 755, same canonical/exposed value, `samplingVerified=true`; body bounds 197.62×2720.
- The page turn, actual body availability, normal close to the NextN host and readonly presentation/repository signature all passed.
- Whole captures independently inspected: `ordinary.png`, `turned.png`, and `exit.png` under `.hermes-artifacts/20260912-interpolation-197/.../05-unfiltered-native/`.
- Final protocol `06-unfiltered-final` completed; portrait, original music/timeout state and lease were restored/released.

Three-value follow-through under `.hermes-artifacts/20260912-interpolation-low-high-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/`:

- The normal Reading settings UI first showed the original `优化（Mipmap）` value. It then selected `标准（双线性）` for `06-low-native`: source indices 2 and 3 exposed actual Image nodes 723 and 755 with canonical `low`, `ImageInterpolation.Low`, and `samplingVerified=true`.
- The same normal UI selected `高（双三次）` for `09-high-native`: the same two actual Image leaves exposed canonical `high`, `ImageInterpolation.High`, and `samplingVerified=true` across the real page turn.
- The normal UI restored `优化（Mipmap）`; `12-restored-medium-native` independently reconfirmed canonical `medium`, `ImageInterpolation.Medium`, and `samplingVerified=true` on both actual leaves.
- Whole setting captures were inspected for Low, High, and restored Medium. That review caught the long hint visually merging with the right-side value. The localized hint was narrowed to the neutral setting description while the menu labels retain `双线性` / `Mipmap` / `双三次`. Final install-r capture `16-quality-label-final` shows separate non-overlapping title, hint `[78,1280][651,1333]`, and restored value `[756,1246][1108,1299]`.
- Final protocol restored `OverrideTimeout=10000ms`, retained portrait 1260×2720 and normal audio state, and released both 197 leases. No device 237 action occurred.

## Device 103 — Koma host and continuous branch

Target `192.168.50.103:12345`, MLR-AL00 tablet, portrait 1600×2560. Independent five-page QA comic only; install used `-r` and retained app data.

Observed named paths under `/Users/honjow/git/Koma/.hermes-artifacts/20260912-reader-interpolation/qa103/device103__MLR-AL00/not-applicable/portrait-1600x2560/`:

- `02-medium`: canonical `medium`, single-page shared reader opens page 2/5 with an actual visible body leaf.
- `03-settings-menu`: normal Reading settings menu exposes Low / Medium / High and marks Medium selected.
- `04-low-paged`: normal UI selection persists `low`; page 2→3 changes the actual shared leaf from slot 1 to slot 3 and page status to 3/5.
- `06-low-continuous`: persists `continuous_scroll` + `low`; the real List is `[0,105][1600,2560]`, adjacent actual Image leaves occupy `[0,105][1600,743]` and `[0,743][1600,2560]` after the vertical scroll.
- `08-high-continuous`: persists `continuous_scroll` + `high`; the same branch scrolls with actual adjacent Image leaves `[0,105][1600,735]` and `[0,735][1600,2560]`.
- `09-restore`: normal UI restores `single_page` + `medium`; whole final settings screen inspected.

The apparent PAGE2 image at source index 3 was investigated before accepting the route. The QA archive intentionally repeats two source PNGs across five entries; `Chapter1/002.png`, `Chapter2/001.png` and `Chapter2/003.png` share SHA256 `56d5d0764d564d1877087211c226430a5faf4ecd302de8d1dfa27b70f7b667a5`. The actual leaf slot changed, so this is fixture duplication rather than stale image rendering.

Restoration proof:

- The original and final XML byte hashes differ because normal UI rewrote element order; formatted/sorted XML has zero differences, so all 22 typed values are exact.
- Library hash before/after: `6da5ebf8ae3828e443a472db8192eadd794c3999270929fc0f91f74a60f85a5c`.
- Reader-session hash before/after: `f0fdbd8fb6f7e315c450b57562380208553eee3c338d87a14adc63f42e1c9cce`.
- Final viewport is portrait 1600×2560, MUSIC remains 9, `OverrideTimeout=10000ms`, normal Koma Reading settings visible, and the lease is released.

## Device 103 — NextN continuous fit-width correction

The earlier 197 continuous capture exposed a real shared-reader regression: source index 2 occupied only about 205 px of a 1260 px reader instead of using the available width. The continuous List forced a row height while the cell root still requested `height('100%')`; the resulting constraints did not preserve the original image ratio. The correction makes the row itself full width with an intrinsic aspect ratio and lets the image fill that ratio-sized row. Failed rows retain the existing compact 220 vp recovery height.

The first 103 online rerun is retained as a rejected gate: the NH request produced no body response and Hypium reported `interpolation body unavailable:2`. It supplied no width evidence. The replacement gate uses an explicit debug-only, three-page local fixture through the same Reader Lab adapter and shared session. It does not change the saved layout or provide a release entry.

Accepted run `17-local-native-selector` under `.hermes-artifacts/20260912-continuous-fit-width-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/`:

- Native report: 1 run, 0 failure, 0 error, 1 pass; 12.502 s.
- Reader root and continuous List are both 1600×2560. Source page 0 is 1600×2400 from the fixture's actual 1024×1536 ratio, with no centered narrow strip.
- The actual Image leaf exposes `ImageInterpolation.Medium`; `samplingVerified=true` and `fitWidthVerified=true`.
- One in-list swipe moves the first row by -1561 px; `verticallyReachable=true`. Both before/after whole screenshots were inspected and show continuous content above and below the initial viewport.
- Reader presentation and repository quality signatures are identical before/after the debug override. The trial closes to the NextN host; no persisted mode, progress or reader-default change occurs.
- Exact tested packages: main 47,070,742 bytes, SHA256 `99127645ba3d072d354983005afeb4309a82a9f0541a0bec89fb2e64fe6b43e1`; native 43,647,891 bytes, SHA256 `d6bd6f45f713d542786a162b7ec970bf609c41c4c84006b35831d611a99e90ab`. Signed builds passed in 8.868 s and 8.430 s respectively.

The matching real-content follow-through on device 197 is `01-online-native` under `.hermes-artifacts/20260912-continuous-fit-width-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/`:

- Native report: 1 run, 0 failure, 0 error, 1 pass; 11.607 s.
- Real NH source index 2 is a 1260×16756.25 continuous row inside a 1260×2720 Reader/List, replacing the rejected roughly 205 px centered strip at the same device width.
- The actual Image leaf exposes `ImageInterpolation.Medium`, `fitWidthVerified=true`, and one in-row swipe moves the same row by -1657 px with `verticallyReachable=true`.
- Whole ordinary/scrolled screenshots were inspected. The large white areas are part of the source page itself; the row and actual Image geometry remain full width. Presentation/repository signatures remain unchanged and the trial closes to the NextN host.
- Exact native package for this follow-through: 43,647,765 bytes, SHA256 `64dc91749b177486ca6d99466e1366fd41f120dd0e5bdb51fbcef11f16c64378`; build passed in 8.759 s. Main package is unchanged from the 103 run.

## Cross-host continuous full-width regression

Koma was rebuilt against the corrected shared module and exercised through its normal Reading settings on device 103. The accepted run is under `.hermes-artifacts/20260912-continuous-fit-width-koma-regression-103/device103__MLR-AL00/not-applicable/portrait-1600x2560/`:

- The real optional reader List is 1600 px wide. Page 1 and its Image are `[0,0][1600,2311]`; after a vertical swipe page 1 moves to `[0,-1562][1600,749]` and page 2 becomes `[0,749][1600,3060]` without narrowing.
- The ordinary and scrolled whole screenshots were inspected. The independent five-page QA comic remains the only test fixture.
- Normal UI restored all 22 preference values exactly after temporarily selecting continuous mode. Library SHA256 stayed `6da5ebf8ae3828e443a472db8192eadd794c3999270929fc0f91f74a60f85a5c`; reader-session SHA256 stayed `f0fdbd8fb6f7e315c450b57562380208553eee3c338d87a14adc63f42e1c9cce`; timeout returned to 10000 ms.
- Matching Koma signed HAP: 14,537,859 bytes, SHA256 `1569e442fe8ec6b27e607b25c4c38a0ceef83cc6e52c963f617df1228618da93`; build passed.

NextE initially exposed a real host-policy drift: `ReaderLabRequest.entryLayoutOverride` accepted `continuous`, but `NextEReaderInitialPolicy` only applied `single` and `spread`, unlike the already validated NextN mapping. The first full-screen entry trial therefore finished its thumbnail transition without creating a continuous List and was retained as a failed gate. NextE now maps the optional continuous override to `layout=continuous` plus `pagingAxis=vertical`; production settings and defaults remain untouched.

The corrected full-screen thumbnail-entry run on device 197 is under `.hermes-artifacts/20260912-continuous-fit-width-nexte-entry-reflow-fixed-197/device197__ALN-AL80/not-applicable/portrait-1260x2720_to_landscape-2720x1260/01-native-reflow/`:

- Native report: 1 run, 0 failure, 0 error, 1 pass; the same reader epoch finished and closed back to the retained Detail P1 thumbnail.
- Before zoom the real continuous List is `[0,124][1260,2720]`; page 1 and its Image are `[0,124][1260,1779]`, proving fit-width rather than the former narrow strip.
- After 2× zoom and horizontal pan, portrait Image original bounds change horizontally while the List stays 1260 px wide. In landscape the full-screen List becomes `[0,0][2720,1260]` and the real Image remains present; returning to portrait restores the 1260 px List, and a second pan remains functional.
- All four whole screenshots were inspected: zoomed portrait, landscape, returned portrait, and post-rotation pan. Original orientation and timeout 10000 ms were restored; the 197 lease was released. No device 237 action occurred.
- Matching NextE packages: main 62,713,523 bytes, SHA256 `4ae42e70a2ddabf011ce9d2572ee63b9a7229f3db3dd149cda7f54cfcbabe1a0`; native 67,603,800 bytes, SHA256 `d2ebc01388b64fcab8b021e27c13f25c29cac2e21e3e9d5409c626fb29e7393a`. Both builds passed.

The follow-up actual enum run is under `.hermes-artifacts/20260912-interpolation-nexte-continuous-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-native/`:

- The same real full-screen thumbnail entry reached continuous P1, then the production settings repository changed only `reading.imageScalingQuality` from its original `medium` to Low and High in sequence.
- The scoped Inspector subtree contained one actual Image. Its retained evidence is exactly `ImageInterpolation.Low` and then `ImageInterpolation.High`; neither result is inferred from a label or shared state snapshot.
- Native report: 1 run, 0 failure, 0 error, 1 pass. The same entry epoch closed to the retained Detail P1 source. The changed preference was restored to `medium` in `finally`, and the before/after preference snapshots both confirm `reading.imageScalingQuality=medium` (unrelated background sync timestamps make raw-file byte identity unsuitable here).
- Both whole screenshots were inspected. The continuous page remains full-width with coherent reader chrome at both sampling points. Timeout returned to 10000 ms and the 197 lease was released; device 237 was not used.
- Matching native HAP: 67,627,018 bytes, SHA256 `96c37188fceeb60d9d5c619470fd9a7545563717918497a4868b0444ed3cca1b`; signed `entry@ohosTest` build passed in 11 s 675 ms. The main HAP is the same package recorded above.

The NextN device-protocol entrypoint now performs a second result gate after the manifest runner: Hypium output must report every test passed with zero failures/errors, and each `file recv` must report no HDC receive failure and produce a non-empty local artifact. This specifically prevents HDC exit code 0 from turning an internal test error or missing capture into a completed acceptance.

## Accepted and still open

Accepted only for these named paths: shared chain source/build gate; NextN actual Low/Medium/High paged Image leaves and real page turn; NextN local-fixture 103 and real-NH long-strip 197 continuous full-width geometry and vertical reach; Koma canonical medium paged plus low/high normal-UI selection, low/high continuous rendering/scroll, and corrected 1600 px continuous-row regression; NextE optional full-screen continuous entry with actual Low/High Image enums, fit-width, zoom/pan, portrait-landscape-portrait reflow, and retained-thumbnail close; exact state restoration; NextN final quality-row visual separation on 197.

Still open: cropped/split-body native enum sampling, failure/retry combinations, and complete default-reader replacement/regression acceptance. These gaps do not justify changing the existing default readers.
