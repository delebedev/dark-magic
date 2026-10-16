import Foundation

struct GameAssets {
    static let archives = ["d2data.mpq", "d2char.mpq", "d2exp.mpq", "patch_d2.mpq", "d2sfx.mpq"]

    static func prepare(documents: URL, bundled: URL) throws -> URL {
        let files = FileManager.default
        if files.fileExists(atPath: documents.path) {
            try validate(documents)
            let music = documents.appendingPathComponent("d2xmusic.mpq")
            let source = bundled.appendingPathComponent("d2xmusic.mpq")
            if !files.fileExists(atPath: music.path), files.fileExists(atPath: source.path) {
                guard readableArchive(source) else {
                    throw NSError(domain: "DarkMagic.Assets", code: 1, userInfo: [NSLocalizedDescriptionKey:
                        "Missing or empty title music archive: d2xmusic.mpq."])
                }
                let staging = documents.appendingPathComponent(".d2xmusic.mpq-importing")
                if files.fileExists(atPath: staging.path) { try files.removeItem(at: staging) }
                try files.copyItem(at: source, to: staging)
                guard readableArchive(staging) else {
                    throw NSError(domain: "DarkMagic.Assets", code: 1, userInfo: [NSLocalizedDescriptionKey:
                        "Missing or empty title music archive: d2xmusic.mpq."])
                }
                try files.moveItem(at: staging, to: music)
            }
        } else {
            try validate(bundled)
            let staging = documents.deletingLastPathComponent().appendingPathComponent(".Assets-importing")
            if files.fileExists(atPath: staging.path) { try files.removeItem(at: staging) }
            try files.createDirectory(at: documents.deletingLastPathComponent(), withIntermediateDirectories: true)
            try files.copyItem(at: bundled, to: staging)
            try validate(staging)
            try files.moveItem(at: staging, to: documents)
        }
        // Owned archives can be restored from the seed and should not fill device backups.
        try (documents as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        return documents
    }

    private static func readableArchive(_ file: URL) -> Bool {
        guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true, (values.fileSize ?? 0) > 0 else { return false }
        return FileManager.default.isReadableFile(atPath: file.path)
    }

    private static func validate(_ directory: URL) throws {
        let missing = archives.filter { name in
            let file = directory.appendingPathComponent(name)
            return !readableArchive(file)
        }
        guard missing.isEmpty else {
            throw NSError(domain: "DarkMagic.Assets", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Missing or empty game archives in \(directory.lastPathComponent): \(missing.joined(separator: ", "))."])
        }
    }
}
