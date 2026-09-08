import SwiftData
import SwiftUI

struct ScoreKeepUITestTeamPresentationSeamView: View {
    @State private var modelContainer: ModelContainer?
    @State private var routingService: SimpleTeamCreationRoutingService?

    var body: some View {
        Group {
            if let modelContainer, let routingService {
                TeamContentView()
                    .modelContainer(modelContainer)
                    .environmentObject(routingService)
            } else {
                Text("Preparing team presentation fixture...")
                    .onAppear(perform: prepareFixture)
            }
        }
    }

    @MainActor
    private func prepareFixture() {
        let schema = Schema([Game.self, Team.self, Player.self, Atbat.self, Pitcher.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            modelContainer = container
            routingService = SimpleTeamCreationRoutingService(
                container: container,
                routeSelection: .proposed,
                readiness: CanonicalTeamCreationWriteReadinessSnapshot(
                    storeOpenedSuccessfully: true,
                    sourceVersionState: .supportedCurrent,
                    migrationState: .complete,
                    cutoverApprovalPresent: true
                ),
                activeContainerAuthority: "uiTestTeamPresentation",
                migrationCompletionState: "completed"
            )
        } catch {
            print("Failed to create team presentation fixture container: \(error)")
        }
    }
}
