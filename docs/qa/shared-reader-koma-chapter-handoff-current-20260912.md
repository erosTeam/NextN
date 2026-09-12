# Shared reader Koma current chapter-handoff checkpoint — 2026-09-12

## Outcome

LIMITED accepted on phone 197 and tablet 103; overall replacement remains OPEN.

The optional Koma reader keeps chapter ordering and adjacent-unit resolution in the host adapter. The shared surface only emits a direction plus the currently displayed unit identity. Koma prepares the target while the source unit remains active, rejects stale/closed/background requests, and only then asks the shared session to open target page 1. Runtime display policy is not reloaded or persisted during the handoff.

## Source and build evidence

- `KomaReaderLabAdapter.adjacent` uses the current chapter's canonical `continuationChapterIds` fallback to `chapterIds`; it does not infer order from chapter IDs.
- `KomaReaderLabPage.switchChapter` checks ready/source identity, route/foreground state and a single cancellation owner before and after target preparation. Close, background and a superseding lifecycle cancel the host request.
- Target metadata is prepared before `ReaderPagedSession.open`, so an unavailable adjacent chapter does not immediately discard the displayed source chapter.
- The actual-method Koma runtime script passes policy, initial lifecycle, host chapter happy path and no-policy-reset assertions. The host tap-zone comparison also passes 1,404 cases.
- Device candidate is the same signed Koma build used for current remote actions: 14,581,473 bytes, SHA-256 `c0dff4d1c79b50bb84bbfffd3654df71b15a47fa560a407798a820fbfee71cb2`.

## Device 197 — existing MangaDex sample

Portrait 1260x2720, retained-data install.

- Source chapter opened as actual page 1/11. The More menu exposed disabled `上一章` and enabled `下一章` from the current session snapshot.
- Selecting `下一章` opened a distinct actual image at page 1/19. Selecting `上一章` from that target returned to the original distinct image at page 1/11.
- Library/session/preferences remained byte-identical with SHA-256 `a997dba1315adba11d236307a66084c0dde19236a6f4a93062f7cd19725f015c`, `32b2533f0346f3f996b9aba8b0d622a706b4286a8403cf8bebc30c2da89884cd`, and `571bd000fb5fdd79021486fbc8694b8759b248c50bc07b24589fa0b01af195a4`.
- Final UI was the ordinary shelf, portrait and 10000 ms screen-off override were restored, and the lease was released.

## Device 103 — independent two-chapter local-folder sample

Portrait 1600x2560 and landscape 2560x1600, retained-data install.

- Chapter 1 opened as the red diagnostic image at page 1/2. The tablet More menu exposed disabled `上一章` and enabled `下一章`.
- Selecting `下一章` opened the blue diagnostic image at page 1/3.
- Rotating that target to landscape preserved page 1/3 and produced responsive image bounds `[726,105][1834,1600]` within the 2560x1600 reader surface.
- Selecting `上一章` in landscape returned to the red diagnostic image at page 1/2 with the same responsive bounds. The device then returned to portrait before exit.
- Library/session/preferences remained byte-identical with SHA-256 `88dbc18480cb6c9b5553df0f57f69bdcb650799d7c0e8b9e1d8cec58dc900130`, `f0fdbd8fb6f7e315c450b57562380208553eee3c338d87a14adc63f42e1c9cce`, and `fd66722b3a91982b09b0827058c445f66b94cce0a881a31953c2270ea3b79015`.
- Final UI was the ordinary shelf, portrait and 10000 ms screen-off override were restored, and the lease was released.

## Visual evidence

- Phone source chapter 1/11: `.hermes-artifacts/20260912-koma-shared-chapter-current-197/device197__phone/not-applicable/portrait-1260x2720/01-open-ch46/screen.jpeg`
- Phone adjacent chapter 1/19: `.hermes-artifacts/20260912-koma-shared-chapter-current-197/device197__phone/not-applicable/portrait-1260x2720/03-next-ch45/screen.jpeg`
- Phone roundtrip 1/11: `.hermes-artifacts/20260912-koma-shared-chapter-current-197/device197__phone/not-applicable/portrait-1260x2720/04-return-ch46/screen.jpeg`
- Tablet source chapter 1/2: `.hermes-artifacts/20260912-koma-shared-chapter-current-103/device103__tablet/not-applicable/portrait-1600x2560/01-open-ch1/screen.jpeg`
- Tablet adjacent chapter 1/3: `.hermes-artifacts/20260912-koma-shared-chapter-current-103/device103__tablet/not-applicable/portrait-1600x2560/03-next-ch2/screen.jpeg`
- Tablet adjacent chapter in landscape: `.hermes-artifacts/20260912-koma-shared-chapter-current-103/device103__tablet/not-applicable/landscape-2560x1600/04-landscape-ch2/screen.jpeg`
- Tablet landscape roundtrip: `.hermes-artifacts/20260912-koma-shared-chapter-current-103/device103__tablet/not-applicable/landscape-2560x1600/05-return-ch1/screen.jpeg`

## Remaining replacement gates

- Adjacent-chapter prepare failure, slow transport, close/background during prepare and rapid repeated requests on physical devices.
- Chapter handoff while continuous, spread, RTL and nonzero runtime source position are active; the current checkpoint proves the saved single-page policy only.
- Automatic advance deliberately remains chapter-local; any future cross-chapter automatic behavior needs a separate host policy.
- Cold reopen/progress writeback semantics and authenticated remote-source chapter refresh.
- Default-reader replacement and persisted setting/progress migration remain prohibited and OPEN.
