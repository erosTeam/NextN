#!/usr/bin/env node

import { readFile } from 'node:fs/promises'

const ROOT = new URL('../', import.meta.url)

const requiredEvents = [
  {
    file: 'shared/src/main/ets/services/NhAccountProfileService.ets',
    event: "profile_switch_restore_failed",
  },
  {
    file: 'feature/user/src/main/ets/pages/FavoritesPage.ets',
    event: "cache_hydrate_failed",
  },
  {
    file: 'feature/home/src/main/ets/pages/HomePage.ets',
    event: "cache_hydrate_failed",
  },
  {
    file: 'feature/gallery/src/main/ets/pages/GalleryDetailPage.ets',
    event: "gallery_enqueue_failed",
  },
  {
    file: 'feature/gallery/src/main/ets/pages/GalleryDetailPage.ets',
    event: "gallery_torrent_export_failed",
  },
  {
    file: 'shared/src/main/ets/services/NhAccountSessionService.ets',
    event: "account_profile_snapshot_clear_failed",
  },
  {
    file: 'feature/home/src/main/ets/pages/HomePage.ets',
    event: "collection_refresh_started",
  },
  {
    file: 'feature/home/src/main/ets/pages/HomePage.ets',
    event: "collection_refresh_settled",
  },
  {
    file: 'feature/home/src/main/ets/pages/PopularPage.ets',
    event: "collection_refresh_started",
  },
  {
    file: 'feature/home/src/main/ets/components/HomeSearchSubtabPage.ets',
    event: "collection_refresh_settled",
  },
  {
    file: 'feature/user/src/main/ets/pages/HistoryPage.ets',
    event: "collection_refresh_settled",
  },
  {
    file: 'shared/src/main/ets/settings/HomeSubtabSettings.ets',
    event: "home_subtabs_canonicalized",
  },
]

for (const item of requiredEvents) {
  const source = await readFile(new URL(item.file, ROOT), 'utf8')
  if (!source.includes(item.event)) {
    throw new Error(`${item.file}: missing fixed diagnostic event ${item.event}`)
  }
}

console.log(`OK diagnostic event contract passed (${requiredEvents.length} critical boundaries scanned)`)
