# NextN agent controls

This file is the repository entrypoint, not a copy of detailed protocols.
Read each linked document when its lane applies; the full protocol overrides
the summary here.

## Always

- Before planning, editing, validating, delegating, or reporting, read
  `docs/controls/nextn-execution-integrity.md`.
- The latest user instruction wins. A temporary execution hold stops
  conflicting work but keeps its outcome `OPEN`; resume after the prerequisite
  unless the user explicitly stops or replaces it.
- Before editing an existing behavior, query
  `docs/controls/rejected-approaches.md` with the affected file and symbol
  names. A matching `REJECTED` entry requires explicit user reopening.
- Keep the active outcome and next unverified action explicit. Questions,
  intermediate results, command failures, builds, and commits do not close an
  unfinished runtime or device-acceptance path.
- Make narrow, evidence-backed changes. Review the exact diff and preserve
  unrelated work.

## HarmonyOS work

- Before inspecting HarmonyOS source, editing, building, or using a device,
  apply `harmony-mandatory-preflight`; it requires `harmony-next`.
- Device, HDC, ArkWeb, screenshot, log, or UI-automation work also requires
  `harmony-run-device-diagnostics`.
- The signed-build entrypoint is `scripts/build-hvigor-signed.sh`. The legacy
  underscore spelling does not exist; resolve the current filename before use.
- Every device-affecting command must use
  `scripts/device-lease --device <full-target>` per `docs/device-lease.md`.
  A lease coordinates agents; it neither selects a device nor grants authority.
- After transport recovery, stateful or evidentiary HDC work must use
  `scripts/run-device-protocol` with the full target, active lease ID, and a
  project-owned manifest. The entrypoint performs the mandatory dry-run and
  then invokes the checked manifest runner inside the lease. Direct lease-
  wrapped HDC is limited to target discovery/reconnect, `shell echo`, boot-
  completion readback, and artifact receive; the lease helper rejects other
  direct HDC forms.

## Reference-derived UI

For visible work based on NextE or ErosN, treat the reference page's full parent
tree as the default contract.

- Map the scroll/scaffold owner, chrome, sections, ordering, geometry, actions,
  and state transitions before editing. Product differences may replace a leaf,
  not silently restructure its parent.
- Do not replace a reference composite with a convenient generic assembly
  without source evidence for that boundary.
- Source similarity and build success are not visual acceptance. Compare a
  current same-state, same-viewport NextN capture with the reference.
- Review the whole affected page and sibling regions. Follow the UI ledger and
  freeze rules in the execution-integrity protocol.

## Authorized account/login acceptance

Before credential or login work, read the authoritative S0-S6 protocol at
`docs/device-protocols/nextn-account-login-acceptance.md`. Before resuming an
existing device/login lane, also read `docs/qa/nextn-active-acceptance.md`.

- Supplied test credentials plus authorization to test permit autonomous form
  entry, CAPTCHA/challenge interaction, and submission. That authorization
  persists across turns and context compaction: do not ask for another
  confirmation, pause at a visible CAPTCHA, or hand the challenge back to the
  user. Redaction is not a manual-user handoff.
- Start from current safe native Account and Favorites evidence. Before a new
  credential epoch, create the required redacted record in
  `docs/qa/nextn-login-attempt-ledger.md`.
- Use semantic field anchors; coordinate-based credential input is forbidden.
  Never repeat credential entry or submit within one attempt epoch.
- Acceptance requires native promotion, force-stop/cold start without clearing
  data, native Account state, and authenticated Favorites state. Builds,
  installs, a visible or completed CAPTCHA, compatibility diagnostics, Web
  state, and input-command success are supplementary and must never be
  reported as a completed login.
- Keep secrets and sensitive session data out of messages and artifacts. After
  interruption, resume the next pending physical action; do not request manual
  submission when autonomous authority already exists.

## Before status, lane switch, or finish

Recover the active outcome, its next unverified runtime/physical action, and
whether that action was actually performed in this run. Update
`docs/qa/nextn-active-acceptance.md` after a material physical result. Report
only observed evidence, what remains unproven, and the next safe action or exact
external block.
