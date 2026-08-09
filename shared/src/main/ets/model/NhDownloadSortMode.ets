/**
 * Transient ordering choices for the local Downloads presentation.
 *
 * This intentionally describes only view order. It is neither written to the
 * queue repository nor consulted by the worker, so changing it cannot alter a
 * task's scheduling, retry state, or private files.
 */
export class NhDownloadSortMode {
  static readonly ADDED_DESC: string = 'added_desc'
  static readonly ADDED_ASC: string = 'added_asc'
  static readonly TITLE_ASC: string = 'title_asc'
  static readonly TITLE_DESC: string = 'title_desc'
}
