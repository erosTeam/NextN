# NextN Gallery direct-route protocol

This is a reusable **device navigation protocol**, not a Goal, test contract,
or visual-acceptance claim. It reaches one numeric Gallery destination without
scrolling Browse or inferring a card coordinate.

## Supported Want parameters

- `nextn_gallery_id` — required positive integer Gallery ID.
- `nextn_gallery_destination=comments` — optional exact string; opens the
  existing native Comments destination for that Gallery ID. Omit it to open
  native Gallery Detail.

The EntryAbility accepts the parameters during either cold start or
`onNewWant`, transfers them once to `GalleryDirectLaunchState`, clears only
the current secondary navigation stack, and then uses the existing `pushGallery`
or `pushComments` route. The Gallery ID is not persisted.

## Device execution

Complete the repository device gate first: resolve the user-selected Connected
target, acquire its lease, wake it, apply the required timeout, and read back
the awake state. Then use the device-reported `aa start -h` parameter syntax:

```bash
hdc -t <selected-target> shell aa start \
  -b com.erosteam.nextn \
  -a EntryAbility \
  --pi nextn_gallery_id <positive-gallery-id>
```

For the existing native Comments route, append:

```bash
--ps nextn_gallery_destination comments
```

After one short navigation settle, capture only the needed final native state.
Do not insert Browse scrolling, card-coordinate discovery, preference writes,
or account actions into this route. Retain any screenshot or layout artifact
locally outside Git.

## Current device observation

On 2026-08-10, the user-designated Gallery ID used for detailed verification
was launched through the integer Want on the selected device. The final state
was a native Gallery `NavDestination` with no Web component and no loading
placeholder. This establishes the route only; it does not establish visual
parity for the destination.
