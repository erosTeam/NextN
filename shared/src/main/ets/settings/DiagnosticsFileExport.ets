import { common } from '@kit.AbilityKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { AppStrings } from '../i18n/AppStrings'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { DiagnosticsSettings } from './DiagnosticsSettings'

const DIAGNOSTICS_EXPORT_DIR: string = 'diagnostics_exports'
const DIAGNOSTICS_EXPORT_PREFIX: string = 'nextn-log-export-'
const DIAGNOSTICS_EXPORT_SUFFIX: string = '.txt'
const DIAGNOSTICS_EXPORT_KEEP_COUNT: number = 3

export interface DiagnosticsExportFile {
  fileName: string
  filePath: string
  uri: string
  text: string
  directoryKind: string
}

interface DiagnosticsExportTarget {
  directory: string
  directoryKind: string
}

export class DiagnosticsFileExport {
  static create(context: common.UIAbilityContext): DiagnosticsExportFile {
    let phase: string = 'prepare_text'
    let fileName: string = ''
    try {
      const text: string = DiagnosticsSettings.exportText() || AppStrings.get('no_diagnostics_logs')
      fileName = DiagnosticsFileExport.safeFileName(new Date())
      phase = 'choose_directory'
      const target: DiagnosticsExportTarget = DiagnosticsFileExport.exportTarget(context)
      const filePath: string = target.directory + '/' + fileName
      phase = 'ensure_directory'
      DiagnosticsFileExport.ensureExportDirectory(target.directory)
      phase = 'write_file'
      DiagnosticsFileExport.writeTextFile(filePath, text)
      phase = 'prune_old_exports'
      DiagnosticsFileExport.pruneOldExports(context, fileName)
      return {
        fileName: fileName,
        filePath: filePath,
        uri: fileUri.getUriFromPath(filePath),
        text: text,
        directoryKind: target.directoryKind,
      }
    } catch (error) {
      DiagnosticLogger.warn(
        'diagnostics',
        'file_export_failed',
        `phase=${phase} file=${fileName} error=${(error as Error).message}`,
      )
      throw new Error('Diagnostics file export failed')
    }
  }

  static pruneOldExports(context: common.UIAbilityContext, keepFileName: string = ''): void {
    const directory: string = DiagnosticsFileExport.exportTarget(context).directory
    let names: string[] = []
    try {
      names = fileIo.listFileSync(directory)
    } catch (_error) {
      return
    }
    const exportNames: string[] = names
      .filter((name: string): boolean => DiagnosticsFileExport.isDiagnosticsExportFileName(name))
      .sort()
      .reverse()
    exportNames.forEach((name: string, index: number): void => {
      if (name === keepFileName || index < DIAGNOSTICS_EXPORT_KEEP_COUNT) {
        return
      }
      try {
        fileIo.unlinkSync(directory + '/' + name)
      } catch (_error) {}
    })
  }

  private static safeFileName(date: Date): string {
    const year: string = date.getFullYear().toString().padStart(4, '0')
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0')
    const day: string = date.getDate().toString().padStart(2, '0')
    const hour: string = date.getHours().toString().padStart(2, '0')
    const minute: string = date.getMinutes().toString().padStart(2, '0')
    const second: string = date.getSeconds().toString().padStart(2, '0')
    return `${DIAGNOSTICS_EXPORT_PREFIX}${year}${month}${day}-${hour}${minute}${second}${DIAGNOSTICS_EXPORT_SUFFIX}`
  }

  private static exportTarget(context: common.UIAbilityContext): DiagnosticsExportTarget {
    const cacheDir: string = DiagnosticsFileExport.nonEmptyDir(context.cacheDir)
    if (cacheDir.length > 0) {
      return { directory: cacheDir + '/' + DIAGNOSTICS_EXPORT_DIR, directoryKind: 'cacheDir' }
    }
    const filesDir: string = DiagnosticsFileExport.nonEmptyDir(context.filesDir)
    if (filesDir.length > 0) {
      return { directory: filesDir + '/' + DIAGNOSTICS_EXPORT_DIR, directoryKind: 'filesDir' }
    }
    throw new Error('Diagnostics export directory unavailable')
  }

  private static ensureExportDirectory(directory: string): void {
    try {
      fileIo.mkdirSync(directory, true)
    } catch (_error) {
      fileIo.listFileSync(directory)
    }
  }

  private static writeTextFile(filePath: string, text: string): void {
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(
        filePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      fileIo.writeSync(file.fd, text)
    } finally {
      if (file !== null) {
        try {
          fileIo.closeSync(file)
        } catch (_error) {}
      }
    }
  }

  private static isDiagnosticsExportFileName(fileName: string): boolean {
    if (!fileName.startsWith(DIAGNOSTICS_EXPORT_PREFIX) ||
      !fileName.endsWith(DIAGNOSTICS_EXPORT_SUFFIX) ||
      fileName.includes('/') || fileName.includes('\\') || fileName.includes('..')) {
      return false
    }
    const middle: string = fileName.substring(
      DIAGNOSTICS_EXPORT_PREFIX.length,
      fileName.length - DIAGNOSTICS_EXPORT_SUFFIX.length,
    )
    if (middle.length !== 'YYYYMMDD-HHMMSS'.length || middle.charAt(8) !== '-') {
      return false
    }
    const digits: string = middle.substring(0, 8) + middle.substring(9)
    for (let index: number = 0; index < digits.length; index += 1) {
      const code: number = digits.charCodeAt(index)
      if (code < 48 || code > 57) {
        return false
      }
    }
    return true
  }

  private static nonEmptyDir(value: string): string {
    let clean: string = (value || '').trim()
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1)
    }
    return clean
  }
}
