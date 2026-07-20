import SwiftUI
import SwiftData

struct ScoreKeepUITestDynamicTypeSeamView: View {
    @State private var columnVisability: NavigationSplitViewVisibility = .automatic
    @State private var modelContainer: ModelContainer?
    
    var body: some View {
        Group {
            if let container = modelContainer, let game = fixtureGame {
                SeamFixtureHost(game: game, columnVisability: $columnVisability)
                    .modelContainer(container)
            } else {
                Text("Preparing fixture...")
                    .onAppear {
                        prepareFixture()
                    }
            }
        }
    }
    
    @State private var fixtureGame: Game?
    
    @MainActor
    private func prepareFixture() {
        let schema = Schema([Game.self, Team.self, Player.self, Atbat.self, Pitcher.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext
            
            let vTeam = Team(name: "Visitors", coach: "", details: "")
            let hTeam = Team(name: "Home", coach: "", details: "")
            let game = Game(date: "2026-07-20", location: "Test Field", highLights: "", hscore: 0, vscore: 0)
            game.vteam = vTeam
            game.hteam = hTeam
            
            let p1 = Player(name: "Alice", number: "1", position: "SS", batDir: "R", batOrder: 1)
            p1.team = vTeam
            
            let atbat = Atbat(game: game, team: vTeam, player: p1, result: "Result", maxbase: "No Bases", batOrder: 1, outAt: "Safe", inning: 1, seq: 1, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
            
            context.insert(vTeam)
            context.insert(hTeam)
            context.insert(p1)
            context.insert(game)
            context.insert(atbat)
            
            try context.save()
            
            self.fixtureGame = game
            self.modelContainer = container
        } catch {
            print("Failed to create in-memory fixture container: \(error)")
        }
    }
}

private struct SeamFixtureHost: View {
    var game: Game
    @Binding var columnVisability: NavigationSplitViewVisibility
    @State private var lAtbats: [Atbat] = []
    @State private var isLoading = false
    @State private var hasChanged = false
    
    var body: some View {
        if let team = game.vteam {
            PlayersToScoreViewWrapper(
                game: game,
                teamName: team.name,
                lAtbats: $lAtbats,
                columnVisability: $columnVisability
            )
        } else {
            Text("No game found in fixture")
        }
    }
}

private struct PlayersToScoreViewWrapper: View {
    @State var game: Game
    var teamName: String
    @Binding var lAtbats: [Atbat]
    @Binding var columnVisability: NavigationSplitViewVisibility
    @State private var isLoading = false
    @State private var hasChanged = false
    
    var body: some View {
        PlayersToScoreView(
            passedGame: $game,
            teamName: teamName,
            theAtbats: $lAtbats,
            isLoading: $isLoading,
            hasChanged: $hasChanged,
            columnVisability: $columnVisability
        )
    }
}
