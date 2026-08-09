/**
 * Per-route state shared by the pushed Search destination and its HDS title
 * bottomBuilder. Keeping it route-local prevents stacked searches from
 * stealing another destination's typed query or filter command.
 */
@ObservedV2
export class SearchChromeState {
  @Trace keyword: string = ''
  @Trace submitVersion: number = 0
  @Trace filterVersion: number = 0
  /** Only manual blank search destinations should raise the IME on arrival. */
  @Trace focusOnAppear: boolean = false
}
