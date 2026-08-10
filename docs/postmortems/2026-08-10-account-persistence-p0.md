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
