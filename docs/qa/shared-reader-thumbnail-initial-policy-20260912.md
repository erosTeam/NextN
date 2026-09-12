# Optional reader thumbnail initial policy — 2026-09-12

Status: **OPEN**. Default readers and product settings/progress writeback remain unchanged. Use197/103 only;237 excluded. This is not replacement approval.

## Source boundary and checks

- N/E full-chrome thumbnail entry now runs the existing canonical initial-policy chain before publishing the session, instead of using legacy default layout/direction. Explicit nullable overrides remain independent.
- Continuous entry publishes the actual whole-image destination only after current native List positioning and image measurement. A separate viewport clip does not alter the full-image transform or treat NH cropped thumbnails as whole-page equivalents.
- Identity covers the entry, source/slot/request/asset, navigation/topology, size and native-position epoch. Close, reflow, valid zoom lock and stale callbacks revoke the target. Ordinary no-entry List scroll/progress ownership remains unchanged.
- Independent review found and corrected pre-show cancellation, zoom-lock stale targets, and late-height changes during pending seek. Root reviewed exact source and actual-method tests:291/291 pass. These are not ArkUI/device acceptance.
- New native tests click actual Detail source2, assert saved policy/body/gesture/return, and preserve N's3exact RDB TEXT keys. N history assertion covers only last_read_index/has_read_progress; Detail may update last_opened_at. E reads current canonical state without fixture/settings/sync writes and requires current site plus finished handoff.

## Matching builds

| Package | Build result | Signed time / bytes | SHA256 |
| --- | --- | --- | --- |
| N main65640 | 12.362s success | 07:34:39 /47015934 | 3c19cc73ead87202fe889406acd9502aa9b765c55832ff3ba75945d8540b9ba0 |
| E main46490 | 13.742s success | 07:39:33 /62686786 | 07cc3b563c0d87505432d6378880df1ec5e05ab1d8010facc2dbcb65a760392c |
| K main40856 | 11.091s success | 07:40:11 /14507247 | d6e7eb6c8dc183bc4f4f067460b67df118e47174084f20afb8b9618321601928 |
| N native75319 capture correction | 8.474s success | 07:48:09 /43466380 | c14eb616089a58705690fe9bf73c171c761461973e891689b90bd6a66db4b7cc |
| E native15192 capture correction | 11.316s success | 07:48:56 /67510839 | fcf764e470330a732d109af5a1df8a18505079eb09e78d960a95fd51aa052c5f |
| N native93464 actual geometry (current) | 8.494s success | 08:01:25 /43465156 | 8152fee9a931ffbc25f9bd1284ba07d79c1f42360c592107e19760b3a361253c |
| E native42299 actual geometry (current) | 11.522s success | 08:06:00 /67510869 | e9750583ba5995c0c931274a64e6bac48b96ce94c372147ea2ba5e7a144add99 |
| N main72274 visible preview candidate | 9.897s success | 08:16:33 /47023309 | 109ba7d8f83e08c2851713684f13df7f8016d20bbdfe3079d9f52eef01344159 |
| E main27875 visible preview candidate | 11.591s success | 08:17:24 /62685964 | 4f89c22f71c2748bfaee5bafaf490d6ddfd7146367a777fd86031d056e85873b |
| K main18512 visible preview candidate | 8.807s success | 08:19:19 /14514622 | b5840f1b33150fe6fed564e6b1748b89c1951a00efe69242d9648704a39300e2 |
| N native71356 visible preview / strict continuous | 9.037s success | 08:26:03 /43475562 | ff2dab6c8e47e836076859fd4a69283979cdc4f46bde792ffbeb239a923a2069 |

Compiler warning retained: the two mutually exclusive clipped/nonclipped preview branches declare the same Image ID. Source exclusivity is not runtime ID/motion acceptance. No unrelated warning cleanup or product rewrite performed.

## Koma103 no-entry continuous regression — limited accepted

Candidate40856; evidence under `/Users/honjow/git/Koma/.hermes-artifacts/20260912-continuous-no-entry/qa103/device103__MLR-AL00/not-applicable/portrait-1600x2560`.

- Normal UI temporarily sets continuous; direct optional Lab entry for independent five-page QA work, source2. This route has no entryTransition.
- Root inspected whole originals04-initial/05-scroll/07-exit and their actual Koma roots: raw1600×2560, visible[0,105][1600,2560]. Blue source2 body and next red source3 are visible, not just a page-number assertion.
- Real swipe800,1900→800,1000 at700: source2 original top0→-1007; red source3 top2311→1304. Actual body displacement1007px.
- Original/final22typed preferences exactly equal; XML ordering differs, so not byte-equal. Library SHA256 `6da5ebf8ae3828e443a472db8192eadd794c3999270929fc0f91f74a60f85a5c` and sessions `f0fdbd8fb6f7e315c450b57562380208553eee3c338d87a14adc63f42e1c9cce` unchanged.
- Final normal Reading settings parent, MUSIC9,portrait,original override timeout10000 restored; lease20260911-234112-c40f094d released.
- Freeze only this named no-entry path. No thumbnail motion, cold/failure, real-source or full-reader acceptance inferred.

## NextN197 first native attempt — rejected before click

Evidence root `.hermes-artifacts/20260912-thumbnail-initial-policy-197/device197__ALN-AL80/not-applicable/portrait-1260x2720`.

- Main65640/native29509 paired install succeeded.04 native PID33524:1failure/0pass/19.121s at capture line55, before actual thumbnail click.
- CLI `uitest dumpLayout -a` succeeded and source JSON164152bytes was received. `executeShellCommand(cat ...)` returned-1: local AbilityDelegator API's explicit command list excludes cat. This is a test API misuse, not established product failure or output-size limit.
- Native finally logged exact3RDB keys restored and gallery column read-only. E was held before repeating the same broken capture.
- Test-only correction uses allowed cp into the known bundle cache and full fileIo read/JSON parse. Strict copy/read/parse and original bounds remain required; matching corrected native builds above still need device proof.
- Recording03 started07:44:23 and stopped07:47:23, but MediaLibrary export failed after bounded retries; no usable MP4. Actual test start was only2.215s after recording-start completion, so the intended3s pre-roll was not met. Neither motion nor complete recording coverage accepted.
- Original timeout10000/MUSIC3/desktop restored and old lease released. New attempt must use fresh artifacts/PID and actual recording timestamps; old exception/absent endpoint files cannot be counted.

## Next unverified physical action

- N12 corrected native75319 also fails before click: PID39390/19.188s, allowed cp returns256 with permission denied reading the shell-generated remote file. Its0644 mode and external shell read do not establish native application access. Finally again restores3exact keys; E held before repeating this path. Main source unchanged.
- N13 native86874 direct-cache smoke failed1/0 in2.772s PID42131 at CLI output exit256, before JSON read/screenshot and with zero fixture writes. No received file exists despite outer receive exit0.14 restored launcher/portrait/MUSIC3/10000 and released lease. Do not run the same failed path in E.
- Next use the existing project API: current ability/window UIContext ComponentUtils.getRectangleById for native actual row/list position and positive dimensions, with same-window/row identity; CLI -a remains in shell storage for host-only receive, and screenshot uses Driver.screenCap. Local SDK supports this API since10; existing N image-information and E thumbnail-entry suites already use it. Independent zero-fixture geometry/capture smoke first, then full realclick suite. Host still independently checks complete received raw JSON/root and original screenshots. No permission or SELinux changes and no clipped-bounds fallback.
- Review original screenshots and exported motion frames, not native PASS alone. Fix evidence preconditions without altering product to satisfy a test. Extreme EH sprites, slow/failure/cancel/reflow combinations and the broader replacement matrix remain OPEN.

N16 geometry/capture smoke: native93464 build8.494s,08:01:25/43465156 SHA256 `8152fee9a931ffbc25f9bd1284ba07d79c1f42360c592107e19760b3a361253c`; PASS1/0/8.029s PID49459,fixtureWrites0. Root independently parsed complete received JSON and inspected PNG: normal Browse, actual ROOT1245/NextN raw1260×2720 matches ComponentUtils root rectangle; clipped UiTest top124 differs from actual top0. Only the sampling channel is accepted, not any reader behavior. New lease20260912-000230-819202ba active during continuation; original MUSIC3/timeout10000 retained for restoration. Next realclick and E matching capture update.

### Additional source-proven geometry risk, motion not yet observed

For unknown-coverage partial thumbnails in a width-constrained continuous destination, current preview end top is `destination.y + (destination.height - destination.width * sourceAspectHeightOverWidth) / 2`. If that exceeds clip.bottom, the entire preview ends outside the visible clip during the280ms flight. The unknown-coverage retirement branch runs only after that flight, so it cannot prevent this.

N21 subsequently supplied actual source Image/content317×488 and actual original entry image/content1260×16756.25 at y0; List1260×2720. Root parsed raw and inspected originals: existing formula puts preview top7408.28px, outside clip. This is now source calculation from observed geometry, still not observed movement.

Minimal source correction implemented after pre-edit UI ledger: only unknown coverage with non-null clip uses the intersection as its preview contain container. It does not claim which original pixels the partial thumbnail represents. Original contentRect/identity/clip/scroll remain unchanged; whole-page and paged branches unchanged; empty intersection cancels before departure. Two actual-method tests fail before/pass after; full293/293 and independent review pass. New3main builds above are not device acceptance. Only affected N continuous preview needs reopening; unchanged E whole-page/no-clip and K no-entry routes are not repeatedly exercised.

## Original candidate197 endpoint results — limited acceptance

These observations use **N main65640 / E main46490**, before the visible-preview correction; they do not accept the new72274 preview or any motion.

- N21 main65640/native93464,PID50814: actual Detail source2 click→continuous P3/14 original→real upswipe→same source return. Root reviewed4whole originals plus exception and actualROOT1245/raw1260×2720. Original row/image height16756.25; top0 matches List0, then same row/window top−968. Native settings/progress-field assertions and exact3key restoration pass. Whole suite reports1error/0pass/53.654s because second Detail launch reused an old List object before new page mounted; RTL was not clicked. Do not relabel the whole suite PASS.
- N test-only route correction waits for the previous confirmed-visible source scope to disappear and requires a new source ID; strict rtl-spread selector permits independent missing-case verification. Native24503 build10.105s/08:12:34/43472387 SHA256 `de54bd5c8f544c8bab4fc05cc01725b28ea14dce7e614330c0aa9d25673f618f`.
- N24 RTL-only main65640/native24503,PID54325: PASS1/47.757s. Root inspected4whole originals andROOT1249/raw1260×2720: source2/right with source3/left at P3; actual right swipe→source4/right with source5/left at P5; returns same Detail thumbnail bounds. SPLIT part slots alone are not image-pixel geometry evidence; actual tall bodies are visible in the originals. Exact3keys restored/columnreadonly; stale exception file from21 excluded because24 never captured it.
- E23 main46490/native42299,PID52391: PASS1/58.473s. Root inspected4whole originals andROOT1247/raw1260×2720: actual source2 sprite thumbnail→P3 original→right swipe P4 airplane page→same source bounds. Actual handoff epoch1/siteeh/work4175844/pageIndex2/snapshotcaptured/movingObserved/phasefinished verified. Current savedrtl,single,odd; WebDAV busy remains enabled,fixtureWrites0,settings/target signature unchanged. Only this current read-only path accepted, not full E combinations.
-25 current original launcher image/root and raw power/window/music reviewed:focus10/raw1260×2720,MUSIC3,portrait,override10000 restored; lease20260912-000230-819202ba released. Root noticed a red camera-style status icon remains; actual recorder stop state is being separately investigated, not assumed from aa command success.
- Media export remains OPEN: short and full observed URI recv fail with source open error; size0 is not a usable MP4. No motion acceptance and no repeated identical recorder retries.

## Recorder notification clarification and affected-path continuation

-197 protocols26–29 establish that the red camera icon belongs to a historical screen-recorder completion notification: “录屏文件已保存至‘图库’”, not a recording-in-progress control. No stop/toggle or new recording was executed. This corrects the icon-based suspicion above; export failure remains separate and unexplained.
-29 closes notification shade and reads back launcher focus10, MUSIC3 and override10000; lease20260912-001854-8914b9d1 released. Notification image contains unrelated notifications and must not be used as the final UI illustration.
- N strict `continuous` selector now isolates the affected path without repeating frozen RTL endpoints. New main72274/native71356 are built; their real click/body/scroll/return and exact settings restoration remain the next unverified device action. Prior main65640 screenshots cannot accept this new candidate. No237 or E/K reinstallation for unchanged routes.

## Visible-preview candidate197 endpoint regression — limited accepted

-31 main72274/native71356 strict continuous, PID62939: PASS1/0/45.844s. Root reviewed all four current whole originals and independently parsed native output/raw actual ROOT1251, original1260×2720 versus visible[0,124][1260,2720]. Actual Detail source2 bounds[764,1960][1081,2448]→P3/14 body; same row2/image1260×16756.25 goes from top0 to−974 after real upward swipe; returns to the same Detail/source bounds.
- Native body-ready/no-pending/no-preview, target progress signature and exact3RDB TEXT key restoration assertions pass. Current PID logged no exception capture; received exception files are old21 leftovers and excluded.
- This accepts the new candidate's named settled entry/scroll/return regression, not its280ms visual flight. No usable recording was exported; motion remains OPEN, so the geometry formula and method tests are not relabelled as motion acceptance.
-32 root-reviewed launcher original and raw restoration: focus10/portrait1260×2720, MUSIC3 and override10000; lease20260912-002653-302c6c6b released. Shared source checkpoint `7d892fa` records this implementation, not full-reader or motion acceptance.
- Next source slice is read-only production custom tap-zone handoff: fixed shared thirds currently omit host behavior. Continuous production actions are±0.75viewport native scroll, not next-source navigation. Preserve this distinction and the optional/default/no-write boundaries. No edits to that slice yet.
