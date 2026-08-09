/** A display-only row from the optional on-device tag dictionary. */
export class NhTagTranslationEntry {
  namespace: string = ''
  rawName: string = ''
  displayName: string = ''
}

/** Metadata for the optional dictionary without exposing its content. */
export class NhTagTranslationStatus {
  rowCount: number = 0
  version: string = ''
  source: string = ''
  updatedAt: number = 0

  isAvailable(): boolean {
    return this.rowCount > 0
  }
}
