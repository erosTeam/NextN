import {
  ContentFilterService,
  ContentFilterState,
  AppStrings,
  BasicDataSource,
  COMMENT_TRANSLATION_DISPLAY_BILINGUAL,
  COMMENT_TRANSLATION_PRIORITY_AUTO,
  COMMENT_TRANSLATION_PRIORITY_INTERACTIVE,
  CommentTranslationService,
  CommentTranslationSettingsState,
  InlineRetryNotice,
  LayoutSafeAreaState,
  NhApiClient,
  AccountSessionState,
  NhComment,
  LlmSourceProfilesState,
  NextNPullRefreshController,
  PageEmptyState,
  PageErrorState,
  PageLoadingState,
  PullRefreshListScaffold,
  ThemeTokens,
  connectAccountSession,
  connectCommentTranslationSettings,
  connectContentFilters,
  connectLayoutSafeArea,
  connectLlmSourceProfiles,
  nextNHdsTitle,
  supportsCommentTranslation,
} from 'shared'
import { common } from '@kit.AbilityKit'
import { KeyboardAvoidMode, uiMaterial } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { GalleryCommentCard } from '../components/GalleryCommentCard'

const COMMENT_COMPOSER_FIELD_ID: string = 'nextn-gallery-comments-composer-field'
const COMMENT_COMPOSER_BOTTOM_RESERVE: number = 136
const COMMENT_COMPOSER_OUTER_GAP: number = ThemeTokens.SPACE_SM
const COMMENT_COMPOSER_INNER_GAP: number = ThemeTokens.SPACE_XS
const COMMENT_COMPOSER_SEND_SIZE: number = 36
const COMMENT_COMPOSER_CLOSE_ICON_SIZE: number =
  COMMENT_COMPOSER_SEND_SIZE - COMMENT_COMPOSER_INNER_GAP * 2
const COMMENT_COMPOSER_RADIUS: number = COMMENT_COMPOSER_SEND_SIZE / 2 + COMMENT_COMPOSER_INNER_GAP
const COMMENT_COMPOSER_INPUT_MAX_H: number = 148
const COMMENT_COMPOSER_QUOTE_LINE_WIDTH: number = 4
const COMMENT_COMPOSER_QUOTE_LINE_HEIGHT: number = 48

/**
 * The single source of truth for one comment's reactive translation fields
 * (NextE GalleryCommentRenderState parity, NH field subset): a @Trace write
 * re-renders exactly the one card holding this state. The page never
 * publishes array snapshots — the @ObservedV2 object IS the update channel.
 */
@ObservedV2
export class CommentTranslationRenderState {
  @Trace commentId: number = 0
  @Trace translated: string = ''
  @Trace shown: boolean = false
  @Trace loading: boolean = false
  @Trace autoStarted: boolean = false
  @Trace failed: boolean = false
}

/**
 * One resolved reply reference. The immutable display leaves may be prepared
 * by the page, but the card keeps the real comment identity and reads its live
 * render state when building the quote body.
 */
export class GalleryCommentReplyReference {
  comment: NhComment = new NhComment()
  body: string = ''
  emphasizedMentions: string[] = []
}

/**
 * A separate destination keeps comments from competing with the Gallery hero
 * and Read action. The HDS owns the destination title while this page owns
 * one pull-to-refresh list and its persistent bottom composer.
 */
@ComponentV2
export struct GalleryCommentsPage {
  @Require @Param galleryId: number
  @Local comments: NhComment[] = []
  /** Retain the returned discussion so local rules reapply without a request. */
  @Local rawComments: NhComment[] = []
  @Local contentFilters: ContentFilterState = connectContentFilters()
  @Local accountSession: AccountSessionState = connectAccountSession()
  @Local sources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local commentTranslationSettings: CommentTranslationSettingsState = connectCommentTranslationSettings()
  @Local loadedGalleryId: number = 0
  @Local isLoading: boolean = false
  @Local errorMessage: string = ''
  @Local commentText: string = ''
  @Local replyTargetId: number = 0
  @Local replyTargetAuthor: string = ''
  @Local replyTargetPreview: string = ''
  @Local isCommentSubmitting: boolean = false
  @Local commentSubmitError: string = ''
  /** Per-comment render states (NextE renderStateMap parity). */
  private renderStateMap: Map<number, CommentTranslationRenderState> = new Map()
  /**
   * Stable all-comment state references consumed directly by quote builders.
   * This is the reactive dependency path used by current NextE: a referenced
   * row's @Trace write invalidates both that row and every mounted quote that
   * reads the same state object.
   */
  private referenceRenderStates: CommentTranslationRenderState[] = []
  /** Stable LazyForEach owner; only mounted comment cards may start automatic work. */
  private commentDataSource: BasicDataSource<NhComment> = new BasicDataSource<NhComment>(
    (comment: NhComment): string => comment.commentId.toString(),
  )
  @Param scroller: Scroller = new Scroller()
  /** A Detail-owned response seeds this route only after it was successfully fetched. */
  @Param commentSnapshot: NhComment[] = []
  @Param commentSnapshotAvailable: boolean = false
  private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private requestGeneration: number = 0
  private commentSubmitGeneration: number = 0
  private refreshController: NextNPullRefreshController = new NextNPullRefreshController()

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
    if (this.hydrateDetailSnapshot()) {
      return
    }
    if (!this.isLoading && this.loadedGalleryId !== this.galleryId) {
      this.loadComments()
    }
  }

  aboutToDisappear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
  }

  @Monitor('galleryId')
  onGalleryChanged(): void {
    if (this.hydrateDetailSnapshot()) {
      return
    }
    if (!this.isLoading && this.loadedGalleryId !== this.galleryId) {
      this.loadComments()
    }
  }

  @Monitor('contentFilters.revision')
  onContentFiltersChanged(): void {
    this.applyContentFilters()
  }

  private applyContentFilters(): void {
    this.comments = ContentFilterService.filterComments(this.rawComments)
    this.commentDataSource.setData(this.comments)
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  /**
   * A Detail-owned snapshot is authoritative for this initial route only. It
   * is allowed to be empty: availability distinguishes an empty successful
   * response from a request that has not completed. Subsequent explicit
   * refreshes still use the full route request path.
   */
  private hydrateDetailSnapshot(): boolean {
    if (!this.commentSnapshotAvailable || this.loadedGalleryId === this.galleryId) {
      return false
    }
    this.requestGeneration += 1
    this.rawComments = this.commentSnapshot.slice()
    this.rebuildRenderStates(true)
    this.applyContentFilters()
    this.loadedGalleryId = this.galleryId
    this.errorMessage = ''
    this.isLoading = false
    return true
  }

  private hasPublishedAccountSession(): boolean {
    return this.accountSession.initialized && this.accountSession.signedIn
  }

  private commentTranslationConfigured(): boolean {
    const binding = this.sources.commentBinding
    if (!binding.configured()) {
      return false
    }
    const profile = this.sources.findById(binding.sourceProfileId)
    return profile !== null && supportsCommentTranslation(profile)
  }

  /**
   * Rebuilds render states from the current raw comments (NextE
   * rebuildCommentList parity): resetStates keeps nothing (fresh route /
   * refresh); otherwise existing states survive so in-flight translations and
   * shown-toggles are never discarded by a filter change.
   */
  private rebuildRenderStates(resetStates: boolean): void {
    const next: Map<number, CommentTranslationRenderState> = new Map()
    const nextStates: CommentTranslationRenderState[] = []
    for (let index: number = 0; index < this.rawComments.length; index++) {
      const comment: NhComment = this.rawComments[index]
      const existing: CommentTranslationRenderState | undefined = resetStates
        ? undefined
        : this.renderStateMap.get(comment.commentId)
      if (existing !== undefined) {
        next.set(comment.commentId, existing)
        nextStates.push(existing)
      } else {
        const state: CommentTranslationRenderState = new CommentTranslationRenderState()
        state.commentId = comment.commentId
        next.set(comment.commentId, state)
        nextStates.push(state)
      }
    }
    this.renderStateMap = next
    this.referenceRenderStates = nextStates
  }

  /** List builder lookup; the map is rebuilt before the list renders. */
  private renderStateFor(comment: NhComment): CommentTranslationRenderState {
    const existing: CommentTranslationRenderState | undefined = this.renderStateMap.get(comment.commentId)
    if (existing !== undefined) {
      return existing
    }
    const state: CommentTranslationRenderState = new CommentTranslationRenderState()
    state.commentId = comment.commentId
    this.renderStateMap.set(comment.commentId, state)
    return state
  }

  /**
   * All reactive translation mutations go through this one writer (NextE
   * applyCommentTranslationState parity): fields are written SYNCHRONOUSLY
   * onto the per-comment @ObservedV2 state; the @Trace write re-renders that
   * one card. No array slice, no global version bump.
   */
  private applyCommentTranslationState(
    commentId: number,
    translated: string | undefined,
    shown: boolean | undefined,
    loading: boolean | undefined,
    autoStarted: boolean | undefined = undefined,
    failed: boolean | undefined = undefined,
  ): void {
    const state: CommentTranslationRenderState | undefined = this.renderStateMap.get(commentId)
    if (state === undefined) {
      return
    }
    if (translated !== undefined) {
      state.translated = translated
    }
    if (shown !== undefined) {
      state.shown = shown
    }
    if (loading !== undefined) {
      state.loading = loading
    }
    if (autoStarted !== undefined) {
      state.autoStarted = autoStarted
    }
    if (failed !== undefined) {
      state.failed = failed
    }
  }

  private canTranslate(comment: NhComment): boolean {
    return this.commentTranslationSettings.enabled &&
      this.commentTranslationConfigured() &&
      this.replyBody(comment).trim().length > 0
  }

  private replyReferencesFor(comment: NhComment): GalleryCommentReplyReference[] {
    const references: NhComment[] = this.replyReferences(comment)
    const resolved: GalleryCommentReplyReference[] = []
    for (let index: number = 0; index < references.length; index += 1) {
      const reference: NhComment = references[index]
      const item: GalleryCommentReplyReference = new GalleryCommentReplyReference()
      item.comment = reference
      const body: string = this.replyBody(reference)
      item.body = body.length > 0 ? body : AppStrings.get('comments_empty_body')
      item.emphasizedMentions = this.replyMentionLabels(reference)
      resolved.push(item)
    }
    return resolved
  }

  private matchedMentionLength(comment: NhComment, segment: string): number {
    const targetId: number = this.replyReferenceTargetId(segment)
    if (targetId > 0) {
      const target: NhComment | null = this.commentById(targetId)
      if (target !== null) {
        const targetNameLength: number = this.matchedAuthorNameLength(
          this.authorLabel(target),
          segment,
        )
        if (targetNameLength > 0) {
          return targetNameLength + 1
        }
      }
    }
    const nameLength: number = this.matchedMentionNameLength(this.candidateComments(comment), segment)
    return nameLength > 0 ? nameLength + 1 : 0
  }

  private replyMentionLabels(comment: NhComment): string[] {
    const labels: string[] = []
    const visibleBody: string = this.replyBody(comment)
    const segments: string[] = visibleBody.split('@')
    for (let index: number = 1; index < segments.length; index += 1) {
      const segment: string = `@${segments[index]}`
      const length: number = this.matchedMentionLength(comment, segment)
      const label: string = length > 1 ? segment.substring(0, length) : ''
      if (label.length === 0 || labels.includes(label)) {
        continue
      }
      labels.push(label)
    }
    return labels
  }

  private translationSourceText(comment: NhComment): string {
    const source: string = this.replyBody(comment)
    let protectedSource: string = ''
    let cursor: number = 0
    while (cursor < source.length) {
      const at: number = source.indexOf('@', cursor)
      if (at < 0) {
        protectedSource += source.substring(cursor)
        break
      }
      protectedSource += source.substring(cursor, at)
      const length: number = this.matchedMentionLength(comment, source.substring(at))
      if (length > 1) {
        protectedSource += CommentTranslationService.protectMentionText(
          source.substring(at, at + length),
        )
        cursor = at + length
      } else {
        protectedSource += '@'
        cursor = at + 1
      }
    }
    return protectedSource
  }

  private isTranslationShown(comment: NhComment): boolean {
    const state: CommentTranslationRenderState | undefined = this.renderStateMap.get(comment.commentId)
    return state !== undefined && state.shown && this.commentTranslationSettings.enabled &&
      state.translated.length > 0
  }

  private isTranslationLoading(comment: NhComment): boolean {
    const state: CommentTranslationRenderState | undefined = this.renderStateMap.get(comment.commentId)
    return state !== undefined && state.loading
  }

  /** NextE parity: one mounted LazyForEach card owns one automatic attempt. */
  private autoTranslateComment(comment: NhComment): void {
    if (!this.commentTranslationSettings.enabled || !this.commentTranslationSettings.autoTranslate ||
      !this.canTranslate(comment)) {
      return
    }
    const state: CommentTranslationRenderState = this.renderStateFor(comment)
    if (state.autoStarted || state.loading || state.translated.length > 0) {
      return
    }
    const source: string = this.translationSourceText(comment)
    if (source.trim().length === 0 || !CommentTranslationService.needsTranslation(source)) {
      return
    }
    this.applyCommentTranslationState(comment.commentId, undefined, undefined, undefined, true, false)
    this.toggleOrTranslate(comment, COMMENT_TRANSLATION_PRIORITY_AUTO)
  }

  private autoTranslateReplyReferences(comment: NhComment): void {
    const references: NhComment[] = this.replyReferences(comment)
    for (let index: number = 0; index < references.length; index += 1) {
      this.autoTranslateComment(references[index])
    }
  }

  private ensureReplyReferencesTranslated(comment: NhComment): void {
    const references: NhComment[] = this.replyReferences(comment)
    for (let index: number = 0; index < references.length; index += 1) {
      this.ensureCommentTranslation(references[index])
    }
  }

  private ensureCommentTranslation(comment: NhComment): void {
    if (!this.canTranslate(comment)) {
      return
    }
    const state: CommentTranslationRenderState = this.renderStateFor(comment)
    if (state.loading) {
      return
    }
    if (state.translated.length > 0) {
      if (!state.shown) {
        this.applyCommentTranslationState(comment.commentId, undefined, true, false, undefined, false)
      }
      return
    }
    this.toggleOrTranslate(comment, COMMENT_TRANSLATION_PRIORITY_INTERACTIVE)
  }

  private translationActionLabel(comment: NhComment): string {
    return this.isTranslationShown(comment)
      ? AppStrings.get('comments_translation_show_original')
      : AppStrings.get('comments_translation_action')
  }

  private async toggleOrTranslate(
    comment: NhComment,
    priority: number = COMMENT_TRANSLATION_PRIORITY_INTERACTIVE,
  ): Promise<void> {
    if (!this.canTranslate(comment)) {
      return
    }
    const state: CommentTranslationRenderState = this.renderStateFor(comment)
    if (state.loading) {
      return
    }
    if (state.translated.length > 0) {
      this.applyCommentTranslationState(comment.commentId, undefined, !state.shown, undefined)
      return
    }
    const galleryId: number = this.galleryId
    this.applyCommentTranslationState(comment.commentId, undefined, undefined, true, undefined, false)
    try {
      const translated: string = await CommentTranslationService.translate(
        this.context(),
        this.translationSourceText(comment),
        priority,
      )
      if (this.galleryId === galleryId && this.loadedGalleryId === galleryId) {
        this.applyCommentTranslationState(
          comment.commentId,
          translated,
          translated.length > 0,
          false,
          undefined,
          false,
        )
      } else {
        this.applyCommentTranslationState(comment.commentId, undefined, undefined, false)
      }
    } catch (_error) {
      const error: Error = _error as Error
      if (priority === COMMENT_TRANSLATION_PRIORITY_AUTO && CommentTranslationService.isQueueCapacityError(error)) {
        // Queue-evicted background work stays untranslated without a toast (NextE parity).
        this.applyCommentTranslationState(comment.commentId, undefined, undefined, false, undefined, false)
        return
      }
      this.applyCommentTranslationState(comment.commentId, undefined, undefined, false, undefined, true)
    }
  }

  private isCurrentRequest(generation: number): boolean {
    return generation === this.requestGeneration
  }

  private async loadComments(): Promise<void> {
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    if (this.loadedGalleryId !== this.galleryId) {
      this.rawComments = []
      this.rebuildRenderStates(true)
      this.applyContentFilters()
      this.loadedGalleryId = 0
    }
    this.isLoading = true
    this.errorMessage = ''
    try {
      const comments: NhComment[] = await NhApiClient.comments(this.galleryId)
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.rawComments = comments
      this.rebuildRenderStates(true)
      this.applyContentFilters()
      this.loadedGalleryId = this.galleryId
    } catch (_error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      // Transport, lifecycle and protocol details are diagnostics, never user
      // copy. The page owns one localized recovery state with an explicit
      // retry action regardless of the lower-layer failure classification.
      this.errorMessage = AppStrings.get('comments_error_load')
    } finally {
      if (this.isCurrentRequest(generation)) {
        this.isLoading = false
      }
    }
  }

  private authorLabel(comment: NhComment): string {
    return comment.posterName.length > 0 ? comment.posterName : AppStrings.get('comments_author_anonymous')
  }

  private twoDigits(value: number): string {
    return value < 10 ? `0${value}` : value.toString()
  }

  private postedLabel(comment: NhComment): string {
    if (comment.postDate <= 0) {
      return ''
    }
    const date: Date = new Date(comment.postDate * 1000)
    if (isNaN(date.getTime())) {
      return ''
    }
    return `${date.getFullYear()}-${this.twoDigits(date.getMonth() + 1)}-${this.twoDigits(date.getDate())} ` +
      `${this.twoDigits(date.getHours())}:${this.twoDigits(date.getMinutes())}`
  }

  private replyCodeForDigit(digit: string): string {
    if (digit === '0') return '····'
    if (digit === '1') return '···-'
    if (digit === '2') return '··-·'
    if (digit === '3') return '··--'
    if (digit === '4') return '·-··'
    if (digit === '5') return '·-·-'
    if (digit === '6') return '·--·'
    if (digit === '7') return '·---'
    if (digit === '8') return '-···'
    if (digit === '9') return '-··-'
    return ''
  }

  private replyDigitForCode(code: string): string {
    if (code === '····') return '0'
    if (code === '···-') return '1'
    if (code === '··-·') return '2'
    if (code === '··--') return '3'
    if (code === '·-··') return '4'
    if (code === '·-·-') return '5'
    if (code === '·--·') return '6'
    if (code === '·---') return '7'
    if (code === '-···') return '8'
    if (code === '-··-') return '9'
    return ''
  }

  private encodeReplyId(commentId: number): string {
    const id: string = commentId.toString()
    let encoded: string = ''
    for (let index: number = 0; index < id.length; index += 1) {
      const code: string = this.replyCodeForDigit(id.charAt(index))
      if (code.length === 0) {
        return ''
      }
      encoded += code
    }
    return encoded
  }

  private decodeReplyId(line: string): number {
    let normalized: string = ''
    for (let index: number = 0; index < line.length; index += 1) {
      const character: string = line.charAt(index)
      if (character === '·' || character === '.') {
        normalized += '·'
      } else if (character === '-') {
        normalized += '-'
      }
    }
    if (normalized.length === 0 || normalized.length % 4 !== 0) {
      return 0
    }
    let decoded: string = ''
    for (let index: number = 0; index < normalized.length; index += 4) {
      const digit: string = this.replyDigitForCode(normalized.substring(index, index + 4))
      if (digit.length === 0) {
        return 0
      }
      decoded += digit
    }
    const value: number = Number.parseInt(decoded, 10)
    return Number.isNaN(value) || value <= 0 ? 0 : value
  }

  private hashReplyId(line: string): number {
    const start: number = line.indexOf('#')
    if (start < 0) {
      return 0
    }
    const end: number = line.indexOf('#', start + 1)
    if (end <= start + 1) {
      return 0
    }
    const value: number = Number.parseInt(line.substring(start + 1, end), 10)
    return Number.isNaN(value) || value <= 0 ? 0 : value
  }

  private commentIdNum(comment: NhComment): number {
    return comment.commentId
  }

  private sortedComments(): NhComment[] {
    const sorted: NhComment[] = this.rawComments.slice()
    sorted.sort((first: NhComment, second: NhComment): number =>
      this.commentIdNum(second) - this.commentIdNum(first))
    return sorted
  }

  private candidateComments(comment: NhComment): NhComment[] {
    const sorted: NhComment[] = this.sortedComments()
    for (let index: number = 0; index < sorted.length; index += 1) {
      if (sorted[index].commentId === comment.commentId) {
        return sorted.slice(index)
      }
    }
    return []
  }

  private commentById(commentId: number): NhComment | null {
    for (let index: number = 0; index < this.rawComments.length; index += 1) {
      const candidate: NhComment = this.rawComments[index]
      if (candidate.commentId === commentId) {
        return candidate
      }
    }
    return null
  }

  private mentionTail(segment: string): string {
    const at: number = segment.indexOf('@')
    return at >= 0 ? segment.substring(at + 1).trim() : ''
  }

  private isNameSeparator(character: string): boolean {
    return character === ' ' || character === '\n' || character === '\t' || character === '\r' ||
      character === '+' || character === ',' || character === '.' || character === '，' || character === '。'
  }

  private nameParts(text: string): string[] {
    const parts: string[] = []
    let current: string = ''
    for (let index: number = 0; index < text.length; index += 1) {
      const character: string = text.charAt(index)
      if (this.isNameSeparator(character)) {
        if (current.length > 0) {
          parts.push(current)
          current = ''
        }
      } else {
        current += character
      }
    }
    if (current.length > 0) {
      parts.push(current)
    }
    return parts
  }

  private normalizedName(name: string): string {
    return this.nameParts(name).join(' ')
  }

  private findBySpaceAuthor(candidates: NhComment[], segment: string): NhComment | null {
    const parts: string[] = this.nameParts(this.mentionTail(segment))
    for (let count: number = parts.length; count > 0; count -= 1) {
      const author: string = parts.slice(0, count).join(' ')
      for (let index: number = 0; index < candidates.length; index += 1) {
        if (this.normalizedName(this.authorLabel(candidates[index])) === author) {
          return candidates[index]
        }
      }
    }
    return null
  }

  private namePartsPrefixLength(text: string, count: number): number {
    let seen: number = 0
    let inPart: boolean = false
    for (let index: number = 0; index < text.length; index += 1) {
      if (this.isNameSeparator(text.charAt(index))) {
        if (inPart) {
          seen += 1
          inPart = false
          if (seen === count) {
            return index
          }
        }
      } else {
        inPart = true
      }
    }
    if (inPart) {
      seen += 1
      if (seen === count) {
        return text.length
      }
    }
    return 0
  }

  private matchedMentionNameLength(candidates: NhComment[], segment: string): number {
    const tail: string = this.mentionTail(segment)
    const parts: string[] = this.nameParts(tail)
    for (let count: number = parts.length; count > 0; count -= 1) {
      const name: string = parts.slice(0, count).join(' ')
      for (let index: number = 0; index < candidates.length; index += 1) {
        if (this.normalizedName(this.authorLabel(candidates[index])) === name) {
          return this.namePartsPrefixLength(tail, count)
        }
      }
    }
    return 0
  }

  private matchedAuthorNameLength(author: string, segment: string): number {
    const authorParts: string[] = this.nameParts(author)
    if (authorParts.length === 0) {
      return 0
    }
    const tail: string = this.mentionTail(segment)
    const prefixLength: number = this.namePartsPrefixLength(tail, authorParts.length)
    if (prefixLength <= 0) {
      return 0
    }
    return this.normalizedName(tail.substring(0, prefixLength)) === this.normalizedName(author)
      ? prefixLength
      : 0
  }

  private replyReferenceTargetId(segment: string): number {
    const hashId: number = this.hashReplyId(segment)
    if (hashId > 0) {
      return hashId
    }
    const lines: string[] = segment.split('\n')
    return lines.length >= 2 ? this.decodeReplyId(lines[1]) : 0
  }

  private pushReply(replies: NhComment[], comment: NhComment, reply: NhComment | null): void {
    if (reply === null || reply.commentId <= 0 || reply.commentId === comment.commentId) {
      return
    }
    for (let index: number = 0; index < replies.length; index += 1) {
      if (replies[index].commentId === reply.commentId) {
        return
      }
    }
    replies.push(reply)
  }

  private replyReferences(comment: NhComment): NhComment[] {
    const segments: string[] = comment.body.split('@')
    const candidates: NhComment[] = this.candidateComments(comment)
    const replies: NhComment[] = []
    for (let index: number = 1; index < segments.length; index += 1) {
      const segment: string = `@${segments[index]}`
      const targetId: number = this.replyReferenceTargetId(segment)
      if (targetId > 0) {
        this.pushReply(replies, comment, this.commentById(targetId))
        continue
      }
      this.pushReply(replies, comment, this.findBySpaceAuthor(candidates, segment))
    }
    return replies
  }

  private replyBody(comment: NhComment): string {
    if (this.replyReferences(comment).length === 0) {
      return comment.body
    }
    const lines: string[] = comment.body.split('\n')
    if (lines.length === 0 || !lines[0].trim().startsWith('@')) {
      return comment.body
    }
    if (this.hashReplyId(lines[0]) > 0) {
      return lines.slice(1).join('\n').trim()
    }
    if (lines.length > 1 && this.decodeReplyId(lines[1]) > 0) {
      return lines.slice(2).join('\n').trim()
    }
    return comment.body
  }

  private replyPlaceholder(): string {
    return this.replyTargetId > 0
      ? AppStrings.get('comments_reply_placeholder')
      : AppStrings.get('comments_placeholder')
  }

  private hasReplyContext(): boolean {
    return this.replyTargetId > 0 && this.replyTargetAuthor.length > 0
  }

  private replyContextTitle(): string {
    return AppStrings.format('comments_replying_to', [this.replyTargetAuthor])
  }

  private openReply(comment: NhComment): void {
    if (this.isCommentSubmitting) {
      return
    }
    if (!this.hasPublishedAccountSession()) {
      this.showCommentToast(AppStrings.get('comments_error_signin_post'))
      return
    }
    const prefix: string = this.encodeReplyId(comment.commentId)
    if (prefix.length === 0) {
      return
    }
    this.replyTargetId = comment.commentId
    this.replyTargetAuthor = this.authorLabel(comment)
    this.replyTargetPreview = this.replyBody(comment)
    this.commentText = `@${this.replyTargetAuthor}\n${prefix}\n`
    this.commentSubmitError = ''
    this.requestComposerFocus()
  }

  private clearReplyContext(): void {
    this.replyTargetId = 0
    this.replyTargetAuthor = ''
    this.replyTargetPreview = ''
    this.commentText = ''
    this.commentSubmitError = ''
  }

  private canSubmitComment(): boolean {
    return this.composerInteractionAvailable() && this.hasCommentMessage() && !this.isCommentSubmitting
  }

  private hasCommentMessage(): boolean {
    if (!this.hasReplyContext()) {
      return this.commentText.trim().length > 0
    }
    return this.commentText.split('\n').slice(2).join('\n').trim().length > 0
  }

  /** The composer stays mounted; this gate controls only mutation interaction. */
  private composerInteractionAvailable(): boolean {
    return this.hasPublishedAccountSession() && !this.isLoading && this.loadedGalleryId === this.galleryId
  }

  /** A successful empty snapshot is resolved; only a missing route result is initial. */
  private initialCommentsResolutionPending(): boolean {
    return this.loadedGalleryId !== this.galleryId
  }

  private requestComposerFocus(): void {
    if (this.isCommentSubmitting) {
      return
    }
    if (!this.hasPublishedAccountSession()) {
      this.showCommentToast(AppStrings.get('comments_error_signin_post'))
      return
    }
    this.commentSubmitError = ''
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus(COMMENT_COMPOSER_FIELD_ID)
    }, 80)
  }

  private async submitComment(): Promise<void> {
    if (!this.canSubmitComment()) {
      return
    }
    const generation: number = this.commentSubmitGeneration + 1
    const galleryId: number = this.galleryId
    this.commentSubmitGeneration = generation
    this.isCommentSubmitting = true
    this.commentSubmitError = ''
    try {
      const comment: NhComment | null = await NhApiClient.postComment(galleryId, this.commentText)
      if (generation !== this.commentSubmitGeneration || galleryId !== this.galleryId) {
        return
      }
      if (comment !== null) {
        this.rawComments = [comment, ...this.rawComments.filter((item: NhComment): boolean => item.commentId !== comment.commentId)]
        this.rebuildRenderStates(false)
        this.applyContentFilters()
      } else {
        // The remote mutation is already confirmed. A normal GET refresh is
        // safe here and avoids guessing the created record or replaying POST.
        this.loadComments()
      }
      this.clearReplyContext()
      this.showCommentToast(AppStrings.get('comments_toast_posted'))
    } catch (_error) {
      if (generation === this.commentSubmitGeneration && galleryId === this.galleryId) {
        this.commentSubmitError = AppStrings.get('comments_error_post')
      }
    } finally {
      if (generation === this.commentSubmitGeneration && galleryId === this.galleryId) {
        this.isCommentSubmitting = false
      }
    }
  }

  private showCommentToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_error) {}
  }

  private composerBottomPadding(): number {
    if (this.layoutSafeArea.keyboardHeight > 0) {
      return ThemeTokens.SPACE_SM
    }
    return this.layoutSafeArea.bottomAvoidHeight
  }

  @Builder
  private CommentComposerFields() {
    Column({ space: COMMENT_COMPOSER_INNER_GAP }) {
      if (this.hasReplyContext()) {
        Row({ space: ThemeTokens.SPACE_SM }) {
          Blank()
            .width(COMMENT_COMPOSER_QUOTE_LINE_WIDTH)
            .height(COMMENT_COMPOSER_QUOTE_LINE_HEIGHT)
            .backgroundColor(ThemeTokens.BRAND)
            .borderRadius(COMMENT_COMPOSER_QUOTE_LINE_WIDTH / 2)
          Column({ space: ThemeTokens.SPACE_XS }) {
            Text(this.replyContextTitle())
              .width('100%')
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeTokens.TEXT_LINK)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.replyTargetPreview)
              .width('100%')
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(COMMENT_COMPOSER_CLOSE_ICON_SIZE)
              .fontColor([ThemeTokens.TEXT_SECONDARY])
          }
          .width(COMMENT_COMPOSER_SEND_SIZE)
          .height(COMMENT_COMPOSER_SEND_SIZE)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .backgroundColor(Color.Transparent)
          .accessibilityText(AppStrings.get('common_cancel'))
          .onClick((): void => {
            this.clearReplyContext()
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({
          left: COMMENT_COMPOSER_RADIUS - COMMENT_COMPOSER_INNER_GAP - COMMENT_COMPOSER_QUOTE_LINE_WIDTH / 2,
          right: COMMENT_COMPOSER_INNER_GAP,
          top: COMMENT_COMPOSER_INNER_GAP,
        })
      }
      Row({ space: ThemeTokens.SPACE_SM }) {
        TextArea({ text: this.commentText, placeholder: this.replyPlaceholder() })
          .id(COMMENT_COMPOSER_FIELD_ID)
          .constraintSize({ maxHeight: COMMENT_COMPOSER_INPUT_MAX_H })
          .maxLines(8)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .enabled(!this.isCommentSubmitting && this.composerInteractionAvailable())
          .onChange((value: string): void => {
            this.commentText = value
            this.commentSubmitError = ''
          })
        SymbolGlyph($r('sys.symbol.location_north_up_right_circle_fill'))
          .fontSize(COMMENT_COMPOSER_SEND_SIZE)
          .fontColor([
            this.canSubmitComment() ? ThemeTokens.BRAND : ThemeTokens.TEXT_TERTIARY,
          ])
          .opacity(this.canSubmitComment() ? 1 : 0.45)
          .onClick((): void => {
            this.submitComment()
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      if (this.commentSubmitError.length > 0) {
        Text(this.commentSubmitError)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
          .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private MaterialCommentComposerSurface() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      Column({ space: COMMENT_COMPOSER_INNER_GAP }) {
        this.CommentComposerFields()
      }
      .width('100%')
      .padding({
        left: COMMENT_COMPOSER_INNER_GAP,
        right: COMMENT_COMPOSER_INNER_GAP,
        top: COMMENT_COMPOSER_INNER_GAP,
        bottom: COMMENT_COMPOSER_INNER_GAP,
      })
      .backgroundColor(Color.Transparent)
      .systemMaterial(this.composerSystemMaterial())
      .borderRadius(COMMENT_COMPOSER_RADIUS)
    } else {
      this.FallbackCommentComposerSurface()
    }
  }

  @Builder
  private FallbackCommentComposerSurface() {
    Column({ space: COMMENT_COMPOSER_INNER_GAP }) {
      this.CommentComposerFields()
    }
    .width('100%')
    .padding({
      left: COMMENT_COMPOSER_INNER_GAP,
      right: COMMENT_COMPOSER_INNER_GAP,
      top: COMMENT_COMPOSER_INNER_GAP,
      bottom: COMMENT_COMPOSER_INNER_GAP,
    })
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
    .borderRadius(COMMENT_COMPOSER_RADIUS)
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
  }

  private composerSystemMaterial() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THICK,
        colorInvert: true,
        applyShadow: true,
        interactive: true,
      })
    }
    return undefined
  }

  @Builder
  private CommentComposer() {
    Column() {
      if (deviceInfo.apiAvailable('26.0.0')) {
        this.MaterialCommentComposerSurface()
      } else {
        this.FallbackCommentComposerSurface()
      }
    }
    .width('100%')
    .padding({
      left: COMMENT_COMPOSER_OUTER_GAP,
      right: COMMENT_COMPOSER_OUTER_GAP,
      bottom: this.composerBottomPadding(),
    })
  }

  @Builder
  private RefreshFailureNotice() {
    Column() {
      InlineRetryNotice({
        message: this.errorMessage,
        onRetry: (): void => {
          this.loadComments()
        },
      })
    }
    .width('100%')
    .padding({
      bottom: ThemeTokens.SPACE_SM,
    })
  }

  @Builder
  private SettledCommentsContent() {
    if (this.initialCommentsResolutionPending()) {
      if (this.errorMessage.length > 0) {
        ListItem() {
          Column() {
            PageErrorState({
              message: this.errorMessage,
              onRetry: (): void => {
                this.loadComments()
              },
            })
          }
          .width('100%')
          .height(240)
          .justifyContent(FlexAlign.Center)
        }
      } else {
        ListItem() {
          Column() {
            PageLoadingState({ text: AppStrings.get('comments_status_loading') })
          }
          .width('100%')
          .height(240)
          .justifyContent(FlexAlign.Center)
        }
      }
    } else {
      if (this.errorMessage.length > 0) {
        ListItem() {
          this.RefreshFailureNotice()
        }
      }
      if (this.comments.length === 0) {
        ListItem() {
          PageEmptyState({
            message: this.rawComments.length > 0
              ? AppStrings.get('comments_status_filtered_empty')
              : AppStrings.get('comments_status_empty'),
          })
        }
      } else {
        LazyForEach(this.commentDataSource, (comment: NhComment): void => {
          ListItem() {
            GalleryCommentCard({
              comment: comment,
              body: this.replyBody(comment),
              renderState: this.renderStateFor(comment),
              canTranslate: this.canTranslate(comment),
              autoTranslate: this.commentTranslationSettings.autoTranslate,
              bilingual: this.commentTranslationSettings.displayMode ===
                COMMENT_TRANSLATION_DISPLAY_BILINGUAL,
              replyReferences: this.replyReferencesFor(comment),
              referenceRenderStates: this.referenceRenderStates,
              translationEnabled: this.commentTranslationSettings.enabled,
              emphasizedMentions: this.replyMentionLabels(comment),
              onToggleTranslate: (): void => {
                const state: CommentTranslationRenderState = this.renderStateFor(comment)
                if (state.translated.length === 0 || !state.shown) {
                  this.ensureReplyReferencesTranslated(comment)
                }
                this.toggleOrTranslate(comment)
              },
              onAutoTranslate: (): void => {
                this.autoTranslateComment(comment)
              },
              onAutoTranslateReferences: (): void => {
                this.autoTranslateReplyReferences(comment)
              },
              onReply: (): void => {
                this.openReply(comment)
              },
            })
          }
        }, (comment: NhComment): string => comment.commentId.toString())
      }
    }
  }

  @Builder
  private SettledCommentsPage() {
    Stack({ alignContent: Alignment.Bottom }) {
      PullRefreshListScaffold({
        scroller: this.scroller,
        listSpace: ThemeTokens.SPACE_SM - 2,
        bottomPadding: COMMENT_COMPOSER_BOTTOM_RESERVE,
        controller: this.refreshController,
        refreshEnabled: !this.initialCommentsResolutionPending() && !this.isLoading,
        onRefresh: async (): Promise<void> => {
          await this.loadComments()
        },
      }) {
        this.SettledCommentsContent()
      }
      this.CommentComposer()
    }
    .width('100%')
    .height('100%')
  }

  build() {
    HdsNavDestination() {
      this.SettledCommentsPage()
    }
    .titleBar(nextNHdsTitle(AppStrings.get('title_comments')))
    .hideBackButton(false)
    .bindToScrollable([this.scroller])
    .backgroundColor(ThemeTokens.SURFACE)
  }
}
