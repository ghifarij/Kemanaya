@testable import KemanayaCore
import Testing

/// The automatic backup's decisions (D-019, D-060): a fresh store writes nothing, a backup this install
/// didn't write is archived on the first real write, writes wait for a restore, and a new folder starts over.
struct AutoBackupPolicyTests {
    @Test func aFreshStoreNeverWrites() {
        // Whether or not the folder already has a backup: the policy doesn't even ask.
        #expect(AutoBackupPolicy().decision(isFreshStore: true, isRestoring: false) == .skipFreshStore)
        #expect(AutoBackupPolicy(hasWrittenToFolder: true).decision(isFreshStore: true, isRestoring: false) == .skipFreshStore)
    }

    @Test func theFirstRealWriteArchivesAKeptBackup() {
        var policy = AutoBackupPolicy()
        #expect(policy.decision(isFreshStore: false, isRestoring: false) == .write(archivingExisting: true))
        policy.recordWrite()
        #expect(policy.hasWrittenToFolder)
        #expect(policy.decision(isFreshStore: false, isRestoring: false) == .write(archivingExisting: false), "then normal rotation")
    }

    /// A store that becomes fresh again (all data deleted) still writes nothing, and keeps its state.
    @Test func skippingDoesNotChangeTheKeptState() {
        var policy = AutoBackupPolicy()
        _ = policy.decision(isFreshStore: true, isRestoring: false)
        #expect(!policy.hasWrittenToFolder)
        policy.recordWrite()
        _ = policy.decision(isFreshStore: true, isRestoring: false)
        #expect(policy.hasWrittenToFolder)
    }

    @Test func aWriteDuringARestoreIsDeferred() {
        #expect(AutoBackupPolicy().decision(isFreshStore: false, isRestoring: true) == .deferUntilRestored)
        #expect(AutoBackupPolicy().decision(isFreshStore: true, isRestoring: true) == .deferUntilRestored)
        #expect(AutoBackupPolicy(hasWrittenToFolder: true).decision(isFreshStore: false, isRestoring: true) == .deferUntilRestored)
    }

    @Test func changingTheFolderResetsTheKeptState() {
        var policy = AutoBackupPolicy()
        policy.recordWrite()
        policy.folderChanged()
        #expect(!policy.hasWrittenToFolder)
        #expect(policy.decision(isFreshStore: false, isRestoring: false) == .write(archivingExisting: true))
    }

    @Test func theBeforeRestoreCopyNeedsAFolderAndRealData() {
        #expect(AutoBackupPolicy.writesBeforeRestore(hasFolder: true, isFreshStore: false))
        #expect(!AutoBackupPolicy.writesBeforeRestore(hasFolder: true, isFreshStore: true), "only the seed to lose")
        #expect(!AutoBackupPolicy.writesBeforeRestore(hasFolder: false, isFreshStore: false), "nowhere to write")
    }
}
