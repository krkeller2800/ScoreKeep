import Foundation
import Testing
@testable import ScoreKeep

struct CanonicalTeamMeaningTests {
    @Test("reusable team identity is stable across display and media changes")
    func reusableTeamIdentityIsStableAcrossDisplayAndMediaChanges() {
        let original = CanonicalTeamMeaningTestSupport.team(
            display: CanonicalTeamMeaningTestSupport.display(logo: .present(CanonicalTeamMeaningTestSupport.logoA))
        )
        let matching = CanonicalTeamMeaningTestSupport.team(
            display: CanonicalTeamMeaningTestSupport.display(logo: .present(CanonicalTeamMeaningTestSupport.logoA))
        )
        let renamed = CanonicalTeamMeaningTestSupport.team(
            display: CanonicalTeamMeaningTestSupport.display(name: .present("Fixture Tigers 2027"))
        )
        let changedCoach = CanonicalTeamMeaningTestSupport.team(
            display: CanonicalTeamMeaningTestSupport.display(coach: .present("Coach Two"))
        )
        let changedLogo = CanonicalTeamMeaningTestSupport.team(
            display: CanonicalTeamMeaningTestSupport.display(logo: .present(CanonicalTeamMeaningTestSupport.logoB))
        )
        let conflictingDisplay = CanonicalTeamMeaningTestSupport.team(
            display: CanonicalTeamMeaningTestSupport.display(
                name: .present("Fixture Wolves"),
                coach: .present("Coach Two"),
                details: .present("Other season"),
                logo: .invalid("not image data")
            )
        )

        #expect(original == matching)
        #expect(original == renamed)
        #expect(original == changedCoach)
        #expect(original == changedLogo)
        #expect(CanonicalTeamMeaningClassifier.compare(original, matching) == .sameIdentityMatchingDisplay)
        #expect(CanonicalTeamMeaningClassifier.compare(original, renamed) == .sameIdentityConflictingDisplay(["name"]))
        #expect(CanonicalTeamMeaningClassifier.compare(original, changedCoach) == .sameIdentityConflictingDisplay(["coach"]))
        #expect(CanonicalTeamMeaningClassifier.compare(original, changedLogo) == .sameIdentityConflictingDisplay(["logoByteCount"]))
        #expect(CanonicalTeamMeaningClassifier.compare(original, conflictingDisplay) == .sameIdentityConflictingDisplay(["coach", "details", "name"]))
        #expect(original.hashValue == renamed.hashValue)
    }

    @Test("same names do not merge distinct reusable team identities")
    func sameNamesDoNotMergeDistinctReusableTeams() {
        let first = CanonicalTeamMeaningTestSupport.team(
            id: CanonicalTeamMeaningTestSupport.teamA,
            display: CanonicalTeamMeaningTestSupport.display(name: .present("Fixture Tigers"))
        )
        let second = CanonicalTeamMeaningTestSupport.team(
            id: CanonicalTeamMeaningTestSupport.teamB,
            display: CanonicalTeamMeaningTestSupport.display(name: .present("Fixture Tigers"))
        )

        #expect(first != second)
        #expect(CanonicalTeamMeaningClassifier.compare(first, second) == .distinctIdentitiesMatchingDisplay)
    }

    @Test("missing invalid duplicate and conflicting team identities remain classified")
    func unresolvedDuplicateAndConflictingTeamIdentitiesRemainClassified() {
        let missing = CanonicalTeamMeaningTestSupport.team(id: nil)
        let invalid = CanonicalTeamMeaningTestSupport.team(rawID: "not-a-team-id")
        let duplicateMatching = CanonicalTeamMeaningTestSupport.team()
        let duplicateConflicting = CanonicalTeamMeaningTestSupport.team(
            display: CanonicalTeamMeaningTestSupport.display(name: .present("Fixture Renamed"))
        )
        let classifications = CanonicalTeamMeaningClassifier.classifyDuplicates([
            duplicateMatching,
            duplicateMatching,
            duplicateConflicting,
            missing,
            invalid
        ])

        #expect(CanonicalTeamMeaningClassifier.compare(missing, duplicateMatching) == .oneMissingIdentifier)
        #expect(CanonicalTeamMeaningClassifier.compare(invalid, duplicateMatching) == .invalidIdentifier)
        #expect(classifications.contains(.exactRepeatedEvidence))
        #expect(classifications.contains(.duplicateIdentifierConflictingDisplay(["name"])))
        #expect(classifications.contains(.missingIdentifier))
        #expect(classifications.contains(.invalidIdentifier))
    }

    @Test("team display evidence preserves blank missing invalid and changed values")
    func teamDisplayEvidencePreservesBlankMissingInvalidAndChangedValues() {
        let complete = CanonicalTeamMeaningTestSupport.display(
            name: .present("Fixture Tigers"),
            coach: .present("Coach One"),
            details: .present("Season roster"),
            logo: .present(CanonicalTeamMeaningTestSupport.logoA)
        )
        let blankName = CanonicalTeamMeaningTestSupport.display(name: .present(""))
        let missingName = CanonicalTeamMeaningTestSupport.display(name: .missing)
        let blankCoach = CanonicalTeamMeaningTestSupport.display(coach: .present(""))
        let missingDetails = CanonicalTeamMeaningTestSupport.display(details: .missing)
        let missingLogo = CanonicalTeamMeaningTestSupport.display(logo: .missing)
        let invalidLogo = CanonicalTeamMeaningTestSupport.display(logo: .invalid("invalid base64 image"))
        let team = CanonicalTeamMeaningTestSupport.team(display: invalidLogo)
        let changedDisplayTeam = CanonicalTeamMeaningTestSupport.team(
            display: CanonicalTeamMeaningTestSupport.display(name: .present("Fixture Renamed"))
        )

        #expect(complete.name == .present("Fixture Tigers"))
        #expect(blankName.name == .present(""))
        #expect(missingName.name == .missing)
        #expect(blankCoach.coach == .present(""))
        #expect(missingDetails.details == .missing)
        #expect(missingLogo.logo == .missing)
        #expect(invalidLogo.logo == .invalid("invalid base64 image"))
        #expect(team.identity == .valid(CanonicalTeamMeaningTestSupport.teamA))
        #expect(team == changedDisplayTeam)
    }

    @Test("current roster evidence is separate from reusable team identity")
    func currentRosterEvidenceIsSeparateFromReusableTeamIdentity() {
        let currentRoster = CanonicalTeamMeaningTestSupport.team(
            rosterEvidence: .relationshipReference(count: 12)
        )
        let changedRoster = CanonicalTeamMeaningTestSupport.team(
            rosterEvidence: .relationshipReference(count: 18)
        )

        #expect(currentRoster == changedRoster)
        #expect(CanonicalTeamMeaningClassifier.compare(currentRoster, changedRoster) == .sameIdentityMatchingDisplay)
        #expect(currentRoster.rosterEvidence != changedRoster.rosterEvidence)
    }
}
