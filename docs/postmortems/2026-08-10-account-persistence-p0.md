# NextN account-persistence P0 postmortem — 2026-08-10

## Verified outcome

On the selected device, a data-preserving explicit native re-verification
promoted the existing first-party browser session back into native state. No
account or password field was written in this recovery. After one
post-promotion retry, Favorites completed an authenticated native read.

The app was then force-stopped and cold-started without clearing data or
uninstalling. The native Account surface was still signed in and Favorites
again completed an authenticated native read. This is the required current
record-present S6 proof for this recovery path. Redacted state transitions are
recorded in the acceptance queue and login ledger; raw local captures are
retained outside Git and are not cited here.

This does **not** identify the historical physical cause of every earlier
missing record. An earlier `account_restore_record_absent` observation proved
only that no envelope was present at that observation.

## Observed recurrence and source defect — 2026-08-12

### Observation

After an in-place signed Debug installation and a data-preserving force-stop /
cold start, Account was still natively signed in but Favorites failed before
an authenticated result. The finite native error was `The ArkWeb account
transport could not load.` No visible login surface, credential entry, submit,
data clear, uninstall, or account mutation occurred.

### Causal code path and evidence boundary

1. Favorites calls the authoritative authenticated GET owner,
   `NhApiClient.favorites()`.
2. That request enters `NhArkWebSessionTransport.requestJson()`, whose
   `ensureReady()` waits for the root-owned ArkWeb host to finish its trusted
   origin bootstrap.
3. `NhArkWebSessionTransportHost` previously forwarded every ArkWeb
   `onErrorReceive` callback to `observeLoadError()`.
4. ArkWeb documents that this callback is raised for both the main resource
   and subresources; the event's `request.isMainFrame()` is the required
   discriminator. The old source therefore had a concrete false-failure path:
   any failed subresource rejected the trusted-origin bootstrap even when the
   main document and browser identity were usable.
5. That rejection propagates the observed fixed transport error through
   Favorites while the independent native Account projection remains signed
   in.

The correction in
`shared/src/main/ets/components/NhArkWebSessionTransportHost.ets` now invokes
`observeLoadError()` only when `event.request.isMainFrame()` is true. The
signed build was installed with `install -r`; a new force-stop/cold start then
produced a native signed-in Account and authenticated Favorites collection on
the same selected device, with no visible Web, sign-in prompt, loading, or
transport error.

The raw callback's frame kind was not retained, so this run proves the
source-level false-failure transition and its removal on the observed device
path; it does not falsely claim direct observation that the earlier callback
was a particular subresource.

### Ruled-out and still-unproven explanations

- In the preceding build, the retained host was changed from `CacheMode.None`
  to `CacheMode.Online` so its login refresh matches the visible
  re-verification route. The next cold-start Favorites request still failed
  with the same transport error. That change is retained as a source-aligned
  refresh policy, but the device result does **not** establish it as the cause
  or cure of this recurrence.
- This verification does not identify why any earlier token received a 401.
- It does not identify the historical physical origin of
  `account_restore_record_absent`.

## Follow-up invalidation and unproven recovery branch

At 23:06-23:08 +0800 a new paired native failure was observed: Favorites
showed its sign-in prompt and Account required re-verification. The explicit
native re-verification action restored Account without a visible form or
credential write, and Favorites then recovered after one settlement retry.
One later force-stop/cold-start again passed. This shows that ArkWeb retained
an identity capable of reissuing a usable access token, but no retained
diagnostic identifies why the preceding token pair received terminal 401s.

The source previously wrote the durable re-verification marker immediately
after the sealed-token replay also returned 401. That skips the browser-owned
refresh that the observed native re-verification later performs without
credentials. The follow-up source change gives that same retained first-party
browser identity one bounded, status-verified re-promotion attempt before the
marker is considered. Its signed Debug build passed one ordinary cold-start
Account/Favorites regression check. No terminal 401 occurred in that check,
so this automatic branch is implemented in source but **not yet device-proven**
and this postmortem does not claim the recurring invalidation is solved.

The marker now also retains one finite non-secret origin:
`terminal_401_browser_refresh_unsuccessful`. It is written only after the
bounded regular-ArkWeb refresh cannot re-promote a verified session, and a
later cold restore maps it to a fixed diagnostic stage. The migration passed a
normal force-stop/cold-start regression on the selected device; it has not yet
observed a real terminal event and therefore supplies future discrimination,
not retrospective proof.

## Verified causal path of the current failure

The current failure was an internally inconsistent session:

1. At cold restore, a token-shaped regular ArkWeb cookie jar caused
   `NhAccountSessionService.restoreInternal()` to return before reading the
   encrypted session envelope.
2. Native Account therefore published signed-in state from the regular jar,
   but `sealedFallbackCookieHeader` remained empty.
3. Favorites used the account-owned GET path. Its first 401 called the bounded
   recovery preparation; without the loaded sealed fallback that preparation
   returned false, so no replay was issued and Favorites surfaced the fixed
   request-level recheck error.
4. The Account UI and Favorites then disagreed: the former looked signed in,
   while the only authenticated product read could not be completed.

The fix is in `NhAccountSessionService.restoreInternal()`:

- a live regular ArkWeb jar remains the primary runtime identity;
- the service now non-destructively reads and decrypts a valid sealed envelope
  into `sealedFallbackCookieHeader` before returning;
- the regular jar is not overwritten during bootstrap;
- an RDB/HUKS/envelope failure cannot demote an otherwise usable regular jar;
- only a real first-401 recovery plus an actual replayed 401 can request
  durable re-verification.

The relevant boundaries are the regular-jar/fallback branch at
`shared/src/main/ets/services/NhAccountSessionService.ets:825`, the one-replay
Favorites gate at `shared/src/main/ets/network/NhApiClient.ets:540`, and the
atomic verified-envelope/marker transaction at
`shared/src/main/ets/storage/AccountSessionRepository.ets:80`.

After this change, the previously hidden fallback path was exercised. Its
recovery correctly led to a native re-verification state rather than an
inconsistent signed-in/recheck-error state. The subsequent explicit native
re-verification re-promoted the first-party browser identity, and the final
cold-start Account/Favorites observations passed.

## What was not established

- Why the earlier regular ArkWeb token or sealed fallback token received a
  server 401 is not established by these observations.
- The historical origin of `account_restore_record_absent` is not established.
  Current source has one explicit envelope deletion path: user-confirmed
  sign-out. The observed old absence cannot be retroactively attributed to it
  without the missing contemporaneous RDB/transition evidence.
- The proof covers the selected device, this fresh browser-session promotion,
  one force-stop/cold-start, and an authenticated Favorites read. It does not
  prove every future server, cookie-rotation, HUKS, or RDB fault mode.

## Why the earlier effort failed to solve it

1. I repeatedly treated source patches, builds, and no-record cold starts as
   if they resolved the user-visible path. They did not test the actual state
   in which a regular jar survives while the encrypted fallback is skipped.
2. I collapsed different observations into “login lost”: absent envelope,
   first-401 recovery unavailable, terminal replayed 401, and stale response
   transitions have different owners and allowed actions.
3. I added defensive branches before mapping the full startup-to-Favorites
   sequence, which obscured the early return in the regular-jar branch.
4. I allowed account-login execution preparation to occur inside timed
   recovery cycles. Two new cycles exceeded the 60-second ceiling without any
   credential input: first because the route was not ready, then because the
   generic WebView helper removed its own forward before the semantic driver
   could use it.
5. I previously wrote an overbroad postmortem and claimed evidence that was
   not current. That is replaced by this account of the observed path and its
   remaining uncertainty.
6. In the 2026-08-12 recurrence, I first treated the cache-mode divergence as
   the likely cause because the hidden and visible hosts used opposite modes.
   The immediate cold-start result falsified that explanation: the identical
   transport error remained. I then traced the exact error string to the host
   callback, checked ArkWeb's main-frame semantics, and fixed the actual
   unconditional callback transition. An observed failure must eliminate a
   proposed cause; it cannot be narrated as progress toward a claim.

## Durable prevention constraints

- Account, envelope, marker, and ArkWeb cookie ownership stay in
  `NhAccountSessionService`; pages only project published state.
- A regular jar must never bypass loading a valid encrypted fallback. The
  fallback may repair exactly one idempotent account-read 401, but must never
  overwrite a regular jar during bootstrap.
- A first 401, an unavailable recovery, public read, mutation, profile
  enrichment, or stale response must not become durable logout. A marker is
  allowed only after the recovery replay was actually issued and also returned
  401.
- Verified promotion must atomically write the envelope and remove the marker;
  explicit sign-out is the sole envelope deletion path.
- Every fresh Account/Favorites failure preempts other development. Completion
  requires the real device’s Account + Favorites cold-start evidence, not a
  code review or build.
- A timed login cycle starts only after device, route, credential handles, and
  a **kept** ArkWeb forward are ready. The forward is removed only after the
  terminal result using its exact two endpoints. A closed/overrun epoch cannot
  be resumed or retried in place.
- Login ledger entries retain only redacted stages and measured timestamps;
  screenshots are kept locally when captured and are never committed or
  automatically deleted.
- The retained ArkWeb host must treat only a main-frame load error as a
  trusted-origin bootstrap failure. Subresource failure is request-local and
  cannot downgrade an authenticated Favorites path.
- A cache-policy change and a callback-semantics change are separate causal
  hypotheses. Each requires its own same-device result; a build or source
  resemblance cannot merge them into one claimed fix.
