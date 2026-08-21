# NextN execution integrity protocol

This file is a behavioral control, not a test plan. It governs every claim,
scope change, agent delegation, and task handoff in this repository.

## 1. The user outcome is the only completion authority

- A task stays open until the outcome the user asked for has been observed at
  the required boundary, the user explicitly stops it, or a concrete external
  block prevents the next safe action.
- Source review, a script, a test, a build, installation, a screenshot of an
  unrelated state, and a no-record diagnostic are intermediate evidence. None
  may be described as completion of a runtime, persistence, visual, or user
  flow outcome.
- The latest explicit user instruction wins over an active queue, automation,
  heartbeat, previous plan, or sub-agent assignment. Stop conflicting work
  immediately, including already-running sub-agents.
- A temporary prohibition on executing one lane is an **execution hold**, not
  closure of its user outcome. Keep that outcome explicitly `OPEN`, preserve
  its evidence boundary and next permitted action, and do not remove its
  continuity record just because an intervening control or review task must
  happen first.
- An already granted authorization remains continuous across that hold. When
  the user-directed prerequisite is actually finished, resume the recorded
  next action automatically; do not ask for a second authorization, invent a
  per-turn permission boundary, or make a stale hold permanent. Only an
  explicit user stop or explicit instruction not to resume changes that.
- A heartbeat is a scheduling mechanism. It must never be used to imply that
  a task was completed, paused, abandoned, or handed back to the user.

### 1.1 No autonomous termination or abandonment

- While an outcome is `OPEN`, the agent must not mark a Goal complete or
  blocked, send a completion/final handoff, delete its continuity record, or
  switch to an unrelated lane merely because a source patch, build, test,
  device command, capture, retry, or explanation has finished.
- A failed command is an observation, never a task terminal. Record its exact
  operation and result, preserve the active outcome, and perform the next
  safe recovery or retry in the same continued run. Only a concrete external
  condition that prevents that next action may be reported as a block.
- A user question, criticism, or request for an explanation is a route
  correction. Answer the question precisely, then recover the active outcome
  and execute its next safe action; it is not permission to end, park, or
  silently replace the work.
- A status report may describe only work already observed and the next action
  that remains. It must not use an intermediate result as a substitute for
  that action or imply that the user must re-authorize an already authorized
  continuation.
- Material source or control changes are not durable until their exact diff is
  reviewed and they are committed in a scoped Git commit. A commit records a
  checkpoint; it never closes the user outcome by itself.

### 1.2 Recoverable tool refusals are not user decision points

- A sandbox, index-lock, lease-lock, or execution-policy refusal is an
  observation about one command form. It is never a reason to yield, end a
  status with the refusal, request a fresh authorization, or treat the active
  lane as blocked when the user has already authorized the underlying work.
- When an ordinary command cannot write a Git index, repository lease, or
  local evidence artifact, immediately retry in the same run using the
  smallest applicable permitted form: one operation, exact staged paths or
  exact selected device, and no unrelated chained work. Do not first ask the
  user to approve the retry merely because the tool chose a stricter command
  mode.
- If a compound elevated command is refused, decompose it before reporting
  anything: for example, stage the exact files, inspect the staged diff, then
  commit; or acquire/renew the exact lease, then run the one device command.
  A policy decision on the compound command says nothing about those smaller
  operations. Continue the sequence automatically.
- A user report is permitted only after the exact minimal operation has itself
  been refused and no materially narrower in-scope operation remains. That
  report must name the one failed operation, preserve the active outcome as
  `OPEN`, and state the next automatic retry or the precise additional
  authority required. It must never be the turn's terminal message while a
  safe retry remains.
- Git checkpoints are part of ordinary requested implementation. After an
  exact diff review, stage only the declared paths and commit automatically.
  Do not turn an index-write mode change into a request that the user repeat
  an existing instruction to commit. If a user interruption occurs between
  staging and commit, first inspect the index and resume that same commit
  before changing lanes.

## 2. Claim vocabulary is fixed

Use only the narrowest true statement.

| Evidence actually obtained | Permitted wording | Forbidden wording |
| --- | --- | --- |
| Code changed, not built | `implemented in source` | `fixed`, `solved`, `works` |
| Build succeeded | `build succeeded` | `validated`, `works on device` |
| HAP installed | `installed` | `preserved data`, `works after restart` |
| One device state observed | `observed <exact state>` | any broader causal or lifecycle claim |
| Exact requested end-to-end state observed | `accepted for <exact path>` | generalization to unobserved branches |

Never infer a cause from an absence. For example, `record absent` means only
that the record is absent at that observation; it does not prove which
historical operation removed it.

## 3. Root-cause work must precede a fix claim

For a persistence, lifecycle, routing, or data-loss report, map before editing:

1. the authoritative owner and state representation;
2. every write, delete, invalidation, migration, and replacement path;
3. the event ordering across startup, background/foreground, request retries,
   and process death;
4. the one observation that would disprove the proposed cause.

If that map does not isolate a cause, state `cause not established` and keep
the task open. Do not manufacture a new login, data reset, preference change,
or unrelated interaction merely to produce a convenient end state.

A patch is allowed only when it removes a source-proven bad transition or adds
an observation that distinguishes previously conflated states. A patch may not
be justified by a test written to mirror the new implementation.

## 4. UI work is reference-first and device-judged

- UI static contracts, source-shape checks, synthetic layout matchers, and
  locally generated fixtures are prohibited as UI acceptance evidence. Do not
  create, run, update, or cite them to establish visual correctness.
- Before a visible edit, identify the nearest reference's whole affected tree:
  scroll owner, fixed chrome, section ownership, child ordering, geometry,
  action placement, and state transition.
- A visible change remains unaccepted until an actual same-state, same-viewport
  result is reviewed against that reference. If such a comparison is not
  available, say exactly that; do not substitute source similarity.
- A reported visual defect triggers a sibling review inside the same parent
  tree before any patch. Do not turn one reported leaf into a license to
  redesign unrelated behavior or data semantics.

### 4.1 UI operation chains are continuous, not per-click investigations

- Separate **route discovery** from **route execution**. Discovery may inspect
  source, screenshots, and current UI state once to establish a semantic
  entry, explicit decision gate, or generic direct route.
- Once a route is known, execute its declared UI actions continuously. Do not
  insert source reading, layout dumping, screenshot capture, coordinate
  inference, model deliberation, or commentary between ordinary actions.
- Repeated paths must use a generic direct intent or a proven semantic action;
  a coordinate inferred from an old screenshot is never a reusable entry
  anchor. Do not reconstruct a known route by scrolling and guessing a tap.
- Screenshot or multimodal inspection is allowed only for: (1) first-time
  route discovery, (2) an explicit visual decision gate whose result changes
  the next action, or (3) terminal acceptance or exception evidence. It is not
  a routine step between known actions.
- Before a capture can be called either the reference or the implementation,
  verify its foreground identity from the current layout root or ability state
  and record the root window bounds. A filename, the requested `aa start`
  command, or a prior foreground observation is not identity evidence.
- A reference/implementation pair is valid only when each capture has its
  expected foreground bundle and both have the same effective root viewport
  (width, height, orientation, and split/window state) and the same reviewed
  state. If any of those facts differ, retain the raw captures locally and
  mark the pair rejected; do not visually compare it, infer a defect, or use
  it to justify a source edit.
- A failed foreground launch or unsupported window-geometry request is an
  evidence failure, not a product finding. Diagnose or re-establish the
  capture precondition first; never relabel the resulting artifact as a
  reference to make a comparison appear complete.
- If a terminal state differs from the declared route outcome, preserve one
  diagnostic capture, mark that chain rejected, and repair its semantic route
  before another run. Do not mask the failure with repeated coordinate and
  screenshot loops.
- When the user requests visual auditability, retain the resulting screenshots
  in a named local audit directory and report their paths. Do not automatically
  delete them; deletion requires a later explicit user instruction. Raw images
  remain local evidence and are never added to source commits unless the user
  explicitly asks.

### 4.2 UI change rationale and freeze gate

- Before any visible UI source edit, add a record to
  `docs/qa/nextn-ui-change-ledger.md`: the user instruction or real
  reference/device evidence, whole parent-tree boundary, exact before/after
  values or structure, minimality rationale, visual verification plan, and
  unresolved risk. A UI commit must include that record.
- “Polish”, “compact”, “balanced”, or a local text/size heuristic are not a
  rationale for a visible change.
- Settings copy defaults to title plus selected value or switch state. A
  subtitle is allowed only when omitting it would change the operation's
  meaning or outcome; it must not explain routine behavior, storage scope, or
  implementation detail.
- Once a value or interaction has current evidence and a user decision, freeze
  it. Do not reopen, recompute, revalidate, or alter it without new explicit
  user feedback or same-state counter-evidence.
- If the user identifies a prior UI change as wrong, record its faulty
  assumption, ignored evidence, impact, and prevention rule before another
  edit in that same region.

### 4.2.1 Stateful overlay and IME guard

- For any visible change to a scroll owner, fixed/overlaid control, composer,
  sheet, or keyboard-aware surface, the pre-change ledger record must name
  every newly affected user-visible state. A successful ordinary-focus state
  never accepts a reply, prefilled, expanded, error, empty, or keyboard-open
  state that was not observed separately.
- A reference-derived page must preserve the reference's destination and
  parent ownership before adapting an NH data/action leaf. Missing server data
  or unsupported actions do not justify locally reassembling the route,
  scroll/overlay relationship, or keyboard owner.
- In a resized-keyboard state, `visible=true`, a successful input injection,
  or a source-level size calculation is not evidence that a control is usable.
  Review the raw current screen and ensure every affected interactive leaf's
  original bounds remain within the actual resized application window. If the
  screen and layout disagree, the screen is counter-evidence and the state
  remains OPEN.

### 4.3 Frozen-surface register and no-repeat rule

- `docs/qa/nextn-ui-change-ledger.md` is the current register of reviewed UI
  surfaces. Every visible surface is either **FROZEN**, **OPEN**, or
  **EVIDENCE-ONLY**. A label records the evidence boundary; it is not a visual
  completion claim.
- **FROZEN** means no screenshot, source inspection, UI test, source edit, or
  value recomputation may be performed for that surface. It may reopen only
  after (a) a visible source change inside the named boundary, (b) new explicit
  user feedback about that boundary, or (c) same-state counter-evidence.
- **OPEN** means a required decision or evidence boundary has not been reached.
  It is not permission to repeatedly revisit the surface. Record one concrete
  next evidence/action and leave it alone until that action becomes available
  or one of the three reopening triggers occurs.
- **EVIDENCE-ONLY** means a prior observation is retained but lacks a valid
  same-state comparison or a decisive device state. Do not rerun it merely to
  obtain another similar capture; retain it until a materially new comparison
  precondition exists.
- Before any UI work, select exactly one non-frozen boundary from the register
  and write why it is newly actionable. If no boundary is newly actionable,
  do not substitute repeated review, a UI static contract, or a synthetic
  test for progress.

## 5. Scope and delegation discipline

- There is one active lane. An audit may identify candidates, but it may not
  create an implementation queue across the product without a user decision.
- A sub-agent receives a bounded question and may not expand it into feature
  work, static acceptance tooling, or a new product design.
- No sub-agent result is a completion claim. The owner must inspect current
  files and reconcile contradictory findings before making a user-facing
  statement.
- Do not change a reference-derived interaction into a different product
  behavior merely because the reference's data source differs. Preserve the
  product capability and ask before a material behavior tradeoff.

### 5.1 Reference-audit disposition

- File inventories, count differences, and structural-pattern scans are
  discovery aids only. Generated or untracked files can change raw counts, so
  use the tracked source set when a count matters and never treat the count as
  proof of either a defect or audit completeness.
- Trace each behavior-relevant candidate in both current parent trees and
  classify it as a confirmed missing behavior, a product-specific leaf
  difference, a split owner, or a false positive. Only a confirmed missing
  behavior with the evidence required by Sections 3 and 4 may become an edit.
- Stop a broad audit after its candidates have concrete dispositions and no
  current reproduction or counter-evidence remains. Reopen only for a new
  reproducible problem, a relevant reference change, or a change inside the
  affected parent tree; a large number of differing files is not by itself a
  reason to continue.

## 6. Status and handoff format

Every status contains only:

1. the exact user outcome still open;
2. evidence newly observed in this run;
3. what remains unproven; and
4. the next safe action, or the exact external block.

Do not repeat a catalogue of prior mistakes, call an intermediate milestone a
completion, or hide an unresolved boundary behind a generic `done` message.
If a durable task is interrupted, preserve its active state and next action in
the project ledger without changing its completion status.

## 7. Change history discipline

- Keep every material change narrow and attributable to one source-proven
  problem.
- Before claiming a change is ready, inspect its exact diff and check that it
  does not include unrelated edits. If the workspace is not a Git worktree,
  say that plainly; do not invent commit or diff evidence.
- Do not use repeated rewrites as a substitute for locating the owner and
  causal transition. Revert or remove a speculative change once it is shown
  to be unsupported.

## 8. Conditional preemption — account persistence P0

Account-persistence P0 is **OPEN whenever current native Account or Favorites
evidence proves that the session is absent or unusable**. It preempts every
other lane immediately at that point; an older no-record observation, a past
build result, or an account concern without current S0 evidence does not by
itself stop the active delivery lane. Once triggered, its completion requires
both:

1. real-device proof on `192.168.50.237:12345`, without clearing data, that a
   completed login survives force-stop/cold start, native account remains
   authenticated, and Favorites completes an authenticated read; and
2. a complete postmortem written in-repository after that proof: the verified
   root cause and causal code/data path; why the prior multi-hour work did not
   solve it; each incorrect assumption or premature claim; the missing
   evidence; and the durable design and execution constraints that prevent a
   recurrence.

Neither a source patch, build, no-record observation, nor a new login used to
mask an unresolved regression satisfies either condition. Once P0 is
triggered, do not close, archive, pause, or switch it before both conditions
are met or the user explicitly stops it. The original device/login
authorization remains continuous; do not request a new authorization to
continue the recorded path.
