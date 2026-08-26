import { SyncDatasetSelection } from './SyncTypes'

/** NH table mapping for the WebDAV dataset selection. */
export class CloudSyncFeatureTables {
  static readonly READ_PROGRESS: string[] = ['reading_history']
  static readonly VIEWED_HISTORY: string[] = ['reading_history']
  static readonly SEARCH_HISTORY: string[] = ['search_history']
  static readonly QUICK_SEARCHES: string[] = ['search_quick']
  // The selected/last-viewed Home tab is a per-device reading position. Only
  // profile configuration belongs to the cross-device dataset.
  static readonly HOME_SUBTABS: string[] = ['home_subtabs']
  static readonly LOCAL_BLOCK: string[] = ['content_filter_rules']
  static readonly SETTINGS_TABLES: string[] = [
    'reader_settings',
    'download_settings',
    'browse_presentation_settings',
    'catalog_preferences',
  ]
}

export const WEBDAV_SYNC_TABLES: string[] = [
  'reading_history',
  'search_history',
  'search_quick',
  'home_subtabs',
  'content_filter_rules',
  'reader_settings',
  'download_settings',
  'browse_presentation_settings',
  'catalog_preferences',
]

export function webDavSyncTablesForSelection(selection: SyncDatasetSelection): string[] {
  const tables: string[] = []
  if (selection.readProgress) {
    CloudSyncFeatureTables.READ_PROGRESS.forEach((table: string) => tables.push(table))
  }
  if (selection.viewedHistory) {
    CloudSyncFeatureTables.VIEWED_HISTORY.forEach((table: string) => tables.push(table))
  }
  if (selection.searchHistory) {
    CloudSyncFeatureTables.SEARCH_HISTORY.forEach((table: string) => tables.push(table))
  }
  if (selection.quickSearches) {
    CloudSyncFeatureTables.QUICK_SEARCHES.forEach((table: string) => tables.push(table))
  }
  if (selection.homeSubtabs) {
    CloudSyncFeatureTables.HOME_SUBTABS.forEach((table: string) => tables.push(table))
  }
  if (selection.localBlock) {
    CloudSyncFeatureTables.LOCAL_BLOCK.forEach((table: string) => tables.push(table))
  }
  if (selection.settingsTables) {
    CloudSyncFeatureTables.SETTINGS_TABLES.forEach((table: string) => tables.push(table))
  }
  return tables
}
