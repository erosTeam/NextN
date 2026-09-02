import {
  HdsListItemCard,
  PrefixCustomBuilder,
  PrefixImage,
  SuffixButton,
  SuffixCustomBuilder,
  SuffixSwitch,
  SuffixText,
  SuffixTextAndArrow,
} from '@kit.UIDesignKit'
import { ImageModifier, TextModifier } from '@kit.ArkUI'
import { appMenuOptions } from './AppMenuOptions'
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
  /** Reference-owned rows may expose a longer descriptive leaf. */
  @Param titleMaxLines: number = 1
  @Param subtitleMaxLines: number = 2
  @Param trailingText: string = ''
  /** An opt-in HDS suffix action. It leaves the row identity neutral. */
  @Param trailingActionText: string = ''
  @Param trailingActionDestructive: boolean = false
  @Param showChevron: boolean = true
  /** Use the standard down-triangle when this row opens a value menu. */
  @Param trailingDropdown: boolean = false
  @Param dropdownMenuEnabled: boolean = false
  @Param dropdownMenuDeferredOpen: boolean = false
  // Keep popup visibility beside the real suffix anchor; pages only provide menu content.
  @Local private dropdownMenuShown: boolean = false
  /** Use a caller-owned HDS suffix only for a reference-owned leaf shape. */
  @Param useCustomTrailing: boolean = false
  @BuilderParam customTrailing: () => void = this.EmptyTrailing
  @BuilderParam dropdownMenuBuilder: (select: (action: () => void) => void) => void =
    this.EmptyDropdownMenu
  /** Right inset of the wrapped custom suffix; rows may zero it when the suffix owns its padding. */
  @Param suffixPaddingRight: Dimension = ThemeTokens.SPACE_MD
  @Param hasSwitch: boolean = false
  @Param checked: boolean = false
  /** Navigational location marker, separate from a switch's checked state. */
  @Param selected: boolean = false
  @Param isEnabled: boolean = true
  @Param destructive: boolean = false
  @Param accessibilityLabel: string = ''
  /** Optional stable selector for a caller-owned native row; no spoken output. */
  @Param accessibilityId: string = ''
  @Event onAction?: () => void
  @Event dropdownMenuOpenAction?: (openMenu: () => void) => void
  @Event onTrailingAction?: () => void
  @Event onSwitchChange?: (value: boolean) => void

  private primaryTextModifier(): TextModifier {
    return new TextModifier()
      .textIndent(this.hasLeading() ? undefined : ThemeTokens.LIST_ROW_TEXT_INDENT)
      .fontSize(ThemeTokens.FONT_SIZE_LIST_ITEM)
      .fontWeight(FontWeight.Regular)
      .fontColor(this.destructive ? Color.Red : ThemeTokens.TEXT_PRIMARY)
      .maxLines(this.titleMaxLines)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private secondaryTextModifier(): TextModifier {
    return new TextModifier()
      .padding({ left: this.hasLeading() ? 0 : ThemeTokens.LIST_ROW_TEXT_INDENT })
      .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
      .fontColor(ThemeTokens.TEXT_SECONDARY)
      .maxLines(this.subtitleMaxLines)
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
    if (this.trailingActionText.length > 0) {
      label += `, ${this.trailingActionText}`
    } else if (this.trailingText.length > 0) {
      label += `, ${this.trailingText}`
    }
    if (this.destructive || this.trailingActionDestructive) {
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

  @Builder
  private EmptyTrailing() {}

  @Builder
  private EmptyDropdownMenu(_select: (action: () => void) => void) {}

  private selectDropdownItem(action: () => void): void {
    // Let the MenuItem click dispatch finish before removing the overlay. Closing it in the
    // active click handler can expose the row underneath to the same pointer event.
    setTimeout((): void => {
      this.dropdownMenuShown = false
      action()
    }, 0)
  }

  @Builder
  private BoundDropdownMenu() {
    this.dropdownMenuBuilder((action: () => void): void => {
      this.selectDropdownItem(action)
    })
  }

  @Builder
  private DropdownSuffixContent() {
    Text(this.trailingText)
      .fontSize(ThemeTokens.FONT_SIZE_BODY)
      .fontColor(ThemeTokens.TEXT_SECONDARY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    SymbolGlyph($r('sys.symbol.arrowtriangle_down_fill'))
      .fontSize(ThemeTokens.FONT_SIZE_TITLE)
      .fontColor([ThemeTokens.TEXT_TERTIARY])
      .padding({ left: ThemeTokens.SPACE_XS })
  }

  @Builder
  private DropdownSuffix() {
    if (this.dropdownMenuEnabled) {
      Row({ space: ThemeTokens.SPACE_XS }) {
        this.DropdownSuffixContent()
      }
      .alignItems(VerticalAlign.Center)
      .bindMenu(this.dropdownMenuShown, this.BoundDropdownMenu, appMenuOptions({
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.dropdownMenuShown = false
        },
      }))
    } else {
      Row({ space: ThemeTokens.SPACE_XS }) {
        this.DropdownSuffixContent()
      }
      .alignItems(VerticalAlign.Center)
    }
  }

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

  private suffixItem():
    | SuffixTextAndArrow
    | SuffixText
    | SuffixSwitch
    | SuffixButton
    | SuffixCustomBuilder
    | undefined {
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
    if (this.useCustomTrailing) {
      return new SuffixCustomBuilder((): void => {
        this.WrappedSuffixBuilder()
      })
    }
    if (this.trailingText.length > 0) {
      if (this.trailingDropdown) {
        return new SuffixCustomBuilder((): void => {
          this.DropdownSuffix()
        })
      }
      if (this.showChevron) {
        return new SuffixTextAndArrow(
          { text: this.trailingText, modifier: this.trailingTextModifier() },
          { color: Color.Gray },
        )
      }
      return new SuffixText({ text: this.trailingText, modifier: this.trailingTextModifier() })
    }
    if (this.trailingActionText.length > 0) {
      return new SuffixButton({
        text: this.trailingActionText,
        textColor: this.trailingActionDestructive ? Color.Red : ThemeTokens.BRAND,
        enable: this.isEnabled,
        onClick: (): void => {
          if (this.isEnabled && this.onTrailingAction) {
            this.onTrailingAction()
          }
        },
      })
    }
    if (this.showChevron) {
      return new SuffixTextAndArrow({ text: '' }, { color: Color.Gray })
    }
    return undefined
  }

  // Custom suffixes own only their internal left separation. HdsListItemCard
  // owns the common right inset for every suffix kind through cardSuffixMargin.
  @Builder
  private WrappedSuffixBuilder() {
    if (this.dropdownMenuEnabled) {
      Row() {
        this.customTrailing()
      }
      .padding({ left: ThemeTokens.SPACE_SM })
      .bindMenu(this.dropdownMenuShown, this.BoundDropdownMenu, appMenuOptions({
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.dropdownMenuShown = false
        },
      }))
    } else {
      Row() {
        this.customTrailing()
      }
      .padding({ left: ThemeTokens.SPACE_SM })
    }
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
        cardSuffixMargin: this.suffixPaddingRight,
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
          if (this.isEnabled) {
            if (this.dropdownMenuEnabled) {
              if (this.dropdownMenuDeferredOpen && this.dropdownMenuOpenAction) {
                this.dropdownMenuOpenAction((): void => {
                  this.dropdownMenuShown = true
                })
              } else {
                this.dropdownMenuShown = true
              }
            }
            if (this.onAction) {
              this.onAction()
            }
          }
        },
      })
    }
    .width('100%')
    .opacity(this.isEnabled ? 1.0 : 0.4)
    .id(this.accessibilityId)
    .accessibilityText(this.resolvedAccessibilityLabel())
  }
}
