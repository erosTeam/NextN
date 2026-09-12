# Shared Reader production partial-download fallback — NextN 197

Status: **LIMITED PASS / replacement OPEN**

This closes the partial-download source-selection branch for the optional shared
Reader. It does not make the shared Reader the default and does not introduce a
mixed local/network page catalog.

## Contract

The legacy Reader and `NextNProductionReaderDataSource` use the same priority:

1. a fully complete download whose promoted page files all revalidate;
2. the one-shot Detail route seed;
3. a fresh NH detail request.

A partial task must therefore remain visible and resumable in Downloads, but it
must not expose either a local catalog or an individual `file://` page to Reader.
This preserves one coherent page manifest instead of silently mixing two owners.

## Build

- First native build rejected one ArkTS-untyped parameters literal before
  packaging; the test was corrected to use the existing explicit Want branches.
- Final `entry@ohosTest` signed build passed in 9.636 s.
- Main HAP SHA-256:
  `43442739e762dd0bc063d6d89074f1345023fc66b0c16c81854eb461559a091c`
- ohosTest HAP SHA-256:
  `124072d0603d286b7bd5d1f71185684165ea2aa3265da972fc95810d09a76a19`

## Device 197 result

Target `192.168.50.197:12345`, ALN-AL80, portrait 1260×2720:

- `ReaderProductionPartialDownloadFallbackTrial`: **1/1 pass**, 28.422 s.
- The test first proved gallery `678049` was absent from the queue and no queue
  worker was active.
- It temporarily used one gallery worker, one page worker, zero retries, no
  completion notification, a ten-second batch interval and a 256 KB/s cap.
- It paused the task at an actual `1/14`; the first promoted file existed in the
  task-owned public Download directory.
- Despite that physical file, `localReaderDetail(...)` returned `null` and
  `localPageUri(...)` returned an empty string.
- Both the direct source assertion and the real Detail → shared Reader entry
  logged `detail_source=route_seed`.
- The shared body rendered `1 / 14`, with no legacy surface, failure card or
  loading layer, and Close returned to the retained Detail page.
- The test removed only its task/directory and byte-compared the resulting queue
  snapshot with the original. Download settings and all eight history columns
  were restored, and the process-local backend was reset to legacy.

The idempotent cleanup gate then passed **1/1 in 2 ms** with no snapshot to
restore, followed by force-stop, Home and the ordinary 10000 ms timeout.

## Visual and semantic inspection

All three full-screen PNGs were inspected, not merely captured:

- `detail-with-partial-task.png` shows the expected Detail page and the visible
  “已暂停” state before Reader entry.
- `shared-route-seed.png` shows the optional shared full-chrome body at `1 / 14`.
  The extreme strip is whole-page `Contain`, matching the accepted legacy paged
  behavior; continuous mode remains the fit-width scrolling mode.
- `detail-returned.png` shows the same retained Detail composition after Close.

The matching semantic trees contain only `nextn-root-navigation` and the Detail
Read action before/after. During Reader they additionally contain
`reader-overlay-navigation`, `rkit-reading-surface`, `rkit-chrome-page` and
`rkit-close`; they contain neither `legacy-reader-surface` nor a failure node.

Evidence:

- `.hermes-artifacts/20260913-shared-production-partial-download-fallback-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/01-direct-host`
- `.hermes-artifacts/20260913-shared-production-partial-download-fallback-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-cleanup`

## Remaining replacement gates

This result complements the already accepted complete-download and network
branches. Default replacement remains open for broader Reader settings/actions,
rotation/fold replay and Koma chapter handoff; those cannot be inferred from this
single host-data-source result.
