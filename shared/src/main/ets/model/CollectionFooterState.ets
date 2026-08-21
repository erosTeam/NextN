/** Canonical settled/refreshing state projection for retained collection footers. */
export class CollectionFooterState {
  static canOfferMore(
    isRefreshing: boolean,
    canLoadMore: boolean,
    isLoadingMore: boolean,
    hasLoadMoreError: boolean,
  ): boolean {
    return !isRefreshing && canLoadMore && !isLoadingMore && !hasLoadMoreError
  }

  static isComplete(
    isRefreshing: boolean,
    canLoadMore: boolean,
    isLoadingMore: boolean,
    hasLoadMoreError: boolean,
  ): boolean {
    return !isRefreshing && !canLoadMore && !isLoadingMore && !hasLoadMoreError
  }

  static idleText(isRefreshing: boolean, settledText: string): string {
    return isRefreshing ? '' : settledText
  }
}
