import Foundation
import Testing
@testable import ScoreKeep

struct RosterMembershipConflictTests {
    @Test func duplicateTeamPlayerPairWithConflictingNumberPositionAndOrderClassifies() {
        let base = CanonicalRosterMembershipTestSupport.membership(
            display: CanonicalRosterMembershipTestSupport.display(number: .present("12"), position: .present("SS"), rosterOrder: 1)
        )
        let conflict = CanonicalRosterMembershipTestSupport.membership(
            display: CanonicalRosterMembershipTestSupport.display(number: .present("34"), position: .present("CF"), rosterOrder: 9)
        )

        #expect(CanonicalRosterMembershipClassifier.compare(base, conflict) == .sameTeamAndPlayerConflictingEvidence([.jerseyNumber, .position, .rosterOrder]))

        let classifications = CanonicalRosterMembershipClassifier.classifyRoster([base, conflict])
        #expect(classifications.contains(.containsDuplicateMembership))
        #expect(classifications.contains(.containsConflictingMembership))
        #expect(classifications.contains(.duplicatePlayerIdentity(CanonicalRosterMembershipTestSupport.playerA)))
    }

    @Test func missingAndInvalidRelationshipsRemainClassified() {
        let missingTeam = CanonicalRosterMembershipTestSupport.membership(team: nil)
        let missingPlayer = CanonicalRosterMembershipTestSupport.membership(player: nil)
        let invalidTeam = CanonicalRosterMembershipTestSupport.invalidTeamMembership()
        let invalidPlayer = CanonicalRosterMembershipTestSupport.invalidPlayerMembership()

        #expect(CanonicalRosterMembershipClassifier.classify(missingTeam) == .missingTeamIdentity)
        #expect(CanonicalRosterMembershipClassifier.classify(missingPlayer) == .missingPlayerIdentity)
        #expect(CanonicalRosterMembershipClassifier.classify(invalidTeam) == .invalidTeamIdentity)
        #expect(CanonicalRosterMembershipClassifier.classify(invalidPlayer) == .invalidPlayerIdentity)

        let classifications = CanonicalRosterMembershipClassifier.classifyRoster([missingTeam, missingPlayer, invalidTeam, invalidPlayer])
        #expect(classifications.contains(.containsIncompleteMembership))
        #expect(classifications.contains(.containsInvalidRelationship))
    }

    @Test func unresolvedConflictingAndDetachedImportedEvidenceDoNotBecomeCurrent() {
        let unknownTeam = CurrentRosterMembership(
            teamEvidence: .unknown(CanonicalTeamMeaningTestSupport.display(name: .present("Unknown Club"))),
            playerEvidence: .reusablePlayer(CanonicalRosterMembershipTestSupport.player()),
            displayEvidence: CanonicalRosterMembershipTestSupport.display(),
            source: .importedRoster
        )
        let conflictingPlayer = CurrentRosterMembership(
            teamEvidence: .reusableTeam(CanonicalRosterMembershipTestSupport.team()),
            playerEvidence: .conflicting(.valid(CanonicalRosterMembershipTestSupport.playerA), CanonicalPlayerMeaningTestSupport.display(name: .present("Casey Conflict"))),
            displayEvidence: CanonicalRosterMembershipTestSupport.display(),
            source: .importedRoster
        )
        let detached = CurrentRosterMembership(
            teamEvidence: .reusableTeam(CanonicalRosterMembershipTestSupport.team()),
            playerEvidence: .detachedImported(CanonicalPlayerMeaningTestSupport.display(name: .present("Detached Player"))),
            displayEvidence: CanonicalRosterMembershipTestSupport.display(),
            source: .importedRoster
        )

        #expect(CanonicalRosterMembershipClassifier.classify(unknownTeam) == .missingTeamIdentity)
        #expect(CanonicalRosterMembershipClassifier.classify(conflictingPlayer) == .conflictingMembershipEvidence)
        #expect(CanonicalRosterMembershipClassifier.classify(detached) == .missingPlayerIdentity)
    }

    @Test func emptyOneAndMultipleRostersAreRepresentable() {
        let team = CanonicalRosterMembershipTestSupport.team()
        let emptyRoster = TeamRosterMembershipSet(team: team)
        let oneRoster = TeamRosterMembershipSet(team: team, memberships: [CanonicalRosterMembershipTestSupport.membership(team: team)])
        let multipleRoster = TeamRosterMembershipSet(team: team, memberships: [
            CanonicalRosterMembershipTestSupport.membership(team: team),
            CanonicalRosterMembershipTestSupport.membership(team: team, player: CanonicalRosterMembershipTestSupport.player(id: CanonicalRosterMembershipTestSupport.playerB))
        ])

        #expect(CanonicalRosterMembershipClassifier.classifyTeamRoster(emptyRoster).contains(.emptyRoster))
        #expect(CanonicalRosterMembershipClassifier.classifyTeamRoster(emptyRoster).contains(.teamWithEmptyRoster(CanonicalRosterMembershipTestSupport.teamA)))
        #expect(CanonicalRosterMembershipClassifier.classifyTeamRoster(oneRoster).contains(.oneCurrentMembership))
        #expect(CanonicalRosterMembershipClassifier.classifyTeamRoster(multipleRoster).contains(.multipleCurrentMemberships))
    }

    @Test func blankMissingAndUnknownOptionalEvidenceIsPreserved() {
        let blankNumber = CanonicalRosterMembershipTestSupport.membership(
            display: CanonicalRosterMembershipTestSupport.display(number: .present(""), position: .present(""), rosterOrder: nil)
        )
        let missingNumber = CanonicalRosterMembershipTestSupport.membership(
            player: CanonicalRosterMembershipTestSupport.player(id: CanonicalRosterMembershipTestSupport.playerB),
            display: CanonicalRosterMembershipTestSupport.display(number: .missing, position: .unknown("unknown"), rosterOrder: nil)
        )

        #expect(CanonicalRosterMembershipClassifier.classify(blankNumber) == .current)
        #expect(CanonicalRosterMembershipClassifier.classify(missingNumber) == .current)
        #expect(blankNumber.displayEvidence.jerseyNumber == .present(""))
        #expect(missingNumber.displayEvidence.jerseyNumber == .missing)
        #expect(missingNumber.displayEvidence.position == .unknown("unknown"))
    }

    @Test func mediaAndBattingOrderRemainEvidenceNotIdentity() {
        let base = CanonicalRosterMembershipTestSupport.membership(
            display: CanonicalRosterMembershipTestSupport.display(battingOrder: 3, media: .present(Data([0x01])))
        )
        let changed = CanonicalRosterMembershipTestSupport.membership(
            display: CanonicalRosterMembershipTestSupport.display(battingOrder: 7, media: .invalid("not image data"))
        )

        #expect(base == changed)
        #expect(CanonicalRosterMembershipClassifier.compare(base, changed) == .sameTeamAndPlayerConflictingEvidence([.battingOrder, .media]))
    }
}
