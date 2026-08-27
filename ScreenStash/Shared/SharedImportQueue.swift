import Foundation

enum ScreenStashAppGroup {
    static let identifier = "group.com.screenstash.shared"
    static let pendingDirectoryName = "PendingScreenshotImports"
    static let failedDirectoryName = "FailedScreenshotImports"
}

struct SharedScreenshotImportRecord: Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let categoryKey: String
    // Optional so imports queued by an earlier app version still decode safely.
    let title: String?

    init(id: UUID, createdAt: Date, categoryKey: String, title: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.categoryKey = categoryKey
        self.title = title
    }
}

struct PendingSharedScreenshotImport: Equatable, Sendable {
    let record: SharedScreenshotImportRecord
    let imageData: Data
}

struct PendingSharedImportBatch: Sendable {
    let imports: [PendingSharedScreenshotImport]
    let invalidEntryCount: Int

    static let empty = PendingSharedImportBatch(imports: [], invalidEntryCount: 0)
}

enum SharedImportQueueError: LocalizedError, Equatable {
    case appGroupUnavailable
    case emptyImage
    case unreadableEntry

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            "FrameFile sharing is not configured yet. Open the main app after enabling its App Group."
        case .emptyImage:
            "The shared screenshot did not contain image data."
        case .unreadableEntry:
            "A shared screenshot could not be read."
        }
    }
}

protocol SharedImportQueuing: Sendable {
    func enqueue(
        imageData: Data,
        categoryKey: String,
        title: String,
        id: UUID,
        createdAt: Date
    ) async throws
    func pendingImports() async throws -> PendingSharedImportBatch
    func removeImport(id: UUID) async throws
    func removeAllImports() async throws
}

actor SharedImportQueue: SharedImportQueuing {
    private let injectedBaseDirectory: URL?
    private let fileManager: FileManager

    init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        injectedBaseDirectory = baseDirectory
        self.fileManager = fileManager
    }

    func enqueue(
        imageData: Data,
        categoryKey: String,
        title: String,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) throws {
        guard !imageData.isEmpty else { throw SharedImportQueueError.emptyImage }

        let root = try pendingDirectory(createIfNeeded: true)
        let temporaryDirectory = root.appendingPathComponent(".\(id.uuidString).tmp", isDirectory: true)
        let finalDirectory = root.appendingPathComponent(id.uuidString, isDirectory: true)

        // Retrying a partially completed share should not create duplicates.
        if fileManager.fileExists(atPath: finalDirectory.path) { return }

        try? fileManager.removeItem(at: temporaryDirectory)
        try fileManager.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        do {
            let record = SharedScreenshotImportRecord(
                id: id,
                createdAt: createdAt,
                categoryKey: categoryKey,
                title: title
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let metadata = try encoder.encode(record)

            try imageData.write(
                to: temporaryDirectory.appendingPathComponent("image.data"),
                options: .atomic
            )
            try metadata.write(
                to: temporaryDirectory.appendingPathComponent("metadata.json"),
                options: .atomic
            )
            try fileManager.moveItem(at: temporaryDirectory, to: finalDirectory)
        } catch {
            try? fileManager.removeItem(at: temporaryDirectory)
            throw error
        }
    }

    func pendingImports() throws -> PendingSharedImportBatch {
        guard let root = try? pendingDirectory(createIfNeeded: false) else {
            // The app should continue normally before its App Group is configured.
            return .empty
        }
        guard fileManager.fileExists(atPath: root.path) else { return .empty }

        let directories = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var imports: [PendingSharedScreenshotImport] = []
        var invalidEntryCount = 0
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for directory in directories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            do {
                let metadata = try Data(
                    contentsOf: directory.appendingPathComponent("metadata.json"),
                    options: .mappedIfSafe
                )
                let record = try decoder.decode(SharedScreenshotImportRecord.self, from: metadata)
                let imageData = try Data(
                    contentsOf: directory.appendingPathComponent("image.data"),
                    options: .mappedIfSafe
                )
                guard !imageData.isEmpty else { throw SharedImportQueueError.emptyImage }
                imports.append(PendingSharedScreenshotImport(record: record, imageData: imageData))
            } catch {
                invalidEntryCount += 1
                quarantineInvalidEntry(at: directory, pendingRoot: root)
            }
        }

        return PendingSharedImportBatch(imports: imports, invalidEntryCount: invalidEntryCount)
    }

    func removeImport(id: UUID) throws {
        guard let root = try? pendingDirectory(createIfNeeded: false) else { return }
        let directory = root.appendingPathComponent(id.uuidString, isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }

    func removeAllImports() throws {
        guard let container = try? containerDirectory() else { return }
        let importDirectories = [
            ScreenStashAppGroup.pendingDirectoryName,
            ScreenStashAppGroup.failedDirectoryName
        ]

        for directoryName in importDirectories {
            let directory = container.appendingPathComponent(directoryName, isDirectory: true)
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
        }
    }

    private func pendingDirectory(createIfNeeded: Bool) throws -> URL {
        let container = try containerDirectory()

        let directory = container.appendingPathComponent(
            ScreenStashAppGroup.pendingDirectoryName,
            isDirectory: true
        )
        if createIfNeeded {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func containerDirectory() throws -> URL {
        if let injectedBaseDirectory {
            return injectedBaseDirectory
        } else if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: ScreenStashAppGroup.identifier
        ) {
            return appGroupURL
        } else {
            throw SharedImportQueueError.appGroupUnavailable
        }
    }

    private func quarantineInvalidEntry(at entry: URL, pendingRoot: URL) {
        let failedRoot = pendingRoot
            .deletingLastPathComponent()
            .appendingPathComponent(ScreenStashAppGroup.failedDirectoryName, isDirectory: true)

        do {
            try fileManager.createDirectory(at: failedRoot, withIntermediateDirectories: true)
            let destination = failedRoot.appendingPathComponent(
                "\(entry.lastPathComponent)-\(UUID().uuidString)",
                isDirectory: true
            )
            try fileManager.moveItem(at: entry, to: destination)
        } catch {
            // If quarantine itself fails, leave the entry in place so a future
            // launch still has an opportunity to recover it.
        }
    }
}
