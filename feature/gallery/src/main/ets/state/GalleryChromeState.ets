/**
 * Route-local chrome for a pushed Gallery destination. The header owns the
 * semantic title at rest; HDS receives it only after that header has scrolled
 * out of view, matching NextE's detail-title handoff.
 */
@ObservedV2
export class GalleryChromeState {
  @Trace title: string = ''
  @Trace showTitle: boolean = false
  // HDS owns the title action, while the retained destination owns the
  // request. Keeping this counter on the route chrome prevents a refresh in
  // one stacked Gallery route from reaching another retained detail.
  @Trace reloadVersion: number = 0
  // Title-bar one-shot command intents share the same route-local rule as
  // reloadVersion: a command from one stacked Gallery route must never
  // reach another retained detail.
  @Trace favoriteRequestVersion: number = 0
  @Trace shareRequestVersion: number = 0
  @Trace externalOpenRequestVersion: number = 0
  @Trace refreshInFlight: boolean = false
  // The title-bar favourite action is owned by the Detail route, but HDS is
  // rendered by the entry shell. Keep that cross-layer state explicit rather
  // than duplicating a local heart icon in the scrolling page.
  @Trace favoriteKnown: boolean = false
  @Trace isFavorited: boolean = false
  @Trace favoriteBusy: boolean = false
  // The same title-bar action represents a local download lifecycle. This is
  // deliberately a status plus bounded page counters, not a task payload:
  // the page remains the sole owner of queue operations and the shell merely
  // renders the right intent and non-sensitive progress.
  @Trace downloadActionReady: boolean = false
  @Trace downloadStatus: string = ''
  @Trace downloadCompletedPages: number = 0
  @Trace downloadPageCount: number = 0
  // In the actual wide Detail workspace, the right pane is the full-thumbnail
  // owner. The entry title bar forwards only these monotonic intents; it never
  // owns the Grid, its pages, or the jump sheet.
  @Trace wideThumbnailActionsAvailable: boolean = false
  @Trace wideThumbnailFirstPageRequestVersion: number = 0
  @Trace wideThumbnailJumpPageRequestVersion: number = 0
}
