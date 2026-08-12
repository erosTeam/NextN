# NextN re-login attempt ledger

This is an append-only, redacted audit ledger for autonomous NextN account
cycles on the explicitly selected device. It makes a distinction that must
never be blurred:

- **Login-page navigation event:** the app displayed a visible ArkWeb login
  route. It starts a time-tracked login cycle even if credential entry does
  not follow.
- **Re-login attempt:** the credential-entry subphase within that cycle. It
  starts only when the account credential is actually entered through the
  semantic field driver.

For every login cycle, write `session-loss-detected-at` immediately after a
cold-start S0 check finds the session absent, then write
`webview-opened-at` when the login route becomes visible. On success, write
`native-promotion-at` and `loss-to-promotion-elapsed`. If no native promotion
occurs, write `last-observed-at` and `elapsed-so-far` before yielding or
switching lanes. Before opening another WebView, review the preceding cycle's
reason, terminal state, and duration. Historic cycles without a recorded
start or terminal timestamp must be marked
`unavailable-from-existing-evidence`; do not reconstruct or estimate their
duration.

## Current execution status

As of the last recorded device result, **no credential epoch or login cycle is
active**. The later native re-verification and cold-start records below closed
the earlier timed entries; their historical headings and timestamps are kept
unchanged as evidence of the overruns, not as instructions to resume them.

A new cycle may begin only after a fresh current S0 observation proves native
Account or Favorites unusable. It must append a new redacted record and never
reuse an old “active”, “prepared”, or “pending” field as a live action. A
source change, build, documentation change, historical login failure, or a
desire to reconfirm the path is not a trigger.

**Normal-path limit:** when the authorized credentials and submit path are
ready and no challenge is present, `loss-to-promotion-elapsed` must be at most
00:01:00. For every overrun, record the first blocking phase
(`credential`, `form`, `challenge`, `network`, or `native-persistence`) and
the measured elapsed time. A later retry never erases that overrun.

**Execution rule:** all build/install, wake/lease, prior-cycle accounting, and
route preparation happen before `session-loss-detected-at`. During a timed
cycle, only the prepared native route and semantic credential sequence may
run. Source inspection, documentation edits, layout analysis, helper work,
and unrelated diagnostics are prohibited until native promotion or a recorded
overrun; none may reset the timing origin.

## Hard gate

Before S2 input, append a new attempt record with all of the following:

1. A concrete reason code for why the current S0 state warrants a new
   attempt, rather than a speculative retry.
2. Current redacted Account and Favorites safe outcomes.
3. The available fixed restore/401 diagnostic stage, or an explicit
   `diagnostic-inconclusive` marker and the repair required before input.
4. Confirmation that this run used neither app-data clear nor uninstall.
5. A volatile attempt epoch identifier that contains no secret or account
   identity.

No record or an inconclusive reason prohibits account input, password input,
and submit. The record must not contain credentials, account/profile values,
cookies, tokens, URLs, raw layouts, screenshots, DevTools ports, or target
metadata.

## Entry template

```text
### <redacted attempt epoch> — <date/time>

- trigger: <concrete reason code and non-secret explanation>
- S0 Account: <fixed safe booleans/state>
- S0 Favorites: <fixed safe booleans/state>
- restore/401 diagnostic: <fixed stage or diagnostic-inconclusive>
- install/data boundary: install-r=<true|false>; data-clear=false; uninstall=false
- login-page navigation: <not-entered|entered>
- session-loss-detected-at: <ISO-8601 local timestamp|unavailable-from-existing-evidence>
- webview-opened-at: <ISO-8601 local timestamp|unavailable-from-existing-evidence>
- native-promotion-at: <ISO-8601 local timestamp|pending|not-applicable>
- loss-to-promotion-elapsed: <duration|pending|unavailable-from-existing-evidence>
- last-observed-at: <ISO-8601 local timestamp|not-applicable>
- elapsed-so-far: <duration|not-applicable>
- account input: <not-started|entered|not-entered>
- password input: <not-started|entered|not-entered>
- submit: <not-issued|issued>
- post-submit native promotion: <pending|fixed safe state>
- cold-start Account: <pending|fixed safe state>
- cold-start Favorites: <pending|fixed safe state>
- conclusion: <accepted|repair-required|not-a-relogin-attempt>
```

## Historic timing baseline

The entries below predate mandatory WebView-to-promotion timing. Their
per-cycle durations are `unavailable-from-existing-evidence`; the date-only
records and whole-turn durations elsewhere in the workspace are not a valid
substitute for measured login-cycle elapsed time.

## Closed strict-timing login cycle — 2026-08-10

- trigger: user-directed data-preserving cold restart after the prior cycle
  exceeded the intended navigation budget.
- session-loss-detected-at: 2026-08-10T04:47:33+0800 (strict conservative
  start captured at the cold-start command boundary; no later timestamp may
  replace it).
- login-route checkpoint-at: 2026-08-10T04:48:41+0800.
- webview-opened-at: 2026-08-10T04:48:41+0800 (first post-action route
  checkpoint; the later semantic probe confirmed the visible login form).
- native-promotion-at: not-applicable.
- loss-to-promotion-elapsed: not-achieved.
- route-checkpoint elapsed: 00:01:08; this exceeded the 00:01:00 ceiling
  before form confirmation or credential input.
- first blocking phase: navigation workflow.
- credential-path result: 2026-08-10T04:50:12+0800;
  `keychain_handle_unavailable`; no account/password value was read, entered,
  cleared, or submitted.
- password-autofill check: 2026-08-10T04:53:54+0800; semantic password focus
  left both fields empty and the submit control disabled. This was an
  observation inside the same cycle, not a new login attempt.
- last-observed-at: 2026-08-10T04:53:54+0800.
- elapsed-so-far: 00:06:21.
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- account input: not-started.
- password input: not-started.
- submit: not-issued.
- conclusion: measured-overrun; native login was not achieved. No later login
  cycle may erase this 00:06:21 result.

## Prepared direct-route cycle — 2026-08-10

- trigger: all route, device, ArkWeb-channel, and credential staging work was
  completed before this timestamp; begin a fresh data-preserving recovery run.
- session-loss-detected-at: 2026-08-10T05:43:33+0800.
- webview-opened-at: 2026-08-10T05:44:53+0800.
- native-promotion-at: not-achieved.
- loss-to-promotion-elapsed: not-achieved.
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- post-submit native promotion: not-applicable.
- cold-start Account: not-applicable.
- cold-start Favorites: not-applicable.
- conclusion: measured-overrun. The private stdin wrapper failed before either
  field write; this epoch is closed and cannot be retried in place.

### Terminal observation — prepared direct-route cycle

- webview-opened-at: 2026-08-10T05:44:53+0800 (the direct route and current
  empty form were live; no credential field changed).
- last-observed-at: 2026-08-10T05:44:53+0800.
- elapsed-so-far: 00:01:20.
- first blocking phase: form executor transport; the host tool closed the
  runner's private stdin before either secret line could be delivered.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- native-promotion-at: not-applicable.
- loss-to-promotion-elapsed: not-achieved.
- conclusion: measured-overrun; no credential was exposed, entered, cleared,
  or submitted. This attempt epoch is closed and cannot be retried in place.

## Keychain-prepared direct-route cycle — 2026-08-10

- trigger: the prior epoch closed before any field write; the fixed Keychain
  slots were provisioned and the direct recovery route plus ArkWeb channel
  were already verified before this fresh data-preserving cold start.
- session-loss-detected-at: 2026-08-10T05:48:44+0800.
- webview-opened-at: observed in the device status-bar minute 05:53; exact
  seconds were not retained.
- native-promotion-at: observed at 2026-08-10T05:55:12+0800; the native
  Account surface was signed in and the login WebView was absent.
- loss-to-promotion-elapsed: 00:06:28 to the retained native-success
  observation (the exact transition second was not retained).
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- account input: completed once through the semantic Keychain-to-private-CDP
  path; no value retained.
- password input: completed once through the semantic Keychain-to-private-CDP
  path; no value retained.
- submit: issued once through the current semantic Login control after the
  temporary CF screenshot showed a green-success state.
- post-submit native promotion: observed; native Account showed signed-in
  state and no visible WebView.
- cold-start Account: observed at 2026-08-10T05:58:00+0800 (device
  status-bar minute): the native Account destination still showed signed-in.
- cold-start Favorites: observed at 2026-08-10T05:56:00+0800 (device
  status-bar minute): authenticated native gallery content was present and no
  sign-in prompt or WebView was visible.
- conclusion: native promotion observed. This timed cycle exceeded the
  00:01:00 ceiling before form execution because preparation and route work
  occurred after the loss timestamp; the WebView form itself was filled,
  CF-reviewed, submitted, and promoted continuously. S6 cold-start and
  authenticated Favorites verification completed without clearing data. The
  required postmortem is recorded at
  `docs/postmortems/2026-08-10-account-persistence-p0.md`; no task closure is
  recorded in this ledger.

## Pre-timing current login cycle — 2026-08-10

- trigger: the latest signed Debug HAP was installed with `install -r`, then
  force-stopped/cold-started without data clearing. The fixed restore stage was
  `account_restore_record_absent`, so native Account entered its explicit
  login route.
- S0 Account: signed-out native Account with explicit Login action.
- S0 Favorites: prior current-run safe state was native sign-in prompt.
- restore/401 diagnostic: `account_restore_record_absent`.
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- login-page navigation: entered.
- webview-opened-at: unavailable-from-existing-evidence; this WebView was
  opened before the mandatory timing rule was added, so no start timestamp is
  being invented.
- native-promotion-at: not-applicable.
- webview-to-promotion-elapsed: unavailable-from-existing-evidence.
- last-observed-at: 2026-08-10T04:41:49+0800.
- elapsed-so-far: unavailable-from-existing-evidence.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- conclusion: not-a-relogin-attempt. The current form was semantically empty;
  no credential was fabricated or submitted. The next cycle begins after the
  user-requested data-preserving restart and will have an immediate measured
  WebView timestamp.

## Cumulative measured login-cycle time

- timed cold-start-to-login cycles observed: 5.
- completed native-login successes with a bounded observation duration: 1.
- measured cumulative elapsed across timed cycles: 00:17:04.
- measured cumulative native-login-success time: 00:06:28 to the retained
  native-success observation.
- recorded overrun count: 5.
- historic-cycle total: unavailable-from-existing-evidence; the older ledger
  records do not contain matching WebView-open and native-promotion timestamps.

## Current navigation event — 2026-08-09

- trigger: latest Debug `install -r` followed by force-stop/cold start; the
  current native Favorites summary showed a sign-in prompt and the Account
  destination showed a visible login Web surface.
- S0 Account: visible-login-Web-present; native-account-section-absent.
- S0 Favorites: native sign-in prompt present; no visible Web; no loading,
  empty, or error state.
- restore/401 diagnostic: diagnostic-inconclusive; the fixed stage collector
  did not yield a stage in this run, so it does not establish a root cause.
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- login-page navigation: entered.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- post-submit native promotion: not-applicable.
- cold-start Account: not-applicable.
- cold-start Favorites: sign-in-prompt.
- conclusion: not-a-relogin-attempt; persistence P0 repair required before
  any credential action.

## P0 cold-start diagnostic event — 2026-08-09

- trigger: non-destructive restore fix installed with `install -r`, then
  force-stop/cold-start to classify the existing local session without opening
  or submitting the login form.
- restore/401 diagnostic: `account_restore_record_absent`.
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- login-page navigation: not-entered by this event.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- conclusion: not-a-relogin-attempt. The pre-fix code had already removed the
  sealed record, so this event cannot be misreported as a runtime proof of the
  new record-preservation branches.

## P0 invalidation-scope cold-start event — 2026-08-10

- trigger: source hardening restricted account invalidation to explicit
  sign-out or a replayed authenticated account read that again returns 401;
  public catalog reads and single mutation 401 responses retain the sealed
  record. The signed Debug HAP was installed with `install -r`, then
  force-stopped/cold-start without opening or submitting the login form.
- restore/401 diagnostic: `account_restore_record_absent`.
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- login-page navigation: not-entered by this event.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- conclusion: not-a-relogin-attempt. The current device still has no sealed
  record, so this check does not claim record-present persistence acceptance.

## P0 durable-verification deployment — 2026-08-10

- trigger: final source hardening adds a persistent verification-required
  state, authenticated-read transition fencing, and durable-first explicit
  sign-out. The signed Debug HAP was installed with `install -r`, then
  force-stopped/cold-started without any login interaction.
- restore/401 diagnostic: diagnostic-inconclusive; the bounded fixed account
  tag yielded no new stage, while the NextN ability was confirmed foreground.
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- login-page navigation: not-entered by this event.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- conclusion: not-a-relogin-attempt. This deployment verifies build/install
  continuity only; record-present persistence still requires a future valid
  S0--S6 run and cannot be fabricated from the currently absent record.

## P0 active-session and RDB-rebuild hardening deployment — 2026-08-10

- trigger: signed Debug deployment of the active-session restore fast path and
  rebuilt/repaired-RDB absent-record verification gate, followed by
  `install -r` and force-stop/cold-start.
- S0 Account: not opened in this event; no visible login route was entered.
- S0 Favorites: native sign-in prompt; no visible Web, loading, empty, or
  error state.
- restore/401 diagnostic: not collected; this is a no-record S0 observation,
  not evidence of a new persistence cause.
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- login-page navigation: not-entered.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- post-submit native promotion: not-applicable.
- cold-start Account: not-opened by this event.
- cold-start Favorites: sign-in-prompt.
- conclusion: not-a-relogin-attempt. No credential was read, entered, cleared,
  or submitted; record-present S6 verification remains pending a future
  authorized epoch with the fixed Keychain handles available.

## Current P0 S0 observation — 2026-08-10

- trigger: after the latest signed Debug `install -r` and ordinary application
  launch, native Favorites displayed a session-recheck error. This was not a
  force-stop/cold-start timing boundary, so no loss-to-promotion timer is
  invented from it.
- S0 Account: native signed-in Account row observed.
- S0 Favorites: native session-recheck error; no visible Web observed.
- restore/401 diagnostic: pending paired S0 and named diagnostic branch.
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- login-page navigation: not-entered.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- conclusion: not-a-relogin-attempt. Account-persistence P0 is active: the
  Account surface is signed in but Favorites cannot recheck the session. The
  normal Favorites retry returned the same error. The next action is its
  source-grounded diagnostic path; no credential action is allowed.

## Closed cold-start recovery cycle — 2026-08-10

- trigger: the built recovery-order fix was installed with `install -r`, then
  NextN was force-stopped and cold-started without data clearing. Favorites
  then showed its native sign-in-required state.
- S0 Account: pending direct native Account observation during the prepared
  recovery route.
- S0 Favorites: native sign-in-required state; no visible Web observed.
- restore/401 diagnostic: diagnostic-inconclusive at this timestamp.
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- login-page navigation: not-entered.
- session-loss-detected-at: 2026-08-10T12:57:07+08:00.
- webview-opened-at: pending.
- native-promotion-at: pending.
- loss-to-promotion-elapsed: not-achieved.
- last-observed-at: 2026-08-10T12:58:50+08:00.
- elapsed-so-far: 00:01:43.
- first blocking phase: form — the native Account route had not reached its
  visible WebView form before the 60-second ceiling.
- account input: not-started.
- password input: not-started.
- submit: not-issued.
- conclusion: measured-overrun; no credential action occurred. This epoch is
  closed and may not be continued in place. Its terminal native Account state
  was re-verification-required; the paired cold-start Favorites state was
  sign-in-required.

## Prepared re-verification cycle — 2026-08-10

- trigger: the prior no-input cycle is closed. Current Account is natively
  re-verification-required and Favorites is natively sign-in-required after
  a data-preserving cold start.
- S0 Account: native re-verification-required state.
- S0 Favorites: native sign-in-required state.
- restore/401 diagnostic: native verification-required state after the
  recovery-order cold-start check; no secret or transport detail retained.
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- preparation: selected-device lease and awake-timeout gate are current; both
  fixed credential handles passed the presence-only check before this timer.
- login-page navigation: not-entered.
- session-loss-detected-at: 2026-08-10T13:02:06+08:00.
- webview-opened-at: unavailable-from-existing-evidence; the native action
  was issued in this cycle but the exact visible-Web timestamp was not retained.
- native-promotion-at: pending.
- loss-to-promotion-elapsed: not-achieved.
- last-observed-at: 2026-08-10T13:03:18+08:00.
- elapsed-so-far: 00:01:12.
- first blocking phase: form — the bounded ArkWeb discovery helper cleaned
  its forwarding before the semantic driver could use it.
- account input: not-started.
- password input: not-started.
- submit: not-issued.
- conclusion: measured-overrun; no credential action occurred. This epoch is
  closed and may not be continued in place.

## Browser-session re-verification and final S6 — 2026-08-10

- trigger: after the closed no-input cycle, the explicit native
  re-verification action promoted the existing first-party browser session.
  No account/password field was written and no submit action was issued.
- native Account after promotion: signed-in native state observed.
- immediate Favorites result: a session-transition fence was observed once;
  one post-settlement retry then completed an authenticated native read.
- final cold-start Account: force-stop/cold-start without data clear or
  uninstall; signed-in native Account observed.
- final cold-start Favorites: authenticated native content observed with no
  sign-in prompt or error state.
- conclusion: current record-present cold-start path accepted. The two prior
  no-input timed overruns remain recorded above and are not erased by this
  later browser-session recovery.

## Fresh browser-session recovery and S6 — 2026-08-10 19:24-19:33 +0800

- trigger: a fresh native Favorites observation showed sign-in-required and
  the paired native Account destination showed verification-required,
  immediately preempting the delivery lane.
- S0 Account: native verification-required state.
- S0 Favorites: native sign-in-required state; no visible Web observed.
- restore/401 diagnostic: native verification-required state; no secret or
  transport detail retained.
- install/data boundary: install-r=none-this-cycle; data-clear=false;
  uninstall=false.
- login-page navigation: not-entered; the explicit native re-verification
  action promoted the existing first-party browser session without a visible
  login WebView.
- session-loss-detected-at: 2026-08-10T19:24:00+08:00.
- webview-opened-at: not-applicable; no visible login WebView was opened.
- native-promotion-at: 2026-08-10T19:27:00+08:00 (native Account signed-in
  after the re-verification action).
- loss-to-promotion-elapsed: 00:03:00.
- last-observed-at: 2026-08-10T19:33:00+08:00.
- elapsed-so-far: 00:09:00 including the one settlement retry and the
  data-preserving cold-start verification.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- cold-start Account: signed-in native state after force-stop/cold start
  without data clear.
- cold-start Favorites: authenticated native content observed with no sign-in
  prompt or error state.
- conclusion: current record-present cold-start path accepted for this fresh
  cycle. This recovery did not enter a credential epoch and does not erase
  any prior measured overrun.

## Fresh paired invalid-session observation — 2026-08-10 23:06-23:08 +0800

- trigger: ordinary root navigation only; this was not a cold-start timing
  boundary and therefore starts no loss-to-promotion timer.
- S0 Favorites: native sign-in prompt; no visible Web, loading, or error
  surface.
- S0 Account: native re-verification-required state.
- restore/401 diagnostic: not yet collected in this event; no session cause is
  inferred from the visible state.
- install/data boundary: install-r=none-this-event; data-clear=false;
  uninstall=false.
- login-page navigation: not-entered.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- conclusion: not-a-relogin-attempt. This paired current state activates P0;
  the next action is the explicit native re-verification route. A credential
  epoch is forbidden unless that route actually produces the visible form.

## Native re-verification recovery and cold-start read — 2026-08-10 23:06-23:22 +0800

- trigger: continuation of the paired ordinary-navigation invalid-session
  observation above; no cold-start loss-to-promotion timer is invented.
- recovery action: one explicit native re-verification action was issued. It
  returned native Account to signed-in at 23:13 without a visible Web form,
  credential field write, or submit.
- immediate Favorites: the first post-promotion read reported a native
  transition-in-progress state. One ordinary settlement retry at 23:16 then
  showed authenticated native content.
- persistence check: NextN was force-stopped and cold-started without data
  clear, uninstall, or install. Native Account was signed in at 23:20 and
  Favorites showed authenticated native content at 23:22.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- conclusion: this observed recovery survives one subsequent cold start, but
  the preceding fresh invalid-session cause is not established. P0 remains
  open; this result must not be described as a general persistence fix.

## Retained-browser recovery deployment regression — 2026-08-10 23:25-23:35 +0800

- trigger: a source change now gives the existing retained ArkWeb identity one
  bounded refresh-and-verify opportunity after the sealed-token replay fails,
  before a durable re-verification marker is written.
- install/data boundary: signed Debug installed with install-r=true;
  data-clear=false; uninstall=false.
- persistence check: the updated app was force-stopped and cold-started.
  Native Account was signed in and Favorites showed authenticated native
  content without a sign-in prompt, session error, or visible Web surface.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- conclusion: normal-session regression path observed. No terminal 401 arose,
  so the new automatic recovery branch remains device-unproven and P0 stays
  open for its real failure boundary.

## Durable verification-origin deployment regression — 2026-08-10 23:45-23:55 +0800

- trigger: the native verification marker now stores only the finite reason
  `terminal_401_browser_refresh_unsuccessful`; a later cold restore maps it to
  a fixed non-secret diagnostic stage. No account value, cookie, URL, or
  response content is stored.
- install/data boundary: signed Debug installed with install-r=true;
  data-clear=false; uninstall=false.
- persistence check: after force-stop/cold start, native Account was signed
  in and Favorites showed authenticated native content without sign-in prompt,
  session error, or visible Web surface.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- conclusion: schema migration and normal-session regression path observed.
  The finite marker reason awaits a real terminal event; it is not treated as
  evidence that the automatic recovery branch has succeeded or failed.

## Fresh S0 Favorites invalid-session observation — 2026-08-12 22:40 +0800

- trigger: current native Favorites root was opened on the selected device
  after a data-preserving signed Debug build; this was ordinary root navigation,
  not a force-stop/cold-start boundary, so no loss-to-promotion timer is
  invented.
- S0 Favorites: native sign-in-required surface; no visible Web, loading, or
  authenticated gallery surface observed.
- S0 Account: native verification-required state; no visible Web surface.
- restore/401 diagnostic: native verification-required state; no cause is
  inferred from the paired native surfaces.
- install/data boundary: signed Debug installed with install-r=true;
  data-clear=false; uninstall=false.
- login-page navigation: not-entered.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- next action: issue the current explicit native re-verification action. A
  credential epoch remains forbidden unless that action yields the visible
  current login form and the S1--S4 protocol gates all pass.

## Native re-verification result — 2026-08-12 22:44 +0800

- recovery action: the single explicit native re-verification action was
  issued from the paired verification-required Account state.
- native Account after action: signed-in native state; no visible Web surface.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- next action: data-preserving force-stop/cold start, then paired native
  Account and Favorites summaries. This recovery observation is not a
  persistence acceptance claim.

## Current re-verification cold-start result — 2026-08-12 22:44-22:49 +0800

- persistence check: NextN alone was force-stopped and cold-started without
  data clear, uninstall, or reinstall on the selected device.
- cold-start Account: native signed-in state; no visible Web surface.
- cold-start Favorites: native authenticated collection state with no sign-in
  prompt, loading, error, or visible Web surface.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- conclusion: this current recovery path survived one cold start, but it does
  not establish why the preceding fresh native session became
  verification-required. P0 remains OPEN; no new credential epoch occurred.

## Cold-start authenticated-read regression — 2026-08-12 23:09-23:12 +0800

- trigger: a data-preserving force-stop/cold start following a signed Debug
  `install -r`; no data clear or uninstall occurred.
- cold-start Account: native signed-in state; no visible Web surface.
- cold-start Favorites: native transport error rather than authenticated
  collection; no sign-in prompt, visible Web, or credential action.
- fixed observed failure: `The ArkWeb account transport could not load.`
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- conclusion: this is a failed authenticated-read verification, not a reason
  to start a credential epoch. The source correction is limited to filtering
  ArkWeb resource-error callbacks by main-frame status; device verification of
  that correction remains the next physical action.

## Cold-start authenticated-read recovery — 2026-08-12 23:15-23:16 +0800

- trigger: installed the committed main-frame-error correction with `install
  -r`, then force-stopped and cold-started NextN without data clear or
  uninstall.
- cold-start Account: native signed-in state; no visible Web, verification
  requirement, or native error.
- cold-start Favorites: authenticated native gallery collection; no sign-in
  prompt, visible Web, loading, or ArkWeb transport error.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- conclusion: the observed record-present cold-start path is accepted for the
  specific retained-host resource-error regression. It does not erase or
  rename prior failure observations.
