import { common } from '@kit.AbilityKit'
import { CustomContentDialog } from '@kit.ArkUI'
import {
  AccountListSettings,
  AccountSessionState,
  AppStrings,
  NextNGroupedListSection,
  NextNListRow,
  SecondaryListScaffold,
  ThemeTokens,
  NhApiClient,
  AccountAuthNoticeState,
  AppPrompt,
  connectAccountAuthNotice,
  connectAccountSession,
} from 'shared'

/** Normal Account child for automatic NH API-key binding through the official settings page. */
@ComponentV2
export struct AccountApiKeyPage {
  @Event onOpenOfficialSettings?: () => void
  @Param manualBindRequestVersion: number = 0
  @Local private accountSession: AccountSessionState = connectAccountSession()
  @Local private accountAuthNotice: AccountAuthNoticeState = connectAccountAuthNotice()
  @Local private apiKeyDraft: string = ''
  @Local private apiKeyNameDraft: string = ''
  @Local private isBindingExistingKey: boolean = false
  private scroller: Scroller = new Scroller()
  private manualBindingDialogController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: AppStrings.get('account_api_key_bind_existing'),
      contentBuilder: (): void => {
        this.ManualBindingDialogContent()
      },
      buttons: [
        {
          value: AppStrings.get('common_cancel'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: (): void => {
            this.closeManualBindingDialog()
          },
        },
        {
          value: AppStrings.get('account_api_key_validate_and_bind'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: (): void => {
            this.bindExistingKey()
          },
        },
      ],
    }),
    autoCancel: true,
    onWillDismiss: (_action: DismissDialogAction): void => {
      this.resetManualBindingDraft()
    },
    alignment: DialogAlignment.Center,
    customStyle: false,
    systemMaterial: AppPrompt.modalSystemMaterial(),
  })

  @Monitor('manualBindRequestVersion')
  private onManualBindRequested(): void {
    if (this.manualBindRequestVersion > 0) {
      this.openManualBindingDialog()
    }
  }

  aboutToDisappear(): void {
    this.closeManualBindingDialog()
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private updateRequired(): boolean {
    return this.accountSession.verificationRequired &&
      this.accountSession.verificationRecoveryKind === 'api_key'
  }

  private active(): boolean {
    return this.accountSession.authenticationAvailable &&
      this.accountSession.credentialKind === 'api_key'
  }

  private statusTitle(): string {
    if (this.updateRequired()) {
      return AppStrings.get('account_api_key_verification_required')
    }
    return AppStrings.get(this.active()
      ? 'account_api_key_status_bound'
      : 'account_api_key_status_not_bound')
  }

  private statusHint(): string {
    if (this.updateRequired()) {
      return AppStrings.get('account_api_key_status_update_hint')
    }
    return AppStrings.get(this.active()
      ? 'account_api_key_status_bound_hint'
      : 'account_api_key_status_not_bound_hint')
  }

  private apiKeyIdentity(): string {
    return this.active() || this.updateRequired() ? this.accountSession.apiKeyIdentity : ''
  }

  private apiKeyName(): string {
    if (this.accountSession.apiKeyName.length > 0) {
      return this.accountSession.apiKeyName
    }
    return AppStrings.get('account_api_key_name_unknown')
  }

  private resetManualBindingDraft(): void {
    this.apiKeyDraft = ''
    this.apiKeyNameDraft = ''
  }

  private openManualBindingDialog(): void {
    this.resetManualBindingDraft()
    this.manualBindingDialogController.open()
  }

  private closeManualBindingDialog(): void {
    try {
      this.manualBindingDialogController.close()
    } catch (_error) {
      // Dialog may already have been dismissed by tapping outside or leaving the route.
    }
    this.resetManualBindingDraft()
  }

  private async bindExistingKey(): Promise<void> {
    if (this.isBindingExistingKey) {
      return
    }
    if (this.apiKeyDraft.trim().length === 0) {
      this.accountAuthNotice.publish('api_key_invalid_input')
      return
    }
    this.isBindingExistingKey = true
    const context: common.UIAbilityContext = this.hostContext()
    const keyName: string = this.apiKeyNameDraft.trim().length > 0
      ? this.apiKeyNameDraft.trim()
      : AppStrings.get('account_api_key_imported_name')
    try {
      await NhApiClient.bindApiKey(context, this.apiKeyDraft, false, keyName)
      const profileSaved: boolean = await AccountListSettings.recordActive(context)
      this.closeManualBindingDialog()
      if (profileSaved) {
        this.accountAuthNotice.clear()
        this.getUIContext().getPromptAction().showToast({
          message: AppStrings.get('account_api_key_saved'),
        })
      } else {
        this.accountAuthNotice.publish('api_key_profile_failed')
      }
    } catch (error) {
      const message: string = error instanceof Error ? error.message : ''
      this.accountAuthNotice.publish(message === 'account_api_key_rejected'
        ? 'api_key_rejected'
        : message === 'account_api_key_persistence_failed'
          ? 'api_key_save_failed'
          : message === 'account_api_key_invalid_input'
            ? 'api_key_invalid_input'
            : 'api_key_unavailable')
    } finally {
      this.isBindingExistingKey = false
    }
  }

  @Builder
  private ManualBindingDialogContent() {
    Column({ space: ThemeTokens.SPACE_SM }) {
      TextInput({
        text: this.apiKeyDraft,
        placeholder: AppStrings.get('account_api_key_value_placeholder'),
      })
        .type(InputType.Password)
        .enabled(!this.isBindingExistingKey)
        .width('100%')
        .onChange((value: string): void => {
          this.apiKeyDraft = value
        })
      TextInput({
        text: this.apiKeyNameDraft,
        placeholder: AppStrings.get('account_api_key_name_placeholder'),
      })
        .enabled(!this.isBindingExistingKey)
        .width('100%')
        .onChange((value: string): void => {
          this.apiKeyNameDraft = value
        })
    }
    .width('100%')
  }

  build() {
    Column() {
      SecondaryListScaffold({
        scroller: this.scroller,
        bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
        alwaysEnableEdgeSpring: true,
      }) {
        ListItem() {
          NextNGroupedListSection() {
            NextNListRow({
              leadingIcon: $r('sys.symbol.key'),
              title: this.statusTitle(),
              subtitle: this.statusHint(),
              showChevron: false,
            })
          }
        }
        if (this.active() || this.updateRequired()) {
          ListItem() {
            NextNGroupedListSection() {
              NextNListRow({
                leadingIcon: $r('sys.symbol.key'),
                title: this.apiKeyName(),
                subtitle: this.apiKeyIdentity(),
                showChevron: false,
              })
            }
          }
        }
        ListItem() {
          NextNGroupedListSection() {
            NextNListRow({
              leadingIcon: $r('sys.symbol.link'),
              title: AppStrings.get('account_api_key_create_new'),
              subtitle: AppStrings.get('account_api_key_open_settings_hint'),
              onAction: (): void => {
                if (this.onOpenOfficialSettings) {
                  this.onOpenOfficialSettings()
                }
              },
            })
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE)
    .id('nextn-account-api-key-root')
  }
}
