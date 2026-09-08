import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Standard ordinary roster player draft flow")
struct StandardPlayerRosterDraftFlowTests {
    @Test("add draft creates no player before save")
    func addDraftCreatesNoPlayerBeforeSave() throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let context = ModelContext(container)
        let team = Team(name: "Draft Team", coach: "", details: "")
        context.insert(team)
        try context.save()

        _ = PlayerFormDraft.empty(for: team)
        let addSource = try repositorySource("ScoreKeep/Common/AddPlayerDraftView.swift")
        let iPhoneSource = try repositorySource("ScoreKeep/List Data/PlayerView.swift")
        let iPadSource = try repositorySource("ScoreKeep/List Data/PlayersOnTeamView.swift")

        #expect(try playerCount(in: container) == 0)
        #expect(addSource.contains("modelContext.insert(player)"))
        #expect(addSource.contains("Button(\"Save\", action: savePlayer)"))
        #expect(iPhoneSource.contains("AddPlayerDraftView(team: pTeam)"))
        #expect(iPadSource.contains("AddPlayerDraftView(team: team)"))
    }

    @Test("save creates exactly one populated player")
    func saveCreatesExactlyOnePopulatedPlayer() throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let context = ModelContext(container)
        let team = Team(name: "Roster Team", coach: "", details: "")
        context.insert(team)
        let draft = PlayerFormDraft(
            name: " Casey Jones ",
            number: "12",
            position: "ss",
            batDir: "R",
            batOrder: 3,
            teamIdentity: team.ident,
            teamName: team.name,
            photoData: Data([1, 2, 3])
        )
        let validation = PlayerDraftValidation.validate(playerName: draft.name)
        let player = Player(
            name: validation.trimmedName,
            number: draft.number,
            position: draft.normalizedPosition,
            batDir: draft.batDir,
            batOrder: PlayerRosterBattingOrder.normalizedRosterOrder(draft.batOrder),
            team: team,
            photo: draft.photoData
        )

        context.insert(player)
        try context.save()
        let players = try fetchPlayers(in: container)

        #expect(players.count == 1)
        #expect(players.first?.name == "Casey Jones")
        #expect(players.first?.number == "12")
        #expect(players.first?.position == "Shortstop")
        #expect(players.first?.batDir == "R")
        #expect(players.first?.batOrder == 3)
        #expect(players.first?.team?.ident == team.ident)
        #expect(players.first?.photo == Data([1, 2, 3]))
    }

    @Test("cancel and dirty back protection are explicit")
    func cancelAndDirtyBackProtectionAreExplicit() throws {
        let addSource = try repositorySource("ScoreKeep/Common/AddPlayerDraftView.swift")
        let editSource = try repositorySource("ScoreKeep/Edit Data/EditPlayerView.swift")
        let dirtyDraft = PlayerFormDraft(
            name: "New Player",
            number: "",
            position: "",
            batDir: "",
            batOrder: 99,
            teamIdentity: UUID(),
            teamName: "Team"
        )

        #expect(dirtyDraft.hasMeaningfulChanges)
        #expect(addSource.contains("Discard New Player?"))
        #expect(addSource.contains("Button(\"Discard New Player\", role: .destructive)"))
        #expect(addSource.contains("Button(\"Keep Editing\", role: .cancel) { }"))
        #expect(editSource.contains("Button(\"Save Changes\")"))
        #expect(editSource.contains("Button(\"Discard Changes\", role: .destructive)"))
        #expect(editSource.contains("Button(\"Keep Editing\", role: .cancel) { }"))
        #expect(editSource.contains("onDisappear") == false)
    }

    @Test("empty name cannot save")
    func emptyNameCannotSave() {
        let validation = PlayerDraftValidation.validate(playerName: "  \n")

        #expect(validation.canSave == false)
        #expect(validation.message == "Enter a player name before saving the player.")
    }

    @Test("duplicate choices preserve model counts and expected result")
    func duplicateChoicesPreserveModelCountsAndExpectedResult() throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let context = ModelContext(container)
        let team = Team(name: "Duplicate Team", coach: "", details: "")
        let existing = Player(name: "Sam Lee", number: "8", position: "Second Baseman", batDir: "L", batOrder: 2, team: team)
        context.insert(team)
        context.insert(existing)
        try context.save()

        let match = try #require(RosterImportReconciler.likelyMatchingPlayer(name: "Sam Lee", number: "8", in: fetchPlayers(in: container)))
        let useExisting = RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .useExistingPlayer,
            matchedPlayer: match,
            name: "Sam Lee",
            number: "88",
            position: "SS",
            batDir: "R",
            preserveHistoricalEvidence: false
        )
        let updateExisting = RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .updateExistingPlayer,
            matchedPlayer: match,
            name: "Sam Lee",
            number: "88",
            position: "SS",
            batDir: "R",
            preserveHistoricalEvidence: false
        )
        let createNew = RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .createNewPlayerAnyway,
            matchedPlayer: match,
            name: "Sam Lee",
            number: "88",
            position: "SS",
            batDir: "R",
            preserveHistoricalEvidence: false
        )
        let cancel = RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .cancel,
            matchedPlayer: match,
            name: "Sam Lee",
            number: "88",
            position: "SS",
            batDir: "R",
            preserveHistoricalEvidence: false
        )

        #expect(useExisting.shouldUseExistingPlayer)
        #expect(updateExisting.didUpdateExistingPlayer)
        #expect(createNew.shouldCreateNewPlayer)
        #expect(cancel.shouldUseExistingPlayer == false)
        #expect(cancel.shouldCreateNewPlayer == false)
        #expect(try playerCount(in: container) == 1)
        #expect(match.number == "88")
        #expect(match.position == "Shortstop")
    }

    @Test("photo selected or pasted in add persists only on save and is discardable")
    func photoSelectedOrPastedInAddPersistsOnlyOnSaveAndIsDiscardable() throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let context = ModelContext(container)
        let team = Team(name: "Photo Team", coach: "", details: "")
        context.insert(team)
        try context.save()
        let photo = Data([9, 8, 7])
        var draft = PlayerFormDraft.empty(for: team)
        draft.name = "Photo Player"
        draft.photoData = photo
        let addSource = try repositorySource("ScoreKeep/Common/AddPlayerDraftView.swift")
        let formSource = try repositorySource("ScoreKeep/Common/PlayerFormDraftView.swift")

        #expect(try playerCount(in: container) == 0)
        #expect(draft.photoData == photo)
        #expect(formSource.contains("PhotosPicker(selection: $selectedPhotoItem, matching: .images)"))
        #expect(formSource.contains("selectedPhotoItem.loadTransferable(type: Data.self)"))
        #expect(formSource.contains("UIPasteboard.general.image"))
        #expect(addSource.contains("photo: draft.photoData"))
        #expect(addSource.contains("Button(\"Discard New Player\", role: .destructive)"))
    }

    @Test("compact landscape player form follows team media left fields right pattern")
    func compactLandscapePlayerFormFollowsTeamMediaLeftFieldsRightPattern() throws {
        let formSource = try repositorySource("ScoreKeep/Common/PlayerFormDraftView.swift")
        let teamFormSource = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")

        #expect(formSource.contains("private var compactLayout: some View"))
        #expect(formSource.contains("GeometryReader { geometry in"))
        #expect(formSource.contains("useCompactHorizontalLayout(for: geometry.size)"))
        #expect(formSource.contains("HStack(alignment: .top, spacing: 14)"))
        #expect(formSource.contains("photoPreview\n                            .frame(width: 88, height: 88)"))
        #expect(formSource.contains("compactPhotoControls"))
        #expect(formSource.contains("compactHorizontalFieldsContent"))
        #expect(formSource.contains(".frame(width: 190)"))
        #expect(teamFormSource.contains("private var compactHorizontalLayout"))
    }

    @Test("compact player photo controls keep Photos and Paste labels on one line")
    func compactPlayerPhotoControlsKeepPhotosAndPasteLabelsOnOneLine() throws {
        let formSource = try repositorySource("ScoreKeep/Common/PlayerFormDraftView.swift")

        #expect(formSource.contains("private var compactPhotoControls"))
        #expect(formSource.contains("Label(\"Photos\", systemImage: \"photo.on.rectangle\")"))
        #expect(formSource.contains("Label(\"Paste\", systemImage: \"doc.on.doc\")"))
        #expect(formSource.contains(".labelStyle(.titleAndIcon)"))
        #expect(formSource.contains(".font(.subheadline)"))
        #expect(formSource.contains(".lineLimit(1)"))
        #expect(formSource.contains(".controlSize(.small)"))
        #expect(formSource.contains(".frame(minWidth: 82)"))
        #expect(formSource.contains(".fixedSize(horizontal: true, vertical: false)"))
    }

    @Test("player form keeps all roster fields visible in compact horizontal layout")
    func playerFormKeepsAllRosterFieldsVisibleInCompactHorizontalLayout() throws {
        let formSource = try repositorySource("ScoreKeep/Common/PlayerFormDraftView.swift")

        #expect(formSource.contains("private var compactHorizontalFieldsContent"))
        #expect(formSource.contains("nameField"))
        #expect(formSource.contains("numberField"))
        #expect(formSource.contains("positionField"))
        #expect(formSource.contains("battingDirectionField"))
        #expect(formSource.contains("battingOrderPicker"))
        #expect(formSource.contains("teamControl"))
        #expect(formSource.contains("LabeledContent(\"Team\", value: draft.teamName.isEmpty ? \"Unknown Team\" : draft.teamName)"))
    }

    @Test("editable player text fields use visible lightweight field affordance")
    func editablePlayerTextFieldsUseVisibleLightweightFieldAffordance() throws {
        let formSource = try repositorySource("ScoreKeep/Common/PlayerFormDraftView.swift")

        #expect(formSource.contains("TextField(\"Name\", text: $draft.name"))
        #expect(formSource.contains("TextField(\"Number\", text: $draft.number"))
        #expect(formSource.contains("TextField(\"Position\", text: $draft.position"))
        #expect(formSource.contains("TextField(\"Batting Direction\", text: $draft.batDir"))
        #expect(formSource.components(separatedBy: ".playerEditableTextField()").count - 1 == 4)
        #expect(formSource.contains("private extension View"))
        #expect(formSource.contains("func playerEditableTextField() -> some View"))
        #expect(formSource.contains(".textFieldStyle(.roundedBorder)"))
        #expect(formSource.contains(".scorebookInputField()"))
        #expect(formSource.contains(".frame(maxWidth: .infinity)"))
        #expect(formSource.contains(".accessibilityIdentifier(\"player_name_field\")"))
        #expect(formSource.contains(".accessibilityIdentifier(\"player_number_field\")"))
        #expect(formSource.contains(".accessibilityIdentifier(\"player_position_field\")"))
        #expect(formSource.contains(".accessibilityIdentifier(\"player_batting_direction_field\")"))
        #expect(formSource.contains("private var battingOrderPicker"))
        #expect(formSource.contains(".accessibilityIdentifier(\"player_batting_order_picker\")"))
        #expect(formSource.contains("LabeledContent(\"Team\", value: draft.teamName.isEmpty ? \"Unknown Team\" : draft.teamName)"))
    }

    @Test("edit loads all current values")
    func editLoadsAllCurrentValues() {
        let team = Team(name: "Loaded Team", coach: "", details: "")
        let photo = Data([4, 5, 6])
        let player = Player(name: "Loaded Player", number: "24", position: "Catcher", batDir: "S", batOrder: 5, team: team, photo: photo)
        let draft = PlayerFormDraft(player: player, fallbackTeam: team)

        #expect(draft.name == "Loaded Player")
        #expect(draft.number == "24")
        #expect(draft.position == "Catcher")
        #expect(draft.batDir == "S")
        #expect(draft.batOrder == 5)
        #expect(draft.teamIdentity == team.ident)
        #expect(draft.photoData == photo)
    }

    @Test("edit save persists all draft changes through explicit save")
    func editSavePersistsAllDraftChangesThroughExplicitSave() throws {
        let editSource = try repositorySource("ScoreKeep/Edit Data/EditPlayerView.swift")

        #expect(editSource.contains("player.name = validation.trimmedName"))
        #expect(editSource.contains("player.number = draft.number"))
        #expect(editSource.contains("player.position = draft.normalizedPosition"))
        #expect(editSource.contains("player.batDir = draft.batDir"))
        #expect(editSource.contains("player.batOrder = PlayerRosterBattingOrder.normalizedRosterOrder(draft.batOrder)"))
        #expect(editSource.contains("player.team = selectedTeamForDraft()"))
        #expect(editSource.contains("player.photo = draft.photoData"))
        #expect(editSource.contains("try modelContext.save()"))
    }

    @Test("team batting order and photo do not mutate persisted player before save")
    func teamBattingOrderAndPhotoDoNotMutatePersistedPlayerBeforeSave() throws {
        let team = Team(name: "Original", coach: "", details: "")
        let otherTeam = Team(name: "Other", coach: "", details: "")
        let player = Player(name: "Original Player", number: "1", position: "P", batDir: "R", batOrder: 1, team: team, photo: Data([1]))
        var draft = PlayerFormDraft(player: player, fallbackTeam: team)
        draft.batOrder = 9
        draft.teamIdentity = otherTeam.ident
        draft.teamName = otherTeam.name
        draft.photoData = Data([2])
        let editSource = try repositorySource("ScoreKeep/Edit Data/EditPlayerView.swift")
        let formSource = try repositorySource("ScoreKeep/Common/PlayerFormDraftView.swift")

        #expect(player.batOrder == 1)
        #expect(player.team?.ident == team.ident)
        #expect(player.photo == Data([1]))
        #expect(formSource.contains("Picker(\"Team\", selection: $draft.teamIdentity)"))
        #expect(editSource.contains("Picker(\"Bat Order\", selection: $player.batOrder)") == false)
        #expect(editSource.contains("Picker(\"Player Team\", selection: $player.team)") == false)
        #expect(editSource.contains("player.photo = image.pngData()") == false)
    }

    @Test("position normalization is preserved")
    func positionNormalizationIsPreserved() {
        let draft = PlayerFormDraft(
            name: "Position Player",
            number: "",
            position: "1b",
            batDir: "",
            batOrder: 99,
            teamIdentity: UUID(),
            teamName: "Team"
        )

        #expect(draft.normalizedPosition == "First Baseman")
    }

    @Test("iPhone and iPad ordinary roster add use the same creation semantics")
    func iPhoneAndIPadOrdinaryRosterAddUseSameCreationSemantics() throws {
        let iPhoneSource = try repositorySource("ScoreKeep/List Data/PlayerView.swift")
        let iPadListSource = try repositorySource("ScoreKeep/List Data/PlayersOnTeamView.swift")
        let editTeamSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")
        let addSource = try repositorySource("ScoreKeep/Common/AddPlayerDraftView.swift")

        #expect(iPhoneSource.contains("AddPlayerDraftView(team: pTeam)"))
        #expect(editTeamSource.contains("usesStandardPlayerAdd: true"))
        #expect(iPadListSource.contains("usesStandardPlayerAdd"))
        #expect(addSource.contains("PlayerRosterBattingOrder.normalizedRosterOrder(draft.batOrder)"))
        #expect(iPhoneSource.contains("createPendingPlayer()") == false)
    }

    @Test("iPhone team players uses isolated player navigation path")
    func iPhoneTeamPlayersUsesIsolatedPlayerNavigationPath() throws {
        let iPhoneSource = try repositorySource("ScoreKeep/List Data/PlayerView.swift")
        let editTeamSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")

        #expect(editTeamSource.contains("PlayerView(team: team, navigationPath: $navigationPath, searchString: $searchText)"))
        #expect(iPhoneSource.contains("@State private var playerNavigationPath = NavigationPath()"))
        #expect(iPhoneSource.contains("NavigationStack(path: $playerNavigationPath)"))
        #expect(iPhoneSource.contains("EditPlayerView(player: player, team: pTeam, navigationPath: $playerNavigationPath)"))
        #expect(iPhoneSource.contains("NavigationStack(path: $navigationPath)") == false)
    }

    @Test("iPad team players remains embedded in edit team navigation")
    func iPadTeamPlayersRemainsEmbeddedInEditTeamNavigation() throws {
        let iPadListSource = try repositorySource("ScoreKeep/List Data/PlayersOnTeamView.swift")
        let editTeamSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")

        #expect(editTeamSource.contains("if UIDevice.type != \"iPhone\""))
        #expect(editTeamSource.contains("PlayersOnTeamView(team: team, searchString: searchText, sortOrder: sortDescriptor, usesStandardPlayerAdd: true)"))
        #expect(editTeamSource.contains(".navigationDestination(for: Player.self) { player in"))
        #expect(iPadListSource.contains("NavigationStack(path: $navigationPath)") == false)
    }

    @Test("existing team draft workflow remains unchanged")
    func existingTeamDraftWorkflowRemainsUnchanged() throws {
        let addTeamSource = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")
        let editTeamSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")

        #expect(addTeamSource.contains("struct TeamFormDraft"))
        #expect(addTeamSource.contains("TeamFormContent(draft: $draft)"))
        #expect(addTeamSource.contains("SimpleTeamCreationSubmission("))
        #expect(editTeamSource.contains("TeamFormContent(draft: $draft)"))
    }

    @Test("out of scope player creation paths are not opted into standard ordinary add")
    func outOfScopePlayerCreationPathsAreNotOptedIntoStandardOrdinaryAdd() throws {
        let lineupSource = try repositorySource("ScoreKeep/Player org/StartingLineupView.swift")
        let pasteSource = try repositorySource("ScoreKeep/Player org/PasteView.swift")
        let importSource = try repositorySource("ScoreKeep/Sharing Data/ImportPlayersView.swift")

        #expect(lineupSource.contains("AddPlayerDraftView") == false)
        #expect(pasteSource.contains("AddPlayerDraftView") == false)
        #expect(importSource.contains("AddPlayerDraftView") == false)
    }

    @Test("replacement screen uses toolbar add player draft without quick entry row")
    func replacementScreenUsesToolbarAddPlayerDraftWithoutQuickEntryRow() throws {
        let replacementSource = try repositorySource("ScoreKeep/Player org/ReplacementView.swift")
        let playersOnTeamSource = try repositorySource("ScoreKeep/List Data/PlayersOnTeamView.swift")

        #expect(replacementSource.contains("PlayersOnTeamView(team: team, searchString: searchText, sortOrder: sortOrder, showsQuickAddRow: false)"))
        #expect(replacementSource.contains("ToolbarItemGroup(placement: .topBarLeading)"))
        #expect(replacementSource.contains("ToolbarItemGroup(placement: .topBarTrailing)"))
        #expect(replacementSource.contains("Button(\"Add Player\", systemImage: \"plus\", action: addPlayers)"))
        #expect(replacementSource.contains("TextField(\"Player name or number\", text: $searchText)"))
        #expect(replacementSource.contains(".searchable(if: UIDevice.type == \"iPhone\" && isSearching"))
        let searchButtonPosition = try #require(replacementSource.range(of: "Image(systemName: \"magnifyingglass\")")?.lowerBound)
        let addPlayerButtonPosition = try #require(replacementSource.range(of: "Button(\"Add Player\", systemImage: \"plus\", action: addPlayers)")?.lowerBound)
        #expect(searchButtonPosition < addPlayerButtonPosition)
        #expect(replacementSource.contains("AddPlayerDraftView(team: team)"))
        #expect(replacementSource.contains("func addPlayers() {\n        showingAddPlayerDraft = true\n    }"))
        #expect(replacementSource.contains("modelContext.insert(player)") == false)
        #expect(playersOnTeamSource.contains("let showsQuickAddRow: Bool"))
        #expect(playersOnTeamSource.contains("} else if showsQuickAddRow {"))
    }

    @Test("pitcher screen uses trailing add player draft after search without forcing pitcher position")
    func pitcherScreenUsesTrailingAddPlayerDraftAfterSearchWithoutForcingPitcherPosition() throws {
        let pitcherSource = try repositorySource("ScoreKeep/Content Views/PitcherContentView.swift")
        let staffSource = try repositorySource("ScoreKeep/Player org/PitchersStaffView.swift")

        #expect(pitcherSource.contains("ToolbarItemGroup(placement: .topBarLeading)"))
        #expect(pitcherSource.contains("ToolbarItemGroup(placement: .topBarTrailing)"))
        #expect(pitcherSource.contains("Menu(\"Sort\", systemImage: \"arrow.up.arrow.down\")"))
        #expect(pitcherSource.contains("if UIDevice.type == \"iPad\" {\n                        pitcherFilterPicker\n                    }"))
        #expect(pitcherSource.contains("if UIDevice.type == \"iPhone\" {\n                        Button(action: {\n                            withAnimation {\n                                isSearching.toggle()"))
        #expect(pitcherSource.contains("ToolbarItemGroup(placement: .topBarTrailing) {\n                    if UIDevice.type == \"iPhone\" {\n                        pitcherFilterPicker"))
        #expect(pitcherSource.contains("private var pitcherFilterControl") == false)
        #expect(pitcherSource.contains("TextField(\"Player name or number\", text: $searchText)"))
        #expect(pitcherSource.contains(".minimumScaleFactor(0.8)"))
        #expect(pitcherSource.contains(".frame(width: UIDevice.type == \"iPad\" ? 220 : 180)"))
        #expect(pitcherSource.contains(".searchable(if: UIDevice.type == \"iPhone\" && isSearching"))
        #expect(pitcherSource.contains("Button(\"Add Player\", systemImage: \"plus\", action: addPlayers)"))
        let searchFieldPosition = try #require(pitcherSource.range(of: "TextField(\"Player name or number\", text: $searchText)")?.lowerBound)
        let addPlayerButtonPosition = try #require(pitcherSource.range(of: "Button(\"Add Player\", systemImage: \"plus\", action: addPlayers)")?.lowerBound)
        #expect(searchFieldPosition < addPlayerButtonPosition)
        #expect(pitcherSource.contains("AddPlayerDraftView(team: team)"))
        #expect(pitcherSource.contains("func addPlayers() {\n        showingAddPlayerDraft = true\n    }"))
        #expect(pitcherSource.contains("Player(name: \"\", number: \"\",  position: \"\", batDir: \"\", batOrder: 99,team: team)") == false)
        #expect(pitcherSource.contains("position: \"P\"") == false)
        #expect(pitcherSource.contains("position: \"SP\"") == false)
        #expect(pitcherSource.contains("position: \"RP\"") == false)
        #expect(staffSource.contains("@State var pName = \"Not Selected Yet\""))
        #expect(staffSource.contains("Button(\"Delete\")"))
    }

    @Test("pitcher title is owned by parent toolbar so asymmetric controls do not pull it from screen center")
    func pitcherTitleIsOwnedByParentToolbarSoAsymmetricControlsDoNotPullItFromScreenCenter() throws {
        let pitcherSource = try repositorySource("ScoreKeep/Content Views/PitcherContentView.swift")
        let staffSource = try repositorySource("ScoreKeep/Player org/PitchersStaffView.swift")

        #expect(pitcherSource.contains("ToolbarItem(placement: .principal)"))
        #expect(pitcherSource.contains("Text(\"Select who will pitch\")"))
        #expect(pitcherSource.contains(".frame(width: UIScreen.main.bounds.width)"))
        #expect(pitcherSource.contains(".allowsHitTesting(false)"))
        #expect(staffSource.contains("ToolbarItem(placement: .principal)") == false)
        #expect(staffSource.contains("Text(\"Select who will pitch\")") == false)
    }

    private func playerCount(in container: ModelContainer) throws -> Int {
        try fetchPlayers(in: container).count
    }

    private func fetchPlayers(in container: ModelContainer) throws -> [Player] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<Player>())
    }

    private func repositorySource(_ relativePath: String) throws -> String {
        try StableIdentityAndOrderingTestSupport.repositorySource(relativePath)
    }
}
