import {
  HdsListItemCard,
  PrefixCustomBuilder,
  PrefixImage,
  SuffixSwitch,
  SuffixText,
  SuffixTextAndArrow,
} from '@kit.UIDesignKit'
import { ImageModifier, TextModifier } from '@kit.ArkUI'
import { ThemeTokens } from '../theme/ThemeTokens'

/**
 * One native HDS list row, following NextE's ConciseListRow contract.
 *
 * This intentionally avoids a Material-style icon tile, filled card, or
 * status chip. HDS owns hover/press and the platform row geometry; callers
 * only supply hierarchy and the action semantics.
 */
@ComponentV2
export struct NextNListRow {
  @Param leadingIcon: Resource | undefined = undefined
  // Keep NextE's HDS image-prefix path available for the small number of
  // identity rows that have an already-validated remote avatar. The regular
  // icon path remains the fallback so no page has to hand-roll list geometry.
  @Param leadingImageUrl: string = ''
  /** Use a caller-owned prefix only when a surface has a proven NextE-specific geometry. */
  @Param useCustomLeading: boolean = false
  @BuilderParam customLeading: () => void = this.EmptyLeading
  @Param title: string = ''
  @Param subtitle: string = ''
  @Param trailingText: string = ''
  @Param showChevron: boolean = true
  @Param hasSwitch: boolean = false
  @Param checked: boolean = false
  /** Navigational location marker, separate from a switch's checked state. */
  @Param selected: boolean = false
  @Param isEnabled: boolean = true
  @Param destructive: boolean = false
  @Param accessibilityLabel: string = ''
  @Event onAction?: () => void
  @Event onSwitchChange?: (value: boolean) => void

  private primaryTextModifier(): TextModifier {
    return new TextModifier()
      .textIndent(this.hasLeading() ? undefined : ThemeTokens.LIST_ROW_TEXT_INDENT)
      .fontSize(ThemeTokens.FONT_SIZE_LIST_ITEM)
      .fontWeight(FontWeight.Regular)
      .fontColor(this.destructive ? Color.Red : ThemeTokens.TEXT_PRIMARY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private secondaryTextModifier(): TextModifier {
    return new TextModifier()
      .padding({ left: this.hasLeading() ? 0 : ThemeTokens.LIST_ROW_TEXT_INDENT })
      .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
      .fontColor(ThemeTokens.TEXT_SECONDARY)
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private trailingTextModifier(): TextModifier {
    return new TextModifier()
      .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
      .fontColor(ThemeTokens.TEXT_SECONDARY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private resolvedAccessibilityLabel(): string {
    if (this.accessibilityLabel.length > 0) {
      return this.accessibilityLabel
    }
    let label: string = this.title.length > 0 ? this.title : 'List item'
    if (this.subtitle.length > 0) {
      label += `, ${this.subtitle}`
    }
    if (this.trailingText.length > 0) {
      label += `, ${this.trailingText}`
    }
    if (this.destructive) {
      label += ', destructive action'
    }
    if (!this.isEnabled) {
      label += ', unavailable'
    }
    return label
  }

  @Builder
  private IconPrefix() {
    Row() {
      if (this.leadingIcon !== undefined) {
        SymbolGlyph(this.leadingIcon)
          .fontSize(22)
          .fontColor([this.destructive ? Color.Red : ThemeTokens.TEXT_SECONDARY])
      }
    }
    .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_SM })
  }

  @Builder
  private EmptyLeading() {}

  private hasLeading(): boolean {
    return this.useCustomLeading || this.leadingIcon !== undefined || this.leadingImageUrl.length > 0
  }

  private normalizeImageUrl(): string {
    const source: string = this.leadingImageUrl.trim()
    if (source.startsWith('//')) {
      return `https:${source}`
    }
    return source
  }

  private prefixItem(): PrefixImage | PrefixCustomBuilder | undefined {
    if (this.useCustomLeading) {
      return new PrefixCustomBuilder((): void => {
        this.customLeading()
      })
    }
    if (this.leadingIcon === undefined) {
      const imageUrl: string = this.normalizeImageUrl()
      if (imageUrl.length > 0) {
        return new PrefixImage({
          image: imageUrl,
          modifier: new ImageModifier().alt($r('sys.media.ohos_app_icon')),
        })
      }
      return undefined
    }
    return new PrefixCustomBuilder(() => {
      this.IconPrefix()
    })
  }

  private suffixItem(): SuffixTextAndArrow | SuffixText | SuffixSwitch | undefined {
    if (this.hasSwitch) {
      return new SuffixSwitch({
        isCheck: this.checked,
        selectColor: ThemeTokens.BRAND,
        enable: this.isEnabled,
        onChange: (value: boolean): void => {
          if (this.isEnabled && this.onSwitchChange) {
            this.onSwitchChange(value)
          }
        },
      })
    }
    if (this.trailingText.length > 0) {
      if (this.showChevron) {
        return new SuffixTextAndArrow(
          { text: this.trailingText, modifier: this.trailingTextModifier() },
          { color: Color.Gray },
        )
      }
      return new SuffixText({ text: this.trailingText, modifier: this.trailingTextModifier() })
    }
    if (this.showChevron) {
      return new SuffixTextAndArrow({ text: '' }, { color: Color.Gray })
    }
    return undefined
  }

  build() {
    Column() {
      HdsListItemCard({
        textItem: {
          primaryText: { text: this.title, modifier: this.primaryTextModifier() },
          secondaryText: this.subtitle.length > 0
            ? { text: this.subtitle, modifier: this.secondaryTextModifier() }
            : undefined,
        },
        cardPrefixMargin: 0,
        cardSuffixMargin: 0,
        prefixItem: this.prefixItem(),
        suffixItem: this.suffixItem(),
        cardBackgroundColor: this.selected
          ? $r('app.color.navigation_item_selected')
          : Color.Transparent,
        cardBorderRadius: ThemeTokens.LIST_ROW_RADIUS,
        hoverBorderRadius: ThemeTokens.LIST_ROW_RADIUS,
        enable: this.isEnabled,
        accessibilityOptions: {
          accessibilitySelected: this.selected,
        },
        onClick: (): void => {
          if (this.isEnabled && this.onAction) {
            this.onAction()
          }
        },
      })
    }
    .width('100%')
    .opacity(this.isEnabled ? 1.0 : 0.4)
    .accessibilityText(this.resolvedAccessibilityLabel())
  }
}
