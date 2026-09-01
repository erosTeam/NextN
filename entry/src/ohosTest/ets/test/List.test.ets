import backupCipherMetadataGuardTest from './BackupCipherMetadataGuard.test'
import backupLocalDataStructureGuardTest from './BackupLocalDataStructureGuard.test'
import backupWebDavCredentialGroupTest from './BackupWebDavCredentialGroup.test'
import nhTagQueryTest from './NhTagQuery.test'
import nhLocalUserTagRulesTest from './NhLocalUserTagRules.test'
import collectionStateTest from './CollectionState.test'
import readerPageCropDetectorTest from './ReaderPageCropDetector.test'

export default function testsuite(): void {
  backupCipherMetadataGuardTest()
  backupLocalDataStructureGuardTest()
  backupWebDavCredentialGroupTest()
  nhTagQueryTest()
  nhLocalUserTagRulesTest()
  collectionStateTest()
  readerPageCropDetectorTest()
}
