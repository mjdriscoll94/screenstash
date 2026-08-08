import SwiftData

enum ScreenStashSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ScreenshotItem.self, ScreenshotCategoryRecord.self]
    }
}

enum ScreenStashMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ScreenStashSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum ScreenStashContainer {
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ScreenStashSchemaV1.self)
        let configuration = ModelConfiguration(
            "ScreenStash",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: ScreenStashMigrationPlan.self,
            configurations: configuration
        )
    }
}
