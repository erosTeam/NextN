# NextN

NextN is a native HarmonyOS NEXT client for NH.

The project takes its modular ArkTS architecture and UI semantics from NextE, while reimplementing the read-only browsing contract from ErosN in native ArkUI. The current slice provides anonymous browsing with session-local language/order controls and a separate Popular route, tag-driven search with local dictionary suggestions, detail with best-effort related galleries, public read-only comments, HDS thumbnail overview with explicit Reader start-page selection, reading, local reading-history resume, management, search, and date grouping, local recent-search history, a bounded private Reader page cache with aggregate status and confirmed clearing, optional local tag-label translation, and privacy-minimal system share and external-open actions for the canonical public gallery link. Settings also provides durable local display filters for gallery titles and public comments; they re-filter retained responses on-device without changing a request, account, or remote content.

Account sign-in is an in-app ArkWeb page. A verified first-party browser session is encrypted on-device with a non-exportable HUKS key; authenticated fixed `https://nhentai.net/api/v2/` reads and explicit account mutations execute in a lazily bootstrapped same-origin ArkWeb context, not NetworkKit, so they retain the browser TLS/cookie context that completed the managed challenge. The native favourites root is read-only: the signed-out state never makes an account request, while a verified first-party session enables its authenticated native read. A user can add a verified Gallery page set to a bounded, app-private download queue; complete tasks open Reader directly from those private files. The persisted queue policy defaults to one gallery × three pages and two retries, with user choices capped at five galleries, five pages, and three retries. A complete verified task may be exported as one cache-backed CBZ through the system share sheet; there is no background transfer or remote write.

Reader zoom follows the NextE gesture boundary: two-finger pinch and one-finger pan remain local to the rendered image, while a Reader-surface double tap toggles the visible page between fit and zoomed state. Continuous List scrolling and paged Swiper navigation are disabled only while the active page is zoomed; no zoom toolbar or additional Reader chrome is introduced.

## Build

```bash
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm install --all
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --mode module -p module=entry@default assembleHap
```

See [docs/architecture.md](docs/architecture.md) for boundaries and the planned feature topology.
The optional tag dictionary is not bundled in the HAP; see [docs/third-party-data.md](docs/third-party-data.md) before enabling it.
