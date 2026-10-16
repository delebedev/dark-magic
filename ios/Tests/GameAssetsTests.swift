import Foundation

@main
struct GameAssetsTests {
    static func main() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent("dark-magic-assets-\(UUID().uuidString)")
        defer { try? files.removeItem(at: root) }
        let bundle = root.appendingPathComponent("bundle/Assets")
        let stored = root.appendingPathComponent("Documents/Assets")
        try files.createDirectory(at: bundle, withIntermediateDirectories: true)
        for archive in GameAssets.archives { try Data(archive.utf8).write(to: bundle.appendingPathComponent(archive)) }
        // An interrupted migration is replaced before the complete set becomes visible.
        let staging = stored.deletingLastPathComponent().appendingPathComponent(".Assets-importing")
        try files.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data("partial".utf8).write(to: staging.appendingPathComponent("d2data.mpq"))
        let migrated = try GameAssets.prepare(documents: stored, bundled: bundle)
        assert(migrated == stored)
        let resources = try stored.resourceValues(forKeys: [.isExcludedFromBackupKey])
        assert(resources.isExcludedFromBackup == true)
        assert(!files.fileExists(atPath: staging.path))
        for archive in GameAssets.archives {
            let data = try Data(contentsOf: stored.appendingPathComponent(archive))
            assert(data == Data(archive.utf8))
        }
        // A lean update has no bundled assets and must keep the stored set untouched.
        try files.removeItem(at: bundle)
        let reused = try GameAssets.prepare(documents: stored, bundled: bundle)
        assert(reused == stored)
        let invalid = root.appendingPathComponent("Imported/Assets")
        try files.createDirectory(at: invalid, withIntermediateDirectories: true)
        try Data().write(to: invalid.appendingPathComponent("d2data.mpq"))
        do {
            _ = try GameAssets.prepare(documents: invalid, bundled: bundle)
            assertionFailure("An incomplete imported set must not be selected or overwritten")
        } catch {
            assert((error as NSError).localizedDescription.contains("d2data.mpq"))
            assert(files.fileExists(atPath: invalid.appendingPathComponent("d2data.mpq").path))
        }
        do {
            _ = try GameAssets.prepare(documents: root.appendingPathComponent("Fresh/Assets"), bundled: bundle)
            assertionFailure("A fresh lean install needs an asset seed")
        } catch {
            assert(!files.fileExists(atPath: root.appendingPathComponent("Fresh/Assets").path))
        }
        print("Asset migration, interrupted-copy recovery, update reuse and incomplete-set rejection passed.")
    }
}
