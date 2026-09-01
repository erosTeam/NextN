import { common } from '@kit.AbilityKit'
import { NhComment } from '../model/NhComment'
import { NhContentFilterRule, NhContentFilterType } from '../model/NhContentFilter'
import { NhGallerySummary } from '../model/NhGallery'
import { connectContentFilters, ContentFilterState } from '../state/ContentFilterState'
import { ContentFilterRepository } from '../storage/ContentFilterRepository'
import { NhCloudBlacklistService } from './NhCloudBlacklistService'
import { NhLocalUserTagService } from './NhLocalUserTagService'

/**
 * Matches ErosN's local block-rule semantics without changing remote queries:
 * explicit regex is opt-in; ordinary values are case-insensitive contains.
 */
export class ContentFilterService {
  private static writeTail: Promise<void> = Promise.resolve()
  private static idSequence: number = 0

  static async restore(context: common.UIAbilityContext): Promise<void> {
    const state: ContentFilterState = connectContentFilters()
    const rules: NhContentFilterRule[] = await ContentFilterRepository.load(context)
    state.rules = rules.map((rule: NhContentFilterRule): NhContentFilterRule => ContentFilterService.cloneRule(rule))
    state.isRestored = true
    state.revision += 1
  }

  static async save(context: common.UIAbilityContext, draft: NhContentFilterRule): Promise<void> {
    const rule: NhContentFilterRule = ContentFilterService.normalizedRule(draft)
    if (rule.text.length === 0) {
      throw new Error('Enter text to match')
    }
    if (rule.isRegex && !ContentFilterService.isRegexValid(rule.text)) {
      throw new Error('The regular expression is invalid')
    }
    if (rule.id.length === 0) {
      ContentFilterService.idSequence += 1
      rule.id = `${Date.now()}-${ContentFilterService.idSequence}`
    }
    await ContentFilterService.enqueueWrite((): Promise<void> => ContentFilterRepository.upsert(context, rule))
    const state: ContentFilterState = connectContentFilters()
    const next: NhContentFilterRule[] = state.rules.map((current: NhContentFilterRule): NhContentFilterRule => {
      return current.id === rule.id ? ContentFilterService.cloneRule(rule) : ContentFilterService.cloneRule(current)
    })
    if (!state.rules.some((current: NhContentFilterRule): boolean => current.id === rule.id)) {
      next.push(ContentFilterService.cloneRule(rule))
    }
    state.rules = next
    state.revision += 1
  }

  static async remove(context: common.UIAbilityContext, ruleId: string): Promise<void> {
    if (ruleId.length === 0) {
      return
    }
    await ContentFilterService.enqueueWrite((): Promise<void> => ContentFilterRepository.remove(context, ruleId))
    const state: ContentFilterState = connectContentFilters()
    state.rules = state.rules
      .filter((rule: NhContentFilterRule): boolean => rule.id !== ruleId)
      .map((rule: NhContentFilterRule): NhContentFilterRule => ContentFilterService.cloneRule(rule))
    state.revision += 1
  }

  static async setEnabled(context: common.UIAbilityContext, ruleId: string, enabled: boolean): Promise<void> {
    const state: ContentFilterState = connectContentFilters()
    const current: NhContentFilterRule | undefined = state.rules.find(
      (rule: NhContentFilterRule): boolean => rule.id === ruleId,
    )
    if (current === undefined) {
      return
    }
    const next: NhContentFilterRule = ContentFilterService.cloneRule(current)
    next.enabled = enabled
    await ContentFilterService.save(context, next)
  }

  static filterGalleries(
    galleries: NhGallerySummary[],
    ignoreLocalUserTagFiltering: boolean = false,
  ): NhGallerySummary[] {
    return galleries.filter((gallery: NhGallerySummary): boolean =>
      !ContentFilterService.isGalleryBlocked(gallery) &&
      !NhCloudBlacklistService.isGalleryCloudBlacklisted(gallery) &&
      !NhLocalUserTagService.isGalleryFiltered(gallery, ignoreLocalUserTagFiltering))
  }

  static filterComments(comments: NhComment[]): NhComment[] {
    return comments.filter((comment: NhComment): boolean => !ContentFilterService.isCommentBlocked(comment))
  }

  static isGalleryBlocked(gallery: NhGallerySummary): boolean {
    return ContentFilterService.matches(gallery.englishTitle, NhContentFilterType.TITLE) ||
      ContentFilterService.matches(gallery.japaneseTitle, NhContentFilterType.TITLE)
  }

  static isCommentBlocked(comment: NhComment): boolean {
    return ContentFilterService.matches(comment.posterName, NhContentFilterType.COMMENTER) ||
      ContentFilterService.matches(comment.body, NhContentFilterType.COMMENT)
  }

  static isRegexValid(value: string): boolean {
    try {
      new RegExp(value)
      return true
    } catch (_error) {
      return false
    }
  }

  private static matches(text: string, type: NhContentFilterType): boolean {
    const normalizedText: string = ContentFilterService.cleanText(text)
    if (normalizedText.length === 0) {
      return false
    }
    const rules: NhContentFilterRule[] = connectContentFilters().rules
    for (let index: number = 0; index < rules.length; index++) {
      const rule: NhContentFilterRule = rules[index]
      if (!rule.enabled || rule.type !== type) {
        continue
      }
      const value: string = ContentFilterService.cleanText(rule.text)
      if (value.length === 0) {
        continue
      }
      if (rule.isRegex) {
        try {
          if (new RegExp(value, 'i').test(normalizedText)) {
            return true
          }
        } catch (_error) {
          continue
        }
      } else if (normalizedText.toLowerCase().indexOf(value.toLowerCase()) >= 0) {
        return true
      }
    }
    return false
  }

  private static normalizedRule(value: NhContentFilterRule): NhContentFilterRule {
    const rule: NhContentFilterRule = ContentFilterService.cloneRule(value)
    rule.type = ContentFilterService.normalizeType(rule.type)
    rule.text = ContentFilterService.cleanText(rule.text)
    return rule
  }

  private static cloneRule(value: NhContentFilterRule): NhContentFilterRule {
    const rule: NhContentFilterRule = new NhContentFilterRule()
    rule.id = value.id
    rule.type = value.type
    rule.text = value.text
    rule.enabled = value.enabled
    rule.isRegex = value.isRegex
    return rule
  }

  private static normalizeType(value: NhContentFilterType): NhContentFilterType {
    if (value === NhContentFilterType.COMMENTER || value === NhContentFilterType.COMMENT) {
      return value
    }
    return NhContentFilterType.TITLE
  }

  private static cleanText(value: string): string {
    return value.replace(/[\u200B-\u200F\uFEFF]/g, '').trim().replace(/\s+/g, ' ')
  }

  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = ContentFilterService.writeTail.then(operation, operation)
    ContentFilterService.writeTail = queued.catch((): void => {})
    return queued
  }
}
