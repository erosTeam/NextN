# Shared reader original-image interpolation — 2026-09-12

## Scope and boundary

This is an optional/debug-reader checkpoint, not a default-reader replacement. The change adds one UI-only `ImageInterpolation` parameter along the existing shared reader composition. It does not change Core policy, page/resource identity, geometry, decode ownership, transitions, gestures, persistence, defaults, or app routing.

- Paged: `ReaderSurface` → `ReaderPagerSurface` → `ReaderNativePager` → `ReaderPagedViewport` → `ReaderPagedCell` → `ReaderPagedImage`.
- Continuous: `ReaderSurface` → `ReaderContinuousSurface` → `ReaderContinuousList` → `ReaderContinuousCell` → `ReaderContinuousZoomImage` → `ReaderPagedImage`.
- Ordinary and cropped original bodies use the canonical host value.
- Thumbnail, sprite, rail and entry-preview sampling remain Low/current and are not coupled to the body setting.
- NextN, NextE and Koma Lab hosts map their already observable `low` / `medium` / `high` state. No new setting or writeback exists.

## Source and build gates

- `node --test --test-reporter=dot tests/*.test.cjs` in reader-kit: 300/300 pass. The new full-chain guard fails if any paged/continuous/cropped original hop drops the parameter or if the ordinary thumbnail branch stops retaining Low sampling.
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

## Accepted and still open

Accepted only for these named paths: shared chain source/build gate; NextN actual Low/Medium/High paged Image leaves and real page turn; Koma canonical medium paged plus low/high normal-UI selection and low/high continuous rendering/scroll; exact state restoration; NextN final quality-row visual separation on 197.

Still open: NextE device leaf capture, continuous/cropped/split-body native enum sampling, failure/retry combinations, and complete default-reader replacement/regression acceptance. These gaps do not justify changing the existing default readers.
