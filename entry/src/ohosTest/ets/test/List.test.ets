import backupCipherMetadataGuardTest from './BackupCipherMetadataGuard.test'
import backupLocalDataStructureGuardTest from './BackupLocalDataStructureGuard.test'
import backupWebDavCredentialGroupTest from './BackupWebDavCredentialGroup.test'
import nhTagQueryTest from './NhTagQuery.test'

export default function testsuite(): void {
  backupCipherMetadataGuardTest()
  backupLocalDataStructureGuardTest()
  backupWebDavCredentialGroupTest()
  nhTagQueryTest()
}
