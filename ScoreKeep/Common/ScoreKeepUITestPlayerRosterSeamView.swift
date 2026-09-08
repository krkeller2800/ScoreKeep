import SwiftData
import SwiftUI

struct ScoreKeepUITestPlayerRosterSeamView: View {
    @State private var modelContainer: ModelContainer?
    @State private var fixtureTeam: Team?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        Group {
            if let modelContainer, let fixtureTeam {
                NavigationStack(path: $navigationPath) {
                    EditTeamView(navigationPath: $navigationPath, team: fixtureTeam)
                        .navigationTitle(fixtureTeam.name)
                }
                .modelContainer(modelContainer)
            } else {
                Text("Preparing player roster fixture...")
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
            let context = container.mainContext
            let team = Team(name: "Seam Team", coach: "Coach", details: "Fixture team")
            let player = Player(name: "Existing Player", number: "7", position: "Shortstop", batDir: "R", batOrder: 1, team: team)

            context.insert(team)
            context.insert(player)
            try context.save()

            fixtureTeam = team
            modelContainer = container
        } catch {
            print("Failed to create player roster fixture container: \(error)")
        }
    }
}
