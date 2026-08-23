import { common } from '@kit.AbilityKit'
import { KeyboardAvoidMode, SymbolGlyphModifier } from '@kit.ArkUI'
import {
  AppStrings,
  MANGA_RENDERING_DETECTION_BALANCED,
  MANGA_RENDERING_DETECTION_HIGH_RECALL,
  MANGA_RENDERING_INPAINTING_FAST,
  MANGA_RENDERING_INPAINTING_QUALITY,
  MangaRenderingServiceConfig,
  MangaRenderingServiceConnection,
  MangaRenderingServiceCredential,
  MangaRenderingServiceSecretStore,
  MangaRenderingServiceSettings,
  MangaRenderingServiceSettingsSnapshot,
  NextNGroupedListSection,
  NextNListRow,
  PageEmptyState,
  SecondaryListScaffold,
  ThemeTokens,
} from 'shared'

const CONNECTION_IDLE: string = 'idle'
const CONNECTION_RUNNING: string = 'running'
const CONNECTION_OK: string = 'ok'
const CONNECTION_FAILED: string = 'failed'

/**
 * Optional self-hosted Reader renderer. The entry and section ordering follow
 * NextE's dedicated manga-rendering-service destination; only persistence and
 * HDS row names differ in NextN.
 */
@ComponentV2
export struct MangaRenderingServiceSettingsPage {
  @Local loaded: boolean = false
  @Local saving: boolean = false
  @Local baseUrlDraft: string = ''
  @Local usernameDraft: string = ''
  @Local passwordDraft: string = ''
  @Local credentialDirty: boolean = false
  @Local configurationDirty: boolean = false
  @Local connectionState: string = CONNECTION_IDLE
  @Local errorMessage: string = ''
  @Local detectionProfile: string = MANGA_RENDERING_DETECTION_HIGH_RECALL
  @Local inpaintingProfile: string = MANGA_RENDERING_INPAINTING_QUALITY
  @Param scroller: Scroller = new Scroller()
  private storedCredential: MangaRenderingServiceCredential = new MangaRenderingServiceCredential()

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
    this.load()
  }

  aboutToDisappear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async load(): Promise<void> {
    this.loaded = false
    this.errorMessage = ''
    try {
      const snapshot: MangaRenderingServiceSettingsSnapshot =
        await MangaRenderingServiceSettings.load(this.context())
      this.storedCredential = await MangaRenderingServiceSecretStore.read(this.context())
      this.baseUrlDraft = snapshot.baseUrl
      this.usernameDraft = this.storedCredential.username
      this.passwordDraft = ''
      this.credentialDirty = false
      this.configurationDirty = false
      this.detectionProfile = snapshot.detectionProfile
      this.inpaintingProfile = snapshot.inpaintingProfile
      this.connectionState = CONNECTION_IDLE
    } catch (_error) {
      this.errorMessage = AppStrings.get('settings_manga_rendering_service_load_failed')
    } finally {
      this.loaded = true
    }
  }

  private markConfigurationChanged(): void {
    this.configurationDirty = true
    this.connectionState = CONNECTION_IDLE
    this.errorMessage = ''
  }

  private draftCredential(): MangaRenderingServiceCredential {
    // This is input validation only. `persistCheckedCandidate` assigns the
    // durable generation after the disabled settings snapshot has committed;
    // passing an absent record's revision 0 here would reject first setup.
    return MangaRenderingServiceCredential.account(this.usernameDraft, this.passwordDraft)
  }

  private effectiveCredential(): MangaRenderingServiceCredential {
    return this.credentialDirty ? this.draftCredential() : this.storedCredential.copy()
  }

  private candidate(enabled: boolean): MangaRenderingServiceSettingsSnapshot {
    const snapshot: MangaRenderingServiceSettingsSnapshot = new MangaRenderingServiceSettingsSnapshot()
    snapshot.baseUrl = MangaRenderingServiceConfig.validatedBaseUrl(this.baseUrlDraft)
    snapshot.detectionProfile = this.detectionProfile
    snapshot.inpaintingProfile = this.inpaintingProfile
    snapshot.enabled = enabled
    return snapshot
  }

  /** Persist a candidate disabled before network verification can make it selectable. */
  private async persistCheckedCandidate(): Promise<MangaRenderingServiceCredential> {
    let credential: MangaRenderingServiceCredential = this.effectiveCredential()
    if (!credential.configured()) {
      throw new Error('credential-required')
    }
    const snapshot: MangaRenderingServiceSettingsSnapshot = this.candidate(false)
    await MangaRenderingServiceSettings.save(this.context(), snapshot)
    if (this.credentialDirty) {
      // A first credential has generation 1; a retained cleared record is
      // advanced as well, so neither path can reuse prior sidecar output.
      const nextRevision: number = MangaRenderingServiceCredential.nextRevision(
        this.storedCredential.revision,
      )
      credential = MangaRenderingServiceCredential.withRevision(
        credential,
        nextRevision,
      )
      credential = await MangaRenderingServiceSecretStore.save(this.context(), credential)
      // HUKS now owns the newer cache generation. Re-publish the canonical
      // selection while the sidecar remains disabled; if this Preferences
      // write fails, the disabled first write above still prevents a later
      // stale sidecar selection.
      await MangaRenderingServiceSettings.save(this.context(), snapshot)
      this.storedCredential = credential.copy()
      this.passwordDraft = ''
      this.credentialDirty = false
    }
    this.baseUrlDraft = snapshot.baseUrl
    this.configurationDirty = false
    return credential
  }

  private async checkConnection(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true
    this.connectionState = CONNECTION_RUNNING
    this.errorMessage = ''
    try {
      const credential: MangaRenderingServiceCredential = await this.persistCheckedCandidate()
      await MangaRenderingServiceConnection.check(this.baseUrlDraft, credential)
      await MangaRenderingServiceSettings.save(this.context(), this.candidate(true))
      this.connectionState = CONNECTION_OK
    } catch (_error) {
      this.connectionState = CONNECTION_FAILED
      this.errorMessage = AppStrings.get('settings_manga_rendering_service_check_failed')
    } finally {
      this.saving = false
    }
  }

  private detectionProfileText(): string {
    return this.detectionProfile === MANGA_RENDERING_DETECTION_BALANCED
      ? AppStrings.get('settings_manga_rendering_service_detection_balanced')
      : AppStrings.get('settings_manga_rendering_service_detection_high_recall')
  }

  private inpaintingProfileText(): string {
    return this.inpaintingProfile === MANGA_RENDERING_INPAINTING_FAST
      ? AppStrings.get('settings_manga_rendering_service_inpainting_fast')
      : AppStrings.get('settings_manga_rendering_service_inpainting_quality')
  }

  private connectionSubtitle(): string {
    if (this.connectionState === CONNECTION_RUNNING) {
      return AppStrings.get('settings_manga_rendering_service_checking')
    }
    if (this.connectionState === CONNECTION_OK) {
      return AppStrings.get('settings_manga_rendering_service_check_success')
    }
    if (this.connectionState === CONNECTION_FAILED) {
      return AppStrings.get('settings_manga_rendering_service_check_failed')
    }
    return AppStrings.get('settings_manga_rendering_service_check_hint')
  }

  @Builder
  private RowDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeTokens.DIVIDER)
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  private DetectionProfileMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({
        content: AppStrings.get('settings_manga_rendering_service_detection_high_recall'),
        symbolEndIcon: this.detectionProfile === MANGA_RENDERING_DETECTION_HIGH_RECALL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        select((): void => {
          this.detectionProfile = MANGA_RENDERING_DETECTION_HIGH_RECALL
          this.markConfigurationChanged()
        })
      })
      MenuItem({
        content: AppStrings.get('settings_manga_rendering_service_detection_balanced'),
        symbolEndIcon: this.detectionProfile === MANGA_RENDERING_DETECTION_BALANCED
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        select((): void => {
          this.detectionProfile = MANGA_RENDERING_DETECTION_BALANCED
          this.markConfigurationChanged()
        })
      })
    }
  }

  @Builder
  private InpaintingProfileMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({
        content: AppStrings.get('settings_manga_rendering_service_inpainting_quality'),
        symbolEndIcon: this.inpaintingProfile === MANGA_RENDERING_INPAINTING_QUALITY
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        select((): void => {
          this.inpaintingProfile = MANGA_RENDERING_INPAINTING_QUALITY
          this.markConfigurationChanged()
        })
      })
      MenuItem({
        content: AppStrings.get('settings_manga_rendering_service_inpainting_fast'),
        symbolEndIcon: this.inpaintingProfile === MANGA_RENDERING_INPAINTING_FAST
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        select((): void => {
          this.inpaintingProfile = MANGA_RENDERING_INPAINTING_FAST
          this.markConfigurationChanged()
        })
      })
    }
  }

  @Builder
  private TextInputRow(label: string, field: string) {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Text(label)
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .width('100%')
      if (field === 'baseUrl') {
        TextInput({
          text: this.baseUrlDraft,
          placeholder: AppStrings.get('settings_manga_rendering_service_url_hint'),
        })
          .type(InputType.Normal)
          .width('100%')
          .height(48)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .backgroundColor(ThemeTokens.SURFACE_SUB)
          .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
          .onChange((value: string): void => {
            this.baseUrlDraft = value
            this.markConfigurationChanged()
          })
      } else if (field === 'username') {
        TextInput({ text: this.usernameDraft })
          .type(InputType.Normal)
          .width('100%')
          .height(48)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .backgroundColor(ThemeTokens.SURFACE_SUB)
          .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
          .onChange((value: string): void => {
            this.usernameDraft = value
            this.credentialDirty = true
            this.markConfigurationChanged()
          })
      } else {
        TextInput({
          text: this.passwordDraft,
          placeholder: this.storedCredential.configured()
            ? AppStrings.get('settings_manga_rendering_service_password_saved')
            : '',
        })
          .type(InputType.Password)
          .width('100%')
          .height(48)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .backgroundColor(ThemeTokens.SURFACE_SUB)
          .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
          .onChange((value: string): void => {
            this.passwordDraft = value
            this.credentialDirty = true
            this.markConfigurationChanged()
          })
      }
    }
    .width('100%')
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
      top: ThemeTokens.SPACE_SM,
      bottom: ThemeTokens.SPACE_SM,
    })
  }

  @Builder
  private ServiceFormGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.doc_plaintext_and_checkmark'),
        title: AppStrings.get('settings_manga_rendering_service_profile'),
        trailingText: AppStrings.get('settings_manga_rendering_service_profile_value'),
        showChevron: false,
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.character_viewfinder'),
        title: AppStrings.get('settings_manga_rendering_service_detection'),
        trailingText: this.detectionProfileText(),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: (select: (action: () => void) => void): void => {
          this.DetectionProfileMenu(select)
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.picture'),
        title: AppStrings.get('settings_manga_rendering_service_inpainting'),
        trailingText: this.inpaintingProfileText(),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: (select: (action: () => void) => void): void => {
          this.InpaintingProfileMenu(select)
        },
      })
      this.RowDivider()
      this.TextInputRow(AppStrings.get('settings_manga_rendering_service_url'), 'baseUrl')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('settings_manga_rendering_service_username'), 'username')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('settings_manga_rendering_service_password'), 'password')
    }
  }

  @Builder
  private ConnectionGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.checkmark_circle'),
        title: AppStrings.get('settings_manga_rendering_service_check'),
        subtitle: this.connectionSubtitle(),
        trailingText: this.saving ? AppStrings.get('common_loading') : '',
        showChevron: false,
        isEnabled: !this.saving,
        onAction: (): void => {
          this.checkConnection()
        },
      })
    }
  }

  build() {
    Column() {
      if (!this.loaded) {
        PageEmptyState({ message: AppStrings.get('common_loading') })
      } else {
        SecondaryListScaffold({
          scroller: this.scroller,
          bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
          alwaysEnableEdgeSpring: true,
        }) {
          ListItem() {
            this.ServiceFormGroup()
          }
          ListItem() {
            this.ConnectionGroup()
          }
          ListItem() {
            Text(AppStrings.get('settings_manga_rendering_service_security_hint'))
              .width('100%')
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
          }
          if (this.errorMessage.length > 0) {
            ListItem() {
              Text(this.errorMessage)
                .width('100%')
                .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                .fontColor(Color.Red)
                .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
            }
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE_SUB)
  }
}
