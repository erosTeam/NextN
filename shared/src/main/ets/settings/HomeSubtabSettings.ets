import { common } from '@kit.AbilityKit'
import { AppStrings } from '../i18n/AppStrings'
import {
  HOME_SUBTAB_LATEST_UUID,
  HOME_SUBTAB_POPULAR_UUID,
  HOME_SUBTAB_PRESENTATION_GLOBAL,
  HOME_SUBTAB_STARTER_CHINESE_UUID,
  HOME_SUBTAB_STARTER_FAVORITED_UUID,
  NhHomeSubtabKind,
  NhHomeSubtabProfile,
} from '../model/NhHomeSubtabProfile'
import { NhSearchLanguage, NhSearchSort } from '../model/NhSearchOptions'
import { HOME_SOURCE_POPULAR, connectHomeSource } from '../state/HomeSourceState'
import { HomeSubtabState, connectHomeSubtabs } from '../state/HomeSubtabState'
import {
  HomeSubtabRepository,
  HomeSubtabSelectionRecord,
} from '../storage/HomeSubtabRepository'
import { SyncScheduler } from '../sync/SyncScheduler'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

export class HomeSubtabBackupSnapshot {
  profiles: NhHomeSubtabProfile[] = []
  selectedUuid: string = ''
}

/** Single writer for Home SubTab state, persistence and selection fallback. */
export class HomeSubtabSettings {
  private static writeTail: Promise<void> = Promise.resolve()
  private static restoreTask: Promise<void> | null = null

  static async restore(context: common.UIAbilityContext): Promise<void> {
    if (HomeSubtabSettings.restoreTask !== null) {
      await HomeSubtabSettings.restoreTask
      return
    }
    const task: Promise<void> = HomeSubtabSettings.restoreInternal(context)
    HomeSubtabSettings.restoreTask = task
    try {
      await task
    } finally {
      HomeSubtabSettings.restoreTask = null
    }
  }

  private static async restoreInternal(context: common.UIAbilityContext): Promise<void> {
    const state: HomeSubtabState = connectHomeSubtabs()
    try {
      const persisted: boolean = await HomeSubtabRepository.hasPersistedState(context)
      let profiles: NhHomeSubtabProfile[] = persisted
        ? await HomeSubtabRepository.loadProfiles(context)
        : HomeSubtabSettings.seedDefaults()
      const selection: HomeSubtabSelectionRecord = persisted
        ? await HomeSubtabRepository.loadSelection(context)
        : new HomeSubtabSelectionRecord()
      const ensured: NhHomeSubtabProfile[] = HomeSubtabSettings.ensureBuiltins(profiles)
      const legacySelected: string = connectHomeSource().selectedKey === HOME_SOURCE_POPULAR
        ? HOME_SUBTAB_POPULAR_UUID
        : HOME_SUBTAB_LATEST_UUID
      const selected: string = HomeSubtabSettings.visibleSelection(
        ensured,
        selection.selectedUuid.length > 0 ? selection.selectedUuid : legacySelected,
      )
      state.profiles = HomeSubtabSettings.snapshot(ensured)
      state.selectedUuid = selected
      state.restored = true
      connectHomeSource().selectedKey = selected
      if (!persisted || ensured.length !== profiles.length || selected !== selection.selectedUuid) {
        await HomeSubtabSettings.enqueueWrite(
          (): Promise<void> => HomeSubtabRepository.replaceAll(context, ensured, selected),
        )
      }
    } catch (error) {
      DiagnosticLogger.warn('settings', 'home_subtabs_restore_failed', (error as Error).message)
      const fallback: NhHomeSubtabProfile[] = HomeSubtabSettings.seedDefaults()
      state.profiles = fallback
      state.selectedUuid = HOME_SUBTAB_LATEST_UUID
      state.restored = true
      connectHomeSource().selectedKey = HOME_SUBTAB_LATEST_UUID
    }
  }

  static async add(context: common.UIAbilityContext, profile: NhHomeSubtabProfile): Promise<boolean> {
    if (!profile.isSearch() || profile.name.trim().length === 0 || !profile.hasEffectiveSearch()) {
      return false
    }
    const state: HomeSubtabState = connectHomeSubtabs()
    if (profile.uuid.length === 0 || state.find(profile.uuid) !== null) {
      return false
    }
    const next: NhHomeSubtabProfile[] = HomeSubtabSettings.snapshot(state.profiles)
    const saved: NhHomeSubtabProfile = profile.copy()
    saved.name = saved.name.trim()
    saved.query = saved.query.trim()
    saved.lastEditTime = HomeSubtabSettings.nextEditTime(saved.lastEditTime)
    next.push(saved)
    state.profiles = next
    state.selectedUuid = saved.uuid
    connectHomeSource().selectedKey = saved.uuid
    await HomeSubtabSettings.persistChanged(context, next, [saved.uuid], '', true)
    return true
  }

  static async update(context: common.UIAbilityContext, profile: NhHomeSubtabProfile): Promise<boolean> {
    if (profile.isBuiltin() || !profile.isSearch() || profile.name.trim().length === 0 ||
      !profile.hasEffectiveSearch()) {
      return false
    }
    const state: HomeSubtabState = connectHomeSubtabs()
    const index: number = HomeSubtabSettings.indexOf(state.profiles, profile.uuid)
    if (index < 0) {
      return false
    }
    const next: NhHomeSubtabProfile[] = HomeSubtabSettings.snapshot(state.profiles)
    const saved: NhHomeSubtabProfile = profile.copy()
    saved.name = saved.name.trim()
    saved.query = saved.query.trim()
    saved.lastEditTime = HomeSubtabSettings.nextEditTime(Math.max(saved.lastEditTime, next[index].lastEditTime))
    next[index] = saved
    state.profiles = next
    await HomeSubtabSettings.persistChanged(context, next, [saved.uuid])
    return true
  }

  static async remove(context: common.UIAbilityContext, uuid: string): Promise<boolean> {
    const state: HomeSubtabState = connectHomeSubtabs()
    const index: number = HomeSubtabSettings.indexOf(state.profiles, uuid)
    if (index < 0 || state.profiles[index].isBuiltin()) {
      return false
    }
    if (!state.profiles[index].hidden && HomeSubtabSettings.visibleCount(state.profiles) <= 1) {
      return false
    }
    const next: NhHomeSubtabProfile[] = []
    state.profiles.forEach((candidate: NhHomeSubtabProfile): void => {
      if (candidate.uuid !== uuid) {
        next.push(candidate.copy())
      }
    })
    let selectionChanged: boolean = false
    if (state.selectedUuid === uuid) {
      state.selectedUuid = HomeSubtabSettings.firstVisible(next)
      connectHomeSource().selectedKey = state.selectedUuid
      selectionChanged = true
    }
    state.profiles = next
    await HomeSubtabSettings.persistChanged(context, next, [], uuid, selectionChanged)
    return true
  }

  static async reorder(context: common.UIAbilityContext, from: number, to: number): Promise<boolean> {
    const state: HomeSubtabState = connectHomeSubtabs()
    if (from < 0 || from >= state.profiles.length || to < 0 || to >= state.profiles.length || from === to) {
      return false
    }
    const next: NhHomeSubtabProfile[] = HomeSubtabSettings.snapshot(state.profiles)
    const moved: NhHomeSubtabProfile = next.splice(from, 1)[0]
    next.splice(to, 0, moved)
    const changed: string[] = []
    const start: number = Math.min(from, to)
    const end: number = Math.max(from, to)
    for (let index: number = start; index <= end; index++) {
      next[index].lastEditTime = HomeSubtabSettings.nextEditTime(next[index].lastEditTime)
      changed.push(next[index].uuid)
    }
    state.profiles = next
    await HomeSubtabSettings.persistChanged(context, next, changed)
    return true
  }

  static async setHidden(
    context: common.UIAbilityContext,
    uuid: string,
    hidden: boolean,
  ): Promise<boolean> {
    const state: HomeSubtabState = connectHomeSubtabs()
    const index: number = HomeSubtabSettings.indexOf(state.profiles, uuid)
    if (index < 0 || state.profiles[index].hidden === hidden) {
      return index >= 0
    }
    if (hidden && HomeSubtabSettings.visibleCount(state.profiles) <= 1) {
      return false
    }
    const next: NhHomeSubtabProfile[] = HomeSubtabSettings.snapshot(state.profiles)
    next[index].hidden = hidden
    next[index].lastEditTime = HomeSubtabSettings.nextEditTime(next[index].lastEditTime)
    let selectionChanged: boolean = false
    if (hidden && state.selectedUuid === uuid) {
      state.selectedUuid = HomeSubtabSettings.firstVisible(next)
      connectHomeSource().selectedKey = state.selectedUuid
      selectionChanged = true
    }
    state.profiles = next
    await HomeSubtabSettings.persistChanged(context, next, [uuid], '', selectionChanged)
    return true
  }

  static async setDisplayMode(
    context: common.UIAbilityContext,
    uuid: string,
    presentation: string,
  ): Promise<boolean> {
    const state: HomeSubtabState = connectHomeSubtabs()
    const index: number = HomeSubtabSettings.indexOf(state.profiles, uuid)
    if (index < 0) {
      return false
    }
    const normalized: string = NhHomeSubtabProfile.normalizePresentation(presentation) === null
      ? HOME_SUBTAB_PRESENTATION_GLOBAL
      : presentation
    if (state.profiles[index].presentation === normalized) {
      return true
    }
    const next: NhHomeSubtabProfile[] = HomeSubtabSettings.snapshot(state.profiles)
    next[index].presentation = normalized
    next[index].lastEditTime = HomeSubtabSettings.nextEditTime(next[index].lastEditTime)
    state.profiles = next
    await HomeSubtabSettings.persistChanged(context, next, [uuid])
    return true
  }

  static async setSelected(context: common.UIAbilityContext, uuid: string): Promise<boolean> {
    const state: HomeSubtabState = connectHomeSubtabs()
    const profile: NhHomeSubtabProfile | null = state.find(uuid)
    if (profile === null || profile.hidden) {
      return false
    }
    state.selectedUuid = uuid
    connectHomeSource().selectedKey = uuid
    await HomeSubtabSettings.enqueueWrite(
      (): Promise<void> => HomeSubtabRepository.saveChanges(context, state.profiles, [], uuid, '', true),
    )
    return true
  }

  static async exportForBackup(context: common.UIAbilityContext): Promise<HomeSubtabBackupSnapshot> {
    await HomeSubtabSettings.writeTail
    const snapshot: HomeSubtabBackupSnapshot = new HomeSubtabBackupSnapshot()
    snapshot.profiles = await HomeSubtabRepository.loadProfiles(context)
    snapshot.selectedUuid = (await HomeSubtabRepository.loadSelection(context)).selectedUuid
    return snapshot
  }

  static async restoreBackup(
    context: common.UIAbilityContext,
    profiles: NhHomeSubtabProfile[],
    selectedUuid: string,
  ): Promise<void> {
    const normalized: NhHomeSubtabProfile[] = HomeSubtabSettings.ensureBuiltins(HomeSubtabSettings.snapshot(profiles))
    const selected: string = HomeSubtabSettings.visibleSelection(normalized, selectedUuid)
    await HomeSubtabSettings.enqueueWrite(
      (): Promise<void> => HomeSubtabRepository.replaceAll(context, normalized, selected),
    )
    await HomeSubtabSettings.refreshFromStorage(context)
    SyncScheduler.requestAfterLocalWrite(context, 'home_subtabs_restore_backup')
  }

  static async refreshFromStorage(context: common.UIAbilityContext): Promise<void> {
    await HomeSubtabSettings.writeTail
    const profiles: NhHomeSubtabProfile[] = HomeSubtabSettings.ensureBuiltins(
      await HomeSubtabRepository.loadProfiles(context),
    )
    const selected: string = HomeSubtabSettings.visibleSelection(
      profiles,
      (await HomeSubtabRepository.loadSelection(context)).selectedUuid,
    )
    const state: HomeSubtabState = connectHomeSubtabs()
    state.profiles = HomeSubtabSettings.snapshot(profiles)
    state.selectedUuid = selected
    state.restored = true
    connectHomeSource().selectedKey = selected
  }

  static flushForSync(): Promise<void> {
    return HomeSubtabSettings.writeTail
  }

  private static async persistChanged(
    context: common.UIAbilityContext,
    profiles: NhHomeSubtabProfile[],
    changed: string[],
    deletedUuid: string = '',
    selectionChanged: boolean = false,
  ): Promise<void> {
    const selectedUuid: string = connectHomeSubtabs().selectedUuid
    try {
      await HomeSubtabSettings.enqueueWrite(
        (): Promise<void> => HomeSubtabRepository.saveChanges(
          context,
          HomeSubtabSettings.snapshot(profiles),
          changed,
          selectedUuid,
          deletedUuid,
          selectionChanged,
        ),
      )
      SyncScheduler.requestAfterLocalWrite(context, 'home_subtabs')
    } catch (error) {
      DiagnosticLogger.warn('settings', 'home_subtabs_save_failed', (error as Error).message)
    }
  }

  private static seedDefaults(): NhHomeSubtabProfile[] {
    const state = connectHomeSource()
    const latest: NhHomeSubtabProfile = HomeSubtabSettings.profile(
      HOME_SUBTAB_LATEST_UUID,
      NhHomeSubtabKind.LATEST,
      AppStrings.get('home_source_latest'),
    )
    const latestPresentation = state.presentationOverrideFor('latest')
    latest.presentation = latestPresentation === null ? HOME_SUBTAB_PRESENTATION_GLOBAL : latestPresentation
    const popular: NhHomeSubtabProfile = HomeSubtabSettings.profile(
      HOME_SUBTAB_POPULAR_UUID,
      NhHomeSubtabKind.POPULAR,
      AppStrings.get('home_source_popular'),
    )
    const popularPresentation = state.presentationOverrideFor('popular')
    popular.presentation = popularPresentation === null ? HOME_SUBTAB_PRESENTATION_GLOBAL : popularPresentation
    const chinese: NhHomeSubtabProfile = HomeSubtabSettings.profile(
      HOME_SUBTAB_STARTER_CHINESE_UUID,
      NhHomeSubtabKind.SEARCH,
      AppStrings.get('home_subtab_starter_chinese'),
    )
    chinese.language = NhSearchLanguage.CHINESE
    const favorite: NhHomeSubtabProfile = HomeSubtabSettings.profile(
      HOME_SUBTAB_STARTER_FAVORITED_UUID,
      NhHomeSubtabKind.SEARCH,
      AppStrings.get('home_subtab_starter_favorited'),
    )
    favorite.query = 'favorites:>=1000'
    favorite.sort = NhSearchSort.RECENT
    return [latest, popular, chinese, favorite]
  }

  private static ensureBuiltins(profiles: NhHomeSubtabProfile[]): NhHomeSubtabProfile[] {
    const out: NhHomeSubtabProfile[] = HomeSubtabSettings.snapshot(profiles)
    if (HomeSubtabSettings.indexOf(out, HOME_SUBTAB_LATEST_UUID) < 0) {
      out.splice(0, 0, HomeSubtabSettings.profile(
        HOME_SUBTAB_LATEST_UUID,
        NhHomeSubtabKind.LATEST,
        AppStrings.get('home_source_latest'),
      ))
    }
    if (HomeSubtabSettings.indexOf(out, HOME_SUBTAB_POPULAR_UUID) < 0) {
      const latestIndex: number = HomeSubtabSettings.indexOf(out, HOME_SUBTAB_LATEST_UUID)
      out.splice(latestIndex + 1, 0, HomeSubtabSettings.profile(
        HOME_SUBTAB_POPULAR_UUID,
        NhHomeSubtabKind.POPULAR,
        AppStrings.get('home_source_popular'),
      ))
    }
    const latest: NhHomeSubtabProfile | null = HomeSubtabSettings.find(out, HOME_SUBTAB_LATEST_UUID)
    if (latest !== null) {
      latest.kind = NhHomeSubtabKind.LATEST
      latest.name = AppStrings.get('home_source_latest')
      latest.query = ''
      latest.language = NhSearchLanguage.ALL
      latest.sort = NhSearchSort.RECENT
    }
    const popular: NhHomeSubtabProfile | null = HomeSubtabSettings.find(out, HOME_SUBTAB_POPULAR_UUID)
    if (popular !== null) {
      popular.kind = NhHomeSubtabKind.POPULAR
      popular.name = AppStrings.get('home_source_popular')
      popular.query = ''
      popular.language = NhSearchLanguage.ALL
      popular.sort = NhSearchSort.RECENT
    }
    return out
  }

  private static profile(uuid: string, kind: NhHomeSubtabKind, name: string): NhHomeSubtabProfile {
    const profile: NhHomeSubtabProfile = new NhHomeSubtabProfile()
    profile.uuid = uuid
    profile.kind = kind
    profile.name = name
    profile.lastEditTime = Date.now()
    return profile
  }

  private static visibleSelection(profiles: NhHomeSubtabProfile[], selectedUuid: string): string {
    const selected: NhHomeSubtabProfile | null = HomeSubtabSettings.find(profiles, selectedUuid)
    if (selected !== null && !selected.hidden) {
      return selected.uuid
    }
    return HomeSubtabSettings.firstVisible(profiles)
  }

  private static firstVisible(profiles: NhHomeSubtabProfile[]): string {
    for (let index: number = 0; index < profiles.length; index++) {
      if (!profiles[index].hidden) {
        return profiles[index].uuid
      }
    }
    return ''
  }

  private static visibleCount(profiles: NhHomeSubtabProfile[]): number {
    let count: number = 0
    profiles.forEach((profile: NhHomeSubtabProfile): void => {
      if (!profile.hidden) {
        count += 1
      }
    })
    return count
  }

  private static find(profiles: NhHomeSubtabProfile[], uuid: string): NhHomeSubtabProfile | null {
    const index: number = HomeSubtabSettings.indexOf(profiles, uuid)
    return index >= 0 ? profiles[index] : null
  }

  private static indexOf(profiles: NhHomeSubtabProfile[], uuid: string): number {
    for (let index: number = 0; index < profiles.length; index++) {
      if (profiles[index].uuid === uuid) {
        return index
      }
    }
    return -1
  }

  private static snapshot(profiles: NhHomeSubtabProfile[]): NhHomeSubtabProfile[] {
    const copies: NhHomeSubtabProfile[] = []
    profiles.forEach((profile: NhHomeSubtabProfile): void => {
      copies.push(profile.copy())
    })
    return copies
  }

  private static nextEditTime(current: number): number {
    return Math.max(Date.now(), Math.floor(current) + 1)
  }

  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = HomeSubtabSettings.writeTail.then(operation, operation)
    HomeSubtabSettings.writeTail = queued.catch((): void => {})
    return queued
  }
}
