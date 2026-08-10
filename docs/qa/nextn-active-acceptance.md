# NextN active device-acceptance queue

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
- All temporary screenshots used for these observations were deleted from the
  host and device. The repository postmortem is recorded at
  `docs/postmortems/2026-08-10-account-persistence-p0.md`. This queue remains
  OPEN until the user explicitly requests closure.

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
- Next physical action: continue the Gallery Detail / Comments reference
  review from a real same-state capture, then make only the next proven
  parent-tree or geometry correction as a separate commit.

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

## Current transport state

- The selected TCP target `192.168.50.237:12345` is currently Connected and
  remains the only device used; the USB target was not used as a substitute.
- The current lease is renewed. The latest wake gate readback is `AWAKE` with
  `OverrideTimeout=86400000ms`.
- The latest Debug HAP was installed with `install -r` only; no uninstall,
  application-data clear, or broad data deletion was performed.
- Raw temporary layouts used solely for safe structural summaries were deleted
  from both host and device immediately after summarization.
- UI static contract and summary tooling has been removed and is not permitted.
  Account persistence is judged only from the durable source owner, signed
  build, and real cold-start state.

## Next physical action

P0 remains conditional: do not create a login attempt from historical evidence,
but immediately preempt P1 if a fresh native Account or Favorites observation
proves the session unusable. Otherwise continue P1 using the existing direct
Gallery route for `471768`: preserve a named local NextN Detail/Comments audit
capture, compare only with a genuinely same-state reference, then make one
source-proven parent-tree or geometry correction in its own commit. Keep this
queue OPEN until the user explicitly requests closure.

## Data and artifact boundary

Never place credentials, account/profile strings, cookies, tokens, raw Web
layouts, or screenshots in this file. Retain raw device and host artifacts in
a named local audit directory when they are used for visual review; never add
them to source control and never delete them automatically.

Use `scripts/probe_arkweb_login_state.mjs` only for its fixed, read-only CDP
summary while a visible login surface exists. UI static summary tools are not
permitted in this repository.
