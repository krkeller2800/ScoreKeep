import Testing
@testable import ScoreKeep

@Suite("Compact player position display")
struct PlayerCompactPositionDisplayTests {
    @Test func knownLongFormPositionsUseStandardAbbreviations() {
        #expect(PlayerCompactPositionDisplay.string(for: "Designated Hitter") == "DH")
        #expect(PlayerCompactPositionDisplay.string(for: "Starting Pitcher") == "SP")
        #expect(PlayerCompactPositionDisplay.string(for: "Relief Pitcher") == "RP")
        #expect(PlayerCompactPositionDisplay.string(for: "Catcher") == "C")
        #expect(PlayerCompactPositionDisplay.string(for: "First Baseman") == "1B")
        #expect(PlayerCompactPositionDisplay.string(for: "Second Baseman") == "2B")
        #expect(PlayerCompactPositionDisplay.string(for: "Shortstop") == "SS")
        #expect(PlayerCompactPositionDisplay.string(for: "Third Baseman") == "3B")
        #expect(PlayerCompactPositionDisplay.string(for: "Left Fielder") == "LF")
        #expect(PlayerCompactPositionDisplay.string(for: "Center Fielder") == "CF")
        #expect(PlayerCompactPositionDisplay.string(for: "Right Fielder") == "RF")
    }

    @Test func existingAbbreviationsRemainAbbreviated() {
        #expect(PlayerCompactPositionDisplay.string(for: "P") == "P")
        #expect(PlayerCompactPositionDisplay.string(for: "SP") == "SP")
        #expect(PlayerCompactPositionDisplay.string(for: "RP") == "RP")
        #expect(PlayerCompactPositionDisplay.string(for: "DH") == "DH")
        #expect(PlayerCompactPositionDisplay.string(for: "SS") == "SS")
    }

    @Test func displayOnlyFormattingTrimsButPreservesUnknownValues() {
        #expect(PlayerCompactPositionDisplay.string(for: "  Utility Rover  ") == "Utility Rover")
        #expect(PlayerCompactPositionDisplay.string(for: "   ") == "")
    }
}
