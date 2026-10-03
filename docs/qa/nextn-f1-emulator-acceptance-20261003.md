# NextN F1 — current emulator evidence, 2026-10-03

The shared-reader replacement remains **OPEN**. This record accepts only the
recorded single-page entry/resume/return chain; Legacy remains the production
default. Device 197 was not retried. An explicit process-local shared-backend
Want selected the normal production Detail and reader routes.

## Current source, artifact and target

- NextN base `f34b0732`, with the scoped `NextNReaderLabPage` image-handoff change;
  reader-kit `a48e119737c4aed410bf7f7a9dc39ad8d22d0718` is unchanged.
- Changed source SHA-256:
  `066be48de36586c821e5c93e9e6e5dca0305db5eb87ddd805a915ba06a84c02c`.
- Signed HAP SHA-256:
  `c922f3312163a70d6ea5102275710927aba426fe9160c3ae78f60b15a909b310`.
  `scripts/build-hvigor-signed.sh debug` succeeded; checked `install -r` installed
  that HAP without a data/cache reset.
- Emulator `127.0.0.1:5555`, PHEMU-FD00, portrait root viewport 1320x2232, 60Hz
  configured display. Fresh gate proves NextN foreground/root47 before the route.
- Standard non-H gallery663205, 40 pages. Fresh semantic source
  `reader-thumb-gallery-detail-1-page-0` has bounds `[72,734][368,1184]`;
  `gallery-detail-read-action` has bounds `[1013,2046][1272,2184]`.

## Recording method and source-proven repair

The emulator's system AVRecorder failure is not a general recording gap.
macOS `/usr/sbin/screencapture -v -V <seconds> -l <current-window-id> -x <mov>`
records the visible Emulator window. A dynamic probe captured actual swipes.
The current window4419 capture includes the emulator frame/toolbar, uses no
audio, and does not capture the whole desktop. Source resolution is1260x1750.
Variable host capture cadence is **not** evidence of 60/120fps rendering or
physical-device performance.

Baseline HAP `ff9b1562…634643e` on the same kit produced a first-entry dim flash
at movie frames124–133, PTS2.586667–2.773333. Source inspection found two owners
suppressing the same reveal: the shared entry selected-image fade and the host
outer content opacity. The Reader placeholder also first mounted at root-proxy
removal. Root and departure-preview PixelMaps are independent; release aliasing
was ruled out.

The narrow host change mounts the existing placeholder during root OPENING,
beneath the unchanged root flight. After arrival, shared selected-image opacity
owns the reveal and host content opacity remains1. Reverse/close and non-root
paths retain their existing gates. No timing, geometry, route, menu, thumbnail
rail, cache, preload, background or shared-library change was made.

## Observed chain and limits

The checked manifest executes continuously, with no screenshot/model inspection
between actions: first thumbnail → three fast swipes to page4 → Back → ordinary
Read/resume4 → reveal chrome → Back → explicit thumbnail1 → reveal chrome → Back.
All1536 decoded frames and their PTS were retained; all32 contact sheets were
reviewed, with page counters enlarged at frames856 and1245.

- First and warm thumbnail flights remain root-owned. The first-entry dim flash
  does not recur at the image ownership boundary in this capture.
- Chrome is hidden at thumbnail entry. Ordinary Read restores `4 / 40`;
  explicit thumbnail1 selects `1 / 40` despite the saved page4.
- Three cached-page swipes retain displayed content. Final Back shrinks the
  selected image into the current visible thumbnail. Page4/ordinary exit uses
  the existing system fallback when its selected source is not fully visible.
- The ordinary no-thumbnail system entrance briefly contains a dark incoming
  content area before its native image appears (frames648–650). This is not
  accepted as a no-black-frame path, and this patch does not address it.
- Before/after Detail rail positions differ (baseline thumb y793, current y734).
  Thus the movies are not a pixel-matched flight-trajectory/latency comparison.
  The source-proven handoff defect and its full-image endpoint are the bounded
  comparison, not a claim that the whole transition matches Legacy.
- Uncached loading, spread companion fade, Back during flight, processed-image
  replacement, other hosts, and performance superiority remain unproven. The
  next action is the ordinary uncached-thumbnail path without deleting cache.

## Retained local evidence

All paths below are under `.hvigor/outputs/emulator-reader-20261003/`:

- `nextn-handoff-build.log`, `handoff-candidate-binding.json`.
- `detail-handoff.json` and
  `emulator__PHEMU-FD00/not-applicable/portrait-1320x2232/detail-handoff/`.
- `f1-resume-handoff-r2.json` and its matching protocol output directory.
- `host-recording/f1-handoff-r2-capture-ledger.json` binds current window,
  protocol and recorder timestamps; both exit0.
- Original `host-recording/f1-resume-handoff-r2.mov`; route excerpt
  `host-recording/f1-handoff-route.mov`, SHA-256
  `c4b88db2f118c9fb155c1c281739c04311df557ca6c751f483ec72dccbb2ec8c`.
- `host-recording/f1-handoff-route-frames/`: all1536 frames, original PTS and
  all32 contact sheets. Baseline `host-recording/f1-route.mov`, SHA-256
  `f7470f404d666558e11d2afacd3a32c8deba84024a2b98f763c195d4201f8c89`.

Earlier `1afe5e7` captures and screenshot-derived “no regression” claims are
superseded. The failed manifest-preparation recording
`f1-resume-handoff.mov` dispatched no UI inputs and is excluded. Historical
build/suite results across three consumers do not establish their runtime
replacement acceptance.
