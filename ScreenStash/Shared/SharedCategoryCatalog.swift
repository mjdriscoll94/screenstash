import Foundation

struct SharedCategoryOption: Codable, Equatable, Identifiable, Sendable {
    let key: String
    let name: String
    let symbolName: String
    let sortOrder: Int
    let isBuiltIn: Bool

    var id: String { key }

    static let unsorted = SharedCategoryOption(
        key: "",
        name: "Unsorted",
        symbolName: "tray",
        sortOrder: -1,
        isBuiltIn: false
    )

    static var builtInDefaults: [SharedCategoryOption] {
        ScreenshotCategory.allCases.enumerated().map { index, category in
            SharedCategoryOption(
                key: category.rawValue,
                name: category.displayName,
                symbolName: category.symbolName,
                sortOrder: index,
                isBuiltIn: true
            )
        }
    }
}

protocol SharedCategoryCataloging: Sendable {
    func loadCategories() async throws -> [SharedCategoryOption]
    func saveCategories(_ categories: [SharedCategoryOption]) async throws
}

actor SharedCategoryCatalog: SharedCategoryCataloging {
    private static let fileName = "categories.json"

    private let injectedBaseDirectory: URL?
    private let fileManager: FileManager

    init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        injectedBaseDirectory = baseDirectory
        self.fileManager = fileManager
    }

    func loadCategories() throws -> [SharedCategoryOption] {
        let fileURL = try catalogFileURL(createDirectory: false)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return [SharedCategoryOption.unsorted] + SharedCategoryOption.builtInDefaults
        }

        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let categories = try JSONDecoder().decode([SharedCategoryOption].self, from: data)
        return categories.sorted(by: categorySort)
    }

    func saveCategories(_ categories: [SharedCategoryOption]) throws {
        let fileURL = try catalogFileURL(createDirectory: true)
        let data = try JSONEncoder().encode(categories.sorted(by: categorySort))
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    private func catalogFileURL(createDirectory: Bool) throws -> URL {
        let container: URL
        if let injectedBaseDirectory {
            container = injectedBaseDirectory
        } else if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: ScreenStashAppGroup.identifier
        ) {
            container = appGroupURL
        } else {
            throw SharedImportQueueError.appGroupUnavailable
        }

        let directory = container.appendingPathComponent("SharedConfiguration", isDirectory: true)
        if createDirectory {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent(Self.fileName)
    }

    private func categorySort(_ lhs: SharedCategoryOption, _ rhs: SharedCategoryOption) -> Bool {
        if lhs.sortOrder == rhs.sortOrder {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return lhs.sortOrder < rhs.sortOrder
    }
}

/// Shares the user's import default with the share extension through the App Group.
/// An empty key represents the system Unsorted collection.
enum SharedDefaultCategoryPreference {
    private static let key = "sharedDefaultCategory"

    static func load() -> String {
        UserDefaults(suiteName: ScreenStashAppGroup.identifier)?.string(forKey: key) ?? ""
    }

    static func save(_ categoryKey: String) {
        UserDefaults(suiteName: ScreenStashAppGroup.identifier)?.set(categoryKey, forKey: key)
    }
}
