import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Reactive list of saved NH accounts for the account switcher. Holds only the
 * displayable account ids (saved order) + the active account id; the actual
 * sealed session envelopes live in the HUKS-protected RDB rows and are never
 * mirrored into this reactive holder. AccountListSettings is the single writer.
 */
@ObservedV2
export class AccountListState {
  @Trace accounts: string[] = []
  @Trace activeAccountId: string = ''
}

const ACCOUNT_LIST_KEY: string = 'nextn_accountList'

export function connectAccountList(): AccountListState {
  return AppStorageV2.connect(AccountListState, ACCOUNT_LIST_KEY, () => new AccountListState())!
}
