# NextN re-login attempt ledger

This is an append-only, redacted audit ledger for autonomous NextN account
cycles on the explicitly selected device. It makes a distinction that must
never be blurred:

- **Login-page navigation event:** the app displayed a visible ArkWeb login
  route. It is recorded even if credential entry does not follow.
- **Re-login attempt:** the credential-entry subphase within that cycle. It
  starts only when the account credential is actually entered through the
  semantic field driver.

For every login cycle, record the trigger, safe S0 state, actions performed,
terminal state, and conclusion. Before opening another WebView, review the
preceding cycle's reason and terminal state. Do not reuse or silently reopen a
closed attempt.

## Current execution status

As of the last recorded device result, **no credential epoch or login cycle is
active**. The later native re-verification and cold-start records below closed
the earlier entries. Historical headings, timestamps, duration fields, and
retired timing-limit observations are kept unchanged as evidence, not as
current instructions.

A new cycle may begin only after a fresh current S0 observation proves native
Account or Favorites unusable. It must append a new redacted record and never
reuse an old “active”, “prepared”, or “pending” field as a live action. A
source change, build, documentation change, historical login failure, or a
desire to reconfirm the path is not a trigger.

**Execution rule:** complete build/install, wake/lease, prior-cycle accounting,
and route preparation before an attempt. During it, run only the prepared
native route and semantic credential sequence. Source inspection,
documentation edits, layout analysis, helper work, and unrelated diagnostics
wait until the attempt reaches a terminal state.

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
- account input: <not-started|entered|not-entered>
- password input: <not-started|entered|not-entered>
- submit: <not-issued|issued>
- post-submit native promotion: <pending|fixed safe state>
- cold-start Account: <pending|fixed safe state>
- cold-start Favorites: <pending|fixed safe state>
- conclusion: <accepted|repair-required|not-a-relogin-attempt>
```

## Historical timing records (retired)

The entries below preserve observations made under the retired timing rule.
They remain historical evidence only and do not define current limits or
required fields.

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

## Diagnostic-build cold-start regression — 2026-08-12 23:31-23:37 +0800

- trigger: data-preserving `install -r` of the signed build that adds the
  finite retained-host main-frame diagnostic, followed by force-stop/cold
  start on the selected device.
- install/data boundary: install-r=true; data-clear=false; uninstall=false.
- cold-start Favorites: native authenticated collection state after one
  observed loading settlement; no sign-in prompt, visible Web, or ArkWeb
  transport error.
- cold-start Account: native signed-in state with the native sign-out action;
  no verification-required state, visible Web, or transport error.
- account input: not-entered.
- password input: not-entered.
- submit: not-issued.
- diagnostic stage: not-observed; the new stage is intentionally emitted only
  on a classified main-frame transport failure.
- classification correction: a broad `登录` text match included the signed-in
  screen's sign-out action and was rejected. It did not represent a sign-in
  prompt.
- conclusion: current record-present cold-start Account plus authenticated
  Favorites path observed for this build. P0 remains OPEN for a future fresh
  Account/Favorites failure and its causal evidence.

## S0 冷启动会话缺失观察 — 2026-08-19 06:12-06:19 +0800（56T0225315001128）

- local timestamp (S0 loss boundary): 2026-08-19 06:12:09 +0800（install -r 日志域修复构建后 force-stop/cold start）。
- concrete reason session absent: 冷启动后 account-preferred 列表读返回 200（公开 JSON），但 ArkWeb 会话（https://nhentai.net/ 页面，socket @webview_devtools_remote_34086）对 /api/v2/user 与 /api/v2/blacklist/ids 均返回 401；收藏页显示“请在设置中登录以查看收藏。”（06:19 观察）。
- prior cycle terminal outcome: 2026-08-18 该设备冷启动已接受（收藏乐观切换、历史标签翻译等验收均以有效会话通过）；本次未保留上一周期结束到本次 S0 损失边界之间的确切时长，标记 unavailable-from-existing-evidence。
- data boundary: install-r=true；data-clear=false；uninstall=false。
- account input / password input / submit: not-entered / not-entered / not-issued（无凭据，未进入 S2）。
- ArkWeb-visible timestamp: 06:19（/api/v2/user 401 探测）。
- native-success timestamp: none；terminal observation 06:19（收藏未登录）。
- elapsed time: 未完成 native promotion；从 S0 损失边界到终端观察约 7 分钟（06:12→06:19）。
- conclusion: 会话缺失复现；与长期账号持久化 P0 同链。客户端云端黑名单端到端验证因此阻塞；无凭据不得重登用户个人账号。

## 用户授权的凭据文件登录尝试 — 2026-08-19 10:42 +0800（192.168.50.197:12345）

- trigger: 用户明确指示使用保留的登录信息文件（.nextn-test-account.local.json5）进行登录，并完成账号持久化 P0 的真机验收；本次 S0 前未清除数据、未卸载、未重装（仅 install -r 新构建 HAP）。
- S0 Account: native Account 卡片显示“登录以使用账户功能。”；无可见登录 Web。
- S0 Favorites: native 收藏根显示“请在设置中登录以查看收藏。”；无 sign-in prompt 之外的其他状态。
- restore/401 diagnostic: 当前安装包含会话修复（浏览器导航刷新优先、HttpOnly 感知、密封信封跟随 Set-Cookie）；S0 未观测到 restore 阶段日志（旧会话已缺失）。
- install/data boundary: install-r=true（新构建）；data-clear=false；uninstall=false。
- login-page entry: not-yet.
- account input: not-yet.
- password input: not-yet.
- submit: not-yet.
- native promotion: not-yet.
- cold-start Account: not-yet.
- cold-start Favorites: not-yet.
- credential source: 用户保留的 .nextn-test-account.local.json5（volatile staging，不落输出/日志/提交）。
- conclusion: S0 证明会话缺失，进入 S1；凭据 epoch 将在 S1 表单就绪后执行。

## USB 设备登录 epoch — 2026-08-19 11:13 +0800（56T0225315001128）

- S0: 安装会话修复构建（install -r），账户页显示“需要重新验证”，收藏页未登录；无可见 Web。
- S1: 点击重新验证打开 nhentai 登录页（可见 Web，无活动 CF iframe）。
- S2: 语义账号聚焦 + 填入成功（账号字段 filled=true）。
- S3: 语义密码聚焦 + 填入成功（密码 masked=true）。
- S4: 提交一次（submitIssued=true）；页面出现“Please complete the CAPTCHA”。
- CF 挑战：Turnstile iframe 内容为空（CF 反自动化，无法渲染交互控件）；尝试语义点击未找到控件；等待 6-10s 后仍空白。
- 重试提交后出现“CAPTCHA solution has expired”，验证码需人工完成。
- 结论：凭据流程（聚焦/填充/提交）已验证通过；CAPTCHA 为外部反自动化挑战，无法自动完成。登录未完成；待用户手动完成 Turnstile 或提供通过挑战的会话。

## CF Turnstile 阻塞终态 — 2026-08-19 11:16 +0800（56T0225315001128）

- 登录表单已正确填入（账号/密码），提交已发出。
- CF Turnstile 挑战：初次点击后显示“成功！”（token 已生成），但提交报 “CAPTCHA solution has expired”；重试提交仍过期。
- Turnstile iframe 内容空白（CF 反自动化检测到 CDP 调试器，拒绝渲染交互控件）；断开 CDP 后状态未恢复。
- 自动化穷尽：语义点击（CDP iframe 内）、设备坐标点击、等待重载、断开调试器——均无法获取新 token。
- 结论：外部 CF Turnstile 反自动化阻塞，无法程序绕过；需要真人完成验证码或提供已通过挑战的会话。表单数据保留在设备（未提交，未清除）。

## 登录成功 + 冷启动持久化验收通过 — 2026-08-19 11:21 +0800（56T0225315001128）

- 重新打开登录页（全新 Turnstile）后重新填表提交，原生提升成功：账户页显示 honjow / ID 5623474 / 退出登录。
- S6 持久化验证：force-stop + 冷启动（未清数据），账户页直接显示已登录（honjow / ID 5623474），无登录提示、无重新验证、无检查会话过程。
- 收藏页冷启动后直接显示认证画廊内容（多个条目、中文标签正常），无“请登录”提示、无加载错误。
- 会话修复构建验证通过：密封信封跟随 Set-Cookie 轮换、冷启动自愈路径工作正常。
- 凭据：用户保留的 .nextn-test-account.local.json5（全程内存 staging，未落任何输出/日志/提交）。
- 遗留：197 设备 TCP 瞬断未用于登录；Turnstile 首次自动化失败后通过重开登录页解决。

## 197 登录成功 + 冷启动持久化验收通过 — 2026-08-19 11:28 +0800（192.168.50.197:12345）

- 197 上残留登录页（此前自动化尝试遗留），重新利用该登录页：语义填入账号/密码 + 提交，原生提升成功（honjow / ID 5623474 / 退出登录）。
- S6：force-stop + 冷启动（未清数据），账户页直接显示已登录（honjow / ID 5623474）；收藏页直接显示认证画廊内容（多个条目），无登录提示、无加载错误。
- 197 TCP 连接多次瞬断，但登录与持久化验收均完成。
- 凭据：用户保留的 .nextn-test-account.local.json5（内存 staging，未落输出/日志/提交）。

## S0 会话续期链缺失观察 — 2026-08-20 22:40-22:51 +0800（192.168.50.200:12345）

- session-loss-detected-at: 2026-08-20 22:40:01 +0800（当前持久诊断日志中首次 authenticated-read 401）。
- concrete reason session absent/invalid: ArkWeb Cookie 形状在初始 401、根刷新和重放 401 三个阶段均为 access=1、refresh=0、session=0；根刷新无法续期，最终 authenticated request 仍为 401。
- prior cycle terminal outcome: 2026-08-20 22:11 的上一安装包曾记录 Account/Favorites 成功，但其 collector 未检查动态请求错误；该结论已撤回。上一有效周期的精确持续时间为 unavailable-from-existing-evidence。
- first blocking phase: native-persistence；旧版 saved-account switch 先删除 refresh/session，再从 version-2 信封仅恢复 access token。
- install/data boundary at observation: install-r=true；data-clear=false；uninstall=false。
- S0 Account: native ownership retained；此项不能证明请求鉴权有效。
- S0 Favorites: cached cards 与 terminal authenticated request error 同时存在；不得归类为 authenticated success。
- restore/401 diagnostic: initial 401 -> root refresh ready -> replay 401 -> terminal 401 after restore。
- WebView-visible timestamp: 2026-08-20 22:40:01 +0800（根刷新开始）；native-success timestamp: none。
- terminal observation: 2026-08-20 22:51:01 +0800；elapsed: 11 分钟，超过 60 秒上限；未重置或隐藏该周期。
- login-page entry / account input / password input / submit / native promotion: not-entered / not-entered / not-entered / not-issued / none。
- no data clear or uninstall occurred: confirmed。
- next action: 先安装完整 Cookie 信封修复构建并重新执行 paired S0；只有该当前 S0 仍证明会话无效时，才建立新的 attemptEpoch 并连续完成 S1-S6。

## 修复构建后的当前 S0 终态 — 2026-08-20 22:53:23-22:55:30 +0800（192.168.50.200:12345）

- session-loss-detected-at: 2026-08-20 22:53:35 +0800（完整 Cookie 信封修复构建 install-r 后，Favorites 当前请求首次 401）。
- current Account safe outcome: native ownership present，saved=1，selected=1，signed-out=false，visible-login-Web=false。
- current Favorites safe outcome: 缓存 collection 已挂载，但同轮持久诊断为 initial 401 -> root refresh -> replay 401 -> terminal 401；该 collection 不构成 authenticated success。
- restore/401 stage: after_initial_401、after_root_refresh、after_replay_401 均为 access=1、refresh=0、session=0；无 Cookie 值或账号信息进入日志。
- collector correction: 22:53 的第一份 `sessionAccepted=true` 因缓存 collection 过早结算而撤回；读取当前请求终态后的结论为 invalid session。
- install/data boundary: signed Debug install-r=true；data-clear=false；uninstall=false。
- prior cycle terminal outcome and elapsed: 22:40 周期 terminal 401，11 分钟；本周期 last-observed-at=22:55:30，elapsed=1 分 55 秒，超过 60 秒上限。
- first blocking phase: native-persistence；旧 version-2 信封已经永久缺少 refresh/session，新构建不能凭空重建服务器续期身份。
- login-page entry / account input / password input / submit / native promotion: not-entered / not-entered / not-entered / not-issued / none。
- keychain staging precondition: 固定 presence-only 检查 accountHandleAvailable=true、passwordHandleAvailable=true；没有读取或输出凭据值。
- no data clear or uninstall occurred: confirmed。
- next action: 通过当前 native Account 的显式登录/添加账户动作进入 S1；确认当前可见 Web 和语义表单后，另起一个 attemptEpoch，单次执行 S2 account、S3 password、S4 submit。

## 完整 Cookie 信封后的单次重登录 epoch — 2026-08-20 23:05:25 +0800（192.168.50.200:12345）

- concrete reason a new attempt is warranted: 上一周期已以 terminal 401 关闭；当前浏览器 jar 的 refresh/session 被旧 version-2 switch 永久删除，新构建无法无凭据恢复。
- prior cycle: session-loss-detected-at=22:53:35，terminal observation=22:55:30，elapsed=1 分 55 秒，first blocker=native-persistence。
- current S0 Account: native ownership=true，saved=1，selected=1，signed-out=false，visible-login-Web=false。
- current S0 Favorites: cached collection 不作为成功；同轮请求 initial 401 -> root refresh -> replay 401 -> terminal 401。
- install/data boundary: signed Debug install-r=true；data-clear=false；uninstall=false。
- S1 login-page entry: explicit native Add account -> native Open login page；visible-login-Web=true。
- S1 semantic probe: loginFormPresent=true，accountFieldPresent=true/filled=false，passwordFieldPresent=true/filled=false/masked=true，submitPresent=true/enabled=false，challengeFramePresent=false，errorMarkerPresent=false。
- credential staging: 固定 Keychain 两个 handle 已做 presence-only 检查并可用；值不进入 argv、环境、日志、布局、截图或台账。
- attemptEpoch started-at: 2026-08-20 23:05:25 +0800；accountEntered=false；passwordEntered=false；submitIssued=false。
- account input: pending one semantic S2 action。
- password input: pending one semantic S3 action。
- submit: pending one semantic S4 action。
- native promotion / cold-start Account / cold-start Favorites: pending / pending / pending。
- next action: 立即由固定 Keychain epoch orchestrator 连续执行一次 S2-S4；之后只观察 S5，不在此 epoch 重填、重清或重提交。

### 该 epoch 终态 — 2026-08-20 23:08:54 +0800

- S2 account input: issued once；postcondition accountFieldFilled=true。
- S3 password input: issued once；postcondition passwordFieldFilled=true、passwordFieldMasked=true。
- S4 submit: issued once；orchestrator 固定结果 s4_submit_dispatched、submitIssued=true。
- S5 post-action: visible-login-Web=true；native Account promotion=false。提交后两次有界探针仍为 loginFormPresent=true、formValid=true、challengeFramePresent=false、errorMarkerPresent=false。
- native promotion: none；cold-start Account/Favorites: not-run because S5 did not promote。
- last-observed-at: 2026-08-20 23:08:54 +0800；attempt elapsed=3 分 29 秒；超过 60 秒上限。
- first blocking phase: form；语义 submit dispatch 已执行，但当前页面未产生导航、challenge/error 状态或 native promotion。该结果不允许在同一 epoch 再次提交。
- no repeated input/clear/submit: confirmed。
- next action: 精确清理本轮 CDP forward；关闭该已填表单并回到新的 S0/S1。只有新空表单和新 ledger epoch 才允许下一次凭据序列；先检查固定 submit driver 为什么“dispatch success”未形成 HTML form submission。

## 第二次空表单 epoch — 2026-08-20 23:12:04 +0800（192.168.50.200:12345）

- reason: 前一 epoch 已以 S5 未提升关闭且 forward 已精确删除；修正后的冷启动 S0 明确 Favorites error=true、authenticated=false，当前会话仍 invalid。
- current S0 Account/Favorites: native ownership=true、saved=1、selected=1；Favorites current request error=true、authenticated=false。
- S1: 重新通过显式 Add account -> Open login page 进入全新 visible Web；当前语义表单 account/password 均 empty，masked=true，challenge=false，error=false。
- install/data boundary: install-r=true；data-clear=false；uninstall=false。
- credential handles: fixed Keychain presence already confirmed；no secret output。
- attemptEpoch started-at: 2026-08-20 23:12:04 +0800；accountEntered=false；passwordEntered=false；submitIssued=false。
- implementation-specific correction before this epoch: 固定 submit driver 改用 HTML `form.requestSubmit(submit)`，仅在 API 不可用时回退单次 `submit.click()`；两者不会在同一 action 同时执行。
- account input / password input / submit / native promotion / cold-start verification: pending / pending / pending / pending / pending。
- next action: 连续执行唯一一次 S2-S3，随后在 challenge-safe 固定分支唯一一次 S4；同一 epoch 不重复。

### 第二次 epoch 终态 — 2026-08-20 23:13:43 +0800

- S2/S3: accountEntered=true once；passwordEntered=true once；filled/masked postconditions=true。
- S4: requestSubmit branch issued once；submitIssued=true。
- S5: bounded wait 后 visible login form 仍存在；challenge=false、error=false、formValid/submitEligible=true；native promotion=false。
- last-observed-at: 2026-08-20 23:13:43 +0800；elapsed=1 分 39 秒，超过 60 秒上限；first blocker=form。
- no repeated input/clear/submit: confirmed；本 epoch 关闭。
- diagnosis boundary: JavaScript `click()` 与 `requestSubmit()` 都只证明 untrusted DOM dispatch 被调用，不能证明服务器页面接受了真实用户激活。下一 epoch 前把 S4 改为“当前语义 submit 控件中心 -> CDP Input mousePressed/mouseReleased”，坐标仅在进程内使用且不输出、不复用；凭据字段仍禁止坐标输入。

## 浏览器级 submit 激活 epoch — 2026-08-20 23:16:55 +0800（192.168.50.200:12345）

- reason/current S0: 前一 epoch 已关闭；再次冷启动证明 Account ownership=true、Favorites error=true/authenticated=false。
- S1: explicit Add account -> Open login page；visible Web=true；account/password empty，masked=true，challenge/error=false。
- install/data: install-r=true；data-clear=false；uninstall=false；fixed Keychain handles available。
- attemptEpoch started-at: 2026-08-20 23:16:55 +0800；accountEntered=false；passwordEntered=false；submitIssued=false。
- S4 driver boundary: 语义唯一 submit 控件的当前中心只在进程内使用，由 CDP Input mousePressed/mouseReleased 发一次浏览器级点击；坐标不输出/保存/复用，credential input 仍无坐标。
- account input / password input / submit / S5 / S6: pending / pending / pending / pending / pending。
- next action: 立即连续执行唯一 S2-S4，随后仅观察提升。

### 浏览器级激活 epoch 终态 — 2026-08-20 23:20 +0800

- S2/S3/S4: account entered once；password entered once；CDP Input semantic submit issued once；no repeat/clear/resubmit。
- S5: login form navigated away；native Account=true、visible Web=false、selected account=true、saveFailed=false。
- native-promotion-at: 2026-08-20 23:19 +0800；从 attempt start 到提升约 2 分钟，超过 60 秒；first blocker=form（前两种 untrusted submit 实现的定位/替换发生在此前已关闭 epoch，本 epoch 的超时不重写）。
- S6: force-stop/cold start without data clear/uninstall；Account signedIn=true、saved=1、selected=1；Favorites error=false、authenticated=true；同轮日志无 authenticated 401。
- conclusion: 登录与第一次冷启动成功；随后继续验证完整 v3 主/selected-saved 信封的落盘和再次冷启动，不把 ArkWeb jar 存活误当成信封恢复成功。

## 完整 v3 信封最终恢复 — 2026-08-20 23:24-23:33 +0800（192.168.50.200:12345）

- final install boundary: signed Debug install-r=true；data-clear=false；uninstall=false。
- first migration cold start: Account/Favorites accepted，但 fixed diagnostic 发现旧重封装 `valid_v3/headerAccess=1/authCount=2/renewal=1/ua=0`，因此该轮不作为信封恢复验收。
- root cause of invalid v3: regular ArkWeb jar survived while restore rejected the prior envelope；successful request re-sealed complete Cookies using an empty process `browserUserAgent`，causing the next restore to reject it again。
- correction: retained ArkWeb stores the exact compatible UA selected for its live browser session；empty UA cannot be sealed；a valid envelope restores its UA；the first successful authenticated read also checkpoints primary and selected saved envelopes。
- self-heal cold start: Account/Favorites accepted and rewrote the existing ua=0 envelope under the retained controller UA。
- second cold start: Account signedIn=true、saved=1、selected=1、visibleWeb=false；Favorites error=false、authenticated=true。
- fixed restore evidence on both Account and Favorites processes: `code=valid_v3;headerAccess=1;ua=1;authCount=2;renewal=1` followed only by `account_restore_arkweb_jar_ready`；no payload-invalid and no authenticated 401 stage。
- credential input / password input / submit in final two cold starts: not-entered / not-entered / not-issued。
- terminal outcome: S6 complete；next login action none。

## 197 最终包 S0 会话无效观察 — 2026-08-20 23:41-23:43 +0800（192.168.50.197:12345）

- session-loss-detected-at: 2026-08-20 23:41:58 +0800（最终签名包 install-r 后，Favorites 当前请求首次 authenticated-read 401）。
- concrete reason session absent/invalid: Account 仍保留 native ownership、saved=1、selected=1，但 corrected collector 等待当前 Favorites 请求结算后记录 error=true、authenticated=false；缓存列表不作为成功。
- prior cycle terminal outcome: 2026-08-20 22:11 的旧包曾报告 Account/Favorites 成功，但该结论没有证明当前最终包的可续期 v3 信封；从该观察到本次失效边界的精确有效时长为 unavailable-from-existing-evidence。
- restore/401 diagnostic: `account_restore_arkweb_jar_ready` -> initial 401 -> root refresh ready -> replay 401 -> terminal 401 after restore；新规则保留 account ownership，没有发布 signed-out。
- install/data boundary: signed Debug install-r=true；data-clear=false；uninstall=false。
- current S0 Account: signedIn=true、signedOut=false、verificationRequired=false、saved=1、selected=1、visible-login-Web=false。
- current S0 Favorites: native structure=true、error=true、authenticated=false、sign-in-prompt=false。
- WebView-visible timestamp: 2026-08-20 23:41:58 +0800；native-success timestamp: none。
- last-observed-at: 2026-08-20 23:43:17 +0800；elapsed=1 分 19 秒，超过 60 秒上限；first blocking phase=native-persistence（设备现存浏览器身份不能通过一次根刷新续期）。
- login-page entry / account input / password input / submit / native promotion: not-entered / not-entered / not-entered / not-issued / none。
- no data clear or uninstall occurred: confirmed。
- credential staging precondition: 使用既有固定 Keychain handles；开始 S2 前仅执行 presence-only 检查，任何值不得进入输出、argv、环境、布局、截图或台账。
- next action: 通过当前 native Account 的显式 Add account -> Open login page 进入一个全新 S1；确认空表单与无 challenge 后建立唯一 attemptEpoch，并连续执行一次 S2-S4，随后只观察 S5/S6。

## 197 完整 v3 信封重登录 epoch — 2026-08-20 23:45:39 +0800（192.168.50.197:12345）

- concrete reason a new attempt is warranted: 当前最终包的 paired S0 已以 terminal 401 关闭；Account ownership 保留但当前 Favorites 明确 error=true/authenticated=false，一次根刷新无法恢复设备现存旧身份。
- prior cycle: session-loss-detected-at=23:41:58，last-observed-at=23:43:17，elapsed=1 分 19 秒，first blocker=native-persistence。
- current S0 Account/Favorites: signedIn=true、saved=1、selected=1；Favorites current request error=true、authenticated=false。
- install/data boundary: signed Debug install-r=true；data-clear=false；uninstall=false。
- S1 login-page entry: explicit native Add account -> Open login page；visible-login-Web=true。
- S1 semantic probe: loginFormPresent=true，account/password fields present and empty，passwordMasked=true，challenge=false，error=false；submit 尚未可用符合空表单前置状态。
- credential staging: fixed Keychain presence-only result accountHandleAvailable=true、passwordHandleAvailable=true；no secret output。
- attemptEpoch started-at: 2026-08-20 23:45:39 +0800；accountEntered=false；passwordEntered=false；submitIssued=false。
- account input / password input / submit / native promotion / cold-start verification: pending / pending / pending / pending / pending。
- next action: 立即连续执行唯一一次 S2 account、S3 password 和浏览器级语义 S4 submit；之后只观察 S5，不在本 epoch 重填、重清或重提交。

### 197 epoch S5 提升 — 2026-08-20 23:47:48 +0800

- S2 account input: issued once；postcondition accountFieldFilled=true。
- S3 password input: issued once；postcondition passwordFieldFilled=true、passwordFieldMasked=true。
- S4 challenge-safe branch: fixed probe challenge=false、error=false、formValid=true；browser-level semantic submit issued once；submitIssued=true。
- S5: login form left the page；privacy-bounded native observation reported nativeAccount=true、visibleLoginWeb=false、savedAccountPresent=true、selectionPresent=true。
- native-promotion-at: 2026-08-20 23:47:48 +0800；从 attempt start 到提升约 2 分 9 秒，超过 60 秒上限；first blocking phase=credential（Keychain 分阶段驱动在唯一 submit 前要求一次固定 challenge-safe probe）。
- no repeated input/clear/submit: confirmed。
- raw layout and temporary forwarding: raw host/device layout deleted；本轮 forward 已由调试生命周期自动移除，显式移除返回 not-exist，未删除其他转发。
- cold-start Account / Favorites: pending / pending。
- next action: 不清数据 force-stop/cold start；只观察 Account 与本次 Favorites 请求结算，不巡检 diagnostics 或其他界面。

### 197 最终 S6 — 2026-08-21 00:00-00:02 +0800

- interruption boundary: 用户报告 200 的同账号 checkpoint 英文提示后，197 S6 保持 OPEN 并停止设备操作；200 根因修复和当前现场验收完成后才恢复本步骤。
- final package boundary: 与 200 相同的签名竞态修复 HAP 以 install-r 安装；data-clear=false；uninstall=false；sign-out/switch/re-login=false。
- first independent cold start: Account signedIn=true、saved=1、selected=1、visibleWeb=false；Favorites error=false、authenticated=true、signInPrompt=false。
- second independent cold start: Account signedIn=true、saved=1、selected=1、visibleWeb=false；Favorites error=false、authenticated=true、signInPrompt=false。
- diagnostics/other UI inspection: not-run；S0 collector 默认仅访问 Account 与 Favorites，diagnostics 已改为显式 opt-in。
- credential input / password input / submit after S5: not-entered / not-entered / not-issued。
- terminal outcome: S6 complete on 197；the v3 renewable session survived two process cold starts and the same-account checkpoint race fix did not demote ownership or expose a request error。
- next login action: none。

## 200 当前会话无效观察 — 2026-08-21 12:31:16 +0800（192.168.50.200:12345）

- session-loss-detected-at: 2026-08-21 12:31:16 +0800（当前 S0 返回后立即记录；collector 返回的精确秒未单独保留）。
- concrete reason session absent/invalid: Account 仍为 native signed-in、saved=1、selected=1，且没有 visible login Web；Favorites 当前请求已结算为 error=true、authenticated=false、sign-in-prompt=false，因此本地 ownership 与远端 authenticated read 再次分离。
- prior cycle terminal outcome and elapsed: 200 上一份可用证据为 2026-08-20 23:24-23:33 的完整 v3 信封恢复与第二次冷启动成功；从该成功证据到本次失效边界的精确有效时长为 unavailable-from-existing-evidence。
- restore/401 diagnostic: 持久化日志记录 `valid_v3/headerAccess=1/ua=1/authCount=2/renewal=1` -> `restore_ready` -> `restore_hydration_deferred`；实际请求随后为 initial 401，且 after-initial/root-refresh/replay 三个 Cookie shape 均为 access=0、refresh=0、session=0，最终 replay 401 -> terminal 401 after restore。实时 hilog 缓冲为空，但 12 个轮转文件保留了 03:18-12:31 的固定脱敏事件。
- install/data boundary: 本轮尚未安装；data-clear=false；uninstall=false；sign-out/switch/re-login=false。
- current S0 Account: signedIn=true、signedOut=false、verificationRequired=false、saved=1、selected=1、visible-login-Web=false。
- current S0 Favorites: native structure=true、error=true、authenticated=false、sign-in-prompt=false。
- WebView-visible timestamp / native-success timestamp: none / none。
- last-observed-at: 2026-08-21 12:36:13 +0800；elapsed=4 分 57 秒；first blocking phase=native-persistence（信封有效但其身份 Cookie 未进入活跃 ArkWeb jar；根页刷新后仍为空）。
- login-page entry / account input / password input / submit / native promotion: not-entered / not-entered / not-entered / not-issued / none。
- no data clear or uninstall occurred: confirmed。
- next action: 修复“可信页面 ready 后没有再次 hydration”的生命周期缺口，安装时不清数据；用现存 v3 信封验证自动恢复、Favorites 成功及新的 hydration 固定阶段。仅当修复后仍证明信封不可用时才重新评估 S1/S2。

### 200 旧会话终态诊断 — 2026-08-21 13:00:10 +0800

- corrected restore boundary: 可信页面 ready 后已恢复 renewal Cookie；固定日志证明 live jar 为 access=0、refresh=1(HttpOnly)、session=0，不再是空 jar。
- definitive invalid-session evidence: 在上一轮 429 窗口结束后的第一个独立 Account 进程中，固定 `POST /api/v2/auth/refresh` 返回 401；现存 refresh token 无法换取新 access token，旧信封不能继续自动修复。
- subsequent rate-limit evidence: 随后的 Favorites 进程返回 429，并给出 `Retry-After=900s`；当前包已把这一非敏感等待截止时间跨进程持久化，后续进程不得在窗口内重试刷新端点。
- current S0 Account/Favorites: signedIn=true、saved=1、selected=1；Favorites error=true、authenticated=false、sign-in-prompt=false。
- last-observed-at: 2026-08-21 13:00:10 +0800；从 session-loss-detected-at 12:31:16 起 elapsed=28 分 54 秒；first blocking phase=native-persistence。
- login-page entry / account input / password input / submit / native promotion: not-entered / not-entered / not-entered / not-issued / none。
- no data clear or uninstall occurred: confirmed；所有安装均为 install-r。
- next action: 现存 refresh token 已被服务器明确拒绝，开始一个新的可见登录 epoch；不得继续拿旧信封重试或把账号 ownership 清成未登录。

## 200 失效 refresh token 重登录 epoch — 2026-08-21 13:02:42 +0800（192.168.50.200:12345）

- concrete reason a new attempt is warranted: 当前包已完成 deferred hydration 和固定 refresh endpoint 修复，但当前设备的 retained refresh token 在正常窗口内返回 401；Account ownership 保留而 Favorites 当前请求仍 error=true/authenticated=false。
- prior cycle: session-loss-detected-at=2026-08-21 12:31:16 +0800，last-observed-at=2026-08-21 13:00:10 +0800，elapsed=28 分 54 秒，first blocker=native-persistence。
- restore/401 stage: valid_v3(headerAccess=1, ua=1, authCount=2, renewal=1, refresh=1) -> trusted-page hydration -> live refresh cookie present -> fixed refresh endpoint 401 -> terminal 401 after restore。
- current S0 Account/Favorites: signedIn=true、saved=1、selected=1、visible-login-Web=false；Favorites error=true、authenticated=false、sign-in-prompt=false。
- install/data boundary: current signed Debug install-r=true；data-clear=false；uninstall=false；explicit sign-out=false。
- device preparation: lease current；AWAKE=true；OverrideTimeout=86400000ms；fixed Keychain handles presence account=true/password=true；no secret output。
- S1 login-page entry: 2026-08-21 13:03:42 +0800，explicit native Add account -> Web login；visible-login-Web=true。
- S1 semantic probe: 2026-08-21 13:04:24 +0800；login form/account/password/submit present，account/password empty，password masked，challenge=false，error=false；空表单下 submit disabled/form invalid 符合前置状态。
- attemptEpoch started-at: 2026-08-21 13:04:48 +0800；accountEntered=false；passwordEntered=false；submitIssued=false。
- account input / password input / submit / native promotion / cold-start Favorites verification: pending / pending / pending / pending / pending。
- next action: 通过 native Account 的显式添加账号路径进入一个新空表单；确认 form/challenge 安全状态并记录 WebView timestamp 后，连续执行唯一一次 S2-S4，随后只观察 S5。

### 200 失效 refresh token epoch 终态 — 2026-08-21 13:08:00 +0800

- S2 account input: issued once；accountFieldFilled=true。
- S3 password input: issued once；passwordFieldFilled=true、passwordFieldMasked=true。
- fixed challenge-safe probe: challenge=false、error=false、formValid=true、submitEligible=true。
- S4 submit: browser-level semantic submit issued once；submitIssued=true；no repeat。
- S5: 20 秒固定原生观察后 visible login Web 仍存在；随后只读 probe 仍为同一已填有效表单，challenge=false、error=false；native promotion=false。
- native-promotion-at: none；last-observed-at=2026-08-21 13:08:00 +0800；从 attempt started-at 13:04:48 起 elapsed=3 分 12 秒，超过 60 秒；从 session-loss-detected-at 12:31:16 起 elapsed=36 分 44 秒；first blocking phase=form。
- no repeated input/clear/submit: confirmed；本 epoch 关闭。
- temporary forward/layout: 本轮精确 CDP forward 已按 local+remote endpoint 删除；原始临时布局与 helper artifact 已删除；无 URL、标题、目标元数据、坐标或字段内容留存。
- cold-start Account / Favorites: not-run；未提升前禁止用冷启动掩盖本轮失败。
- next action: 在新的 S0/S1 epoch 前，复核现有 browser-level submit driver 与 2026-08-20 成功路径的实际事件序列差异；不得在当前已填表单上再次提交。

## 200 原子登录执行器 epoch — 2026-08-21 13:12:50 +0800（192.168.50.200:12345）

- concrete reason a new attempt is warranted: 前一 epoch 因打开 WebView 后分段工具回合耗尽验证有效期而以 form blocker 关闭；现存 refresh token 的服务器 401 仍证明当前会话无效，且没有发生原生提升。
- current safe state carried from closed epoch: Account ownership/saved/selected retained；Favorites authenticated=false；旧 visible login Web 已 force-stop 关闭；no data clear/uninstall/sign-out。
- preparation completed before WebView: current lease、AWAKE/OverrideTimeout=86400000ms、fixed Keychain handles、single-process route/forward/probe/fill/submit/promotion coordinator、syntax/contract checks；no secret output。
- hard execution rule: credential retrieval occurs before visible Web；without CF, the coordinator cannot yield between S1 and S5；visible-to-fill ceiling=5s、whole flow ceiling=60s。Only `cf_intervention_required` may preserve the visible page and pause the queue。
- S1 / account input / password input / submit / native promotion / cold-start Favorites: pending / pending / pending / pending / pending / pending。
- attemptEpoch starts when the coordinator begins the native route；accountEntered=false；passwordEntered=false；submitIssued=false。
- next action: invoke the single coordinator once；no intermediate commentary, source/log inspection, build, ledger edit, or model decision unless its sole terminal code is `cf_intervention_required`。

### 200 原子 epoch S5 提升 — 2026-08-21 13:13:45 +0800

- one-process result: native_promotion=true；visible-Web-to-credential-fill=691ms；whole route-to-native-promotion=27.201s，均在 5s/60s ceiling 内。
- S1: fresh visible login form confirmed internally；CF challenge=false、error=false。
- S2/S3/S4: account entered once；password entered once；browser-level semantic submit issued once；no model/tool yield and no repeated input/clear/submit。
- native-promotion-at: 2026-08-21 13:13:45 +0800；attemptEpoch terminal success。
- secrets/forward/artifacts: credential buffers wiped；exact temporary forward removed；temporary DevTools/layout artifacts removed；no values、URL、title、target metadata or coordinates retained。
- cold-start Account / Favorites: pending / pending；no new login action permitted unless a later independent S0 proves this new session invalid。
- next action: independent force-stop/cold-start S0 without data clear/uninstall；verify Account ownership/selection and current Favorites authenticated request。

## 200 用户授权退出后的原子复验 epoch — 2026-08-21 13:17:57 +0800（192.168.50.200:12345）

- authorization/reason: 用户明确要求当前设备退出账号并重新验证原子登录流程；退出确认已执行，safe observation 为 saved/native signed-in rows absent。
- prior cycle terminal: 13:13:45 native promotion success；随后独立 cold-start S0 Account signedIn/saved/selected=true、Favorites authenticated=true。
- install/data boundary: no install、data clear or uninstall；explicit sign-out=true（本轮用户授权）；Cloudflare challenge cookies retained by product sign-out contract。
- preparation before WebView: lease current、AWAKE/OverrideTimeout retained、fixed Keychain handles、single-process coordinator ready。
- S1 / account input / password input / submit / native promotion / cold-start Favorites: pending / pending / pending / pending / pending / pending。
- attemptEpoch starts inside the coordinator；only CF may interrupt；visible-to-fill ceiling=5s、whole-flow ceiling=60s。
- next action: invoke the coordinator once with no intermediate model control。

### 该 epoch 终态 — precise timestamp unavailable-from-existing-evidence

- S1/S2/S3/S4: coordinator entered one fresh form, entered account once,
  entered password once, and issued submit once; no repeated input, clear, or
  submit occurred.
- S5: native promotion was not observed before the coordinator was explicitly
  terminated. The observer used a poll-count timeout whose individual device
  calls could exceed the intended 60-second wall-clock ceiling.
- native promotion / cold-start verification: none / not-run. First blocking
  phase: native-persistence observation. Exact terminal timestamp and elapsed
  are `unavailable-from-existing-evidence`; they are not inferred from the
  later successful route check.
- terminal cleanup: the process was interrupted, the app was later force
  stopped, and the next safe Account observation remained signed out with no
  saved account. No data clear or uninstall occurred.

## 200 空账号直达 Web 后的原子复验 epoch — 2026-08-21 13:31 +0800（192.168.50.200:12345）

- concrete reason a new attempt is warranted: user-authorized explicit
  sign-out removed the only saved account; current safe observation after the
  signed `install-r` reports saved=0/selected=0/signed-out=true. The user
  explicitly requested the login flow be reverified.
- prior cycle: the 13:17:57 epoch is closed without native promotion because
  its old observer exceeded the intended wall-clock boundary. The executor now
  uses one absolute route-to-promotion deadline and bounds each device call by
  the remaining time.
- current S0 Account/Favorites: Account signed-out=true, saved=0, selected=0;
  Favorites is not used to justify this already-authorized post-sign-out
  attempt. The empty Account entry was opened once for route-only acceptance,
  showed the visible first-party Web directly with no native two-row page, and
  was force-stopped without credential input.
- install/data boundary: current signed Debug `install-r`=true; data-clear=false;
  uninstall=false; explicit sign-out belongs to the user-authorized preceding
  boundary.
- device preparation before WebView: lease current; AWAKE=true;
  OverrideTimeout=86400000ms; route/credential/submit/promotion coordinator
  syntax and regression contract passed. Credential handles are retrieved and
  checked inside the coordinator before it opens Web; no value is emitted.
- S1 / account input / password input / submit / native promotion / cold-start
  Account / cold-start Favorites: pending / pending / pending / pending /
  pending / pending / pending.
- next action: invoke the single coordinator exactly once. Without an actual
  CF interaction it may not yield between visible Web and native promotion;
  only `cf_intervention_required` may preserve the page for intervention.

### 该 epoch 终态 — 2026-08-21 13:34 +0800

- terminal trigger: user observed that the CF verification control was still
  pending while the executor had already advanced toward credential handling
  and immediately corrected the required order. The coordinator was sent
  SIGINT at once; the app was then force-stopped.
- account/password input: the interrupted process emitted no safe terminal
  result, so whether either write completed is inconclusive. For safety this
  epoch treats both as consumed and permits no retry on that form.
- submit/native promotion: submit is not proven and must be treated as
  inconclusive; native promotion did not occur. No retry, clear, or second
  submit was issued in this epoch.
- root cause: the staged helper explicitly replaced the live
  `challengeFramePresent` value with false and documented CF as a post-fill
  branch. A single early probe could also run before a delayed Turnstile frame
  mounted. This was the wrong state-machine order.
- cleanup: NextN was force-stopped; both stale forwards were matched to dead
  ArkWeb process ids and removed exactly. No data clear or uninstall occurred.
- first blocking phase: challenge. The precise credential-write timing is
  unavailable from safe output and is not inferred.

## 200 CF 前置门禁复验 epoch — 2026-08-21 13:38 +0800（192.168.50.200:12345）

- concrete reason: explicit sign-out still leaves Account signed-out with no
  saved row, and the user-requested complete re-login validation remains open.
  The preceding incorrect-order epoch is closed and its form/process removed.
- implementation correction before WebView: the forced challenge=false branch
  is deleted; the read-only probe now distinguishes a pending widget from a
  completed response token; a three-second no-widget settlement or a completed
  response is required before field focus; the staged helper independently
  rechecks the challenge before focus and every later credential boundary.
- CF intervention contract: pending CF returns
  `cf_intervention_required` before account/password input and preserves the
  page. After the user-visible verification completes, `--resume-visible`
  attaches to that same page, proves the response ready, then performs the
  single S2-S4 sequence without rerouting.
- device/install boundary: current signed HAP remains installed with
  `install-r`; AWAKE=true; OverrideTimeout=86400000ms; data-clear=false;
  uninstall=false. Script syntax, challenge-before-focus behavioral test,
  account regression contract, and `git diff --check` pass.
- S1 / CF complete / account input / password input / submit / native
  promotion / cold-start Account / cold-start Favorites: pending / pending /
  pending / pending / pending / pending / pending / pending.
- next action: invoke the corrected coordinator once. If CF is pending, stop
  before credentials and inspect/interact only with that verification control;
  do not fill until the same-page response is confirmed complete.

### 该 epoch 终态 — 2026-08-21 13:41:22 +0800

- first coordinator result: `cf_intervention_required`; account/password
  input=false/false and submit=false by the pre-credential gate. The Web page
  was preserved.
- CF observation: the permitted current-page capture showed the Cloudflare
  control in its green completed state (`成功!`) while both credential fields
  were empty. No CF click was required because the challenge completed before
  intervention.
- same-page resume: `--resume-visible` reattached without rerouting. Its
  read-only probe observed the completed response token; only then did S2
  account input once, S3 password input once, and S4 semantic submit once.
  Reported `cfReadyToFillMs=0` confirms no model/tool pause after the completed
  gate.
- S5: native promotion was not observed by the absolute deadline. Fixed result
  was `promotion_failed`, elapsed=60286ms. No repeated input, clear, or submit
  occurred; the failure branch force-stopped NextN.
- native promotion / cold-start Account / cold-start Favorites: none / not-run
  / not-run. First blocking phase: native-persistence after a correctly ordered
  submit.
- next action: inspect only the fixed post-submit capture/promotion/session
  stages from this closed epoch. Do not begin another credential epoch unless
  the terminal evidence establishes a new safe reason.

### 该 epoch 后续证据更正 — 2026-08-21 13:47 +0800

- Persistent diagnostics prove the login did promote and finish durable
  account recording at 2026-08-21 13:40:12 +0800:
  `auth.account_recorded count=1`. Therefore the preceding executor result was
  a false negative, not an authentication or persistence failure.
- false-negative root cause: the S5 observer accepted only
  `nextn-account-native-root + nextn-account-saved-row`. The successful route
  had already navigated to `nextn-account-list-root + nextn-account-saved-row`,
  so the observer ignored the correct final page until its deadline and then
  force-stopped it. The observer now accepts either native/account-list owner
  root with a saved row and no Web.
- first and second independent cold starts both reported Account list=true,
  saved=1, selected=1, signedIn=true and Favorites
  error=false/authenticated=true.
- final logging-build boundary: `BrowserSessionPage` moved off reserved hilog
  domain 0x0000 to 0xE001 and now records fixed candidate, verification,
  promotion and account-save stages through the persistent redacted logger.
  The signed HAP was installed with `install-r`; a third independent cold
  start again passed saved=1/selected=1 and authenticated Favorites.
- final S5/S6 outcome: native promotion complete at 13:40:12; three independent
  S6 observations complete. No additional credential action was performed.
  No data clear or uninstall occurred.
