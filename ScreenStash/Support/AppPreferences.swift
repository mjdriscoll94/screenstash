import Foundation

enum ScreenshotLayoutMode: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum ScreenshotAgingThreshold: Int, CaseIterable, Identifiable {
    case thirtyDays = 30
    case sixtyDays = 60
    case ninetyDays = 90

    var id: Int { rawValue }
    var displayName: String { "\(rawValue) days" }
}

enum AppPreferenceKey {
    static let hasSeenOnboarding = "hasSeenOnboarding"
    static let defaultLayout = "defaultLayout"
    static let defaultCategory = "defaultCategory"
    // Keep the original persisted key so existing user preferences migrate automatically.
    static let showResolvedCategory = "showResolved"
    static let agingThreshold = "agingThreshold"
    static let deletedBuiltInCategories = "deletedBuiltInCategories"

    static let allKeys = [
        hasSeenOnboarding,
        defaultLayout,
        defaultCategory,
        showResolvedCategory,
        agingThreshold,
        deletedBuiltInCategories
    ]

    static func resetAll(in defaults: UserDefaults = .standard) {
        allKeys.forEach(defaults.removeObject(forKey:))
    }
}

/// Remembers intentionally removed default categories so the startup seeder
/// does not recreate them on the next launch.
enum DeletedBuiltInCategoryStore {
    static func keys(in defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: AppPreferenceKey.deletedBuiltInCategories) ?? [])
    }

    static func markDeleted(_ key: String, in defaults: UserDefaults = .standard) {
        var deletedKeys = keys(in: defaults)
        deletedKeys.insert(key)
        defaults.set(
            deletedKeys.sorted(),
            forKey: AppPreferenceKey.deletedBuiltInCategories
        )
    }

    static func reset(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: AppPreferenceKey.deletedBuiltInCategories)
    }
}
