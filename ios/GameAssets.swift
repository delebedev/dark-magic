import Foundation

struct GameAssets {
    static let archives = ["d2data.mpq", "d2char.mpq", "d2exp.mpq", "patch_d2.mpq", "d2sfx.mpq"]

    static func prepare(documents: URL, bundled: URL) throws -> URL {
        let files = FileManager.default
        if files.fileExists(atPath: documents.path) {
            try validate(documents)
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

    private static func validate(_ directory: URL) throws {
        let missing = archives.filter { name in
            let file = directory.appendingPathComponent(name)
            guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true, (values.fileSize ?? 0) > 0 else { return true }
            return !FileManager.default.isReadableFile(atPath: file.path)
        }
        guard missing.isEmpty else {
            throw NSError(domain: "DarkMagic.Assets", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Missing or empty game archives in \(directory.lastPathComponent): \(missing.joined(separator: ", "))."])
        }
    }
}
