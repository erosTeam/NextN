import { Want } from '@kit.AbilityKit'

/**
 * Debug-only, process-local Reader rehearsal configuration. Parsed straight
 * from the Debug Want by the host entry; never persisted and never a user
 * setting. Empty by default so ordinary launches are unaffected.
 */
export class ReaderSelfHostedRehearsal {
  private static endpoint: string = ''
  private static user: string = ''
  private static password: string = ''
  private static superResolutionRecordingArmed: boolean = false
  private static productionSuperResolutionWork: string = ''
  private static productionSuperResolutionPage: number = -1
  private static productionSuperResolutionScenario: string = ''

  static capture(want: Want, debugBuild: boolean): void {
    ReaderSelfHostedRehearsal.clear()
    if (!debugBuild || want.parameters === undefined) return
    const endpoint = want.parameters['readerLabSelfHostedEndpoint']
    const user = want.parameters['readerLabSelfHostedUser']
    const password = want.parameters['readerLabSelfHostedPassword']
    ReaderSelfHostedRehearsal.endpoint = typeof endpoint === 'string' ? endpoint : ''
    ReaderSelfHostedRehearsal.user = typeof user === 'string' ? user : ''
    ReaderSelfHostedRehearsal.password = typeof password === 'string' ? password : ''
    const chrome = want.parameters['readerLabChrome']
    const page = want.parameters['readerLabPage']
    const pageIndex = typeof page === 'string' ? Number(page) : (typeof page === 'number' ? page : -1)
    ReaderSelfHostedRehearsal.superResolutionRecordingArmed =
      want.parameters['readerLabSuperResolutionRecording'] === 'off-on-once' &&
      want.parameters['readerLabWork'] === '__rkit_local_fixture__' &&
      (chrome === true || chrome === 'true') && pageIndex === 2
    const galleryId = want.parameters['nextn_gallery_id']
    const rawProductionPage = want.parameters['readerProductionSuperResolutionPage']
    const productionPage: number = typeof rawProductionPage === 'number' ? rawProductionPage : -1
    const rawScenario = want.parameters['readerProductionSuperResolutionScenario']
    const scenario: string = typeof rawScenario === 'string' ? rawScenario : ''
    if (typeof galleryId === 'number' && Number.isSafeInteger(galleryId) && galleryId > 0 &&
      productionPage === 2 && (scenario === 'delay-once' || scenario === 'fail-once')) {
      ReaderSelfHostedRehearsal.productionSuperResolutionWork = galleryId.toString()
      ReaderSelfHostedRehearsal.productionSuperResolutionPage = productionPage
      ReaderSelfHostedRehearsal.productionSuperResolutionScenario = scenario
    }
  }

  static clear(): void {
    ReaderSelfHostedRehearsal.endpoint = ''
    ReaderSelfHostedRehearsal.user = ''
    ReaderSelfHostedRehearsal.password = ''
    ReaderSelfHostedRehearsal.superResolutionRecordingArmed = false
    ReaderSelfHostedRehearsal.productionSuperResolutionWork = ''
    ReaderSelfHostedRehearsal.productionSuperResolutionPage = -1
    ReaderSelfHostedRehearsal.productionSuperResolutionScenario = ''
  }

  static active(): boolean {
    return ReaderSelfHostedRehearsal.endpoint.length > 0 &&
      ReaderSelfHostedRehearsal.user.length > 0 && ReaderSelfHostedRehearsal.password.length > 0
  }

  static currentEndpoint(): string { return ReaderSelfHostedRehearsal.endpoint }
  static currentUser(): string { return ReaderSelfHostedRehearsal.user }
  static currentPassword(): string { return ReaderSelfHostedRehearsal.password }

  static consumeSuperResolutionRecording(): boolean {
    const armed = ReaderSelfHostedRehearsal.superResolutionRecordingArmed
    ReaderSelfHostedRehearsal.superResolutionRecordingArmed = false
    return armed
  }

  static consumeProductionSuperResolutionScenario(work: string, pageIndex: number): string {
    if (ReaderSelfHostedRehearsal.productionSuperResolutionWork !== work ||
      ReaderSelfHostedRehearsal.productionSuperResolutionPage !== pageIndex) return ''
    const scenario = ReaderSelfHostedRehearsal.productionSuperResolutionScenario
    ReaderSelfHostedRehearsal.productionSuperResolutionScenario = ''
    return scenario
  }
}
