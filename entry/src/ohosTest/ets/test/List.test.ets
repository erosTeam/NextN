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
import readerThumbnailRailTest from './ReaderThumbnailRail.test'
import readerSliderLifecycleTest from './ReaderSliderLifecycle.test'

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
  readerThumbnailRailTest()
  readerSliderLifecycleTest()
}
