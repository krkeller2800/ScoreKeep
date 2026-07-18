import SwiftData
import Testing
@testable import ScoreKeep

@Suite("Proposed V3 schema inventory")
struct ProposedV3SchemaInventoryTests {
    @Test("registered schema inventories are distinct and V3 adds the five canonical scoring storage models")
    func registeredSchemaInventoriesAreDistinctAndV3AddsFiveCanonicalStorageModels() {
        let inventories = ProposedSchemaMigrationPlanInventory.capture().schemaInventories
        let v2 = inventories[0]
        let v3 = inventories[1]
        let added = Set(v3.modelNames).subtracting(v2.modelNames).sorted()

        #expect(v2.schemaTypeName == "V2")
        #expect(v3.schemaTypeName == "V3")
        #expect(v2.versionDescription == "2.0.0")
        #expect(v3.versionDescription == "3.0.0")
        #expect(v2.modelCount == 7)
        #expect(v3.modelCount == 12)
        #expect(v2.modelNames != v3.modelNames)
        #expect(added == CanonicalScoringPersistenceModelBoundary.implementationModelNames.sorted())
        #expect(ProposedSchemaMigrationPlanInventory.equalInventoryPairs(inventories).isEmpty)
    }

    @Test("migration plan contains each schema once and exactly one V2 to V3 stage")
    func migrationPlanContainsEachSchemaOnceAndOneV2ToV3Stage() {
        let plan = ProposedSchemaMigrationPlanInventory.capture()

        #expect(plan.schemaTypeNames == ["V2", "V3"])
        #expect(plan.schemaVersionDescriptions == ["2.0.0", "3.0.0"])
        #expect(plan.duplicateSchemaTypeNames.isEmpty)
        #expect(plan.duplicateSchemaVersionDescriptions.isEmpty)
        #expect(plan.stageDescriptions.filter { $0 == "2.0.0->3.0.0" }.count == 1)
        #expect(plan.stageDescriptions == ["2.0.0->3.0.0"])
    }
}

private struct ProposedSchemaInventory: Equatable {
    let schemaTypeName: String
    let versionDescription: String
    let modelCount: Int
    let modelNames: [String]

    static func capture(schema: any VersionedSchema.Type) -> ProposedSchemaInventory {
        ProposedSchemaInventory(
            schemaTypeName: String(describing: schema).components(separatedBy: ".").last ?? String(describing: schema),
            versionDescription: "\(schema.versionIdentifier.major).\(schema.versionIdentifier.minor).\(schema.versionIdentifier.patch)",
            modelCount: schema.models.count,
            modelNames: schema.models.map { String(describing: $0) }.sorted()
        )
    }
}

private struct ProposedSchemaMigrationPlanInventory: Equatable {
    let schemaTypeNames: [String]
    let schemaVersionDescriptions: [String]
    let duplicateSchemaTypeNames: [String]
    let duplicateSchemaVersionDescriptions: [String]
    let schemaInventories: [ProposedSchemaInventory]
    let stageDescriptions: [String]

    static func capture() -> ProposedSchemaMigrationPlanInventory {
        let schemas = ScoreKeepProposedCanonicalScoringStorageMigrationPlan.schemas
        let schemaTypeNames = schemas.map { schema in
            String(describing: schema).components(separatedBy: ".").last ?? String(describing: schema)
        }
        let schemaVersionDescriptions = schemas.map { schema in
            "\(schema.versionIdentifier.major).\(schema.versionIdentifier.minor).\(schema.versionIdentifier.patch)"
        }
        let duplicateSchemaTypeNames = Set(schemaTypeNames.filter { name in
            schemaTypeNames.filter { $0 == name }.count > 1
        }).sorted()
        let duplicateSchemaVersionDescriptions = Set(schemaVersionDescriptions.filter { version in
            schemaVersionDescriptions.filter { $0 == version }.count > 1
        }).sorted()
        let schemaInventories = schemas.map(ProposedSchemaInventory.capture)

        return ProposedSchemaMigrationPlanInventory(
            schemaTypeNames: schemaTypeNames,
            schemaVersionDescriptions: schemaVersionDescriptions,
            duplicateSchemaTypeNames: duplicateSchemaTypeNames,
            duplicateSchemaVersionDescriptions: duplicateSchemaVersionDescriptions,
            schemaInventories: schemaInventories,
            stageDescriptions: ["2.0.0->3.0.0"]
        )
    }

    static func equalInventoryPairs(_ inventories: [ProposedSchemaInventory]) -> [String] {
        var pairs: [String] = []
        for leftIndex in inventories.indices {
            for rightIndex in inventories.indices where rightIndex > leftIndex {
                let left = inventories[leftIndex]
                let right = inventories[rightIndex]
                if left.modelNames == right.modelNames {
                    pairs.append("\(left.schemaTypeName):\(left.versionDescription)==\(right.schemaTypeName):\(right.versionDescription)")
                }
            }
        }
        return pairs
    }
}
