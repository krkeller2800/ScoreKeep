import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Standard team creation draft flow")
struct StandardTeamCreationDraftFlowTests {
    @Test("add save creates exactly one team with all fields")
    func addSaveCreatesExactlyOneTeamWithAllFields() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let service = proposedService(container: container)
        let logoData = Data([1, 2, 3, 4])
        let submission = SimpleTeamCreationSubmission(
            operationIdentity: CanonicalTeamCreationOperationIdentity("standard-draft-save-op"),
            teamIdentity: UUID(uuidString: "11111111-2222-4333-8444-555555555555")!,
            teamName: "Standard Draft Team",
            coach: "Coach Draft",
            details: "Created from Add Team draft",
            logoData: logoData
        )

        let outcome = await service.submit(submission)
        let teams = try IsolatedVersionedTeamCreationEvidenceSupport.observedTeams(from: container)

        #expect(outcome.disposition == .created)
        #expect(teams == [TeamCreationObservedTeam(identity: submission.teamIdentity, name: submission.teamName, coach: submission.coach, details: submission.details)])
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.firstTeamLogo(in: container) == logoData)
    }

    @Test("add logo from Photos persists logo through draft save path")
    func addLogoFromPhotosPersistsLogoThroughDraftSavePath() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let service = proposedService(container: container)
        let logoData = Data("photos-logo".utf8)
        let submission = SimpleTeamCreationSubmission(
            operationIdentity: CanonicalTeamCreationOperationIdentity("standard-draft-photos-logo-op"),
            teamIdentity: UUID(uuidString: "22222222-3333-4444-8555-666666666666")!,
            teamName: "Photos Logo Team",
            coach: "",
            details: "",
            logoData: logoData
        )

        let outcome = await service.submit(submission)
        let formSource = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")

        #expect(formSource.contains("PhotosPicker(selection: $selectedLogoItem, matching: .images)"))
        #expect(formSource.contains("selectedLogoItem.loadTransferable(type: Data.self)"))
        #expect(outcome.disposition == .created)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.firstTeamLogo(in: container) == logoData)
    }

    @Test("add pasted logo persists logo through draft save path")
    func addPastedLogoPersistsLogoThroughDraftSavePath() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let service = proposedService(container: container)
        let logoData = Data("pasted-logo".utf8)
        let submission = SimpleTeamCreationSubmission(
            operationIdentity: CanonicalTeamCreationOperationIdentity("standard-draft-pasted-logo-op"),
            teamIdentity: UUID(uuidString: "33333333-4444-4555-8666-777777777777")!,
            teamName: "Pasted Logo Team",
            coach: "",
            details: "",
            logoData: logoData
        )

        let outcome = await service.submit(submission)
        let formSource = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")

        #expect(formSource.contains("UIPasteboard.general.image"))
        #expect(formSource.contains("draft.logoData = data"))
        #expect(outcome.disposition == .created)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.firstTeamLogo(in: container) == logoData)
    }

    @Test("add draft exposes no players before save")
    func addDraftExposesNoPlayersBeforeSave() throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")

        #expect(source.contains("struct AddTeamDraftView"))
        #expect(source.contains("Button(\"Players\")") == false)
        #expect(source.contains("PlayersOnTeamView") == false)
        #expect(source.contains("PlayerView(") == false)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.teamCount(in: container) == 0)
    }

    @Test("untouched add back dismisses without alert and creates nothing")
    func untouchedAddBackDismissesWithoutAlertAndCreatesNothing() throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")
        let untouchedDraft = TeamFormDraft.empty

        #expect(untouchedDraft.hasMeaningfulChanges == false)
        #expect(source.contains(".navigationBarBackButtonHidden(true)"))
        #expect(source.contains("Button(\"Back\")"))
        #expect(source.contains("dismissOrConfirmDiscard()"))
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.teamCount(in: container) == 0)
    }

    @Test("add has no cancel affordance")
    func addHasNoCancelAffordance() throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")
        let untouchedDraft = TeamFormDraft(name: "   ", coach: "\n", details: "\t", logoData: nil)

        #expect(untouchedDraft.hasMeaningfulChanges == false)
        #expect(source.contains("Button(\"Cancel\")") == false)
        #expect(source.contains("Cancel team creation") == false)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.teamCount(in: container) == 0)
    }

    @Test("add back or dismiss without save creates no team")
    func addBackOrDismissWithoutSaveCreatesNoTeam() throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")

        #expect(source.contains("modelContext.insert") == false)
        #expect(source.contains("TeamFormDraft.empty"))
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.teamCount(in: container) == 0)
    }

    @Test("modified add back requires confirmation")
    func modifiedAddBackRequiresConfirmation() throws {
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")
        let nameDraft = TeamFormDraft(name: "Falcons", coach: "", details: "", logoData: nil)
        let coachDraft = TeamFormDraft(name: "", coach: "Coach", details: "", logoData: nil)
        let detailsDraft = TeamFormDraft(name: "", coach: "", details: "Details", logoData: nil)
        let logoDraft = TeamFormDraft(name: "", coach: "", details: "", logoData: Data([1]))

        #expect(nameDraft.hasMeaningfulChanges)
        #expect(coachDraft.hasMeaningfulChanges)
        #expect(detailsDraft.hasMeaningfulChanges)
        #expect(logoDraft.hasMeaningfulChanges)
        #expect(source.contains("Button(\"Back\")"))
        #expect(source.contains("dismissOrConfirmDiscard()"))
        #expect(source.contains("showingUnsavedNewTeamAlert = true"))
        #expect(source.contains(".navigationBarBackButtonHidden(true)"))
    }

    @Test("dirty add back warning uses discard new team and keep editing")
    func dirtyAddBackWarningUsesDiscardNewTeamAndKeepEditing() throws {
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")

        #expect(source.contains("Button(\"Back\")"))
        #expect(source.contains("dismissOrConfirmDiscard()"))
        #expect(source.contains("showingUnsavedNewTeamAlert = true"))
        #expect(source.contains("Discard New Team?"))
        #expect(source.contains("Button(\"Discard New Team\", role: .destructive)"))
        #expect(source.contains("Button(\"Keep Editing\", role: .cancel) { }"))
    }

    @Test("discard new team creates nothing and dismisses")
    func discardNewTeamCreatesNothingAndDismisses() throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")

        #expect(source.contains("Button(\"Discard New Team\", role: .destructive)"))
        #expect(source.contains("dismiss()"))
        #expect(source.contains("modelContext.insert") == false)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.teamCount(in: container) == 0)
    }

    @Test("keep editing preserves all add draft fields including logo")
    func keepEditingPreservesAllAddDraftFieldsIncludingLogo() throws {
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")
        let draft = TeamFormDraft(name: "Falcons", coach: "Coach", details: "Details", logoData: Data([7, 8, 9]))

        #expect(draft.hasMeaningfulChanges)
        #expect(draft.name == "Falcons")
        #expect(draft.coach == "Coach")
        #expect(draft.details == "Details")
        #expect(draft.logoData == Data([7, 8, 9]))
        #expect(source.contains("Button(\"Keep Editing\", role: .cancel) { }"))
    }

    @Test("add save behavior remains unchanged")
    func addSaveBehaviorRemainsUnchanged() throws {
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")

        #expect(source.contains("Button(\"Save\", action: saveTeam)"))
        #expect(source.contains("teamCreationRoutes.submit(submission)"))
        #expect(source.contains("SimpleTeamCreationSubmission("))
        #expect(source.contains("Button(\"Save Changes\")") == false)
    }

    @Test("add team has back and save without cancel")
    func addTeamHasBackAndSaveWithoutCancel() throws {
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")

        #expect(source.contains("ToolbarItem(placement: .topBarLeading)"))
        #expect(source.contains("Button(\"Back\")"))
        #expect(source.contains("ToolbarItem(placement: .confirmationAction)"))
        #expect(source.contains("Button(\"Save\", action: saveTeam)"))
        #expect(source.contains("Button(\"Cancel\")") == false)
        #expect(source.contains(".navigationBarBackButtonHidden(true)"))
    }

    @Test("iPhone compact landscape team form uses one horizontal composition")
    func iPhoneCompactLandscapeTeamFormUsesOneHorizontalComposition() throws {
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")

        #expect(source.contains("private var compactHorizontalLayout"))
        #expect(source.contains("useCompactHorizontalLayout(for: geometry.size)"))
        #expect(source.contains("HStack(alignment: .top, spacing: 14)"))
        #expect(source.contains("VStack(spacing: 8)"))
        #expect(source.contains("VStack(spacing: 10)"))
        #expect(source.contains("TextField(\"Name\""))
        #expect(source.contains("TextField(\"Coach\""))
        #expect(source.contains("TextField(\"Details\""))
        #expect(source.contains("logoPreview\n                            .frame(width: 88, height: 88)"))
    }

    @Test("compact logo controls keep Photos and Paste labels on one line")
    func compactLogoControlsKeepPhotosAndPasteLabelsOnOneLine() throws {
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")

        #expect(source.contains("private var compactLogoControls"))
        #expect(source.contains("Label(\"Photos\", systemImage: \"photo.on.rectangle\")"))
        #expect(source.contains("Label(\"Paste\", systemImage: \"doc.on.doc\")"))
        #expect(source.contains(".labelStyle(.titleAndIcon)"))
        #expect(source.contains(".font(.subheadline)"))
        #expect(source.contains(".lineLimit(1)"))
        #expect(source.contains(".controlSize(.small)"))
        #expect(source.contains(".frame(minWidth: 82)"))
        #expect(source.contains(".fixedSize(horizontal: true, vertical: false)"))
        #expect(source.contains("HStack(spacing: 8)"))
        #expect(source.contains("logoControls\n                    .frame(maxWidth: .infinity, alignment: .leading)") == false)
    }

    @Test("standard team add routes transition to edit after save")
    func standardTeamAddRoutesTransitionToEditAfterSave() throws {
        let sources = [
            try repositorySource("ScoreKeep/Content Views/TeamContentView.swift"),
            try repositorySource("ScoreKeep/Content Views/ContentView.swift"),
            try repositorySource("ScoreKeep/Content Views/ScoreContentView.swift")
        ].joined(separator: "\n")
        let editSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")

        #expect(sources.contains("AddTeamDraftView(dismissAfterCreation: false)"))
        #expect(sources.contains("path.removeLast()"))
        #expect(sources.contains("path.append(TeamNavigationDestination(teamIdentity: team.ident))"))
        #expect(editSource.contains("Button(\"Players\")"))
        #expect(editSource.contains("PlayerView(team: team"))
    }

    @Test("returning from players remains edit team without cancel")
    func returningFromPlayersRemainsEditTeamWithoutCancel() throws {
        let editSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")

        #expect(editSource.contains(".fullScreenCover(isPresented: $presentPlayers)"))
        #expect(editSource.contains("PlayerView(team: team, navigationPath: $navigationPath, searchString: $searchText)"))
        #expect(editSource.contains("Button(\"Cancel\")") == false)
        #expect(editSource.contains("navigationBarBackButtonHidden(hasUnsavedChanges)"))
    }

    @Test("duplicate name with logo selected creates nothing and preserves draft")
    func duplicateNameWithLogoSelectedCreatesNothingAndPreservesDraft() throws {
        let validation = AddTeamDraftValidation.validate(teamName: "Falcons", existingTeamNames: ["Falcons"])
        let source = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")

        #expect(validation.canSave == false)
        #expect(validation.message == "Falcons has already been created.")
        #expect(source.contains("Your entries are still here."))
        #expect(source.contains("draft.logoData") == true)
    }

    @Test("empty name cannot save")
    func emptyNameCannotSave() {
        let validation = AddTeamDraftValidation.validate(teamName: "   ", existingTeamNames: [])

        #expect(validation.canSave == false)
        #expect(validation.message == "Enter a team name before saving the team.")
    }

    @Test("edit existing team loads all current values")
    func editExistingTeamLoadsAllCurrentValues() {
        let logoData = Data([9, 8, 7])
        let team = Team(name: "Loaded", coach: "Coach", details: "Details", logo: logoData)
        let draft = TeamFormDraft(team: team)

        #expect(draft.name == "Loaded")
        #expect(draft.coach == "Coach")
        #expect(draft.details == "Details")
        #expect(draft.logoData == logoData)
    }

    @Test("edit save persists text and logo changes")
    func editSavePersistsTextAndLogoChanges() throws {
        let editSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")

        #expect(editSource.contains("team.name = validation.trimmedName"))
        #expect(editSource.contains("team.coach = draft.coach"))
        #expect(editSource.contains("team.details = draft.details"))
        #expect(editSource.contains("team.logo = draft.logoData"))
        #expect(editSource.contains("try modelContext.save()"))
    }

    @Test("edit back with no changes exits without alert")
    func editBackWithNoChangesExitsWithoutAlert() throws {
        let editSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")

        #expect(editSource.contains("navigationBarBackButtonHidden(hasUnsavedChanges)"))
        #expect(editSource.contains("private var hasUnsavedChanges: Bool"))
        #expect(editSource.contains("draft != initialDraft"))
    }

    @Test("edit back with unsaved changes does not silently discard them")
    func editBackWithUnsavedChangesDoesNotSilentlyDiscardThem() throws {
        let editSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")

        #expect(editSource.contains("showingUnsavedChangesAlert = true"))
        #expect(editSource.contains("Unsaved Changes"))
        #expect(editSource.contains("onDisappear") == false)
    }

    @Test("save changes from unsaved alert persists edits")
    func saveChangesFromUnsavedAlertPersistsEdits() throws {
        let editSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")

        #expect(editSource.contains("Button(\"Save Changes\")"))
        #expect(editSource.contains("saveTeam(dismissAfterSave: true)"))
    }

    @Test("discard changes leaves original persisted values")
    func discardChangesLeavesOriginalPersistedValues() throws {
        let editSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")

        #expect(editSource.contains("Button(\"Discard Changes\", role: .destructive)"))
        #expect(editSource.contains("draft = initialDraft"))
        #expect(editSource.contains("team.name = initialDraft.name") == false)
    }

    @Test("keep editing leaves form open")
    func keepEditingLeavesFormOpen() throws {
        let editSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")

        #expect(editSource.contains("Button(\"Keep Editing\", role: .cancel) { }"))
    }

    @Test("game edit add team preserves current game while draft is open")
    func gameEditAddTeamPreservesCurrentGameWhileDraftIsOpen() throws {
        let editGame = try repositorySource("ScoreKeep/Edit Data/EditGameView.swift")

        #expect(editGame.contains(".sheet(isPresented: $showingAddTeam)"))
        #expect(editGame.contains("guard let game, !showingAddTeam else { return }"))
        #expect(editGame.contains("modelContext.insert(team)") == false)
        #expect(editGame.contains("navigationPath.append(team)") == false)
    }

    @Test("game edit add team refetches assigns saves and persists across reopen")
    func gameEditAddTeamRefetchesAssignsSavesAndPersistsAcrossReopen() async throws {
        let url = try IsolatedVersionedTeamCreationEvidenceSupport.temporaryStoreURL("EditGameAddTeamPersistence-\(UUID().uuidString)")
        let teamIdentity = UUID(uuidString: "ABCDEFAB-1111-4222-8333-ABCDEFABCDEF")!
        let gameIdentity = UUID(uuidString: "BBBBBBBB-1111-4222-8333-CCCCCCCCCCCC")!

        do {
            let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2DiskContainer(url: url)
            let service = proposedService(container: container)
            let submission = SimpleTeamCreationSubmission(
                operationIdentity: CanonicalTeamCreationOperationIdentity("edit-game-add-team-persistence-op"),
                teamIdentity: teamIdentity,
                teamName: "Edit Game Persisted Team",
                coach: "Coach",
                details: "Created from Edit Game"
            )

            let outcome = await service.submit(submission)
            let editGameContext = ModelContext(container)
            let createdTeam = try #require(try fetchTeam(identity: teamIdentity, in: editGameContext))
            let existingHome = Team(name: "Existing Home", coach: "", details: "")
            let game = Game(
                ident: gameIdentity,
                date: "2026-09-06T16:00:00Z",
                location: "Persistence Field",
                highLights: "",
                hscore: 0,
                vscore: 0,
                vteam: createdTeam,
                hteam: existingHome
            )
            editGameContext.insert(existingHome)
            editGameContext.insert(game)
            try editGameContext.save()

            #expect(outcome.disposition == .created)
        }

        let reopened = try IsolatedVersionedTeamCreationEvidenceSupport.v2DiskContainer(url: url)
        let reopenedContext = ModelContext(reopened)
        let persistedTeam = try #require(try fetchTeam(identity: teamIdentity, in: reopenedContext))
        let persistedGame = try #require(try fetchGame(identity: gameIdentity, in: reopenedContext))

        #expect(persistedTeam.name == "Edit Game Persisted Team")
        #expect(persistedGame.vteam?.ident == teamIdentity)
    }

    @Test("game edit add team callback uses local refetch and save")
    func gameEditAddTeamCallbackUsesLocalRefetchAndSave() throws {
        let editGame = try repositorySource("ScoreKeep/Edit Data/EditGameView.swift")

        #expect(editGame.contains("guard let persistedTeam = fetchTeam(identity: team.ident)"))
        #expect(editGame.contains("visitingTeamBinding.wrappedValue = persistedTeam"))
        #expect(editGame.contains("homeTeamBinding.wrappedValue = persistedTeam"))
        #expect(editGame.contains("try modelContext.save()"))
        #expect(editGame.contains("private func fetchTeam(identity: UUID) -> Team?"))
    }

    @Test("paste create team returns and selects without resetting import setup")
    func pasteCreateTeamReturnsAndSelectsWithoutResettingImportSetup() throws {
        let pasteView = try repositorySource("ScoreKeep/Player org/PasteView.swift")

        #expect(pasteView.contains(".sheet(isPresented: $showingAddTeam)"))
        #expect(pasteView.contains("selectCreatedTeam(createdTeam)"))
        #expect(pasteView.contains("team = createdTeam"))
        #expect(pasteView.contains("previousTeam = createdTeam"))
        #expect(pasteView.contains("func addTeam()") == false)
        #expect(pasteView.contains("modelContext.insert(team)") == false)
    }

    @Test("converted entry points use standard draft route instead of blank placeholder insert")
    func convertedEntryPointsUseStandardDraftRouteInsteadOfBlankPlaceholderInsert() throws {
        let sources = [
            try repositorySource("ScoreKeep/List Data/TeamView.swift"),
            try repositorySource("ScoreKeep/Content Views/TeamContentView.swift"),
            try repositorySource("ScoreKeep/Content Views/ContentView.swift"),
            try repositorySource("ScoreKeep/Content Views/ScoreContentView.swift"),
            try repositorySource("ScoreKeep/Edit Data/EditGameView.swift"),
            try repositorySource("ScoreKeep/Player org/PasteView.swift")
        ]
        let combined = sources.joined(separator: "\n")

        #expect(combined.contains("AddTeamDraftView"))
        #expect(combined.contains("AddTeamNavigationDestination"))
        #expect(combined.contains("addBlankTeam") == false)
        #expect(combined.contains("createTeamTrigger") == false)
        #expect(combined.contains("modelContext.insert(team)") == false)
        #expect(combined.contains("modelContext.insert(theTeam)") == false)
    }

    @Test("add and edit use shared team form content")
    func addAndEditUseSharedTeamFormContent() throws {
        let addSource = try repositorySource("ScoreKeep/Common/AddTeamDraftView.swift")
        let editSource = try repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")

        #expect(addSource.contains("struct TeamFormContent"))
        #expect(addSource.contains("TeamFormContent(draft: $draft)"))
        #expect(editSource.contains("TeamFormContent(draft: $draft)"))
    }

    private func proposedService(container: ModelContainer) -> SimpleTeamCreationRoutingService {
        SimpleTeamCreationRoutingService(
            container: container,
            routeSelection: .proposed,
            readiness: CanonicalTeamCreationWriteReadinessSnapshot(
                storeOpenedSuccessfully: true,
                sourceVersionState: .supportedCurrent,
                migrationState: .complete,
                cutoverApprovalPresent: true
            ),
            activeContainerAuthority: "proposedV2",
            migrationCompletionState: "completed"
        )
    }

    private func repositorySource(_ relativePath: String) throws -> String {
        try StableIdentityAndOrderingTestSupport.repositorySource(relativePath)
    }

    private func fetchTeam(identity: UUID, in context: ModelContext) throws -> Team? {
        let descriptor = FetchDescriptor<Team>(predicate: #Predicate { team in
            team.ident == identity
        })
        return try context.fetch(descriptor).first
    }

    private func fetchGame(identity: UUID, in context: ModelContext) throws -> Game? {
        let descriptor = FetchDescriptor<Game>(predicate: #Predicate { game in
            game.ident == identity
        })
        return try context.fetch(descriptor).first
    }
}
