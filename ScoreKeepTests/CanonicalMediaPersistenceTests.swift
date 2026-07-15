import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical media persistence verification")
struct CanonicalMediaPersistenceTests {
    @Test("player photo and team logo round trip through isolated store")
    func playerPhotoAndTeamLogoRoundTripThroughIsolatedStore() throws {
        let environment = try IsolatedPersistenceEnvironment()
        IsolatedMediaPersistenceSupport.insertMediaGraph(into: environment.context)
        try environment.save()

        let first = try IsolatedMediaPersistenceSupport.mediaSnapshot(from: environment.container)
        let second = try IsolatedMediaPersistenceSupport.mediaSnapshot(from: environment.container)

        #expect(first == second)
        #expect(first.playerPhotos[PersistenceVerificationIDs.visitingPlayerOne] == IsolatedMediaPersistenceSupport.smallValidPNG)
        #expect(first.playerPhotos[PersistenceVerificationIDs.visitingPlayerTwo] == IsolatedMediaPersistenceSupport.alternateValidPNG)
        #expect(first.teamLogos[PersistenceVerificationIDs.visitingTeam] == IsolatedMediaPersistenceSupport.alternateValidPNG)
        #expect(first.teamLogos[PersistenceVerificationIDs.homeTeam] == IsolatedMediaPersistenceSupport.smallValidPNG)
        #expect(first.teamNames[MediaPersistenceVerificationIDs.unrelatedTeam] == "Unrelated Media Team")
    }

    @Test("nil empty valid and malformed media classify without changing baseball facts")
    func nilEmptyValidAndMalformedMediaClassifyWithoutChangingBaseballFacts() throws {
        let environment = try IsolatedPersistenceEnvironment()
        IsolatedMediaPersistenceSupport.insertMediaGraph(into: environment.context, includeMedia: false)
        try environment.save()
        let before = try IsolatedMediaPersistenceSupport.mediaSnapshot(from: environment.container)

        let missing = IsolatedMediaPersistenceSupport.classifyMediaEvidence(ownerIdentity: PersistenceVerificationIDs.visitingPlayerOne, data: nil)
        let empty = IsolatedMediaPersistenceSupport.classifyMediaEvidence(ownerIdentity: PersistenceVerificationIDs.visitingPlayerOne, data: Data())
        let valid = IsolatedMediaPersistenceSupport.classifyMediaEvidence(ownerIdentity: PersistenceVerificationIDs.visitingPlayerOne, data: IsolatedMediaPersistenceSupport.smallValidPNG)
        let malformed = IsolatedMediaPersistenceSupport.classifyMediaEvidence(ownerIdentity: PersistenceVerificationIDs.visitingPlayerOne, data: IsolatedMediaPersistenceSupport.malformedBytes)
        let missingOwner = IsolatedMediaPersistenceSupport.classifyMediaEvidence(ownerIdentity: nil, data: IsolatedMediaPersistenceSupport.smallValidPNG)
        let after = try IsolatedMediaPersistenceSupport.mediaSnapshot(from: environment.container)

        #expect(missing.disposition == .noChange)
        #expect(empty.disposition == .mediaFailure)
        #expect(valid.disposition == .success)
        #expect(malformed.disposition == .mediaFailure)
        #expect(malformed.findings.first?.unsupportedRatherThanMalformed == true)
        #expect(missingOwner.disposition == .relationshipFailure)
        #expect(before == after)
    }

    @Test("media replacement removal and distinct owners persist without unrelated record changes")
    func mediaReplacementRemovalAndDistinctOwnersPersistWithoutUnrelatedRecordChanges() throws {
        let environment = try IsolatedPersistenceEnvironment()
        IsolatedMediaPersistenceSupport.insertMediaGraph(into: environment.context)
        try environment.save()
        let before = try IsolatedMediaPersistenceSupport.mediaSnapshot(from: environment.container)
        let players = try environment.fetch(FetchDescriptor<Player>())
        let teams = try environment.fetch(FetchDescriptor<Team>())

        let visitorOne = try #require(players.first { $0.identifier == PersistenceVerificationIDs.visitingPlayerOne })
        let visitorTwo = try #require(players.first { $0.identifier == PersistenceVerificationIDs.visitingPlayerTwo })
        let visitingTeam = try #require(teams.first { $0.ident == PersistenceVerificationIDs.visitingTeam })
        let homeTeam = try #require(teams.first { $0.ident == PersistenceVerificationIDs.homeTeam })
        visitorOne.photo = IsolatedMediaPersistenceSupport.alternateValidPNG
        visitorTwo.photo = nil
        visitingTeam.logo = IsolatedMediaPersistenceSupport.smallValidPNG
        homeTeam.logo = nil
        try environment.save()

        let after = try IsolatedMediaPersistenceSupport.mediaSnapshot(from: environment.container)

        #expect(after.playerPhotos[PersistenceVerificationIDs.visitingPlayerOne] == IsolatedMediaPersistenceSupport.alternateValidPNG)
        #expect(after.playerPhotos.keys.contains(PersistenceVerificationIDs.visitingPlayerTwo))
        #expect(after.playerPhotos[PersistenceVerificationIDs.visitingPlayerTwo]! == nil)
        #expect(after.teamLogos[PersistenceVerificationIDs.visitingTeam] == IsolatedMediaPersistenceSupport.smallValidPNG)
        #expect(after.teamLogos.keys.contains(PersistenceVerificationIDs.homeTeam))
        #expect(after.teamLogos[PersistenceVerificationIDs.homeTeam]! == nil)
        #expect(after.teamNames == before.teamNames)
        #expect(after.playerNames == before.playerNames)
        #expect(after.gameIDs == before.gameIDs)
        #expect(after.teamLogos[MediaPersistenceVerificationIDs.unrelatedTeam] == IsolatedMediaPersistenceSupport.smallValidPNG)
    }

    @Test("deterministic failed media replacement preserves prior accepted media after rollback")
    func deterministicFailedMediaReplacementPreservesPriorAcceptedMediaAfterRollback() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let failingBoundary = IsolatedPersistenceSaveBoundary { _ in
            throw IsolatedPersistenceInjectedSaveError.deterministicFailure
        }
        let probe = IsolatedPersistenceProbeState(freeGameCreatesRemaining: 2, mlbDownloadUseCount: 1, entitlementMarker: "active-2026")
        IsolatedMediaPersistenceSupport.insertMediaGraph(into: environment.context)
        try environment.save()
        let accepted = try IsolatedMediaPersistenceSupport.mediaSnapshot(from: environment.container, allowanceProbe: probe)
        let players = try environment.fetch(FetchDescriptor<Player>())
        let visitorOne = try #require(players.first { $0.identifier == PersistenceVerificationIDs.visitingPlayerOne })

        let result = failingBoundary.apply(operationIdentity: "failed-media-replacement", context: environment.context) {
            visitorOne.photo = IsolatedMediaPersistenceSupport.alternateValidPNG
        }
        environment.context.rollback()
        let afterRollback = try IsolatedMediaPersistenceSupport.mediaSnapshot(from: environment.container, allowanceProbe: probe)

        #expect(result.disposition == .saveFailed)
        #expect(result.priorAcceptedStateRemainsUsable)
        #expect(result.explicitReloadRequired)
        #expect(afterRollback == accepted)
        #expect(afterRollback.allowanceProbe == probe)
    }

    @Test("duplicate owner identity remains diagnostic and does not merge media")
    func duplicateOwnerIdentityRemainsDiagnosticAndDoesNotMergeMedia() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let team = Team(ident: PersistenceVerificationIDs.visitingTeam, name: "Duplicate Team", coach: "", details: "")
        let first = Player(identifier: PersistenceVerificationIDs.visitingPlayerOne, name: "First", number: "1", position: "SS", batDir: "R", batOrder: 1, team: team, photo: IsolatedMediaPersistenceSupport.smallValidPNG)
        let duplicate = Player(identifier: PersistenceVerificationIDs.visitingPlayerOne, name: "Duplicate", number: "99", position: "CF", batDir: "L", batOrder: 2, team: team, photo: IsolatedMediaPersistenceSupport.alternateValidPNG)
        team.players = [first, duplicate]
        environment.context.insert(team)
        environment.context.insert(first)
        environment.context.insert(duplicate)
        try environment.save()

        let validation = CanonicalDomainValidator.validateDuplicateIdentities([
            StableIdentityAndOrderingTestSupport.playerEvidence(id: first.identifier, name: first.name, number: first.number),
            StableIdentityAndOrderingTestSupport.playerEvidence(id: duplicate.identifier, name: duplicate.name, number: duplicate.number)
        ])
        let assessment = CanonicalPersistenceRepairAssessor.assessment(for: validation, affectedRecordIdentities: [first.identifier.uuidString])
        let players = try environment.fetch(FetchDescriptor<Player>())
        let photoCounts = players.compactMap { $0.photo?.count }.sorted()

        #expect(validation.disposition == .contradictory)
        #expect(assessment.disposition == .duplicateIdentityCandidate)
        #expect(assessment.isAssessmentOnly)
        #expect(players.count == 2)
        #expect(photoCounts == [IsolatedMediaPersistenceSupport.smallValidPNG.count, IsolatedMediaPersistenceSupport.alternateValidPNG.count].sorted())
    }
}
