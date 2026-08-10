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
- Once a value or interaction has current evidence and a user decision, freeze
  it. Do not reopen, recompute, revalidate, or alter it without new explicit
  user feedback or same-state counter-evidence.
- If the user identifies a prior UI change as wrong, record its faulty
  assumption, ignored evidence, impact, and prevention rule before another
  edit in that same region.

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
