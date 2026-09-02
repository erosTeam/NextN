import { common } from '@kit.AbilityKit'
import { NhTag } from '../model/NhGallery'
import { NhTagSuggestion } from '../model/NhTagSuggestion'
import { NhApiClient } from '../network/NhApiClient'
import { NhTagCatalogRepository } from '../storage/NhTagCatalogRepository'
import { TagTranslationRepository } from '../storage/TagTranslationRepository'

/**
 * One autocomplete policy for Search/Subtab composition and local-tag management.
 * Dictionary text is presentation/discovery only; callers that persist an NH tag
 * use suggestVerified() and receive only candidates carrying a positive NH id.
 */
export class NhTagSuggestionService {
  static async suggest(
    context: common.UIAbilityContext,
    namespace: string,
    query: string,
    limit: number = 10,
  ): Promise<NhTagSuggestion[]> {
    const normalizedNamespace: string = namespace.trim().toLowerCase()
    const normalizedQuery: string = query.trim().toLowerCase()
    const boundedLimit: number = NhTagSuggestionService.boundedLimit(limit)
    if (normalizedQuery.length === 0 || normalizedQuery.length > 128) {
      return []
    }
    let local: NhTagSuggestion[] = normalizedNamespace.length > 0
      ? await TagTranslationRepository.suggest(context, normalizedNamespace, normalizedQuery, boundedLimit)
      : await TagTranslationRepository.suggestUnscoped(context, normalizedQuery, boundedLimit)
    if (local.length < boundedLimit && !NhTagSuggestionService.isPureCjk(normalizedQuery)) {
      const remote: NhTagSuggestion[] = await NhApiClient.tagSuggestions(
        normalizedNamespace,
        normalizedQuery,
        boundedLimit - local.length,
      )
      local = NhTagSuggestionService.merge(local, remote, boundedLimit)
    }
    return local
  }

  /** Resolve dictionary-only matches through the local NH catalog, then exact public NH lookup. */
  static async suggestVerified(
    context: common.UIAbilityContext,
    namespace: string,
    query: string,
    limit: number = 10,
  ): Promise<NhTagSuggestion[]> {
    const boundedLimit: number = NhTagSuggestionService.boundedLimit(limit)
    const candidates: NhTagSuggestion[] = await NhTagSuggestionService.suggest(
      context,
      namespace,
      query,
      boundedLimit,
    )
    const verifiedByKey: Map<string, NhTagSuggestion> = new Map<string, NhTagSuggestion>()
    const unresolved: NhTagSuggestion[] = []
    for (let index: number = 0; index < candidates.length; index++) {
      const candidate: NhTagSuggestion = candidates[index]
      if (candidate.tagId > 0) {
        verifiedByKey.set(NhTagSuggestionService.identityKey(candidate), candidate)
        continue
      }
      const cached: NhTag | null = await NhTagCatalogRepository.findByIdentity(
        context,
        candidate.namespace,
        candidate.rawName,
      )
      if (cached !== null) {
        verifiedByKey.set(
          NhTagSuggestionService.identityKey(candidate),
          NhTagSuggestionService.withIdentity(candidate, cached.id, cached.type, cached.name),
        )
      } else {
        unresolved.push(candidate)
      }
    }

    const remoteChecks: Promise<NhTagSuggestion | null>[] = []
    for (let index: number = 0; index < unresolved.length; index++) {
      remoteChecks.push(NhTagSuggestionService.verifyAgainstNh(unresolved[index]))
    }
    const remoteMatches: Array<NhTagSuggestion | null> = await Promise.all(remoteChecks)
    for (let index: number = 0; index < remoteMatches.length; index++) {
      const match: NhTagSuggestion | null = remoteMatches[index]
      if (match !== null) {
        verifiedByKey.set(NhTagSuggestionService.identityKey(match), match)
      }
    }

    const result: NhTagSuggestion[] = []
    for (let index: number = 0; index < candidates.length && result.length < boundedLimit; index++) {
      const verified: NhTagSuggestion | undefined = verifiedByKey.get(
        NhTagSuggestionService.identityKey(candidates[index]),
      )
      if (verified !== undefined && verified.tagId > 0) {
        result.push(verified)
      }
    }
    return result
  }

  private static async verifyAgainstNh(candidate: NhTagSuggestion): Promise<NhTagSuggestion | null> {
    try {
      const matches: NhTagSuggestion[] = await NhApiClient.tagSuggestions(
        candidate.namespace,
        candidate.rawName,
        15,
      )
      const targetName: string = candidate.rawName.trim().toLowerCase()
      const targetNamespace: string = candidate.namespace.trim().toLowerCase()
      for (let index: number = 0; index < matches.length; index++) {
        const match: NhTagSuggestion = matches[index]
        if (match.tagId > 0 && match.namespace.trim().toLowerCase() === targetNamespace &&
          match.rawName.trim().toLowerCase() === targetName) {
          return NhTagSuggestionService.withIdentity(
            candidate,
            match.tagId,
            match.namespace,
            match.rawName,
          )
        }
      }
    } catch (_error) {}
    return null
  }

  private static withIdentity(
    source: NhTagSuggestion,
    tagId: number,
    namespace: string,
    rawName: string,
  ): NhTagSuggestion {
    const result: NhTagSuggestion = new NhTagSuggestion()
    result.tagId = Math.floor(tagId)
    result.namespace = namespace.trim().toLowerCase()
    result.rawName = rawName.trim()
    result.displayName = source.displayName.trim().length > 0 ? source.displayName : result.rawName
    return result
  }

  private static merge(
    localSuggestions: NhTagSuggestion[],
    remoteSuggestions: NhTagSuggestion[],
    limit: number,
  ): NhTagSuggestion[] {
    const merged: NhTagSuggestion[] = []
    const seen: Set<string> = new Set<string>()
    const candidates: NhTagSuggestion[] = localSuggestions.concat(remoteSuggestions)
    for (let index: number = 0; index < candidates.length && merged.length < limit; index++) {
      const candidate: NhTagSuggestion = candidates[index]
      const key: string = NhTagSuggestionService.identityKey(candidate)
      if (candidate.namespace.length === 0 || candidate.rawName.length === 0 || seen.has(key)) {
        continue
      }
      seen.add(key)
      merged.push(candidate)
    }
    return merged
  }

  private static identityKey(suggestion: NhTagSuggestion): string {
    return `${suggestion.namespace.trim().toLowerCase()}\u001f${suggestion.rawName.trim().toLowerCase()}`
  }

  private static isPureCjk(value: string): boolean {
    const hasCjk: boolean = /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff66-\uff9f]/.test(value)
    return hasCjk && !/[A-Za-z0-9]/.test(value)
  }

  private static boundedLimit(value: number): number {
    return Math.max(1, Math.min(15, Math.floor(value)))
  }
}
