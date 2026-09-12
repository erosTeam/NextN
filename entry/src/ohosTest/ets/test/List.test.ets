import backupCipherMetadataGuardTest from './BackupCipherMetadataGuard.test'
import backupLocalDataStructureGuardTest from './BackupLocalDataStructureGuard.test'
import backupWebDavCredentialGroupTest from './BackupWebDavCredentialGroup.test'
import nhTagQueryTest from './NhTagQuery.test'
import nhBrowserSessionOwnershipTest from './NhBrowserSessionOwnership.test'
import nhLocalUserTagRulesTest from './NhLocalUserTagRules.test'
import nhLocalUserTagSyncTest from './NhLocalUserTagSync.test'
import collectionStateTest from './CollectionState.test'
import readerPageCropDetectorTest from './ReaderPageCropDetector.test'
import readerLabGesturesTest from './ReaderLabGestures.test'
import readerChromeTest from './ReaderChrome.test'
import readerPagingAxisTest from './ReaderPagingAxis.test'
import readerSpreadLayoutTest from './ReaderSpreadLayout.test'
import readerInitialPolicyTest from './ReaderInitialPolicy.test'
import readerThumbnailInitialPolicyTest from './ReaderThumbnailInitialPolicy.test'
import readerTapZonesTest from './ReaderTapZones.test'
import readerPageNumberTest from './ReaderPageNumber.test'
import readerInterpolationTest from './ReaderInterpolation.test'
import readerThumbnailRailTest from './ReaderThumbnailRail.test'
import readerSliderLifecycleTest from './ReaderSliderLifecycle.test'
import readerThumbnailRetryTest from './ReaderThumbnailRetry.test'
import readerVolumeKeysTest from './ReaderVolumeKeys.test'
import readerImageShareTest from './ReaderImageShare.test'
import readerImageInformationTest from './ReaderImageInformation.test'
import readerThumbnailEntryTest from './ReaderThumbnailEntry.test'
import readerThumbnailOriginalProbeTest from './ReaderThumbnailOriginalProbe.test'
import readerObservedProgressTest from './ReaderObservedProgress.test'
import readerProgressPersistenceTest from './ReaderProgressPersistence.test'
import readerProductionBackendTrialTest from './ReaderProductionBackendTrial.test'
import readerProductionDownloadSourceTrialTest from './ReaderProductionDownloadSourceTrial.test'
import readerProductionDownloadEntryTrialTest from './ReaderProductionDownloadEntryTrial.test'
import readerProductionPartialDownloadFallbackTrialTest from './ReaderProductionPartialDownloadFallbackTrial.test'

export default function testsuite(): void {
  backupCipherMetadataGuardTest()
  backupLocalDataStructureGuardTest()
  backupWebDavCredentialGroupTest()
  nhTagQueryTest()
  nhBrowserSessionOwnershipTest()
  nhLocalUserTagRulesTest()
  nhLocalUserTagSyncTest()
  collectionStateTest()
  readerPageCropDetectorTest()
  readerLabGesturesTest()
  readerChromeTest()
  readerPagingAxisTest()
  readerSpreadLayoutTest()
  readerInitialPolicyTest()
  readerThumbnailInitialPolicyTest()
  readerTapZonesTest()
  readerPageNumberTest()
  readerInterpolationTest()
  readerThumbnailRailTest()
  readerSliderLifecycleTest()
  readerThumbnailRetryTest()
  readerVolumeKeysTest()
  readerImageShareTest()
  readerImageInformationTest()
  readerThumbnailEntryTest()
  readerThumbnailOriginalProbeTest()
  readerObservedProgressTest()
  readerProgressPersistenceTest()
  readerProductionBackendTrialTest()
  readerProductionDownloadSourceTrialTest()
  readerProductionDownloadEntryTrialTest()
  readerProductionPartialDownloadFallbackTrialTest()
}
