# Shared reader Koma remote-page checkpoint — 2026-09-12

## Outcome

LIMITED accepted; overall replacement remains OPEN.

The optional Koma adapter no longer rejects every non-local page. It reuses Koma's production `ReaderPageSourceAdapter` for source-runtime descriptors, request headers and the bounded remote-image cache, then gives the resulting local cache file to the same shared original, thumbnail, metadata and border-crop path used for downloaded chapters.

No new network client, credential store, source protocol or cache format was introduced. The adapter remains `consumer-only`: a late fetch may finish in the production cache, while a closed/cancelled optional reader refuses to publish the late asset.

## Source and build evidence

- The adapter configures the established `${filesDir}/reader-image-cache` and calls `fetchAndCacheReaderRemoteSource` for both local and remote render sources.
- `URI_PLACEHOLDER` remains an explicit failure. Remote pages advertise thumbnails; successful remote fetches are converted to local files before thumbnail derivation, metadata inspection and `ReaderFileCropSource` sampling.
- The old `koma_lab_requires_local_page` body gate is absent. Current-page share remains intentionally local-only and is not claimed by this checkpoint.
- Static remote-handoff contract passed.
- Koma signed debug build succeeded in 2.314 s. Device candidate: 14,581,746 bytes, SHA-256 `2ecfd2924276c478e54f50956579493654769740d0c8c9e610c1879842e06f46`.

## Device 197 evidence

Target: `192.168.50.197:12345`, portrait 1260x2720. The candidate was installed with retained data. The test selected an existing public four-page MangaDex source-runtime chapter; no new library item was created.

- Optional reader opened actual remote page 1/4 as `rkit-entry-image-0-1-1` in `[0,471][1260,2249]`; the whole screenshot shows decoded artwork rather than a placeholder, retry card or stretched preview.
- Opening the shared rail produced four displayed thumbnail image leaves, numbered 1–4. The whole screenshot shows four distinct decoded remote images with coherent cover-bounded proportions.
- Reader logs record new `source_cache_written` events for the selected chapter's `page:0` (477,421 bytes), `page:1` (1,903,393 bytes), `page:2` (1,163,470 bytes), and `page:3` (1,575,650 bytes). Cache usage increased from 36,903 KiB to 39,591 KiB during the path.
- Selecting thumbnail 4 changed the main leaf to `rkit-part-3-whole` / `rkit-entry-image-0-3-1` in `[0,689][1260,2032]`, the slider to 4, and chrome to 4/4. The fourth thumbnail became the selected item.
- Final library bytes were identical, SHA-256 `a997dba1315adba11d236307a66084c0dde19236a6f4a93062f7cd19725f015c`.
- Final reader-session bytes were identical, SHA-256 `32b2533f0346f3f996b9aba8b0d622a706b4286a8403cf8bebc30c2da89884cd`.
- Final reader-preference bytes were identical, SHA-256 `571bd000fb5fdd79021486fbc8694b8759b248c50bc07b24589fa0b01af195a4`.
- Final UI was the ordinary Koma shelf. Screen-off override was restored to 10000 ms and the lease was released.

Private library/session file contents were used only for exact target selection and byte-for-byte restoration. They are not reproduced here.

## Visual evidence

- Remote page 1/4: `.hermes-artifacts/20260912-koma-shared-remote-197/device197__phone/not-applicable/portrait-1260x2720/02-open/screen.jpeg`
- Four remote thumbnails: `.hermes-artifacts/20260912-koma-shared-remote-197/device197__phone/not-applicable/portrait-1260x2720/03-rail/screen.jpeg`
- Thumbnail-selected remote page 4/4: `.hermes-artifacts/20260912-koma-shared-remote-197/device197__phone/not-applicable/portrait-1260x2720/04-select-p4/screen.jpeg`
- Final ordinary shelf: `.hermes-artifacts/20260912-koma-shared-remote-197/device197__phone/not-applicable/portrait-1260x2720/05-final-exit/screen.jpeg`

## Remaining replacement gates

- Authenticated Komga/Kavita/WebDAV/OPDS remote-page acceptance and expired-header renewal.
- Explicit remote fetch failure, retry, offline-cache hit, close/cancel during transport, and cache-eviction paths.
- Remote current-page share/save, which still deliberately requires a local page in the optional Koma adapter.
- A truly bordered remote page with crop OFF/ON/OFF; local/downloaded border-crop behavior is independently accepted.
- Chapter switching, cold reopen and layout combinations on remote pages.
- Default-reader replacement and persisted setting/progress migration remain prohibited and OPEN.
