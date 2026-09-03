import { common } from '@kit.AbilityKit'
import { NhTagTranslationEntry, NhTagTranslationInfo } from '../model/NhTagTranslation'
import { TagTranslationRepository } from '../storage/TagTranslationRepository'

/** NextE-compatible presentation service for complete local tag-dictionary information. */
export class TagTranslationInfoService {
  static async lookupTagInfo(
    context: common.UIAbilityContext,
    namespace: string,
    rawName: string,
    introImageLevel: string,
  ): Promise<NhTagTranslationInfo | null> {
    const entries: NhTagTranslationEntry[] = await TagTranslationRepository.lookupInfoEntries(
      context,
      namespace,
      rawName,
    )
    const entry: NhTagTranslationEntry | null = TagTranslationInfoService.mergeEquivalentEntries(entries)
    if (entry === null) {
      return null
    }
    const translatedIntro: string = await TagTranslationInfoService.translateInlineCodeTags(context, entry.intro)
    const filteredIntro: string = TagTranslationInfoService.filterIntroImages(
      translatedIntro,
      introImageLevel,
    ).trim()
    const info: NhTagTranslationInfo = new NhTagTranslationInfo()
    info.namespace = entry.namespace
    info.rawName = entry.rawName
    info.displayName = entry.displayName
    info.intro = filteredIntro
    info.links = entry.links.trim()
    info.images = TagTranslationInfoService.extractMarkdownImageUrls(filteredIntro)
    return info
  }

  /**
   * NH collapses female/male/mixed/other to `tag`. The source dictionary often
   * keeps the same definition in those namespaces but supplies different
   * example images. Merge those examples only when the translated name,
   * image-free definition, and links agree; genuinely different definitions
   * remain unresolved instead of selecting one by insertion order.
   */
  private static mergeEquivalentEntries(entries: NhTagTranslationEntry[]): NhTagTranslationEntry | null {
    if (entries.length === 0) {
      return null
    }
    const first: NhTagTranslationEntry = entries[0]
    const body: string = TagTranslationInfoService.introWithoutImages(first.intro)
    for (let index: number = 1; index < entries.length; index++) {
      const candidate: NhTagTranslationEntry = entries[index]
      if (candidate.displayName !== first.displayName ||
        TagTranslationInfoService.introWithoutImages(candidate.intro) !== body ||
        candidate.links !== first.links) {
        return null
      }
    }
    if (entries.length === 1) {
      return first
    }
    const merged: NhTagTranslationEntry = new NhTagTranslationEntry()
    merged.namespace = first.namespace
    merged.rawName = first.rawName
    merged.displayName = first.displayName
    merged.links = first.links
    const images: string[] = []
    for (let index: number = 0; index < entries.length; index++) {
      TagTranslationInfoService.imageMarkdown(entries[index].intro).forEach((value: string): void => {
        if (images.indexOf(value) < 0) {
          images.push(value)
        }
      })
    }
    merged.intro = images.length > 0 ? `${body}\n${images.join('')}`.trim() : body
    return merged
  }

  private static introWithoutImages(value: string): string {
    return value.replace(/!\[[^\]]*\]\([^)]+\)/g, '').trim()
  }

  private static imageMarkdown(value: string): string[] {
    const images: string[] = []
    const pattern: RegExp = /!\[[^\]]*\]\([^)]+\)/g
    let match: RegExpExecArray | null = pattern.exec(value)
    while (match !== null) {
      images.push(match[0])
      match = pattern.exec(value)
    }
    return images
  }

  private static async translateInlineCodeTags(
    context: common.UIAbilityContext,
    intro: string,
  ): Promise<string> {
    if (intro.length === 0) {
      return ''
    }
    const codeTag: RegExp = /`(([\w:]+\s+?)*[\w:]+)`/g
    const translations: Map<string, string> = new Map<string, string>()
    let match: RegExpExecArray | null = codeTag.exec(intro)
    while (match !== null) {
      const raw: string = match[1]
      if (!translations.has(raw)) {
        const name: string = await TagTranslationRepository.lookupCodeTagName(context, raw)
        if (name.length > 0 && name !== raw) {
          translations.set(raw, `${name} (${raw})`)
        }
      }
      match = codeTag.exec(intro)
    }
    return intro.replace(codeTag, (_match: string, raw: string): string => {
      const translated: string | undefined = translations.get(raw)
      return translated === undefined ? ` ${raw} ` : ` ${translated} `
    })
  }

  static filterIntroImages(intro: string, level: string): string {
    const r18g: RegExp = /!\[((\S+)?)\]\(##\s+?"(.+?)"\)/g
    const r18AndR18g: RegExp = /!\[((\S+)?)\]\(##?\s+?"(.+?)"\)/g
    const all: RegExp = /!\[((\S+)?)\]\((.+?)\)/g
    switch (level) {
      case 'disable':
        return intro.replace(all, '')
      case 'r18':
        return intro
          .replace(r18g, '')
          .replace(r18AndR18g, (_match: string, _alt0: string, alt: string, url: string): string =>
            `![${alt}](${url})`)
      case 'r18g':
        return intro.replace(r18AndR18g, (_match: string, _alt0: string, alt: string, url: string): string =>
          `![${alt}](${url})`)
      default:
        return intro.replace(r18AndR18g, '')
    }
  }

  static extractMarkdownImageUrls(value: string): string[] {
    const urls: string[] = []
    const image: RegExp = /!\[([^\]]*)\]\(([^)]+)\)/g
    let match: RegExpExecArray | null = image.exec(value)
    while (match !== null) {
      const url: string = match[2].trim()
      if (url.length > 0 && !url.startsWith('##')) {
        urls.push(url)
      }
      match = image.exec(value)
    }
    return urls
  }
}
