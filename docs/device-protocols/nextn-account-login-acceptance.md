# NextN ArkWeb account-login acceptance protocol

This is the durable, redacted protocol for a user-authorized real-account
acceptance run. It is a state machine, not a collection of reusable taps.
It applies to the selected live device only; an address, coordinate, WebView
socket, page title, or field bound from a prior run is never an input to the
next run.

The protocol has two deliberately separate outcomes:

1. An existing accepted session still restores and serves an authenticated
   Favorites read. In this case **do not open or submit the login form**.
2. The current safe evidence proves that the session is absent or invalid.
   Only then run the one-attempt login branch below.

## Continuous execution rule — loss-to-login recovery

This is the sole login-recovery flow. Its boundary is exactly:

`current native state detects login lost` → `native account reports signed in`

It does not include application start, force-stop, cold start, Favorites, or
any persistence verification. Those actions may produce the loss signal or
verify a completed login later, but they never become login-flow steps.

The coordinator builds one immutable recovery run at the loss signal, then
executes it from beginning to end with no ad-hoc per-step analysis.

### Preparation

The login executor keeps these conditions live before a loss signal arrives:

1. Resolve the selected device, lease, wake state, and screen timeout.
2. Resolve the already-authorized credential material into the coordinator's
   volatile memory.  Credential retrieval is a preparation concern, never a
   branch inside a login run; a missing implementation-specific secret handle
   must not cause the coordinator to invent a new decision layer.
3. Predeclare the ArkWeb channel owner and semantic login-form binding. Once
   S1 makes the visible form available, that owner creates the fixed local
   forward with `webview-devtools --keep-forward`; it stays alive through the
   read-only probe, both semantic writes, the sole CF decision, and submit.
   The helper's default auto-cleanup mode is forbidden when S2--S4 will
   follow. The exact forward is removed only after the terminal native result.

Complete preparation before the attempt begins. Do not interrupt an active
attempt with new setup work.

### Fixed sequence: loss signal to native login

With one attempt epoch, execute exactly this queue:

1. At `login-lost-detected`, begin the attempt epoch and invoke the native
   Account login action if the visible login form is not already foreground.
2. Confirm the current semantic login form.
3. Run the **only live conditional**: when a Cloudflare challenge is present,
   invoke its one currently bound verification action once, then poll at the
   fixed interval until it clears or reaches the fixed challenge deadline.
   When absent, continue immediately.  No other WebView condition changes the
   sequence.
4. Write the account once through the bound account field.
5. Write the password once through the bound password field.
6. Submit once through the bound submit control.
7. Poll only for native promotion.

The login flow ends at native promotion or a fixed terminal result. A challenge
branch may use only its declared poll/click loop.

### Separate persistence verification — never invoked by this flow

Only after the login flow has ended in native promotion may the independent
P0 verifier force-stop/cold-start without clearing data and read native
Account plus Favorites. It is not a login-flow stage and it does not alter the
single-submit epoch.

### No-interruption constraint

Between attempt start and the terminal result, the coordinator must not read
documentation, inspect source, run a build, renew a lease, rediscover a
route, recreate a forwarding channel, retrieve credentials, edit a ledger,
launch a subtask, or add a diagnostic.  A non-CF failure maps directly to one
fixed terminal code (`route_failed`, `form_failed`, `account_write_failed`,
`password_write_failed`, `submit_failed`, `promotion_failed`, or
`persistence_failed`) and closes that attempt epoch.  It is recorded after
the terminal observation; it never triggers in-place reasoning, retyping,
or resubmission.

## Privacy and session boundary

- Keep the supplied account and secret only in the authorized live input
  action. Never put either in a shell command, transcript, screenshot,
  layout, CDP result, test fixture, queue file, or commit.
- Never persist, print, or return form values, field lengths, URLs, page
  titles, cookies, tokens, account/profile strings, DOM text, HTML, or raw
  `/json` DevTools metadata.
- A temporary layout or DevTools response may be held only long enough to
  produce the fixed safe summary required by this protocol, then must be
  deleted from both host and device. The redacted summary is the retained
  evidence.
- Clean up every temporary ArkWeb forwarding in the same run, including probe
  failure or cancellation. Remove the exact mapping created for that run with
  both endpoints: `hdc fport rm tcp:<local-port> tcp:<remote-port>`. A bare
  `hdc fport rm tcp:<local-port>` is insufficient and must not be treated as
  cleanup. The retained acceptance queue may record only a fixed cleanup
  outcome/failure code; it must never retain port numbers, remote endpoints,
  WebSocket URLs, or DevTools discovery content.
- Use the in-app ArkWeb route. The system Browser has an independent cookie
  jar and is neither a login substitute nor evidence of NextN session
  persistence.
- Never clear application data, uninstall, delete a session, or replace the
  selected target to make this test easier. A current Debug installation uses
  `install -r` only.

## Required run setup

Before any UI or WebView action, apply the repository Harmony preflight:

1. Resolve exactly the user-selected Connected device and acquire its current
   project lease. Do not substitute another target.
2. Wake it, dismiss only a non-secure lock through the accepted neutral
   gesture if the lock owns input, set the unattended-test timeout to
   `86400000ms`, and read back both `Current State: AWAKE` and the exact
   `OverrideTimeout` before normal UI input.
3. Preserve that override through the complete login/cold-start scenario. If
   the screen locks, turns off, or transport reconnects, repeat this gate
   contiguously before inspecting or tapping the app.
4. Keep one volatile run record in the active process only:
   `attemptEpoch`, `accountEntered`, `passwordEntered`, and
   `submitIssued`. It must never be written to a file. `submitIssued` starts
   `false` and becomes permanently `true` after the one allowed submit.
5. Before S2, append a redacted entry to
   `docs/qa/nextn-login-attempt-ledger.md`. It must explain why the current
   S0 state justifies a new attempt, record the Account/Favorites safe
   summaries and available restore/401 stage, and separately mark each of
   login-page entry, account input, password input, submit, native promotion,
   cold start, and Favorites verification. No ledger entry means no
   credential action.
6. Complete the lease/wake gate, installation, prior-cycle ledger closure, and
   route preparation before starting the attempt. During the attempt, run only
   the minimal live route plus semantic credential sequence; do not insert
   source review, document edits, build work, layout analysis, helper creation,
   or unrelated diagnostics.

### Credential staging

When a resumed authorized run needs credential material, the coordinator
resolves it before the attempt from the already-authorized task context and
holds it only as volatile input to the semantic field writer.  It must not
turn an implementation-specific credential-store miss into a user handoff, a
coordinate-input fallback, or an in-run analysis branch.

The fixed `scripts/run_arkweb_login_keychain_epoch.mjs` contract remains one
optional host-side staging mechanism:

| Slot | Generic-password service | Generic-password account label |
| --- | --- | --- |
| Account input | `com.erosteam.nextn.acceptance.login.v1` | `account` |
| Password input | `com.erosteam.nextn.acceptance.login.v1` | `password` |

When this mechanism is used, its two entries must be readable by the
noninteractive `security` child process. Their values must be non-empty UTF-8,
at most 4096 bytes, contain no NUL, and not end in CR/LF. These labels are
automation handles, not the actual NextN account value.

`--diagnose-keychain` is a presence-only check. It invokes only the two exact
non-revealing lookups, discards all child output, and reports fixed
availability booleans; it never lists Keychain items or requests a password.
Do not run it merely to explore a machine's Keychain.

For an already authorized S2 form, the normal epoch receives staged volatile
bytes, re-probes the current account focus and empty-field precondition, passes
them only to the imported semantic CDP field action, and clears the buffers on
every return path. No secret is accepted in CLI argv, environment variables,
files, stdout, logs, test fixtures, or acceptance records. The CDP driver
remains field-semantic; it never uses `uiInput inputText` or stored geometry.

The process creates one volatile S2--S4 epoch: one account write, one password
write, and one submit. Each issuance flag is set immediately before dispatch.
Therefore a field-action or submit transport ambiguity is terminal for that
epoch; a future run must return to S0/S1 evidence and never retype or submit
inside the old epoch. The epoch stops after S4 and does not replace the native
S5/S6 promotion and persistence checks below.

## Safe state readers

Use only these readers for decision-making:

| Reader | Allowed result | Never return |
| --- | --- | --- |
| Native Account layout summary | visible-login-Web absent/present; native Account section; signed-in, signed-out, or save-failed booleans | account/profile text, Web descendants, bounds, arbitrary layout text |
| ArkWeb login probe | fixed booleans for field presence/focus/filled/masked state, form validity, submit enabled, challenge/error presence | field values/lengths, selectors, DOM text, URL/title/cookies |
| Favorites layout summary | native Favorites structure; sign-in prompt/loading/error booleans | gallery content, account text, raw layout |

`scripts/probe_arkweb_login_state.mjs` is the ArkWeb reader. It accepts only a
localhost DevTools forwarding port, creates no forwarding, changes no page
state, and prints one fixed JSON object. Obtain the forwarding first with the
Harmony `webview-devtools` evidence helper; after the probe completes, remove
only that run's exact local-to-remote mapping with both `fport rm` endpoints.

Example (the local port is ephemeral and is not retained):

```bash
node scripts/probe_arkweb_login_state.mjs --port <local-devtools-port>
```

The probe is diagnostic only. It must never focus a field, clear a field,
insert text, click a challenge, submit a form, navigate, or read cookies.

## State machine

### S0 — existing-session gate

1. Open the native Account destination and collect the safe Account summary.
2. Open Favorites and collect its safe summary.

If Account is natively signed in **and** Favorites has native authenticated
structure with no sign-in prompt, the session is accepted. Record the two
redacted outcomes, restore any temporary preference changed by the wider test
run, and continue the next non-login acceptance item. Do not re-open login.

If the summaries show an absent/invalid session, record only their fixed
booleans and proceed to S1. A static build, a historical successful login, or
a visible WebView is not a substitute for this current gate.

### S1 — visible-login precondition

1. Navigate from the native Account action to the in-app login route.
2. Capture a current native safe summary proving one **visible** login Web
   surface. A protected/black screenshot is not a page-state diagnosis.
3. Run the read-only ArkWeb probe through the prepared kept forward. It must
   report a login form with current account and password fields before any
   credential action. Do not invoke a discovery helper that auto-removes this
   forward before the semantic driver runs.

If the DevTools forwarding, page selection, or probe fails, preserve only its
fixed failure code, remove that run's exact local-to-remote forwarding mapping
with both `fport rm` endpoints, and diagnose transport or WebView state. Do
not guess a field coordinate, type into a presumed field, or submit.

### S2 — account field anchor and input

The mandatory redacted re-login ledger entry is prepared before the timed
sequence begins. Once S2 begins, it is not edited until the terminal outcome.

1. Establish the account field from the current visible document's semantic
   text-like control. The anchor is this run's field identity, not an old
   screen coordinate, screenshot, or `uiInput inputText x y ...` call.
2. Focus that exact control through the field-aware input driver. Re-run the
   safe probe and require `accountFieldFocused=true` before clearing.
3. Clear only the focused account control, then enter the supplied account
   through the secret-capable focused-field input path. The value must remain
   inside that one input action and must not enter shell history or artifacts.
4. Re-run the probe. It must show the account field present and filled. It
   must not report a password value as the evidence for this step.

If a field is already filled before S2, or the focus/fill postcondition is
false, stop at the current page and record the fixed probe booleans. Do not
clear the other field, retype either value, or move to submit. A corrective
entry requires a new visible-login epoch with a documented field-specific
cause, not a blind in-place retry.

### S3 — password field anchor and secure input

1. Establish the password field from the current visible document's semantic
   password control, independently of the account anchor.
2. Focus it through the field-aware driver. Require
   `passwordFieldFocused=true` before clearing.
3. Clear only that focused control and enter the supplied secret through the
   secure focused-field path. Never use a coordinate-based `inputText` command
   as the field selector or write the secret into a command/log artifact.
4. Re-run the probe and require all of:
   `accountFieldFilled=true`, `passwordFieldFilled=true`, and
   `passwordFieldMasked=true`.

If any result is false, keep the current evidence and stop this input branch.
In particular, an account-field result cannot be treated as password success.

### S4 — single-submit gate

The submit action is permitted exactly once per volatile `attemptEpoch`, and
only when the current probe reports all of:

- account and password fields present, focused-field postconditions completed,
  filled, and the password masked;
- a submit control present and enabled; and
- `formValid=true` and `submitEligible=true`.

Use the current semantic submit control; never reuse an old button coordinate.
Set `submitIssued=true` immediately before dispatching the one submit. A
command exit or injected tap is not success evidence.

If the challenge frame remains visible, treat it as an in-progress browser
state, not a reason to re-enter credentials or press submit again. Perform a
bounded wait or one currently anchored challenge action when applicable, then
re-probe. If `submitIssued=true`, every subsequent action is observation or
native-state verification only—no second submit, no field clear, and no
credential re-entry in that epoch.

### S5 — post-submit native promotion

After the one submit, observe the current route with the safe readers.

| Safe outcome | Meaning | Required next action |
| --- | --- | --- |
| Visible login Web remains | Browser/challenge/response has not produced native promotion evidence | Keep `submitIssued=true`; collect only the fixed probe/native booleans and bounded redacted stage diagnostics. Do not submit again. |
| Visible login Web absent; native Account section present; signed in; no save failure | Native promotion succeeded | Proceed to S6 immediately. |
| Native Account reports save failure, signed out, or verification-retry state | Promotion/restore did not complete | Preserve the fixed native state and redacted stage code. Do not re-enter or re-submit; repair or diagnose the state transition first. |

No screenshot, full log, cookie inspection, URL inspection, or raw Web layout
can replace the native promotion summary.

### S6 — persistence and authenticated Favorites

1. Force-stop NextN and start it again without clearing data or reinstalling.
2. Collect the native Account safe summary after cold start.
3. Open Favorites and collect its safe summary.

Acceptance requires the cold-start Account summary to remain natively signed
in and the Favorites summary to show an authenticated native state with no
sign-in prompt. This confirms an authenticated read/state only; it must not
issue account mutations such as favorite toggles, comments, votes, or downloads.

If either cold-start summary fails, the correct next branch is a fixed-stage
restore/401 diagnostic. It is **not** a new login attempt until that diagnostic
proves the current session is invalid and starts a new `attemptEpoch` at S1.
An unavailable HUKS key, HUKS key-check failure, decrypt failure, or invalid
sealed envelope must publish a signed-out native state while retaining the
ciphertext for a later recovery diagnostic; restore itself must never create a
replacement key or delete that record. Destructive deletion remains limited to
an explicit sign-out or the established confirmed authenticated-session
invalidation path. In this retained-record recovery state, Account must remain
native and verification-required: opening the destination, a cold start, or a
failed authenticated read may not auto-open/capture a visible login Web
surface. Only one explicit native Account action may register a replacement
login epoch, after which the ordinary S1--S4 guard and ledger remain required.
For an authenticated GET, a failed sealed-cookie recovery leaves its first 401
as a retained diagnostic; deletion is permitted only after the recovery
actually issues its one replay and that replay also returns 401.

## Non-negotiable anti-repetition rules

1. Never login merely because the app restarted, a HAP was installed with
   `-r`, a screenshot is protected, or a prior command said `No Error`.
2. Never use historical coordinates, field order, page geometry, or stale
   focus as a credential-entry method.
3. A failed focus, fill, form-validity, challenge, native-promotion, or
   cold-start check chooses its named diagnostic branch; it never falls
   through to another credential entry or submit.
4. One attempt means one account input, one password input, and one submit.
   Repeating any of them requires a new explicit visible-login epoch after the
   prior attempt's outcome has been safely established.
5. Before yielding or changing lanes, record the active state (`S0`–`S6`),
   the next unverified physical action, and whether it happened in this run in
   the redacted acceptance queue. Never report a user-handoff state when
   autonomous test authority already exists.
