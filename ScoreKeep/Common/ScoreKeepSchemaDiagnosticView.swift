import SwiftData
import SwiftUI

struct ScoreKeepSchemaDiagnosticView: View {
    var body: some View {
        Text("ScoreKeep Schema Diagnostic")
            .task {
                ScoreKeepSchemaDiagnosticReporter.report()
            }
    }
}

private enum ScoreKeepSchemaDiagnosticReporter {
    static func report() {
        reportSchema("V2", ScoreKeepProposedVersionedSchema.V2.self)
        reportSchema("V3", ScoreKeepProposedVersionedSchema.V3.self)
        print("SCHEMA_DIAGNOSTIC stageEvaluationBegin")
        let planSchemas = ScoreKeepProposedCanonicalScoringStorageMigrationPlan.schemas.map {
            "\(String(describing: $0)):\($0.versionIdentifier.description)"
        }.joined(separator: ",")
        print("SCHEMA_DIAGNOSTIC planSchemasEvaluated=\(planSchemas)")
        let stages = ScoreKeepProposedCanonicalScoringStorageMigrationPlan.stages
        print("SCHEMA_DIAGNOSTIC stageEvaluationSucceeded stageCount=\(stages.count)")
        print("SCHEMA_DIAGNOSTIC hostedV2ToV3MigrationOpen=notPerformed boundary=inventoryOnly")
        reportProductionMetadataClassification()
    }

    private static func reportSchema(_ label: String, _ schemaType: any VersionedSchema.Type) {
        let schema = Schema(versionedSchema: schemaType)
        print("SCHEMA_DIAGNOSTIC schema=\(label) version=\(schemaType.versionIdentifier.description) entityCount=\(schema.entities.count) schemaInventoryOnly=true")
        for entity in schema.entities.sorted(by: { $0.name < $1.name }) {
            let properties = entity.properties
                .map { String(describing: $0) }
                .sorted()
                .joined(separator: "|")
            print("SCHEMA_DIAGNOSTIC entity=\(label).\(entity.name) properties=\(properties)")
        }
    }

    private static func reportProductionMetadataClassification() {
        let root = ScoreKeepPhysicalDeviceDiagnostics.applicationSupportRoot()
        let layout = ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: root)
        let assessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: layout.activeStore)
        let journal = ScoreKeepMigrationJournalStore(directory: layout.journal.deletingLastPathComponent()).load()
        let journalStatus: String
        if let record = journal.record {
            journalStatus = "\(record.phase.rawValue):\(record.sourceClassification.rawValue)"
        } else if journal.error != nil {
            journalStatus = "unreadable"
        } else {
            journalStatus = "absent"
        }
        let matchingVersions = assessment.matchingRegisteredVersions.joined(separator: "+")
        print("SCHEMA_DIAGNOSTIC productionSourceClassification=\(assessment.sourceClassification.rawValue) hashEntryCount=\(assessment.hashEntryCount) versionIdentifierCount=\(assessment.versionIdentifierCount) matchingRegisteredVersions=\(matchingVersions) selectedStartupRoute=\(assessment.selectedStartupRoute) journal=\(journalStatus)")
    }
}
