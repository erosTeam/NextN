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

## Supported external Deep Link

- `nextn://gallery/<positive-integer>` — public Gallery Detail route only.

`module.json5` declares this in a separate `ohos.want.action.viewData` skill;
the `EntryAbility` accepts the URI only when its scheme, host, and entire path
match exactly. It then uses the same one-shot `GalleryDirectLaunchState` as
the internal parameter route. URI query strings, alternate hosts, zero,
negative values, non-integers, and the Comments destination are intentionally
not part of the public link.

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

For a public Gallery Detail deep link, do **not** add an explicit bundle or
ability: that would test the parser but not the system URI skill match. Use
the selected device's `aa start` URI syntax:

```bash
hdc -t <selected-target> shell aa start \
  -A ohos.want.action.viewData \
  -U nextn://gallery/<positive-gallery-id>
```

For cold-start validation, force-stop only `com.erosteam.nextn` first; for
hot-start validation, issue the same URI once while the native Detail is
foreground. Both branches must reach native Gallery Detail without scrolling
or interacting with Browse.

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

On 2026-08-12, the existing public URI path was re-observed once on the same
selected TCP device after the required awake/timeout gate. The system
`viewData` launch for `nextn://gallery/471768` settled on native
`com.erosteam.nextn:EntryAbility`, `pages/Index`, with one Gallery
`NavDestination` at the `1320×2120` portrait root viewport and loaded Detail
content. No Browse navigation, account, credential, preference, download,
comment, or content mutation was performed. Local final-state evidence is
retained in `.hvigor/outputs/gallery-direct-link-20260812T1045/` and is not
committed. This confirms only the existing public Deep Link path; it does not
reopen Gallery Detail visual review.
