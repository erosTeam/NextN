# Persistence Dataset Inventory

Status: active contract source.

Every Preferences key, RDB table, and filesystem persistence owner must have an explicit backup
decision. `plaintext` is included in ordinary backup, `encrypted-only` only in password-encrypted
backup, `localData` through the structured local-data section, and `excluded` never through app-data
backup. Cache/output exclusions are intentional, not omissions.

## Preferences stores

| Owner | Class | Backup | Sync | Notes |
| --- | --- | --- | --- | --- |
| `shared/src/main/ets/services/AppReleaseService.ets#APP_RELEASES_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/services/LlmSourceSecretVault.ets#SECRET_STORE` | store | excluded | excluded | HUKS vault store name |
| `shared/src/main/ets/services/NhAccountSessionService.ets#ACCOUNT_STATE_STORE` | store | excluded | excluded | Derived account runtime markers |
| `shared/src/main/ets/services/ToriiCreditsService.ets#TORII_STORE` | store | excluded | excluded | Mixed Torii settings/secret/cache store |
| `shared/src/main/ets/services/ToriiWholePageSecretStore.ets#TORII_STORE` | store | excluded | excluded | Mixed Torii settings/secret/cache store |
| `shared/src/main/ets/settings/AccountListSettings.ets#ACCOUNT_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/ActionAlignmentSettings.ets#LAYOUT_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/AppColorFavoritesSettings.ets#APPEARANCE_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/ComicVisualProviderSettings.ets#PROVIDER_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/CommentTranslationSettings.ets#SETTINGS_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/CoverBackgroundSettings.ets#LAYOUT_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/DiagnosticsSettings.ets#DIAGNOSTICS_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/GalleryDetailTransitionSettings.ets#LAYOUT_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/GalleryTitleSettings.ets#LAYOUT_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/HomeTabSettings.ets#LAYOUT_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/ImmersiveMaterialSettings.ets#APPEARANCE_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/LanguageSettings.ets#APPEARANCE_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/MangaRenderingServiceSettings.ets#RENDERING_SERVICE_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/NhClipboardLinkSettings.ets#LAYOUT_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/ReadButtonStyleSettings.ets#LAYOUT_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/ReaderImageCacheSettings.ets#STORE_NAME` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/SafeModeSettings.ets#SAFE_MODE_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/ScreenOrientationSettings.ets#SCREEN_ORIENTATION_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/SearchTranslationSettings.ets#SETTINGS_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/SyncSettings.ets#SYNC_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/TabletLayoutSettings.ets#TABLET_LAYOUT_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/TagTranslationSettings.ets#SETTINGS_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/ThemeColorSettings.ets#APPEARANCE_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/settings/ThemeSettings.ets#APPEARANCE_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/storage/LlmSourceProfileRepository.ets#LLM_SOURCE_STORE` | store | excluded | excluded | Store name only |
| `shared/src/main/ets/storage/NhCloudBlacklistRepository.ets#BLACKLIST_STORE` | store | excluded | excluded | Store name only |

## Preferences keys

| Owner | Class | Backup | Sync | Notes |
| --- | --- | --- | --- | --- |
| `shared/src/main/ets/services/AppReleaseService.ets#APP_RELEASES_CACHE_KEY` | remote-cache | excluded | excluded | Regenerable GitHub release cache |
| `shared/src/main/ets/services/LlmSourceSecretVault.ets#SECRET_ENVELOPE_KEY` | secret | encrypted-only | excluded | Exported as decrypted source map, then target-HUKS re-wrapped |
| `shared/src/main/ets/services/NhAccountSessionService.ets#ACCOUNT_PRESENT_KEY` | derived-runtime | excluded | excluded | Rebuilt from sealed sessions |
| `shared/src/main/ets/services/NhAccountSessionService.ets#AUTH_REFRESH_RETRY_AT_KEY` | runtime | excluded | excluded | Server cooldown timestamp |
| `shared/src/main/ets/services/ToriiCreditsService.ets#TORII_CREDITS_CACHE_KEY` | volatile-cache | excluded | excluded | API-key-scoped balance cache |
| `shared/src/main/ets/services/ToriiWholePageSecretStore.ets#TORII_CREDENTIAL_KEY` | secret | encrypted-only | excluded | Torii API credential |
| `shared/src/main/ets/settings/AccountListSettings.ets#ACCOUNT_IDS_KEY` | account-secret | encrypted-only | excluded | Saved account ownership list |
| `shared/src/main/ets/settings/AccountListSettings.ets#ACTIVE_ACCOUNT_ID_KEY` | account-secret | encrypted-only | excluded | Active saved-account identity |
| `shared/src/main/ets/settings/ActionAlignmentSettings.ets#ACTION_ALIGNMENT_MODE_KEY` | setting | plaintext | excluded | Action placement |
| `shared/src/main/ets/settings/AppColorFavoritesSettings.ets#FAVORITES_KEY` | setting | plaintext | excluded | Theme favorites |
| `shared/src/main/ets/settings/ComicVisualProviderSettings.ets#ROUTE_KEY` | setting | plaintext | excluded | Local, self-hosted, or Torii route |
| `shared/src/main/ets/settings/ComicVisualProviderSettings.ets#MULTIMODAL_ASSIST_KEY` | setting | plaintext | excluded | Multimodal translation policy |
| `shared/src/main/ets/settings/ComicVisualProviderSettings.ets#TORII_MODEL_KEY` | setting | plaintext | excluded | Torii model |
| `shared/src/main/ets/settings/ComicVisualProviderSettings.ets#TORII_FONT_KEY` | setting | plaintext | excluded | Torii rendering font |
| `shared/src/main/ets/settings/ComicVisualProviderSettings.ets#LEGACY_BILLING_MODE_KEY` | retired-tombstone | excluded | excluded | Deleted on load |
| `shared/src/main/ets/settings/ComicVisualProviderSettings.ets#LEGACY_BYOK_PROVIDER_KEY` | retired-tombstone | excluded | excluded | Deleted on load |
| `shared/src/main/ets/settings/ComicVisualProviderSettings.ets#LEGACY_BYOK_SOURCE_PROFILE_KEY` | retired-tombstone | excluded | excluded | Deleted on load |
| `shared/src/main/ets/settings/ComicVisualProviderSettings.ets#LEGACY_BYOK_MODEL_KEY` | retired-tombstone | excluded | excluded | Deleted on load |
| `shared/src/main/ets/settings/CommentTranslationSettings.ets#KEY_ENABLED` | setting | plaintext | excluded | Comment translation switch |
| `shared/src/main/ets/settings/CommentTranslationSettings.ets#KEY_AUTO` | setting | plaintext | excluded | Auto translation |
| `shared/src/main/ets/settings/CommentTranslationSettings.ets#KEY_DISPLAY_MODE` | setting | plaintext | excluded | Translation display mode |
| `shared/src/main/ets/settings/CoverBackgroundSettings.ets#COVER_BACKGROUND_BLUR_KEY` | setting | plaintext | excluded | Cover blur |
| `shared/src/main/ets/settings/DiagnosticsSettings.ets#DIAGNOSTICS_ENABLED_KEY` | setting | plaintext | excluded | Diagnostics opt-in |
| `shared/src/main/ets/settings/DiagnosticsSettings.ets#DIAGNOSTICS_MIN_LEVEL_KEY` | setting | plaintext | excluded | Diagnostics level |
| `shared/src/main/ets/settings/GalleryDetailTransitionSettings.ets#DETAIL_MODE_KEY` | setting | plaintext | excluded | List-to-detail transition mode |
| `shared/src/main/ets/settings/GalleryDetailTransitionSettings.ets#LEGACY_DETAIL_ENABLED_KEY` | migration | plaintext | excluded | Legacy transition switch migration source |
| `shared/src/main/ets/settings/GalleryDetailTransitionSettings.ets#READER_THUMBNAIL_ENABLED_KEY` | setting | plaintext | excluded | Thumbnail-to-Reader transition switch |
| `shared/src/main/ets/settings/GalleryTitleSettings.ets#GALLERY_TITLE_JAPANESE_PRIMARY_KEY` | setting | plaintext | excluded | Title preference |
| `shared/src/main/ets/settings/HomeTabSettings.ets#HOME_TAB_AUTO_HIDE_KEY` | setting | plaintext | excluded | Tab behavior |
| `shared/src/main/ets/settings/ImmersiveMaterialSettings.ets#IMMERSIVE_MATERIAL_LEVEL_KEY` | setting | plaintext | excluded | Material preference |
| `shared/src/main/ets/settings/LanguageSettings.ets#LANGUAGE_KEY` | setting | plaintext | excluded | App language |
| `shared/src/main/ets/settings/MangaRenderingServiceSettings.ets#BASE_URL_KEY` | setting | plaintext | excluded | Rendering endpoint |
| `shared/src/main/ets/settings/MangaRenderingServiceSettings.ets#DETECTION_PROFILE_KEY` | setting | plaintext | excluded | Detector profile |
| `shared/src/main/ets/settings/MangaRenderingServiceSettings.ets#INPAINTING_PROFILE_KEY` | setting | plaintext | excluded | Inpainting profile |
| `shared/src/main/ets/settings/MangaRenderingServiceSettings.ets#ENABLED_KEY` | setting | plaintext | excluded | Rendering service switch |
| `shared/src/main/ets/settings/NhClipboardLinkSettings.ets#ENABLED_KEY` | device-consent | excluded | excluded | Device-local consent |
| `shared/src/main/ets/settings/NhClipboardLinkSettings.ets#CHANGE_COUNT_KEY` | runtime | excluded | excluded | Device clipboard cursor |
| `shared/src/main/ets/settings/ReadButtonStyleSettings.ets#READ_BUTTON_STYLE_KEY` | setting | plaintext | excluded | Reader action style |
| `shared/src/main/ets/settings/ReaderImageCacheSettings.ets#KEY_LIMIT_MB` | setting | plaintext | excluded | Cache size preference, not cache content |
| `shared/src/main/ets/settings/SafeModeSettings.ets#SAFE_MODE_UNLOCKED_KEY` | runtime | excluded | excluded | Device-local restricted-build escape marker |
| `shared/src/main/ets/settings/ScreenOrientationSettings.ets#SCREEN_ORIENTATION_KEY` | setting | plaintext | excluded | Orientation policy |
| `shared/src/main/ets/settings/SearchTranslationSettings.ets#KEY_TRANSLATE_ENABLED` | setting | plaintext | excluded | Search translation display policy |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_WEBDAV_URL` | credential-group | encrypted-only | excluded | Atomic WebDAV group |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_WEBDAV_USERNAME` | credential-group | encrypted-only | excluded | Atomic WebDAV group |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_WEBDAV_ENABLED` | credential-group | encrypted-only | excluded | Atomic WebDAV group |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_WEBDAV_PASSWORD` | credential-group | encrypted-only | excluded | Atomic WebDAV group |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_DATASET_READ_PROGRESS` | setting | plaintext | excluded | Sync selection |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_DATASET_VIEWED_HISTORY` | setting | plaintext | excluded | Sync selection |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_DATASET_SEARCH_HISTORY` | setting | plaintext | excluded | Sync selection |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_DATASET_QUICK_SEARCHES` | setting | plaintext | excluded | Sync selection |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_DATASET_HOME_SUBTABS` | setting | plaintext | excluded | Sync selection |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_DATASET_LOCAL_USER_TAGS` | setting | plaintext | excluded | Sync selection |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_DATASET_LOCAL_BLOCK` | setting | plaintext | excluded | Sync selection |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_DATASET_SETTINGS_TABLES` | setting | plaintext | excluded | Sync selection |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_LAST_RUN_AT` | runtime | excluded | excluded | Provider status |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_LAST_STATUS` | runtime | excluded | excluded | Provider status |
| `shared/src/main/ets/settings/SyncSettings.ets#KEY_LAST_DETAIL` | runtime | excluded | excluded | Provider status |
| `shared/src/main/ets/settings/TabletLayoutSettings.ets#TABLET_LAYOUT_KEY` | setting | plaintext | excluded | Tablet layout |
| `shared/src/main/ets/settings/TagTranslationSettings.ets#KEY_ENABLED` | setting | plaintext | excluded | Tag translation switch |
| `shared/src/main/ets/settings/TagTranslationSettings.ets#KEY_USE_CDN` | setting | plaintext | excluded | Translation source policy |
| `shared/src/main/ets/settings/TagTranslationSettings.ets#KEY_UPDATE_MODE` | setting | plaintext | excluded | Update mode |
| `shared/src/main/ets/settings/ThemeColorSettings.ets#THEME_COLOR_KEY` | setting | plaintext | excluded | Theme accent |
| `shared/src/main/ets/settings/ThemeSettings.ets#THEME_KEY` | setting | plaintext | excluded | Theme mode |
| `shared/src/main/ets/storage/LlmSourceProfileRepository.ets#LLM_SOURCE_PROFILES_KEY` | setting | plaintext | excluded | Provider metadata |
| `shared/src/main/ets/storage/LlmSourceProfileRepository.ets#COMMENT_SOURCE_KEY` | setting | plaintext | excluded | Comment source selection |
| `shared/src/main/ets/storage/LlmSourceProfileRepository.ets#COMMENT_MODEL_KEY` | setting | plaintext | excluded | Comment model selection |
| `shared/src/main/ets/storage/LlmSourceProfileRepository.ets#MANGA_SOURCE_KEY` | setting | plaintext | excluded | Manga source selection |
| `shared/src/main/ets/storage/LlmSourceProfileRepository.ets#MANGA_MODEL_KEY` | setting | plaintext | excluded | Manga model selection |
| `shared/src/main/ets/storage/NhCloudBlacklistRepository.ets#KEY_BLACKLIST_IDS` | account-cache | excluded | excluded | Refreshed from account API |

## LocalDataStore tables

| Owner | Class | Backup | Sync | Notes |
| --- | --- | --- | --- | --- |
| `reading_history` | local-data | localData | WebDAV | Progress and viewed history |
| `search_history` | local-data | localData | WebDAV | Search history |
| `search_quick` | local-data | localData | WebDAV | Pinned searches |
| `tag_translations` | cache | excluded | excluded | Downloaded translation dictionary |
| `tag_translation_meta` | cache | excluded | excluded | Dictionary metadata |
| `nh_tag_catalog` | remote-cache | excluded | excluded | Regenerable tag catalog |
| `nh_gallery_detail_cache` | remote-cache | excluded | excluded | Regenerable detail cache |
| `reader_settings` | local-data | localData | WebDAV | Reader preferences |
| `account_session` | secret | encrypted-only | excluded | Active and saved sessions, target-HUKS re-wrapped |
| `account_profile` | account-secret | encrypted-only | excluded | Active and saved display profiles |
| `account_session_verification` | runtime | excluded | excluded | Recovery decision marker |
| `download_queue` | operational | excluded | excluded | Device download task state |
| `download_settings` | local-data | localData | WebDAV | Download preferences |
| `content_filter_rules` | local-data | localData | WebDAV | User rules |
| `browse_presentation_settings` | local-data | localData | WebDAV | Browse presentation |
| `catalog_preferences` | local-data | localData | WebDAV | Catalog query preferences |
| `home_subtabs` | local-data | localData | WebDAV | Custom home subtabs |
| `local_user_tags` | local-data | localData | WebDAV | Local tag color, weight, Hidden, and tombstones |
| `local_user_tag_settings` | local-data | localData | WebDAV | Local tag filtering threshold and tombstone |
| `home_subtab_selection` | local-data | localData | excluded | Device-local selected home subtab |
| `comic_translation_document_cache` | cache | excluded | excluded | Regenerable translation document cache |
| `comment_translation_cache` | cache | excluded | excluded | Regenerable comment translations |
| `nh_gallery_list_cache` | remote-cache | excluded | excluded | Regenerable list cache |

## Filesystem persistence owners

| Owner | Class | Backup | Sync | Notes |
| --- | --- | --- | --- | --- |
| `shared/src/main/ets/diagnostics/DiagnosticsLogFileSink.ets` | diagnostics | excluded | excluded | Device-local logs |
| `shared/src/main/ets/services/ComicLocalVisualBackend.ets` | temporary | excluded | excluded | Derived work files |
| `shared/src/main/ets/services/ComicRenderedPageRepository.ets` | cache | excluded | excluded | Regenerable rendered pages |
| `shared/src/main/ets/services/ComicTranslationModelService.ets` | model-cache | excluded | excluded | Downloadable local model |
| `shared/src/main/ets/services/DownloadQueueService.ets` | download | excluded | excluded | Downloaded user media is outside settings backup |
| `shared/src/main/ets/services/MangaRenderingServiceArchive.ets` | temporary | excluded | excluded | Imported/rendering archive work files |
| `shared/src/main/ets/services/MangaRenderingServiceBackend.ets` | temporary | excluded | excluded | Rendering work files |
| `shared/src/main/ets/services/NhDownloadCbzExportService.ets` | user-export | excluded | excluded | Explicit CBZ export |
| `shared/src/main/ets/services/NhDownloadExportCacheService.ets` | temporary | excluded | excluded | Export staging cache |
| `shared/src/main/ets/services/NhTorrentFileExportService.ets` | user-export | excluded | excluded | Explicit torrent export |
| `shared/src/main/ets/services/ReaderImageCacheService.ets` | cache | excluded | excluded | Regenerable reader images |
| `shared/src/main/ets/services/ReaderSuperResolutionModelService.ets` | model-cache | excluded | excluded | Downloadable model |
| `shared/src/main/ets/services/ReaderSuperResolutionService.ets` | temporary | excluded | excluded | Derived image work files |
| `shared/src/main/ets/services/TagTranslationUpdateService.ets` | temporary | excluded | excluded | Download staging file |
| `shared/src/main/ets/services/ToriiWholePageContextStore.ets` | cache | excluded | excluded | Regenerable Torii continuation context |
| `shared/src/main/ets/services/ToriiWholePageLiveEvaluationService.ets` | temporary | excluded | excluded | Evaluation artifacts |
| `shared/src/main/ets/services/ToriiWholePageRenderBackend.ets` | temporary | excluded | excluded | Torii render work files |
| `shared/src/main/ets/settings/DiagnosticsFileExport.ets` | user-export | excluded | excluded | Explicit diagnostics export |
