# Shared reader Koma remote-image actions checkpoint — 2026-09-12

## Outcome

LIMITED accepted; overall replacement remains OPEN.

The optional Koma reader now resolves a non-placeholder remote current page through the same production-backed image cache used by rendering, then supplies the cached local file to the existing host save and share actions. It does not introduce another downloader, credential path, or media writer.

## Source and build evidence

- `KomaReaderLabAdapter.imageShareSource` is asynchronous and accepts the action cancellation token. Local pages remain direct; remote pages call the established `fetchAndCacheReaderRemoteSource` path and only publish a file-backed share source after the cache file is available.
- `KomaReaderLabImageShareHost` awaits the adapter result before invoking the existing system save/share hosts.
- Placeholder pages remain explicit failures. Closing or cancelling the consumer prevents a late remote result from being published even if the production cache finishes its write.
- Koma signed debug build succeeded in 2.430 s. Device candidate: 14,581,473 bytes, SHA-256 `c0dff4d1c79b50bb84bbfffd3654df71b15a47fa560a407798a820fbfee71cb2`.

## Device 197 evidence

Target: `192.168.50.197:12345`, portrait 1260x2720. The candidate was installed with retained data and reopened the already validated public MangaDex four-page remote chapter at page 4/4.

- Save opened the HarmonyOS confirmation dialog `允许“Koma”保存 1 张图片？` with the actual page-4 artwork preview. The run selected `禁止`, so no media asset was created. Dismissal returned to the same remote page 4/4 with both shared save and share actions enabled.
- Share opened the HarmonyOS share sheet with the same actual page-4 artwork, `分享 1 项`, and a 1.58 MB payload. No recipient or destination was selected. Dismissal returned to the same remote page 4/4 with both actions enabled.
- The final UI was the ordinary Koma shelf and contained no shared-reader surface.
- Library bytes remained identical, SHA-256 `a997dba1315adba11d236307a66084c0dde19236a6f4a93062f7cd19725f015c`.
- Reader-session bytes remained identical, SHA-256 `32b2533f0346f3f996b9aba8b0d622a706b4286a8403cf8bebc30c2da89884cd`.
- Reader-preference bytes remained identical, SHA-256 `571bd000fb5fdd79021486fbc8694b8759b248c50bc07b24589fa0b01af195a4`.
- Screen-off override was restored to 10000 ms and the device lease was released.

Private library/session contents were used only for exact target selection and byte-for-byte restoration. They are not reproduced here.

## Visual evidence

- Remote page before actions: `.hermes-artifacts/20260912-koma-shared-remote-197/device197__phone/not-applicable/portrait-1260x2720/06-actions-open/screen.jpeg`
- Save confirmation with actual remote image: `.hermes-artifacts/20260912-koma-shared-remote-197/device197__phone/not-applicable/portrait-1260x2720/07-save-open/screen.jpeg`
- Same page after save cancellation: `.hermes-artifacts/20260912-koma-shared-remote-197/device197__phone/not-applicable/portrait-1260x2720/08-save-cancel/screen.jpeg`
- Share sheet with actual remote image: `.hermes-artifacts/20260912-koma-shared-remote-197/device197__phone/not-applicable/portrait-1260x2720/09-share-open/screen.jpeg`
- Same page after share dismissal: `.hermes-artifacts/20260912-koma-shared-remote-197/device197__phone/not-applicable/portrait-1260x2720/10-share-dismiss/screen.jpeg`
- Final ordinary shelf: `.hermes-artifacts/20260912-koma-shared-remote-197/device197__phone/not-applicable/portrait-1260x2720/11-actions-final-exit/screen.jpeg`

## Remaining replacement gates

- Completed save-to-gallery and an explicitly authorized recipient/destination delivery; this checkpoint deliberately stopped at system UI.
- Remote action cache miss, transport failure, retry, close/cancel during fetch, and cache eviction.
- Spread/multi-page save and share semantics.
- Authenticated Komga/Kavita/WebDAV/OPDS pages and expired-header renewal.
- Default-reader replacement and persisted setting/progress migration remain prohibited and OPEN.
