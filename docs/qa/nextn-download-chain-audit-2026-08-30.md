# NextN download-chain audit — 2026-08-30

## Scope

This audit follows the current NextN gallery-download contract through detail enqueue, public-Download ownership, bounded workers, page persistence, pause/resume, cold restore, manual directory restore, Reader, CBZ export, notification, and removal. NextE is the behavior reference where the NH product leaf does not differ.

## Ownership map

- `GalleryDetailPage` issues enqueue/resume and routes existing tasks to Downloads.
- `DownloadQueueService` owns task lifecycle, public directory resolution, workers, page files, restore reconciliation, Reader paths, and removal.
- `DownloadQueueRepository` owns serialized RDB task rows; per-task `metadata.json` is the public-directory recovery sidecar.
- `DownloadQueueState` publishes identity-preserving task projections to the retained Downloads page.
- `ReaderPage` accepts a local task only through `localReaderDetail()` and `localPageUri()`.
- `NhDownloadCbzExportService` reads only a fully verified page set and writes a private cache-backed `.part` before archive promotion and ShareKit handoff.

## Confirmed findings and disposition

### 1. Public final files were not crash-safe completion evidence

Public Download pages are streamed directly to their final filename because that provider does not support the sandbox rename contract. Before this correction, cold restore counted any nonempty final file as complete. A process death after only part of an image arrived therefore left a nonempty file that could be promoted into task progress, Reader, and export.

Disposition: implemented in source. Schema 23 adds a nullable per-page completion journal. A page enters that journal only after the stream closes and its exact written size verifies; cold restore and every downstream consumer require both journal membership and a nonempty file. Existing schema-1 public tasks receive one migration scan, after which their explicit journal is persisted. Missing journaled files are pruned before resume, so a replacement stream cannot inherit stale completion authority.

### 2. Public sidecar extensions were weaker than queue/RDB validation

`metadata.json` is stored in a user-visible directory. The parser accepted any nonempty extension while enqueue and the RDB repository require a bounded alphanumeric extension. A crafted extension could therefore alter the path assembled for Reader, resume, or export.

Disposition: implemented in source. Sidecar extensions now pass the same normalized-extension guard, and the containing task directory name must equal the parsed gallery ID before import.

### 3. Active removal crossed worker and persistence ownership

Removal invalidated a token but immediately deleted files, then attempted the RDB deletion. If the worker still held a public file or the RDB deletion failed, the service could reinsert a task after some or all of its files had already gone; a previously complete snapshot could remain visibly complete while Reader/export had no page set.

Disposition: implemented in source. The service retains and awaits the exact gallery worker after cancellation, uses cancellation-aware pacing, commits the RDB deletion before deleting the owned directories, and removes the in-memory row last. A file-removal failure restores a freshly reconciled paused/complete row for an explicit retry.

### 4. The hidden-download-images policy was missing end to end

NextN omitted the reference Download setting, its durable preference, and the
storage marker lifecycle. This was not only a missing row: downloaded images
could be indexed by the system media library because the public download root
never owned a `.nomedia` marker.

Disposition: implemented in source. `hideFromMediaLibrary` defaults to enabled,
persists through the existing settings repository, and is exposed directly
after completion notifications with the reference title, hint, symbol, and
switch behavior. `DownloadQueueService` owns one marker at the shared public
`nextn-downloads` root and reconciles it when storage becomes ready, when the
setting changes, and during cold restore. Disabling removes only that exact
marker.

### 5. Public directory names and task-deletion copy lost the reference contract

The public-storage port reduced every task directory to a bare GID and required
that exact bare name during sidecar recovery. The Downloads task menu also used
the generic action `Remove`, while its confirmation explained an unrelated
remote-gallery non-effect instead of stating the local destructive consequence.

Disposition: implemented in source. New public tasks and legacy-sandbox resumes
use a filesystem-safe, UTF-8-bounded `GID-title` segment matching the current
NextE contract. Root adoption and sidecar recovery accept this current name;
existing GID-only directories remain valid read/removal compatibility owners so
the correction does not bulk-rename user data. The action tree now says Delete
download, Delete download?, that the task leaves Downloads and its local files
are deleted, and Delete, across all four locales.

## Reviewed branches without a confirmed defect

- Enqueue validates the complete NH page manifest before creating either state or RDB ownership.
- Page retries remain bounded; a partial-success batch persists successful page journals and terminates as retryable error.
- Pause invalidates future stream callbacks and retains verified page files for resume.
- Cold restore keeps interrupted work non-active and auto-retries only `ERROR` tasks when the saved policy enables it; manual `PAUSED` remains manual.
- Reader and CBZ export both require a complete verified local set and perform no network fallback inside that local branch.
- Export cache ownership is gallery-scoped, active exports are not reclaimed, and abandoned `.part` files are pruned on cold restore.
- Completion notifications occur only after the durable final task write and are default-off; notification failure does not alter queue state.
- Download settings backup/sync continues to use the repository's generic key table, so the new hidden-images key follows the existing settings transport rather than introducing a second persistence path.
- Removal is bounded to the task-owned public directory, its exact legacy compatibility directory, and its gallery-scoped private export cache.
- Current and legacy public directory names are matched only against the task's
  own gallery ID and title-derived safe segment; recovery does not adopt an
  arbitrary sibling directory.

## Verification evidence and boundary

- `node scripts/test_download_queue_progress_contract.mjs`, `node
  scripts/test_download_queue_integrity_contract.mjs`, resource JSON parsing,
  and `git diff --check` pass. The signed build completed in `9 s 402 ms`; the
  installed HAP SHA-256 is
  `676a2126f04ccb764f39c1870d5681c0dcbf3f945c12f5d2549c558ffbd88f79`.
- The HAP was installed in place on `192.168.50.237:12345` without uninstall or
  data clear. Download settings rendered `隐藏下载图片` and its `.nomedia` hint.
  Toggling it off and on produced service diagnostics respectively reporting
  `enabled=false,present=false` and `enabled=true,present=true`; a force-stop
  and cold start retained the enabled switch and reconciled the marker again.
- Schema-23 migration retained the existing 200-page completed gallery as
  `200 / 200 已完成`; opening it through the local Reader rendered `1 / 200`.
- Removing a freshly active task left `暂无画廊下载`, and a subsequent cold start
  kept it absent. A separate forced process stop captured the task at
  `6 / 200 下载中`; cold restore produced `36 / 200 已暂停`, not complete. The
  count grew before process death because verified streams completed between
  the semantic capture and force-stop. Resume followed by pause advanced the
  journal to `39 / 200 已暂停`. Final cleanup again left an empty queue.
- Device evidence is retained under
  `.hvigor/outputs/nextn-download-chain-integrity-237-20260830/` and excluded
  from Git. The device finishes with an empty download queue and hidden-images
  enabled.
- The follow-up naming/copy correction was installed in place only on the
  user-selected `192.168.50.197:12345`; target 237 was not used for this
  follow-up. Fresh Gallery `676543` completed at `107 / 107`, survived a cold
  start, and the system Files semantic path exposed the exact directory
  `nextn-downloads/676543-(潤子_采華）グッバイ マイ ビューティフル ワールド（K)`.
  The task menu and confirmation rendered `删除下载`, `删除下载？`,
  `将从下载列表移除，并删除本地文件。`, and `删除`; confirming removed only the
  acceptance task and retained the six existing completed tasks. Follow-up
  evidence is under
  `.hvigor/outputs/nextn-download-path-delete-copy-197-20260830/`.

This accepts the corrected persistence, Reader, active-removal,
interruption/restore, resume/pause, and marker lifecycle on 237, plus current
directory naming, cold persistence, explicit deletion copy, and scoped deletion
on 197. CBZ ShareKit handoff, notification delivery, and manual directory
restore were source- and build-reviewed but were not physically exercised in
this run.
