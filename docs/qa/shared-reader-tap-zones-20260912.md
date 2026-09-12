# Optional shared reader custom tap zones — 2026-09-12

Status: **OPEN**. No default-reader replacement or preference/progress writes in product code. Only197 and103;237 excluded. Previous thumbnail checkpoint: shared7d892fa / NextN8413c9c, unrecorded entry flight remains OPEN independently.

## Contract and source review

- Three production readers already resolve two-dimensional saved tap zones. N/E keep paged and continuous preferences separately; Koma has one global preset/invert, including its normalized legacy `wide_edges` alias. Root read all three actual resolvers and action handlers, not just method names.
- Shared surface accepts nullable synchronous `(xFraction,yFraction,ReaderLayout) => ReaderTapAction`, preserving logical previous/next versus physical left/right, plus menu/none. Only physical actions use the current runtime direction. No host preference schema was moved into core.
- Paged gestures pass both actual coordinates. Continuous gestures use API20 windowX/windowY in vp against current native List rectangle converted from px; never divide by the long image height. Invalid/missing geometry does nothing. Native List retains scrolling and uses ±0.75viewport, not session.move to a different original.
- N/E host callbacks choose preference fields from actual runtime layout, not saved mode. Koma reuses hydrated ReaderModeState published by its existing awaited load. No additional restore/load or mutation. Independent host review found no blocker; complete initialization-to-render execution still needs device evidence.
- Root review intercepted candidate regression: an added global zoom lock would block showing chrome during stable zoom. Corrected before build: paged stable zoom retains existing menu/navigation, continuous owner zoom permits menu but cannot scroll List. New actual-method tests failed before and passed after. Existing gesture exclusivity/pinch/tap suppression remain.
- Shared299/299 actual-method tests pass; host1404 actual resolver comparisons plus lifecycle/no-write assertions pass. They are not UI acceptance. Canonical initial-policy method suites also pass after host additions.

## Matching candidate main builds

| Host | Build | Signed time / bytes | SHA256 |
| --- | --- | --- | --- |
| NextN |64300 /12.657s success|08:42:01 /47035975|4305bae0af857c897917e73cf96010fcb30ad2900a12cf8e34ff3279f5def5bc|
| NextE |52302 /14.454s success|08:42:46 /62702559|a53fbbf27d7999e8579b2bc089389dfb6cfdf6b9433c6db64b91a6ebb14e55c0|
| Koma |11698 /11.467s success|08:43:37 /14527380|710c92c24e165fb29f849b83997e529ee6ae011fa45d3469b8fe8c182a4312d0|

Native matching builds: N81464 /10.693s,08:49:04/43535318 SHA256 `e9dcc3db0dc20eb9255d2cb6c79b6850c4f0ac00f6f14e7f512bca682a796954`; E25533 /13.626s,08:52:27/67546192 SHA256 `22f4309591b5d2a07996c0e39405984047fe42832b3591ff852373e9c5c1c0e2`.

## NextN197 old-main baseline — not candidate acceptance

Evidence `.hermes-artifacts/20260912-tap-zones-baseline-197`, installed main72274. No new install or fixture writes, no production Reader body entry.

- Root reviewed whole originals04,06,07,08,09,10,11 and relevant raw image/viewport bounds. Normal Reading settings show paged and continuous both rightLeft/none, savedRTL and double-page off.
- Actual viewport ROOT1251 original1260×2720; chrome-visible UiTest area starts y124, hidden chrome reaches y0. Original image itself remains[528,0][733,2720].
- P3 actual long body→left1/6 tap(210,1360)→P4 different actual body→right5/6(1050,1360)→P3. Center(630,1360) hides/shows chrome; More opens image-information item without page change. Back/close returns to the same Reading settings.
-12 reads original timeout10000, MUSIC3, portrait and current N window1251; lease20260912-003439-d8f4385b released. This proves only old fixed-thirds baseline, not custom2D behavior or zoom/retry.

## Next unverified actions

- N197 paired native L-shaped/none tests: temporary six exact TEXT keys with existence/live restoration; pagedRTL topcenter logicalprevious/bottomcenter next/menu; continuous actual same-row±0.75viewport displacement; stable2x menu and More isolation. Legacy tap fallback keys, parity and progress remain read-only signatures. No failure fixture exists for retry isolation: retain that row OPEN.
- Koma103 existing independent five-page QA work: normal UI temporary settings, typed preferences and library/session hashes retained/restored; candidate portrait/landscape actual coordinate actions and scrolling, zoom menu and exit. Candidate11698 build is not device acceptance.
- E197 keep enabled sync and use current canonical zones read-only. Do not turn off synchronization to run a full mutation matrix; current-path evidence cannot substitute for all presets/inverts.

## N197 first native result — FAIL, named earlier endpoints only

- Main64300/native81464,02-native PID9756 actualROOT1253, FAIL1/0/36.908s. Root reviewed five whole originals and native/raw: actual L-shaped topcenter P3/source2→P2/source1, bottomcenter→P3/source2; More shows image-information item without navigation. Those inputs are distinct from the old horizontal-thirds baseline.
- Immediately after More capture the test calls pressBack then center tap without first establishing menu dismissal. `hideChrome` asserts null but chrome remains visible. Exception capture shows menu absent later, not proof that it was absent at the input instant. No root-cause or product-regression conclusion inferred; zoom and continuous not reached.
- Finally reports six exact entry TEXT keys restored, legacy/column/history unchanged.03 reads launcherfocus10,portrait,MUSIC3 and original10000; lease released. Old/missing remaining endpoint files cannot be counted.
- Next test-only repair requires bounded menu absence/current reader confirmation before a single next tap; no repeated blind taps and no disabling product menu input protection. Keep failure artifact, rebuild matching native, then re-execute; source candidate remains unchanged. E independent current read-only test can run separately.

## Koma103 in-progress observations — restoration still pending

- Root reviewed actual whole originals04/05/06 and08/09/10, currentROOT95 and raw List/image bounds. Portrait source2 originaltop0→1920→0 at actualList1600×2560; landscape0→1200→0 at List2560×1600. These are±75% viewport movements, not a next-source command. Source2 image height changes2311→3698 with width as expected.
- Only current continuous named endpoints observed. SingleRTL/zoom menu, preference/hash restoration and final exit still pending; do not mark whole103 suite accepted yet.

## Further physical review — named endpoints, not whole parity

- Root reviewed Koma originals12–20 and raw currentROOT95: portrait1600×2560 and landscape2560×1600, actual source2→source1→source2 in both orientations. Portrait normal image1600×2311 becomes3200×4622 at stable2x, with chrome visible and source2 unchanged. Landscape image1108×1600 remains contained.
- Root reviewed continuous22/23/24 originals: stable2x body retains its pixel position while center input shows then hides chrome; actual List1600×2560 and source2 row[0,0][1600,2311] remain identical. These are double-tap zoom/menu endpoints, not real two-finger pinch acceptance.
- A second reviewer reported a central black block in20. Root directly reopened that exact original: central blue body and white circle are fully present. That report is not established product evidence and cannot justify a product patch; independent same-file recheck requested. Original is retained, not overwritten.
- E197 native05 fails before opening Lab: canonical restore is notStarted versus applied (1ms). No fixture writes or current captures; stale receive files excluded. Test-only repair starts normal EntryAbility and boundedly waits for existing canonical restore before unchanged read-only assertions. Main source stays frozen; matching native rebuild and physical rerun remain required.
- N197 corrected native76078 rerun is in progress; Koma final preference/hash/exit readback remains pending at this record.

## N197 corrected run and Koma103 closure

- N06 main64300/native76078 PASS1/0/93.491s PID15331. Root read native capture/restoration logs, current NextN EntryAbility ROOT1256 original1260×2720, and all13 named whole originals. Actual source2→1→2; stable2x actual image205×2720→410×5440 retains the same bounds across chrome shown/hidden/More. Continuous same source2 rowtop0→−2040→0 at List height2720; More leaves top0. Closed capture returns normal Browse. Old exception files lack this run's capture marker and are excluded.
- N finally restores six exact entry TEXT keys and preserves named legacy/column/history fields; no sync flush.07 physical exit reads launcherfocus10/portrait/MUSIC3/10000; lease retained only for separate E rerun. This accepts the named L-shaped/no-inversion paths, not every preset or retry isolation.
- Koma103 final07 current normal Reading settings original1600×2560 root-reviewed. Agent compared all22 typed preferences with zero differences; library/session SHA unchanged, MUSIC9 and10000 restored, lease released. Root reviewed source identity/bounds for portrait and landscape paged paths,2x original geometry and continuous22/23/24 unchanged List rows plus full originals. Named L-shaped paths accepted only. Agent independently reopened20 and withdrew its erroneous black-block reading; no product change followed.
- E test-only bootstrap correction build27924 succeeds11.816s, native09:03:34/67554006 SHA256 `6c9c26e7883d7752e8a84641f11ac3e1f0bd76ecca9cd65934f047aaa57d5c78`. Device rerun remains the next unverified action; main52302 unchanged. No default replacement or writeback.

## E197 read-only closure and next boundary

- E09 main52302/native27924 PASS1/0/40.657s PID18571. Root reviewed all six current originals and raw EntryAbility ROOT1258/1260×2720: initial source2/P3, center hides chrome; actual saved region(.1667,.5) moves to source3/P4; region(.5,.7083) returns source2/P3; center shows chrome; exit returns normal Non-H Gallery. Image actual1260×1779 at y471, correct distinct original bodies visible. Current policy signature stayed unchanged; no fixture writes, restore calls or sync changes. This is current saved paged-policy acceptance only, not continuous/zoom/full preset matrix for E.
- Final10 raw/original launcher1260×2720 reviewed, MUSIC3 and10000 readback; lease released. Both devices have completed this bounded run. Previous failures remain retained as test-precondition failures, not silently relabelled.
- Next slice is an implementation-precondition audit of passive page-number preference: three production hosts have a saved flag while shared passive status is currently unconditional. Preserve chrome navigation page count, inspect complete owners and rejected approaches before a minimal read-only optional handoff. Background/quality/gaps/animation, actual retry isolation, full-preset matrix, Koma real pinch and chapter-failure/cancel, thumbnail motion and progress compatibility remain separately OPEN. Defaults and writeback stay disabled.
