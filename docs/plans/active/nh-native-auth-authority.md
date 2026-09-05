# NextN NH native authentication authority

Status: implemented current candidate. Real API-key creation, cold restore, explicit rejection/replacement recovery, shared-WebView login retention, and same-device encrypted existing-primary restore have passed. Real two-account mutation plus blank-target and cross-device restore remain open.

## Implemented candidate — 2026-09-03

- Sealed envelope v4 carries a typed native credential. Existing v3 Web-token
  envelopes remain readable; new API-key envelopes authorize with `Key` and never
  call `/api/v2/auth/refresh`.
- Account now has a normal API-key child page. It opens the original official
  `user/settings#apikeys` page and captures the successful same-origin create response
  so the one-time raw key does not cross the clipboard; masked paste remains a fallback.
  The app does not call the first-party-only create endpoint itself. It validates through the sole
  native transport, binds the returned stable account id in the same HUKS/RDB
  transaction, performs durable readback, refreshes the profile and records the
  existing multi-account projection.
- API-key 401/403 performs one fixed account-endpoint confirmation. A confirmed
  rejection persists `terminal_api_key_rejected` and routes the root HDS action to
  the key page without clearing the Web Cookie jar; a valid unchanged key or a
  transport/server failure is retained and the rejected operation is not replayed.
- Response Cookie authority is explicit at the unified transport boundary. Anonymous
  and API-key-authorized responses cannot mutate the Web Cookie jar. Only an actual
  Web User-Token request, or a newly verified visible Web candidate whose account
  identity is already known, may checkpoint response `Set-Cookie` into native storage
  and then the ArkWeb compatibility jar.
- Portable account backup bundle v2 contains API-key envelopes only. Web access and
  refresh tokens, session cookies, Cloudflare state and browser UA are excluded;
  legacy portable session bundles are ignored. Restore transaction rollback uses a
  separately requested local-only snapshot so it can restore the pre-import state.
  An encrypted restore now fences the live account session before its first durable
  mutation and releases a new epoch only after either the imported state or rollback
  state has been completely reapplied, preventing in-flight responses from
  checkpointing into a different restored owner.
- `scripts/test_network_authority_contract.mjs`,
  `scripts/test_account_history_regression.mjs`,
  `scripts/test_settings_backup_contract.mjs`, resource JSON parsing and
  `git diff --check` pass. A signed ten-module build completed successfully. The
  resulting candidate was installed in place on authorized target 197 without a
  data clear and completed the API-key acceptance described below.

## Official refresh contract and owner binding — 2026-09-04

- The current official OpenAPI document (`https://nhentai.net/api/v2/openapi.json`,
  version `2.0.0+483414f`) states that `POST /api/v2/auth/refresh` revokes the
  supplied refresh token and returns a replacement `access_token`, replacement
  `refresh_token` and required `user`. It exposes no `expires_in` field. An
  initial access-token 401 is therefore the legacy path's expiry signal; the
  refresh JSON body, not a hoped-for response `Set-Cookie`, is the documented
  rotation contract.
- The refresh decoder now requires the complete token pair plus `user.id` and
  rejects a response whose user differs from the account that issued the
  request. The returned identity is verified before either the encrypted native
  generation or compatibility Cookie jar can receive replacements. The
  subsequent fixed `/user` check also validates the same account identity before
  accepting its response Cookie side effects.
- The account owner is carried in the authenticated-read token and resolved at
  the durable HUKS/RDB checkpoint. A response can fill a previously ownerless
  legacy envelope, but cannot relabel a known account or overwrite another saved
  account's credential.
- The ordinary `/user` profile path now applies the same owner check after any
  bounded refresh. A successful response for a different saved owner is not a
  recoverable transport error: it durably disables that mismatched credential,
  retains the account row and publishes the existing credential-specific HDS
  verification action. The foreground probe can no longer swallow this state.

## Existing-component reuse boundary

This lane must extend the following existing owners; it must not introduce a
parallel container, transport, Cookie manager or notification surface.

- ArkWeb host: `shared/components/EhWebView`. `GalleryWebPage` and
  `BrowserSessionPage` may each own a controller and route lifecycle, but the raw
  `Web` component remains exclusively inside
  `EhWebView`. `GalleryWebPage` is gallery-browser chrome, not a generic login or
  settings container.
- Account/settings structure: `SecondaryListScaffold ->
  NextNGroupedListSection -> NextNListRow`; modal work uses
  `NextNModalScaffold`; native custom dialogs keep their compiler-recognized
  direct `CustomDialogController` options and reuse
  `AppPrompt.modalSystemMaterial()`; menus, sheets and search reuse
  `AppMenuOptions`, `AppSheetOptions` and `AppSearchField` when those shapes
  apply.
- User-facing authentication failures: `AccountAuthNoticeState` at the root HDS
  `HdsSnackBar`. A page-local success toast is allowed; a fixed list-top error
  banner or page-local failure toast is not.
- NH network authority: `NhApiClient -> NhSessionHttpClient ->
  NhApiHttpTransport -> AxiosHttpClient`. `NhSessionHttpClient` exclusively owns
  credential selection, 401 handling, refresh and safe replay.
  `NhCookieAuthority` exclusively owns `WebCookieManager` interaction.
- Repository-wide inspection on 2026-09-03 found one raw `Web({ ... })` owner,
  `EhWebView`; all three page callers compose that wrapper. The component
  inventory found no existing API-key onboarding leaf to reuse, so the two new
  pages are route-specific leaves over the owners above, not replacements for
  them.

## 197 physical API-key acceptance — 2026-09-03

- The installed signed candidate SHA-256 was
  `e20327b486cf536cdfe94d9b270b7aab57bad217cf3647cb5e93cdb0f035da03`.
  The official settings page ran inside `EhWebView`; its `Key Name` label had a
  unique visible input target but that target had no parent form. Removing the
  erroneous form requirement made the existing semantic fill path stable with
  no coordinate or keyboard input.
- One challenge and one Create Key submit produced a successful same-origin
  capture, native validation, durable HUKS/RDB promotion and automatic return to
  native Account. No key or challenge value was logged or copied.
- A subsequent data-preserving force-stop/cold start restored
  `valid_v4_api_key`. Native Account remained authenticated, and Favorites
  loaded in the same cold process with one success and zero initial-401,
  refresh, Web replay, rejection or terminal-401 events. This proves direct
  persisted API-key authentication rather than legacy Cookie recovery.

## Current-candidate physical closure — 2026-09-04

- The current signed candidate has SHA-256
  `98cd290bae8c450a2b93e027c14005aaa33e1658b770c206f8b3f1885ff8ecf4`.
  A newly created API key was captured from the authenticated official settings
  page, verified through the sole native transport, durably promoted, and then
  restored after a data-preserving cold start. Native Account retained one
  selected owner and native Favorites completed an authenticated read without a
  legacy refresh chain.
- The promoted key was then deliberately revoked. The next native request
  recorded the credential-specific rejection and terminal 401 while retaining
  the Account row and cached feature state. The existing root HDS recovery
  action opened the native API-key destination and the shared official WebView;
  the website session remained authenticated.
- One replacement key was created from a fresh challenge epoch, captured,
  verified and promoted exactly once. A subsequent data-preserving cold start
  again restored native Account and authenticated Favorites. This accepts both
  the ordinary durable API-key path and the explicit rejected-key recovery path
  required to close the user-visible persistence P0 for this candidate.
- The encrypted existing-primary backup restore and its session-transition
  fence have also passed a real export/import/cold-start/Favorites run. Source
  and device tests cover portable API-key filtering and account-owner
  atomicity. A real second-account switch/remove cycle and real blank-target or
  cross-device import remain broader matrix items; they are not inferred from
  the single-account physical result.

## Problem established by current evidence

- Device 200 restored a complete, previously checkpointed access/refresh pair, then the fixed refresh endpoint
  returned 401 at 2026-09-03 12:44. The account row remained local, but that session family no longer provided
  native authority.
- The same NH account remained usable on device 197 (successful refresh at 11:35) and device 237 (successful
  refresh at 12:48). The account itself was therefore not globally rejected; the failure was specific to the
  credential family retained by 200.
- All three retained diagnostic windows classify access and refresh expiry as `unknown`. NextN can only discover
  access expiry after a business request returns 401, then attempt recovery with another rotating credential.
- None of the three retained windows contains a response-Cookie stored/applied/rejected event. This occurrence is
  not evidence of mishandling an observed response `Set-Cookie`.
- Older builds exported active and saved Web access/refresh session payloads into the encrypted cross-device
  backup. There is no retained device evidence proving that this path produced the observed failure, but copying a
  rotating session family is independently invalid because either copy can revoke the other's refresh token. The
  current portable bundle now exports only stripped API-key envelopes and rejects Web-token envelopes on restore.
- The server does not expose a retained reason that distinguishes expiry, revocation, session-limit eviction or
  another invalidation. Client code cannot make an already rejected refresh credential durable by retrying it.

The current hourly cold-start observation is no longer a causal test. It may prove that the bounded legacy refresh
chain works on a still-valid family, but cannot prove that a Web refresh credential will never later be rejected.

The claim is deliberately bounded: an API key may still be explicitly revoked by the user or server. The fix is to
remove silent expiry/rotation as the ordinary native-session lifecycle and to make any real key rejection a durable,
visible recovery state; it does not claim that a server-side credential can be immortal.

## Target contract

### One native request authority

`NhApiClient -> NhSessionHttpClient -> NhApiHttpTransport` remains the only NH API v2 request path.

- A saved account gains a credential kind: `API_KEY` or legacy `WEB_TOKEN`.
- `API_KEY` sends only a bounded, validated `Authorization: Key ...` header. It never enters the refresh endpoint.
- Legacy `WEB_TOKEN` keeps the existing `Authorization: User ...`, single-flight refresh and safe-read replay only
  as a migration/fallback path. A terminal refresh 401 remains a visible verification state, not a silent sign-out.
- A 401/403 from an API-key request does not immediately discard authority. One session-wide verification request
  to the fixed account endpoint distinguishes a rejected key from a request-specific permission response or an
  unavailable transport. Only a confirming 401/403 records `terminal_api_key_rejected`; transport/5xx/429 keeps
  the credential and reports the request failure without forcing re-onboarding.
- Terminal recovery carries its credential kind. `terminal_api_key_rejected` disables only native API-key
  authority and routes the root HDS action to the normal API-key editor; it does not clear or replace the website
  Cookie jar. API-key identity mismatch follows that same recovery route. Legacy Web-token rejection or identity
  mismatch keeps the existing original-WebView re-login action.
- Mutations are never replayed. A safe read may be replayed only when the credential generation changed during its
  request; validating the same key does not turn an endpoint-specific rejection into an automatic retry loop.
- Feature code cannot select a credential, own a Cookie jar, call refresh, or implement its own 401 retry.
- Redacted diagnostics may record only credential kind, response class and state transition. They never record a
  key, token, Cookie, account value, URL or derived fingerprint.

### Website session is separate

- The original first-party WebView remains the owner of website cookies, Cloudflare state, PoW/CAPTCHA and API-key generation.
- OpenAPI marks `POST /api/v2/user/keys` as User-Token-only, PoW- and CAPTCHA-protected and places it under a
  first-party/internal-only tag. NextN therefore never invokes it natively. The original settings page performs the
  mutation after the user's explicit action; a document-start bridge observes only its successful same-origin POST
  response and passes the one-time key directly to native validation without logging or clipboard use.
- API-key authentication must not overwrite, synthesize or take authority from the WebView Cookie jar.
- The native API-key page shows the one locally active key by its saved name and
  masked identity. The official settings page remains the source of truth for the
  complete server-side key list. Automatic creation uses a timestamped human-readable
  name so repeated device tests do not create indistinguishable entries.
- Comment posting must not be removed or moved out of the unified native stack. The official OpenAPI contract
  declares `POST /api/v2/galleries/{gallery_id}/comments` as User-Token-only even though comment reads accept an
  optional User Token or API Key. NextN therefore keeps API Key as the native authority for Account/Favorites, but
  preflights and, when possible, refreshes the same account's optional sealed website token before the existing
  PoW-backed comment mutation. The comment POST remains one-shot and is never replayed after recovery; failure of
  the optional website token must not reject or replace the native API key.

### Normal, visible onboarding

- API-key setup is reachable from the normal Account page; no hidden route or developer-only page.
- The Account page opens the first-party `user/settings#apikeys` destination. After the user completes the site's
  explicit create/CAPTCHA action, the app captures the successful response, validates the key with the same bounded
  transport, then atomically seals it for that returned account id. A secure native paste remains available if the
  website changes its fetch/XHR implementation and the supported page can no longer be observed.
- Promotion returns to native Account only after validation and durable readback. Existing multi-account ordering,
  switching and removal remain intact.
- Failures use the established HDS/Snackbar path; no fixed banner is inserted into a list.
- The retained-account/verification state exposes a bounded recovery kind so the root HDS action cannot send an
  API-key failure to Web login or a Web-session failure to the key editor.

### Persistence and backup

- A new backward-compatible sealed-envelope version stores the native credential kind separately from optional
  device-local Web session material.
- Existing version-3 Web-token envelopes continue to restore and refresh during migration; they are never
  mislabeled as API-key credentials.
- New API-key promotion writes the active envelope and matching saved-account envelope in the existing serialized
  RDB transaction, verifies encrypted readback, then updates profile/list projection. Startup reconciliation must
  recover a committed saved envelope if process death occurs before the Preferences list projection completes.
- Encrypted backup may carry account metadata and API keys, but must not export or restore `access_token`,
  `refresh_token`, `sessionid`, Cloudflare state or a browser user agent.
- The portable credential bundle gets a new version. Import of a legacy bundle may restore non-secret account
  metadata but must ignore its rotating Web-session payloads and publish a bounded re-onboarding result; compatibility
  must not reintroduce cross-device access/refresh restoration.
- Restoring a backup without website cookies yields working native API access for API-key accounts and an explicit
  website-login requirement only when a genuinely Web-only action is requested.
- The encrypted restore transaction owns a durable session-transition fence from the
  first preference/local/secret mutation through successful reapply or rollback.
  Authenticated requests cannot start in that window, and responses from the previous
  epoch cannot checkpoint into the restored primary account.

## Source lane

- `shared/src/main/ets/services/NhAccountSessionService.ets`: credential kind, versioned envelope, state and
  migration rules.
- `shared/src/main/ets/network/NhSessionHttpClient.ets`: API-key direct path versus bounded legacy refresh path.
- `shared/src/main/ets/network/NhApiHttpTransport.ets`: bounded `Key` authorization validation.
- `shared/src/main/ets/backup/BackupSecretsAdapter.ets`: sanitized API credential export/restore; rotating Web
  sessions excluded.
- `feature/settings/src/main/ets/pages/AccountPage.ets` and the existing root Web destination: normal API-key
  onboarding without replacing the account-list parent tree.
- Account/network/backup tests and persistence inventory only; unrelated Reader work remains untouched.

## Acceptance

1. Static contracts prove every NH API v2 call still crosses the sole transport; no feature-owned authorization,
   refresh or Cookie path appears.
2. Legacy version-3 sessions still restore, perform one bounded refresh, preserve multi-account state and surface a
   terminal 401 through the existing recovery notice.
3. A valid API key survives process death and cold start, loads native Account and Favorites without an
   `initial_401 -> refresh` chain, and a rejected key produces one visible actionable notice.
   A simulated transport/5xx/429 or endpoint-specific failure does not clear the key or publish that notice.
   Dismissing or acting on the notice leaves the existing website session untouched.
4. Account switching selects the matching sealed credential; removing/signing out one account cannot delete or
   overwrite another account.
5. Encrypted backup inspection proves no rotating Web credential or browser identity is exported; restored API-key
   accounts work natively while Web-only actions request website login when needed.
6. Existing native comment read/PoW/post behavior is retained. Source and tests prove that the User-Token-only
   mutation uses the matching account's optional website credential without changing ordinary native API-Key
   authority and without replaying POST. A real comment mutation remains the physical acceptance row, including
   the server's optional CAPTCHA branch.

No number of successful legacy refreshes satisfies item 3. The API-key cold-start
path and explicit rejected-credential recovery path have now both been observed
on the current candidate. The user-visible persistence P0 is accepted for that
candidate; the remaining real multi-account, blank-target/cross-device restore,
and comment-mutation rows stay open as separate coverage boundaries.

The proposed cause/direction is disproved if a validated, unchanged API key is later rejected while it remains
accepted by the first-party API on another client under the same request conditions. That result would return the
lane to transport/header comparison instead of being explained away as another refresh failure.
