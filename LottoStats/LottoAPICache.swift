import Foundation
import CryptoKit

final class LottoAPICache {
    static let shared = LottoAPICache()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        let baseDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        cacheDirectory = baseDirectory
            .appendingPathComponent("LottoStats", isDirectory: true)
            .appendingPathComponent("APICache", isDirectory: true)

        try? fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var cacheDirectoryURL = cacheDirectory
        try? cacheDirectoryURL.setResourceValues(resourceValues)
    }

    var latestModificationDate: Date? {
        cacheFilesWithAttributes()
            .compactMap { $0.modificationDate }
            .max()
    }

    var totalSizeBytes: Int64 {
        cacheFilesWithAttributes()
            .reduce(0) { $0 + $1.size }
    }

    func load(
        for url: URL,
        maxAge: TimeInterval,
        allowExpired: Bool = false
    ) -> Data? {
        let fileURL = cacheFileURL(for: url)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        if !allowExpired {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let modificationDate = attributes[.modificationDate] as? Date else {
                return nil
            }

            let age = Date().timeIntervalSince(modificationDate)

            guard age <= maxAge else {
                return nil
            }
        }

        return try? Data(contentsOf: fileURL)
    }

    func save(
        _ data: Data,
        for url: URL
    ) {
        let fileURL = cacheFileURL(for: url)

        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            AppLogger.debug("Nie udało się zapisać cache dla", url.absoluteString, error)
        }
    }

    func markAllExpired() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for file in files {
            try? fileManager.setAttributes(
                [.modificationDate: Date.distantPast],
                ofItemAtPath: file.path
            )
        }
    }

    func clear() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }

    private func cacheFilesWithAttributes() -> [(modificationDate: Date?, size: Int64)] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files.compactMap { file in
            guard let values = try? file.resourceValues(
                forKeys: [.contentModificationDateKey, .fileSizeKey]
            ) else {
                return nil
            }

            return (
                modificationDate: values.contentModificationDate,
                size: Int64(values.fileSize ?? 0)
            )
        }
    }

    private func cacheFileURL(for url: URL) -> URL {
        let keyData = Data(url.absoluteString.utf8)
        let hash = SHA256.hash(data: keyData)
            .map { String(format: "%02x", $0) }
            .joined()

        return cacheDirectory
            .appendingPathComponent(hash)
            .appendingPathExtension("json")
    }
}
