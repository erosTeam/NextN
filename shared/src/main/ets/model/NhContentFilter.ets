/**
 * Local-only display filters derived from ErosN's block-rule contract.
 * They never alter the query sent to the public API and are not account data.
 */
export enum NhContentFilterType {
  TITLE = 'title',
  COMMENTER = 'commenter',
  COMMENT = 'comment',
}

export class NhContentFilterRule {
  id: string = ''
  type: NhContentFilterType = NhContentFilterType.TITLE
  text: string = ''
  enabled: boolean = true
  isRegex: boolean = false
}
