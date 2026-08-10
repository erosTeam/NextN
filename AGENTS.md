# NextN execution controls

## Execution-integrity override

Read and follow `docs/controls/nextn-execution-integrity.md` before planning,
delegating, editing, validating, or reporting work in this repository. Its
latest-user-instruction, evidence, UI-static-contract prohibition, and
completion-claim rules override any conflicting queue, heartbeat, or older
protocol language.

When the user temporarily prohibits execution in a lane, immediately stop
every conflicting device command, source edit, build, test, automation, and
sub-agent, but preserve that lane as `OPEN`. An execution hold is never task
completion, a blocker, a handoff, or permission to delete its continuity
record. Existing authorization remains valid through that hold: once the
user-directed prerequisite is actually completed, resume the recorded action
without asking for fresh, per-turn, or per-minute permission. Only an explicit
user stop or replacement of the outcome can close it.

## HarmonyOS work

Before inspecting source, editing, building, or operating a HarmonyOS device,
read and apply `harmony-mandatory-preflight`. It in turn requires
`harmony-next`; device, HDC, ArkWeb, screenshot, or UI-automation work also
requires `harmony-run-device-diagnostics`.

For every device-affecting command, use `scripts/device-lease --device <full-target>`
as documented in `docs/device-lease.md`. The lease is an agent coordination lock,
not a device-selection default or an authorization mechanism.

Keep an active multi-step objective explicit. A user question, correction, or
status request changes the relevant detail of that objective; it never ends or
replaces an unfinished implementation or device-acceptance path unless the
user explicitly stops or replaces it.

## UI reference integrity

For any visible NextN change grounded in NextE or ErosN, the reference page is
the default parent-tree contract, not a loose feature suggestion.

- Before editing, map the complete affected parent tree: scroll/scaffold,
  chrome, sections, ordering, geometry, and state transitions. Preserve that
  tree by default. An NH difference may replace only a leaf data source,
  action, or unsupported leaf; it does not authorize restructuring its parent.
- Do not substitute a reference composite with generic `Row`, `Column`, list,
  or grouped-card assembly merely because the local primitive is convenient.
  A changed parent tree requires explicit source evidence for the NH boundary.
- Build success and source inspection never establish visual parity.
  Before a visible change is accepted, compare a current, same-state and
  same-viewport NextN capture directly against the reference capture and fix
  hierarchy, spacing, insets, action placement, and state presentation found
  there.
- One owner must review the whole affected page after all leaf changes. A
  locally correct subcomponent cannot close a page-level visual change.
- When a visible defect is found, review its sibling regions inside the same
  parent tree before patching; do not apply a one-point correction and then
  move to another page.

## Authorized real-login acceptance

When the user has supplied NextN test credentials and authorized real-device
login testing, the agent must autonomously enter the account and password,
activate the login control, and complete the acceptance path. Credential
redaction applies to output and nonessential artifacts only; it is not a
reason to wait for manual entry.

The required evidence sequence is: current UI precondition; account input;
password input; login activation; post-action state; native account/profile
state; force-stop/cold start without clearing data; authenticated Favorites
state. Builds and source review are supplementary and do
not close this acceptance path.

After every interruption, resume the next pending physical acceptance action.
Do not substitute unrelated source work, a wait-for-user state, or a summary
for that action. Keep secrets out of messages, command output, screenshots,
layouts, and logs whenever possible, but do not omit the authorized action.

## Long-running task continuity

For this project, a user-supplied test account plus an instruction to test is
an authorization to operate the visible login form end-to-end. Do not turn
credential redaction, a scoped diagnostic subtask, a locked screen, or an
intervening user message into a request for the user to submit the form.
Redaction controls what is retained or reported; it never removes the
authorization to enter the credentials, press the login control, and verify
the result.

## Durable login state-machine reuse

Before any NextN account credential action, read and follow
`docs/device-protocols/nextn-account-login-acceptance.md`. It is the
authoritative S0–S6 state machine for this repository and survives thread
compaction, agent changes, and resumed device work.

- Start at S0: prove the current native Account and Favorites state first.
  A restart, `install -r`, protected screenshot, historical result, or input
  command success never by itself authorizes another login attempt.
- Enter S1 only after current safe evidence proves the session absent or
  invalid. Use the protocol's semantic field anchors and postconditions;
  coordinate-based `uiInput inputText` is forbidden for account credentials.
- Keep one volatile `attemptEpoch`: one account entry, one password entry, and
  one submit. After submit, only state observation or the protocol's named
  diagnostic branch is allowed. Do not retype, re-clear, or re-submit inside
  that epoch.
- If cold-start Account or Favorites verification fails, collect only the
  fixed restore/401 stages before deciding whether a new visible-login epoch
  is warranted. Do not use re-login to mask an unresolved persistence or
  transport failure.

The protocol controls *how* the already-authorized autonomous login happens;
it must never be interpreted as a request for manual user input.

## Mandatory re-login ledger

Before any S2 credential entry, create a redacted attempt record in
`docs/qa/nextn-login-attempt-ledger.md`. The record must state the concrete
reason a new attempt is warranted, the current S0 Account and Favorites safe
outcomes, the available restore/401 diagnostic stage, and confirmation that
no data clear or uninstall occurred. It must separately record login-page
entry, account input, password input, submit, native promotion, cold start,
and Favorites verification. A missing or inconclusive record prohibits
credential input; it never authorizes a speculative re-login.

Every cold-start S0 observation that finds the session absent is a mandatory
**login-cycle timing record**, even if no credential is ultimately entered.
Record the local timestamp immediately when the restart/restore boundary is
observed, the concrete reason the session is absent, and the prior cycle's
terminal outcome and elapsed time before beginning another cycle. Record the
separate WebView-visible timestamp, then the native-success timestamp and
elapsed time from the S0 loss boundary to native promotion; on any terminal
failure or unresolved state, record the last observation timestamp and
elapsed time instead. Never infer or invent an earlier cycle duration when the
start/end timestamp was not retained: mark it
`unavailable-from-existing-evidence`. This timing record is not optional
bookkeeping and must be updated before yielding, switching lanes, or opening
another login WebView.

For a ready visible form with the authorized account/password available and no
active challenge, the operational ceiling is **60 seconds from the cold-start
S0 loss boundary to native promotion**. A cycle exceeding that ceiling must record
the exact first blocking phase (`credential`, `form`, `challenge`, `network`,
or `native-persistence`) and elapsed time; it may never be silently restarted
or hidden behind a later successful login.

Before starting a timed cycle, finish all non-login work: build/install,
device wake/lease, prior-cycle ledger closure, and route preparation. Once
`session-loss-detected-at` is written, execute only the minimal current-device
route and semantic credential sequence continuously. Do not insert source
inspection, document edits, build work, layout archaeology, new helpers, or
unrelated diagnostics before native promotion or the 60-second overrun has
been recorded. If the cycle overruns, record the first blocking phase rather
than changing the start time or restarting the clock.

The ledger never contains credentials, account/profile values, cookies,
tokens, raw layouts, URLs, screenshots, or DevTools target data. Entering a
visible login page without input is still recorded as a navigation event, not
as a re-login attempt.

At the start and end of every resumed turn, recover the active objective and
the next unverified physical acceptance step. An inserted question is a
correction to that queue, not a completion boundary. Do not announce, imply,
or enter a "waiting for user submission" state when the test account and
automation authorization already exist. Only a concrete external authority
block may pause the queue, and it must be reported with the failed operation
and the next retry action.

## Mandatory continuity gate

Before yielding a status, switching lanes, or ending a resumed long-running
task, state internally: (1) the active objective, (2) the next unverified
physical action, and (3) whether that action has actually been performed in
this run. If credentials and device authorization already exist, an unfilled
or unsubmitted visible login form is an action to perform autonomously, never
a user handoff. A local subtask completion, redaction constraint, transient
device condition, or user interruption cannot change that rule. Never use
the phrases "wait for the user to submit" or "manual submission required" in
this project unless the user explicitly revoked autonomous-login authority.

When it exists, read `docs/qa/nextn-active-acceptance.md` before resuming a
long-running device or login lane, then update it after a material physical
result. It contains only redacted state, completed evidence, and the next
physical action; it must never contain credentials, profile values, cookies,
or screenshots.
