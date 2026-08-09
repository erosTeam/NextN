/**
 * Local Browse presentation choices. They alter only the native arrangement
 * of already loaded anonymous summaries and never participate in a request.
 */
export enum NhBrowsePresentation {
  /**
   * Reduced NextE medium-list presentation. The value is deliberately
   * distinct from the legacy simple-list setting so persisted preferences are
   * never silently migrated when this mode is introduced.
   */
  LIST = 'list',
  /** Existing persisted compact-row value; keep it readable and writable. */
  SIMPLE_LIST = 'simple_list',
  /** Existing persisted cover-grid value. */
  COVER_GRID = 'cover_grid',
  /** Regular metadata-below-cover WaterFlow presentation. */
  WATERFALL = 'waterfall',
  /** Compact metadata-over-cover WaterFlow, kept separate from CoverWall. */
  WATERFALL_COMPACT = 'waterfall_compact',
  /** Cover-first WaterFlow wall; persisted independently from the grid. */
  COVER_WALL = 'cover_wall',
}
