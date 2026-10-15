import { ComicTranslationDiagnosticLogger } from './ComicTranslationDiagnosticLogger'
import { AxiosHttpClient, AxiosTextResponse } from '../network/AxiosHttpClient'

const TRANSLATION_CONNECT_TIMEOUT_MS: number = 12000
const TRANSLATION_READ_TIMEOUT_MS: number = 30000
const BING_ORIGIN: string = 'https://cn.bing.com'
const BING_TRANSLATOR_PAGE_URL: string = 'https://cn.bing.com/translator'
const BING_TRANSLATE_ENDPOINT: string = 'https://cn.bing.com/ttranslatev3?isVertical=1'
const BING_IID: string = 'translator.5028.1'
/** The translator page mints a key/token pair plus this instrumentation id; the POST needs all three. */
const BING_ABUSE_TICKET_RE: RegExp =
  /params_AbusePreventionHelper\s*=\s*\[\s*(\d+)\s*,\s*"([^"]+)"(?:\s*,\s*(\d+))?/
const BING_IG_RE: RegExp = /IG:"([0-9A-Fa-f]+)"/
const BING_TICKET_DEFAULT_LIFETIME_MS: number = 30 * 60 * 1000
const BING_TICKET_MIN_LIFETIME_MS: number = 60 * 1000
/** Stop using a ticket this long before its advertised expiry, so a POST never races the rotation. */
const BING_TICKET_SAFETY_MS: number = 60 * 1000

class BingTranslationItem {
  text: string = ''
}

class BingTranslateResponse {
  translations: BingTranslationItem[] = []
}

/** Credentials one POST spends: the minted key/token pair plus the page's instrumentation id. */
class BingTranslatorTicket {
  key: string = ''
  token: string = ''
  ig: string = ''
  expiresAt: number = 0
}


/** Anonymous public-text translation; NH cookies and LLM credentials never enter this boundary. */
export class BingTranslationService {
  private static bingTicket: BingTranslatorTicket | null = null
  static async translate(text: string, targetLang: string): Promise<string> {
    ComicTranslationDiagnosticLogger.info('comment-translation', 'bing_translation_start', '')
    const ticket: BingTranslatorTicket = await BingTranslationService.bingTicketFor(false)
    try {
      return await BingTranslationService.bingTranslate(text, targetLang, ticket)
    } catch (_error) {
      // The likely cause is a ticket that expired between minting and spending. One forced refresh
      // separates that from a genuine failure; the second outcome is what the caller sees.
      const refreshed: BingTranslatorTicket = await BingTranslationService.bingTicketFor(true)
      return await BingTranslationService.bingTranslate(text, targetLang, refreshed)
    }
  }

  private static async bingTranslate(
    text: string,
    targetLang: string,
    ticket: BingTranslatorTicket,
  ): Promise<string> {
    const form: string =
      `fromLang=auto-detect&text=${BingTranslationService.bingFormEncode(text)}` +
      `&to=${BingTranslationService.bingFormEncode(BingTranslationService.bingLanguageCode(targetLang))}` +
      `&token=${BingTranslationService.bingFormEncode(ticket.token)}` +
      `&key=${BingTranslationService.bingFormEncode(ticket.key)}`
    const url: string =
      `${BING_TRANSLATE_ENDPOINT}&IG=${BingTranslationService.bingFormEncode(ticket.ig)}` +
      `&IID=${BING_IID}`
    const resp: AxiosTextResponse = await AxiosHttpClient.requestText(
      url,
      'POST',
      {
        'User-Agent': 'NextN/1.0.0',
        'Accept': 'application/json,text/plain,*/*',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': BING_ORIGIN,
        'Referer': BING_TRANSLATOR_PAGE_URL,
        // Without this header the endpoint still answers 200, but the body carries no translations.
        'X-Requested-With': 'XMLHttpRequest',
      },
      form,
      TRANSLATION_CONNECT_TIMEOUT_MS,
      TRANSLATION_READ_TIMEOUT_MS,
      2 * 1024 * 1024,
    )
    if (resp.statusCode !== 200) {
      throw new Error(`Bing Translate HTTP ${resp.statusCode}`)
    }
    const translated: string = BingTranslationService.parseBingBody(resp.body)
    if (translated.length === 0) {
      throw new Error('Bing Translate returned empty response')
    }
    ComicTranslationDiagnosticLogger.info('comment-translation', 'bing_translation_done', '')
    return translated
  }

  /** Reuses the live ticket when one exists, and mints a new one otherwise (or when forced). */
  private static async bingTicketFor(force: boolean): Promise<BingTranslatorTicket> {
    const cached: BingTranslatorTicket | null = BingTranslationService.bingTicket
    if (!force && cached !== null && cached.expiresAt > Date.now()) {
      return cached
    }
    const resp: AxiosTextResponse = await AxiosHttpClient.requestText(
      BING_TRANSLATOR_PAGE_URL,
      'GET',
      {
        'User-Agent': 'NextN/1.0.0',
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      },
      '',
      TRANSLATION_CONNECT_TIMEOUT_MS,
      TRANSLATION_READ_TIMEOUT_MS,
      2 * 1024 * 1024,
    )
    if (resp.statusCode !== 200) {
      throw new Error(`Bing translator page HTTP ${resp.statusCode}`)
    }
    const ticket: BingTranslatorTicket = BingTranslationService.parseBingTicket(resp.body)
    BingTranslationService.bingTicket = ticket
    return ticket
  }

  private static parseBingTicket(html: string): BingTranslatorTicket {
    const abuse: RegExpMatchArray | null = html.match(BING_ABUSE_TICKET_RE)
    if (abuse === null) {
      throw new Error('Bing translator ticket not found')
    }
    const ig: RegExpMatchArray | null = html.match(BING_IG_RE)
    if (ig === null) {
      throw new Error('Bing translator IG not found')
    }
    const ticket: BingTranslatorTicket = new BingTranslatorTicket()
    ticket.key = abuse[1]
    ticket.token = abuse[2]
    ticket.ig = ig[1]
    // A missing or implausible advertised lifetime falls back to a conservative default rather than
    // pinning a ticket that is already dead.
    const advertisedRaw: string | undefined = abuse[3]
    const advertised: number = advertisedRaw === undefined ? 0 : Number.parseInt(advertisedRaw, 10)
    const lifetime: number = advertised > BING_TICKET_MIN_LIFETIME_MS
      ? advertised
      : BING_TICKET_DEFAULT_LIFETIME_MS
    ticket.expiresAt = Date.now() + lifetime - BING_TICKET_SAFETY_MS
    return ticket
  }

  /** `application/x-www-form-urlencoded` wants a literal plus for a space, not `%20`. */
  private static bingFormEncode(value: string): string {
    return encodeURIComponent(value).replace(/%20/g, '+')
  }

  /** Bing spells the Chinese targets by script rather than by region. */
  private static bingLanguageCode(targetLang: string): string {
    if (targetLang === 'zh-CN') {
      return 'zh-Hans'
    }
    if (targetLang === 'zh-TW') {
      return 'zh-Hant'
    }
    return targetLang
  }

  private static parseBingBody(body: string): string {
    let root: Object
    try {
      root = JSON.parse(body) as Object
    } catch (_error) {
      return ''
    }
    if (!Array.isArray(root)) {
      return ''
    }
    const responses: Object[] = root as Object[]
    if (responses.length === 0 || responses[0] === null || typeof responses[0] !== 'object') {
      return ''
    }
    const parsed: BingTranslateResponse = responses[0] as BingTranslateResponse
    if (!Array.isArray(parsed.translations) || parsed.translations.length === 0) {
      return ''
    }
    const first: BingTranslationItem | undefined = parsed.translations[0]
    if (first === undefined || first === null || typeof first.text !== 'string') {
      return ''
    }
    return first.text.trim()
  }

}
