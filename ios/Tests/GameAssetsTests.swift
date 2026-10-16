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
        // A title-only seed supplements an existing complete set without replacing any archives.
        try files.createDirectory(at: bundle, withIntermediateDirectories: true)
        let music = stored.appendingPathComponent("d2xmusic.mpq")
        let bundledMusic = bundle.appendingPathComponent("d2xmusic.mpq")
        let musicStaging = stored.appendingPathComponent(".d2xmusic.mpq-importing")
        let musicData = Data("title music".utf8)
        try musicData.write(to: bundledMusic)
        try Data("interrupted".utf8).write(to: musicStaging)
        _ = try GameAssets.prepare(documents: stored, bundled: bundle)
        let importedMusic = try Data(contentsOf: music)
        assert(importedMusic == musicData)
        assert(!files.fileExists(atPath: musicStaging.path))
        for archive in GameAssets.archives {
            let data = try Data(contentsOf: stored.appendingPathComponent(archive))
            assert(data == Data(archive.utf8))
        }
        // An existing optional archive wins even if the bundled replacement is invalid.
        try Data().write(to: bundledMusic)
        _ = try GameAssets.prepare(documents: stored, bundled: bundle)
        let preservedMusic = try Data(contentsOf: music)
        assert(preservedMusic == musicData)
        try files.removeItem(at: music)
        func rejectInvalidMusic() throws {
            do {
                _ = try GameAssets.prepare(documents: stored, bundled: bundle)
                assertionFailure("An invalid optional archive must not become visible")
            } catch {
                assert((error as NSError).localizedDescription.contains("d2xmusic.mpq"))
                assert(!files.fileExists(atPath: music.path))
            }
            for archive in GameAssets.archives {
                let data = try Data(contentsOf: stored.appendingPathComponent(archive))
                assert(data == Data(archive.utf8))
            }
        }
        try rejectInvalidMusic()
        try files.removeItem(at: bundledMusic)
        try files.createDirectory(at: bundledMusic, withIntermediateDirectories: true)
        try rejectInvalidMusic()
        try files.removeItem(at: bundledMusic)
        try musicData.write(to: bundledMusic)
        let freshMusicOnly = root.appendingPathComponent("MusicOnly/Assets")
        do {
            _ = try GameAssets.prepare(documents: freshMusicOnly, bundled: bundle)
            assertionFailure("A title-only seed cannot replace a complete first seed")
        } catch {
            assert(!files.fileExists(atPath: freshMusicOnly.path))
            assert((error as NSError).localizedDescription.contains("d2data.mpq"))
        }
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
            _ = try GameAssets.prepare(documents: root.appendingPathComponent("Fresh/Assets"), bundled: root.appendingPathComponent("Absent/Assets"))
            assertionFailure("A fresh lean install needs an asset seed")
        } catch {
            assert(!files.fileExists(atPath: root.appendingPathComponent("Fresh/Assets").path))
        }
        print("Asset migration, title supplementation, interrupted-copy recovery, update reuse and invalid-set rejection passed.")
    }
}
