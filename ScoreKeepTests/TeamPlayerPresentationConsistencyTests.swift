import Foundation
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Team and player form presentation consistency")
struct TeamPlayerPresentationConsistencyTests {
    @Test("iPad standard Add Team routes present as sheets while iPhone keeps push route")
    func standardAddTeamRoutesUseSheetOnIPadAndPushOnIPhone() throws {
        let contentView = try source("ScoreKeep/Content Views/ContentView.swift")
        let teamContentView = try source("ScoreKeep/Content Views/TeamContentView.swift")

        for routeSource in [contentView, teamContentView] {
            #expect(routeSource.contains("@State private var showingAddTeamDraft = false"))
            #expect(routeSource.contains("private func presentAddTeam()"))
            #expect(routeSource.contains("if UIDevice.type == \"iPhone\""))
            #expect(routeSource.contains("path.append(AddTeamNavigationDestination())"))
            #expect(routeSource.contains("showingAddTeamDraft = true"))
            #expect(routeSource.contains(".sheet(isPresented: $showingAddTeamDraft)"))
            #expect(routeSource.contains("NavigationStack {\n"))
            #expect(routeSource.contains("AddTeamDraftView { team in"))
            #expect(routeSource.contains("path.append(TeamNavigationDestination(teamIdentity: team.ident))"))
        }

        let scoreContentView = try source("ScoreKeep/Content Views/ScoreContentView.swift")
        #expect(scoreContentView.contains("@State private var showingAddTeamDraft = false") == false)
        #expect(scoreContentView.contains("private func presentAddTeam()") == false)
        #expect(scoreContentView.contains(".sheet(isPresented: $showingAddTeamDraft)") == false)
    }

    @Test("standard iPhone Add Team navigation still transitions through Add destination to Edit Team")
    func standardIPhoneAddTeamNavigationStillTransitionsToEditTeam() throws {
        let contentView = try source("ScoreKeep/Content Views/ContentView.swift")
        let teamContentView = try source("ScoreKeep/Content Views/TeamContentView.swift")

        for routeSource in [contentView, teamContentView] {
            #expect(routeSource.contains(".navigationDestination(for: AddTeamNavigationDestination.self)"))
            #expect(routeSource.contains("AddTeamDraftView(dismissAfterCreation: false) { team in"))
            #expect(routeSource.contains("path.removeLast()"))
            #expect(routeSource.contains("path.append(TeamNavigationDestination(teamIdentity: team.ident))"))
        }

        let scoreContentView = try source("ScoreKeep/Content Views/ScoreContentView.swift")
        #expect(scoreContentView.contains(".navigationDestination(for: AddTeamNavigationDestination.self)") == false)
    }

    @Test("Edit Game and Paste Add Team sheets preserve caller-specific handoff")
    func editGameAndPasteAddTeamSheetsPreserveReturnCallbacks() throws {
        let editGameView = try source("ScoreKeep/Edit Data/EditGameView.swift")
        let pasteView = try source("ScoreKeep/Player org/PasteView.swift")

        #expect(editGameView.contains(".sheet(isPresented: $showingAddTeam, onDismiss:"))
        #expect(editGameView.contains("AddTeamDraftView { createdTeam in"))
        #expect(editGameView.contains("assignCreatedTeam(createdTeam)"))
        #expect(pasteView.contains(".sheet(isPresented: $showingAddTeam)"))
        #expect(pasteView.contains("AddTeamDraftView { createdTeam in"))
        #expect(pasteView.contains("selectCreatedTeam(createdTeam)"))
    }

    @Test("Game screen no longer exposes general Add Team toolbar route")
    func gameScreenNoLongerExposesGeneralAddTeamToolbarRoute() throws {
        let scoreContentView = try source("ScoreKeep/Content Views/ScoreContentView.swift")

        #expect(scoreContentView.contains("// Leading: Add Team") == false)
        #expect(scoreContentView.contains("private func addTeamToolbarButton()") == false)
        #expect(scoreContentView.contains("Button(\"Add Team\")") == false)
        #expect(scoreContentView.contains(".navigationDestination(for: AddTeamNavigationDestination.self)") == false)
    }

    @Test("Team editable fields use same lightweight field language as Player")
    func teamEditableFieldsUseSameLightweightFieldLanguageAsPlayer() throws {
        let teamForm = try source("ScoreKeep/Common/AddTeamDraftView.swift")
        let playerForm = try source("ScoreKeep/Common/PlayerFormDraftView.swift")

        #expect(teamForm.contains("TextField(\"Name\", text: $draft.name"))
        #expect(teamForm.contains("TextField(\"Coach\", text: $draft.coach"))
        #expect(teamForm.contains("TextField(\"Details\", text: $draft.details, prompt: scorebookInputPrompt(\"Details\"), axis: .vertical)"))
        #expect(teamForm.components(separatedBy: ".teamEditableTextField()").count - 1 == 3)
        #expect(teamForm.contains("func teamEditableTextField() -> some View"))
        #expect(teamForm.contains(".textFieldStyle(.roundedBorder)"))
        #expect(teamForm.contains(".scorebookInputField()"))
        #expect(teamForm.contains(".frame(maxWidth: .infinity)"))
        #expect(teamForm.contains(".lineLimit(4...8)"))
        #expect(teamForm.contains(".accessibilityIdentifier(\"team_name_field\")"))
        #expect(teamForm.contains(".accessibilityIdentifier(\"team_coach_field\")"))
        #expect(teamForm.contains(".accessibilityIdentifier(\"team_details_field\")"))

        #expect(playerForm.contains("func playerEditableTextField() -> some View"))
        #expect(playerForm.contains(".textFieldStyle(.roundedBorder)"))
        #expect(playerForm.contains(".scorebookInputField()"))
        #expect(playerForm.contains(".frame(maxWidth: .infinity)"))
    }

    @Test("Add Player remains sheet style on both ordinary roster hosts")
    func addPlayerRemainsSheetStyleOnOrdinaryRosterHosts() throws {
        let playerView = try source("ScoreKeep/List Data/PlayerView.swift")
        let playersOnTeamView = try source("ScoreKeep/List Data/PlayersOnTeamView.swift")

        #expect(playerView.contains(".sheet(isPresented: $showingAddPlayerDraft)"))
        #expect(playerView.contains("NavigationStack {\n                        AddPlayerDraftView(team: pTeam)"))
        #expect(playersOnTeamView.contains(".sheet(isPresented: $showingAddPlayerDraft)"))
        #expect(playersOnTeamView.contains("NavigationStack {\n                    AddPlayerDraftView(team: team)"))
    }

    private func source(_ relativePath: String) throws -> String {
        try StableIdentityAndOrderingTestSupport.repositorySource(relativePath)
    }
}
