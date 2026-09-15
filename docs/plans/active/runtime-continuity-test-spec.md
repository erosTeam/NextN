# Runtime Continuity Test Specification (Package 5 Gap)

> STATUS: DRAFT — not integrated, not compiled, not run.
> Prepared in main checkout because worktree write was unavailable (429).
> Must be moved to codex/shared-reader-refactor worktree and completed before use.

## Purpose
Verify that reading progress and settings survive an install -r upgrade and
rollback cycle, and that the user can resume reading at the exact same page
after each transition. The existing A/B/C file-hash experiments only prove
that install does not touch durable files; they do not verify runtime
continuity of the reading experience.

## Key contract constraints
- Cold start resets to Legacy backend (ReaderProductionBackendTrial.test.ets:805)
- Runtime continuity must verify content identity, real reading progress,
  and persistent settings — not just file hashes
- Shared backend must be re-selected in-process after cold start for
  continuity testing; do not change the cold-start default

## Test phases (orchestrated via device protocol manifest)

### Phase 1: Setup and baseline
1. Install shared-reader HAP (candidate build)
2. Cold open app (Legacy default), select Shared in Settings
3. Open a real completed download gallery
4. Enter reader, navigate to page N
5. Wait for image decode, capture screenshot + layout dump
6. Save reading position to a known file for Phase 2 verification
7. Force-stop the app

### Phase 2: Upgrade continuity
1. Install upgrade HAP via install -r
2. Cold open app (Legacy default), select Shared in Settings
3. Navigate to same gallery
4. Reader should open at page N
5. Capture screenshot + layout dump

### Phase 3: Rollback continuity
1. Install original shared-reader HAP via install -r
2. Cold open app (Legacy default), select Shared in Settings
3. Navigate to same gallery
4. Reader should open at page N
5. Capture screenshot + layout dump

## Acceptance criteria
- Page identity (gallery ID, page index) identical across all three phases
- Reading mode preserved
- Backend selection: Legacy on cold start, Shared after in-process re-selection
- No crash, no data loss
- All screenshots captured and retrieved for visual review
