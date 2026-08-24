import Testing
@testable import ScoreKeep

struct PitcherNamePresentationTests {
    @Test func scorecardDisplayNameKeepsSuffixWithFamilyName() {
        #expect(PitcherNamePresentation.scorecardDisplayName(for: "Jackson Jobe IV") == "Jobe IV")
        #expect(PitcherNamePresentation.scorecardDisplayName(for: "Ronald Acuna Jr.") == "Acuna Jr.")
        #expect(PitcherNamePresentation.scorecardDisplayName(for: "Chris Smith III") == "Smith III")
    }

    @Test func scorecardDisplayNamePreservesExistingCompactLastNameBehavior() {
        #expect(PitcherNamePresentation.scorecardDisplayName(for: "Kenley Jansen") == "Jansen")
        #expect(PitcherNamePresentation.scorecardDisplayName(for: "Sears") == "Sears")
        #expect(PitcherNamePresentation.scorecardDisplayName(for: "  Kyle Finnegan  ") == "Finnegan")
    }
}
