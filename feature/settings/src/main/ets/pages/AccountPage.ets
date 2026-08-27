import { common } from '@kit.AbilityKit'
import {
  AccountListSettings,
  AccountListState,
  AccountProfileRepository,
  AccountProfileState,
  AccountSessionState,
  AppStrings,
  NextNGroupedListSection,
  NextNListRow,
  NhAccountProfile,
  NhAccountSessionService,
  SecondaryListScaffold,
  ThemeTokens,
  connectAccountList,
  connectAccountProfile,
  connectAccountSession,
} from 'shared'

/**
 * NH multi-account management leaf (port of NextE's AccountPage).
 *
 * The saved-account list is AccountListSettings.saved order; each row shows
 * the saved display profile (AccountProfileRepository.loadByKey) and marks
 * the active row selected. Tap switches through AccountListSettings.switchTo,
 * swipe left deletes (NextE parity, no confirm; deleting the active row
 * switches to the first remaining saved account or clears the session), the
 * the title-bar action enters the login-only original Web destination, and
 * the bottom row signs the current account out while removing its saved-list
 * relationship.
 * The NextE EH dashboard sections are intentionally absent: NH has no EH
 * dashboard data source (see data-transfer-multiaccount-webdav.md §2.3).
 */
class AccountProfileSummary {
  accountId: string = ''
  username: string = ''
  avatarUrl: string = ''

  constructor(accountId: string, username: string, avatarUrl: string) {
    this.accountId = accountId
    this.username = username
    this.avatarUrl = avatarUrl
  }
}

@ComponentV2
export struct AccountPage {
  /** Opens the selected account's first-party settings in the shared session WebView. */
  @Event onOpenNhSettings?: () => void
  @Local accountList: AccountListState = connectAccountList();
  @Local accountSession: AccountSessionState = connectAccountSession();
  @Local accountProfile: AccountProfileState = connectAccountProfile();
  @Local accountProfiles: AccountProfileSummary[] = [];
  @Local isMutatingAccount: boolean = false;
  @Local isSigningOut: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.reload()
  }

  @Monitor('accountList.accounts')
  private onAccountListChanged(): void {
    this.loadAccountProfiles()
  }

  @Monitor('accountList.activeAccountId')
  private onActiveAccountChanged(): void {
    this.loadAccountProfiles()
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message })
  }

  private async reload(): Promise<void> {
    await AccountListSettings.load(this.ctx())
    await this.loadAccountProfiles()
  }

  private async loadAccountProfiles(): Promise<void> {
    const ids: string[] = this.accountList.accounts
    const rows: AccountProfileSummary[] = []
    for (let i: number = 0; i < ids.length; i++) {
      const accountId: string = ids[i]
      let profile: NhAccountProfile | null = null
      try {
        profile = await AccountProfileRepository.loadByKey(this.ctx(), accountId)
      } catch (_error) {
        profile = null
      }
      const username: string = profile === null ? '' : profile.username
      const avatarUrl: string = profile === null ? '' : profile.avatarUrl
      rows.push(new AccountProfileSummary(accountId, username, avatarUrl))
    }
    this.accountProfiles = rows
  }

  private accountProfileSummary(accountId: string): AccountProfileSummary | null {
    for (let i: number = 0; i < this.accountProfiles.length; i++) {
      if (this.accountProfiles[i].accountId === accountId) {
        return this.accountProfiles[i]
      }
    }
    return null
  }

  private hasDisplayName(accountId: string): boolean {
    if (accountId === this.accountList.activeAccountId && this.accountProfile.username.length > 0) {
      return true
    }
    const summary: AccountProfileSummary | null = this.accountProfileSummary(accountId)
    return summary !== null && summary.username.length > 0
  }

  private displayName(accountId: string): string {
    if (accountId === this.accountList.activeAccountId && this.accountProfile.username.length > 0) {
      return this.accountProfile.username
    }
    const summary: AccountProfileSummary | null = this.accountProfileSummary(accountId)
    if (summary !== null && summary.username.length > 0) {
      return summary.username
    }
    return AppStrings.format('account_profile_id', [accountId])
  }

  private accountTitle(accountId: string): string {
    return this.hasDisplayName(accountId) ? this.displayName(accountId) : AppStrings.format('account_profile_id', [accountId])
  }

  private accountSubtitle(accountId: string): string {
    return this.hasDisplayName(accountId) ? AppStrings.format('account_profile_id', [accountId]) : ''
  }

  private accountAvatarUrl(accountId: string): string {
    if (accountId === this.accountList.activeAccountId && this.accountProfile.avatarUrl.length > 0) {
      return this.accountProfile.avatarUrl
    }
    const summary: AccountProfileSummary | null = this.accountProfileSummary(accountId)
    return summary === null ? '' : summary.avatarUrl
  }

  private accountRowAccessibilityLabel(accountId: string): string {
    const title: string = this.accountTitle(accountId)
    const subtitle: string = this.accountSubtitle(accountId)
    const base: string = subtitle.length > 0 ? `${title}, ${subtitle}` : title
    if (accountId === this.accountList.activeAccountId) {
      return `${base}. ${AppStrings.get('account_status_signed_in')}`
    }
    return base
  }

  private addAccountTitle(): string {
    return this.accountSession.signedIn
      ? AppStrings.get('settings_add_account')
      : AppStrings.get('account_sign_in')
  }

  private addAccountSubtitle(): string {
    return this.accountSession.signedIn ? '' : AppStrings.get('account_sign_in_subtitle')
  }

  private addAccountAccessibilityLabel(): string {
    if (this.accountSession.signedIn) {
      return AppStrings.get('settings_add_account')
    }
    return `${AppStrings.get('account_sign_in')}. ${AppStrings.get('account_sign_in_subtitle')}`
  }

  /** Tap a saved row to switch; the active row is a no-op. */
  private async switchAccount(accountId: string): Promise<void> {
    if (this.isMutatingAccount || accountId === this.accountList.activeAccountId) {
      return
    }
    this.isMutatingAccount = true
    try {
      const switched: boolean = await AccountListSettings.switchTo(this.ctx(), accountId)
      if (!switched) {
        this.toast(AppStrings.get('account_switch_failed'))
      }
      await this.loadAccountProfiles()
    } catch (_error) {
      this.toast(AppStrings.get('account_switch_failed'))
    } finally {
      this.isMutatingAccount = false
    }
  }

  /**
   * NextE swipe-delete parity: no confirm. Removing the active saved account
   * switches to the first remaining account, or clears the session when the
   * list becomes empty.
   */
  private async removeSavedAccount(accountId: string): Promise<void> {
    if (this.isMutatingAccount) {
      return
    }
    this.isMutatingAccount = true
    try {
      const wasActive: boolean = accountId === this.accountList.activeAccountId
      const remaining: string[] = await AccountListSettings.remove(this.ctx(), accountId)
      if (wasActive) {
        if (remaining.length > 0) {
          const switched: boolean = await AccountListSettings.switchTo(this.ctx(), remaining[0])
          if (!switched) {
            this.toast(AppStrings.get('account_switch_failed'))
          }
        } else {
          await NhAccountSessionService.clear(this.ctx())
        }
      }
      await this.loadAccountProfiles()
    } catch (_error) {
      this.toast(AppStrings.get('account_clear_failed'))
    } finally {
      this.isMutatingAccount = false
    }
  }

  private confirmSignOut(): void {
    if (this.isMutatingAccount || !this.accountSession.signedIn) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('account_sign_out_title'),
      message: AppStrings.get('account_sign_out_message'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('account_sign_out_action'),
        fontColor: Color.Red,
        action: (): void => {
          this.signOut()
        },
      },
    })
  }

 /**
   * NextE sign-out parity: remove the current account from the saved list;
   * when another saved account remains, switch to it immediately, otherwise
   * clear the active session through the BrowserSessionPage chain.
  */
  private async signOut(): Promise<void> {
    if (this.isMutatingAccount || this.isSigningOut) {
      return
    }
    this.isSigningOut = true
    this.isMutatingAccount = true
    try {
      const activeAccountId: string = this.accountList.activeAccountId
      if (activeAccountId.length > 0) {
        const remaining: string[] = await AccountListSettings.remove(this.ctx(), activeAccountId)
        if (remaining.length > 0) {
          const switched: boolean = await AccountListSettings.switchTo(this.ctx(), remaining[0])
          if (!switched) {
            this.toast(AppStrings.get('account_switch_failed'))
          }
        } else {
          await NhAccountSessionService.clear(this.ctx())
        }
      } else {
        await NhAccountSessionService.clear(this.ctx())
      }
      await AccountListSettings.load(this.ctx())
      await this.loadAccountProfiles()
    } catch (_error) {
      this.toast(AppStrings.get('account_clear_failed'))
    } finally {
      this.isSigningOut = false
      this.isMutatingAccount = false
    }
  }

  /** Same 44vp circular identity prefix as NextN's Settings root avatar. */
  @Builder
  private AccountAvatar(accountId: string) {
    Stack() {
      if (this.accountAvatarUrl(accountId).length > 0) {
        Image(this.accountAvatarUrl(accountId))
          .width(ThemeTokens.ACCOUNT_AVATAR_SIZE)
          .height(ThemeTokens.ACCOUNT_AVATAR_SIZE)
          .objectFit(ImageFit.Cover)
      } else {
        SymbolGlyph($r('sys.symbol.person_fill'))
          .fontSize(ThemeTokens.ACCOUNT_AVATAR_SIZE / 2)
          .fontColor([Color.White])
      }
    }
    .width(ThemeTokens.ACCOUNT_AVATAR_SIZE)
    .height(ThemeTokens.ACCOUNT_AVATAR_SIZE)
    .borderRadius(ThemeTokens.ACCOUNT_AVATAR_SIZE / 2)
    .clip(true)
    .backgroundColor(ThemeTokens.BRAND)
  }

  /** One saved account as a card row; the active one is selected via Radio (NextE parity). */
  @Builder
  private AccountRow(accountId: string) {
    Row({ space: ThemeTokens.SPACE_MD }) {
      this.AccountAvatar(accountId)
      Column({ space: ThemeTokens.SPACE_XS }) {
        Text(this.accountTitle(accountId))
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.accountSubtitle(accountId).length > 0) {
          Text(this.accountSubtitle(accountId))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Radio({ value: accountId, group: 'nextn_accounts' })
        .checked(accountId === this.accountList.activeAccountId)
        .radioStyle({ checkedBackgroundColor: ThemeTokens.BRAND })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .padding(ThemeTokens.SPACE_MD)
    .borderRadius(ThemeTokens.RADIUS_CARD)
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
    .alignItems(VerticalAlign.Center)
    .opacity(this.isMutatingAccount ? 0.6 : 1)
    .id('nextn-account-saved-row')
    .accessibilityText(this.accountRowAccessibilityLabel(accountId))
    .onClick((): void => {
      this.switchAccount(accountId)
    })
  }

  /** Swipe-left delete (V2Next pattern): red trash button, no confirm. */
  @Builder
  private DeleteAction(accountId: string) {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(ThemeTokens.FONT_SIZE_TITLE)
          .fontColor([Color.White])
      }
      .width(ThemeTokens.MIN_TOUCH_TARGET)
      .height(ThemeTokens.MIN_TOUCH_TARGET)
      .backgroundColor(Color.Red)
      .accessibilityText(AppStrings.get('common_delete'))
      .onClick((): void => {
        this.removeSavedAccount(accountId)
      })
    }
    .height('100%')
    .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        scroller: this.scroller,
        bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
        alwaysEnableEdgeSpring: true,
      }) {
        ForEach(
          this.accountList.accounts,
          (accountId: string): void => {
            ListItem() {
              this.AccountRow(accountId)
            }
            .swipeAction({
              end: (): void => {
                this.DeleteAction(accountId)
              },
            })
          },
          (accountId: string): string => accountId,
        )
        if (this.accountSession.signedIn) {
          ListItem() {
            NextNGroupedListSection() {
              NextNListRow({
                leadingIcon: $r('sys.symbol.gearshape'),
                title: AppStrings.get('nh_settings_title'),
                subtitle: AppStrings.get('nh_settings_hint'),
                isEnabled: !this.isMutatingAccount,
                onAction: (): void => {
                  if (this.onOpenNhSettings) {
                    this.onOpenNhSettings()
                  }
                },
              })
            }
          }
          ListItem() {
            NextNGroupedListSection() {
              NextNListRow({
                leadingIcon: $r('sys.symbol.arrow_right_to_line'),
                title: this.isSigningOut
                  ? AppStrings.get('account_signing_out')
                  : AppStrings.get('account_sign_out'),
                subtitle: AppStrings.get('account_sign_out_subtitle'),
                showChevron: false,
                destructive: true,
                isEnabled: !this.isMutatingAccount,
                accessibilityLabel: this.isSigningOut
                  ? AppStrings.get('account_signing_out_a11y')
                  : AppStrings.get('account_sign_out_a11y'),
                onAction: (): void => {
                  this.confirmSignOut()
                },
              })
            }
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE)
    .id('nextn-account-list-root')
  }
}
