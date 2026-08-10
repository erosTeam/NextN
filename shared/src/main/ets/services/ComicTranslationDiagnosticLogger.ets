/**
 * Translation-pipeline diagnostics intentionally publish only fixed event names.
 * Source text, translated text, image paths, page identities, and provider payloads
 * stay in the calling frame and are never written to device logs.
 */
export class ComicTranslationDiagnosticLogger {
  static info(_domain: string, event: string, _details: string): void {
    console.info('ComicTranslation event=' + ComicTranslationDiagnosticLogger.event(event))
  }

  static warn(_domain: string, event: string, _details: string): void {
    console.warn('ComicTranslation event=' + ComicTranslationDiagnosticLogger.event(event))
  }

  private static event(value: string): string {
    return /^[a-z0-9_]{1,96}$/.test(value) ? value : 'invalid_event'
  }
}
