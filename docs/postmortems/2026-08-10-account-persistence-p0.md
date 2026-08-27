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

The next build also records a single fixed diagnostic code,
`account_arkweb_transport_main_frame_load_failed`, only after the host has
already classified an ArkWeb error as main-frame. It retains no request URL,
error code, response, cookie, account data, or browser payload. A future
recurrence can therefore distinguish a true main-document failure from an
ignored subresource callback without changing session state merely to collect
evidence.

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

## 2026-08-27--28 continuation: unified native lifecycle (OPEN)

This section supersedes the earlier document's description of the **current**
request architecture. It does not delete the historical evidence above. The
temporary `NhArkWebSessionTransportHost` / `NhArkWebSessionTransport` request
path no longer exists: ArkWeb is now only the original first-party visible
login and Turnstile host. Native NH API traffic uses one lifecycle:

`NhApiClient` -> `NhSessionHttpClient` -> `NhApiHttpTransport`

`NhSessionHttpClient` owns request scope, the access/refresh generation,
single-flight refresh, profile verification, safe-read replay, response
Cookie checkpointing, and terminal-401 publication. `NhCookieAuthority` is
the sole `WebCookieManager` owner. `AccountPage` is the sole native account
management page; `BrowserSessionPage` is a login-only destination that must
return to `AccountPage` after real native promotion.

### What the current evidence actually establishes

The original multi-day failure is only **partially** explained. On 237, a
previously valid v3 envelope with access and refresh present restored on
2026-08-23. The first authenticated read later returned 401, and the fixed
refresh endpoint also returned 401. This proves that the retained renewal
credential was rejected by the server; it does not retrospectively distinguish
expiry, revocation, or a missed earlier credential rotation because that
response carried no retained reason or rotation evidence.

The continuation did establish these separate causal defects:

1. **Ordinary native responses discarded `Set-Cookie` (source-proven).**
   The former native wire response retained status/body metadata but did not
   expose first-party `Set-Cookie`. A successful API response could therefore
   rotate `access_token` or `refresh_token` while neither the ArkWeb
   compatibility jar nor the HUKS/RDB native generation was updated. This is a
   concrete lifecycle hole consistent with a later stale-refresh rejection.
   It is not yet proven to be the historical physical trigger because no
   natural auth-cookie rotation has occurred in the current observation
   window.

   A follow-up audit found that the first global-sink candidate still rewrote
   the regular jar after a response auth rotation: it stored the original
   `Set-Cookie`, then `applyRefreshedApiTokens()` wrote the same values again
   with JSON-refresh defaults (`Max-Age=1209600`, fixed path/security/SameSite)
   and saved the jar a second time. That defeated the claimed server-attribute
   preservation. The response path now performs exactly the original
   `Set-Cookie` jar write plus the HUKS/RDB value-pair checkpoint; only a JSON
   token refresh without authoritative auth `Set-Cookie` may synthesize the
   compatibility jar values. This correction is source/build verified and
   installed on 237, but still awaits a natural rotating response.

   The same audit also found an ArkWeb API semantic error in the initial sink.
   `configCookieSync(..., includeHttpOnly)` uses its fourth argument to permit
   replacement of an **existing** HttpOnly cookie; it does not assign the
   attribute to the incoming value. Deriving that argument from whether the
   new header contained `HttpOnly` could prevent a server deletion/rotation
   header without that attribute from replacing the old HttpOnly refresh
   cookie. The fixed first-party response sink now always permits replacement;
   the raw server header still exclusively determines the resulting Cookie
   attributes.

2. **A late old-generation 401 launched a second refresh (device-proven).**
   At 02:56 on 237, two requests using the same old access generation completed
   on opposite sides of the first refresh. The first 401 refreshed,
   checkpointed, and verified a replacement pair. The second old 401 arrived
   after that promise had been cleared and launched a second refresh using the
   newly published global renewal credential. Favorites ultimately recovered,
   so this run proves duplicate credential churn, not terminal account loss.
   The old lock was keyed only by a session epoch that intentionally did not
   advance for in-place token rotation; request tokens had no credential
   revision.

3. **Current terminal reasons were rejected by an obsolete marker allow-list
   (source-proven).** The terminal lifecycle emitted
   `terminal_401_replay_rejected` and
   `terminal_401_refresh_token_rejected`, while the repository accepted the
   removed `terminal_401_browser_refresh_unsuccessful` reason. A conclusive
   401 could therefore fail before persisting/publishing the recovery gate,
   explaining a silent user-visible failure path. The repository now accepts
   the two actual reasons, and a marker-write failure can no longer suppress
   the current process's fail-closed verification state. A natural terminal
   401 has not yet occurred under this candidate, so the HDS result remains
   device-unproven.

4. **Account ownership was confused with authentication (user A/B plus
   source-proven).** A retained saved account keeps `signedIn=true` while
   `authenticationAvailable=false` and `verificationRequired=true`.
   `BrowserSessionPage` previously consumed its one-shot return latch from the
   ownership bit before the replacement Web login promoted a new session. The
   later real promotion could then remain stranded in WebView. Signing out
   first made the control work because it removed the misleading ownership
   bit. Return is now scheduled only for
   `authenticationAvailable && !verificationRequired`; sign-out is not a
   login precondition. The next natural terminal-401/re-login cycle on 237 is
   still required to accept this correction.

5. **The compatibility jar could suppress authoritative saved-envelope
   recovery (source-proven).** If the primary envelope was absent or unreadable,
   saved HUKS envelopes were tried only when the regular ArkWeb jar was also
   empty. A readable compatibility jar could therefore manufacture a
   verification-required state over recoverable ciphertext. Saved-envelope
   fallback is now independent of the jar. The 04:12 in-place installation on
   237 exercised an ordinary primary restore, not this fallback, so only the
   source correction and non-regression are established.

6. **Response-Cookie extraction and sink rejection were still silent
   (source-proven).** The first global response boundary could discard an
   unparseable, over-limit or invalid `Set-Cookie` value without propagating a
   failure, and the Cookie sink could skip an invalid header before the caller
   logged the checkpoint as stored. That reintroduced the same false-success
   class at the supposedly unified boundary. Extraction now returns an explicit
   rejected state; the sink validates the complete bounded batch before its
   first mutation; either rejection fails the request and emits only the fixed
   value-free rejected diagnostic. The 05:13 installation proved ordinary and
   refresh-path non-regression, but no response `Set-Cookie` arrived, so live
   rejection/rotation acceptance remains pending.

7. **The Harmony adapter boundary and the two NetworkKit Cookie encodings were
   conflated (source-proven).** NetworkKit exposes `HttpResponse.header` and
   `HttpResponse.cookies` separately. Its exact response `Set-Cookie` values
   are an array in `header['set-cookie']`; its `cookies` string is instead a
   CRLF-separated libcurl/Netscape cookie-jar snapshot. The bundled
   `@ohos/axios` 2.2.12 adapter copied `data.header` but dropped the separate
   `data.cookies` field. The 05:37 interceptor candidate recovered the dropped
   property but still treated jar rows as raw `Set-Cookie`, so a natural Cookie
   could have failed closed despite the empty-Cookie cold check passing. The NH
   transport now captures both values in a NetworkKit `FINAL_RESPONSE`
   interceptor, prefers the exact header array, uses a bounded first-party
   seven-field parser only as a fallback, disables opaque redirects, and
   rejects unavailable, unobserved or lossy capture. The 05:57 process on 237
   restored and completed authenticated Favorites with the corrected HAP.
   That response exposed no Cookie, so a natural rotating/deleting response and
   its later cold restore remain pending device evidence.

8. **Displayed verification UI and renewable native authority were still
   conflated.** The root handler consumed a terminal revision when the HDS
   Snackbar was shown, so temporary suppression by Safe Mode or the login route
   could permanently hide an unhandled recovery action. Separately, the sealed
   payload decoder called a version-2 access-only record valid and did not
   require renewal material in version 3. Those paths could recreate the exact
   contradictory state of a selected retained account without usable server
   authority. Display, suppression and user handling are now separate states;
   version 2 and version 3 without renewal retain ownership but require
   verification. The 06:17 cold process on 237 restored the existing complete
   version-3 pair and completed Favorites on HAP SHA-256
   `94dcffe893e0577c80a4fb9e56d130445661b5898ed46d8ce21b02e99079e366`.

### Current durable design

- Every NH v2 endpoint declares one of `PUBLIC`, `ACCOUNT_PREFERRED`, or
  `ACCOUNT_OWNED` and crosses the same native transport. No feature owns a
  Cookie jar, refresh call, retry loop, or terminal-auth transition.
- Every bounded first-party response sends its `Set-Cookie` values to
  `NhCookieAuthority` before the caller receives the response. A successful
  response may change native authority only for the exact current session and
  credential revision; the access/refresh pair crosses the HUKS/RDB durable
  checkpoint before authorizing another request.
- One session-wide refresh promise is shared across in-place credential
  rotation. After it settles, a credential revision identifies a late response
  from the previous pair. Refresh rejection and replay-401 publication require
  the exact current session **and** credential revision. Mutations are never
  replayed automatically.
- A terminal refresh/replay 401 retains account ownership, withdraws request
  authentication, persists the non-secret verification marker when possible,
  and publishes verification-required even if the local marker write fails.
  The sole UI is the root-owned indefinite HDS Snackbar with close and original
  WebView sign-in actions; retained feature content remains mounted.
- Cold restore treats the sealed HUKS generation as native request authority.
  The ArkWeb jar is a compatibility input/output boundary and cannot suppress
  an available primary or saved encrypted envelope.

### Current 237 evidence boundary

- At 00:25, natural access expiry produced initial 401 -> refresh 200 ->
  durable replacement checkpoint -> profile verification -> one safe replay
  -> authenticated Favorites.
- A separate 00:27 force-stop/cold start restored that replacement pair, and
  later 00:56, 01:56, 03:56, 04:12, 04:32, and 04:38 processes remained healthy
  without clearing data.
- The 02:56 run directly reproduced the duplicate-refresh concurrency defect.
- At 05:13, the corrected candidate exercised the corresponding late-old-
  credential boundary: one initial 401 launched exactly one refresh 200, the
  replacement pair crossed the durable checkpoint, a later old 401 was marked
  stale, the safe replay recovered, and Favorites succeeded. No second refresh
  endpoint or terminal publication occurred.
- The installed 05:13 candidate has HAP SHA-256
  `5c1ca6575e23994df3b61e90190c7b53468ba19e48cca8bc7c147e07dd75b14b`.
- Those header-only and jar-as-Set-Cookie candidates are superseded. The
  current installed 237 candidate keeps the exact Set-Cookie array plus the
  separate source-defined cookie-jar fallback, separates HDS suppression from
  user handling, and rejects non-renewable envelopes. It has HAP SHA-256
  `94dcffe893e0577c80a4fb9e56d130445661b5898ed46d8ce21b02e99079e366`.
  Its 06:17 cold process restored the durable pair and completed authenticated
  Favorites, but received no observable response Cookie.

These results do **not** yet establish cross-day survival, a natural first-
party auth `Set-Cookie` checkpoint, the saved-envelope fallback on device, or
a natural terminal 401 with retained Account, close/re-login HDS Snackbar, one
original-WebView login, native return, cold restore, and authenticated
Favorites. The P0 and this postmortem therefore remain OPEN.

### Why the extended effort still failed to close the user outcome

1. Cookie handling was implemented on selected login/refresh branches instead
   of at every NH response boundary. A local fix could pass immediately while
   ordinary server rotation remained unowned.
2. Saved-account ownership, authentication availability, browser identity,
   and durable native request authority were repeatedly collapsed into one
   `signedIn` idea. That produced contradictory Account/Favorites state and
   the retained-account WebView return failure.
3. The first single-flight correction guarded an active promise but did not
   identify a late response after that promise settled. The missing credential
   revision was exposed only by the real 02:56 overlap.
4. Obsolete marker reason vocabulary remained disconnected from the request
   lifecycle, so a terminal failure could be conclusive internally and still
   have no durable or visible recovery signal.
5. Builds, in-place installs, one healthy cold start, and source-shaped tests
   were repeatedly allowed to look like closure before the natural lifecycle
   events occurred.
6. Login automation work was allowed to become a separate product-flow
   project instead of remaining an external atomic acceptance tool. It delayed
   the actual persistence investigation and repeatedly exercised invalid
   challenge timing. Product-embedded acceptance bridges and duplicate account
   UI were removed; the original first-party WebView flow remains.
7. A report about an unspecified second device was incorrectly expanded into
   authorization to operate 197. That installation is excluded from product
   evidence. The active target set for this P0 is exactly
   `{192.168.50.237:12345}`; discovery or connectivity cannot expand it.

### Additional prevention constraints

- Device authorization is checked at the final command boundary: CLI target,
  manifest target/authorized target, and active lease must all equal the full
  237 address. Another connected device is never a fallback.
- A new credential epoch is permitted only after current native Account and
  Favorites evidence proves the session unusable. It uses the original visible
  WebView: account once, password once, post-credential CAPTCHA action/poll,
  one submit, and uninterrupted native-promotion observation. It never signs
  out to make return routing easier.
- Completion remains event-based, not patch-based: cross-day/multi-cycle
  survival, natural response-Cookie rotation persistence, and the next natural
  terminal-401/HDS/re-login/cold-Favorites path must all be observed on 237.
