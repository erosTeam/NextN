# Account session owner — P0 execution plan

## Goal

After a successful login, ordinary page navigation, page refresh, a cold
start, a public request failure, or one account request failure must not turn
the app into signed-out state or require another login. Only the user choosing
**Sign out** may delete the durable session.

## Reference rule

The Flutter client has one durable cookie owner. Startup loads that owner;
pages read a published `isLogin` value; retrying a request does not clear the
cookie jar. Cookie deletion is in the explicit logout action.

NextN must follow the same ownership rule. The encrypted session envelope and
ArkWeb cookie jar are implementation details of that one owner, not a service
that every page may independently re-run.

## Single state model

`AccountSessionState` becomes the only page-facing truth with three
non-secret fields:

| Field | Meaning |
| --- | --- |
| `initialized` | Entry startup has completed the one durable restore attempt. |
| `signedIn` | The current process owns a validated session. |
| `verificationRequired` | A retained record needs an explicit user verification action; it is not deleted. |

The encrypted envelope, HUKS key, cookie values, browser UA, and profile data
never enter this state.

## Allowed transitions

| Event | Owner | Durable action | Published state |
| --- | --- | --- | --- |
| Process startup | `EntryAbility` | One read/decrypt/hydrate attempt | initialized + signed-in/signed-out/verification-required |
| Verified visible login | session service | Atomically write envelope and remove verification marker | signed-in |
| Explicit logout | session service | Atomically delete envelope and marker, then clear browser identity | signed-out |
| Terminal account-read 401 | session service | Persist verification marker; retain envelope and browser identity | verification-required |
| RDB/HUKS/decrypt failure on cold start | session service | Do not delete | verification-required |
| RDB rebuilt/repaired with missing envelope | session service | Do not treat as first install | verification-required |

No other code path may clear cookies, profile state, the envelope, or the
published signed-in state.

## Required source changes

1. Publish the boot result from `NhAccountSessionService.restoreAtBootstrap()` into
   `AccountSessionState` exactly once at entry startup.
2. Remove `NhAccountSessionService.restore()` from `FavoritesPage`,
   `SettingsPage`, and `BrowserSessionPage`. Those pages consume only
   `AccountSessionState`; Favorites starts its read only when
   `initialized && signedIn`.
3. Keep the active-runtime fast path, but make it a consequence of the state
   owner rather than the normal mechanism that pages rely on.
4. Keep the existing narrow account-read retry/verification transitions; do
   not let public reads, mutations, page appearance, or a stale response
   delete or downgrade the owner.
5. Do not create, modify, run, or rely on UI static contracts for this work.
   The implementation is reviewed from the source ownership graph and then
   validated by the signed build and the real cold-start path.

## Acceptance gates

Source and build gates:

1. Source review proves one startup `restoreAtBootstrap()` call exists in `EntryAbility`; no
   feature page calls it.
2. Source review proves each page renders from published state only; it cannot
   trigger a durable session read/clear as a side effect of appearing.
3. The signed Debug build passes.

Real-device gates (no credential action until the code gates pass):

1. A known signed-in record survives ordinary tab/account/favorites navigation
   without a second restore or login surface.
2. Force-stop/cold-start keeps native Account signed-in and Favorites
   authenticated.
3. A bounded account-read failure produces verification-required while
   preserving the durable record; it never silently opens/replaces login.

Current device status is explicitly **not** a pass: its old session record is
already absent, so it cannot prove record-present persistence until a future
authorized login epoch creates one.
