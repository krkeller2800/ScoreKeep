import Foundation
import Testing
@testable import ScoreKeep

@Suite("Paste lineup header rows")
struct PasteLineupHeaderRowTests {
    @Test("spreadsheet header row is excluded while actual players remain")
    func spreadsheetHeaderRowIsExcludedWhileActualPlayersRemain() {
        let rows = [
            PasteLineupMappedRow(number: "Num", firstName: nil, lastName: "Name", batsDirection: "L/R", position: "Pos", batOrder: "Order"),
            PasteLineupMappedRow(number: "12", firstName: nil, lastName: "Kevin McGonigle", batsDirection: "L", position: "3B", batOrder: "1"),
            PasteLineupMappedRow(number: "8", firstName: nil, lastName: "Hao-Yu Lee", batsDirection: "R", position: "2B", batOrder: "2")
        ]

        let importedRows = rows.filter { PasteLineupHeaderRowPolicy.isHeaderRow($0) == false }

        #expect(importedRows == [
            PasteLineupMappedRow(number: "12", firstName: nil, lastName: "Kevin McGonigle", batsDirection: "L", position: "3B", batOrder: "1"),
            PasteLineupMappedRow(number: "8", firstName: nil, lastName: "Hao-Yu Lee", batsDirection: "R", position: "2B", batOrder: "2")
        ])
    }

    @Test("headerless paste keeps first player and subsequent players")
    func headerlessPasteKeepsFirstPlayerAndSubsequentPlayers() {
        let rows = [
            PasteLineupMappedRow(number: nil, firstName: "Kevin", lastName: "McGonigle", batsDirection: "(L)", position: "3B", batOrder: nil),
            PasteLineupMappedRow(number: nil, firstName: "Hao-Yu", lastName: "Lee", batsDirection: "(R)", position: "2B", batOrder: nil),
            PasteLineupMappedRow(number: nil, firstName: "Colt", lastName: "Keith", batsDirection: "(L)", position: "1B", batOrder: nil)
        ]

        let importedRows = rows.filter { PasteLineupHeaderRowPolicy.isHeaderRow($0) == false }

        #expect(importedRows == rows)
    }

    @Test("Paste Order assigns sequential roster order to every non-header player")
    func pasteOrderAssignsSequentialRosterOrderToEveryNonHeaderPlayer() {
        let rows = [PasteLineupMappedRow(number: "Num", firstName: nil, lastName: "Name", batsDirection: nil, position: "Pos", batOrder: nil)] +
            (1...12).map {
                PasteLineupMappedRow(number: "\($0)", firstName: nil, lastName: "Player \($0)", batsDirection: nil, position: "SS", batOrder: nil)
            }

        let orders = rows.reduce(into: (importedIndex: 0, values: [Int]())) { result, row in
            guard PasteLineupHeaderRowPolicy.isHeaderRow(row) == false else { return }
            result.values.append(PasteLineupBattingOrderPolicy.resolvedOrder(
                mappedValue: "99",
                usesPasteOrder: true,
                importedPlayerIndex: result.importedIndex
            ))
            result.importedIndex += 1
        }.values

        #expect(orders == Array(1...12))
    }

    @Test("explicit mapped batting order remains authoritative")
    func explicitMappedBattingOrderRemainsAuthoritative() {
        let mappedValues = ["12", "3", "99", "52"]

        let orders = mappedValues.enumerated().map { offset, value in
            PasteLineupBattingOrderPolicy.resolvedOrder(
                mappedValue: value,
                usesPasteOrder: false,
                importedPlayerIndex: offset
            )
        }

        #expect(orders == [12, 3, 99, 52])
    }

    @Test("single label-like player field is not enough to discard a row")
    func singleLabelLikePlayerFieldIsNotEnoughToDiscardRow() {
        let row = PasteLineupMappedRow(number: nil, firstName: nil, lastName: "Player", batsDirection: nil, position: "SS", batOrder: nil)

        #expect(PasteLineupHeaderRowPolicy.isHeaderRow(row) == false)
    }

    @Test("column mapping source remains first row driven")
    func columnMappingSourceRemainsFirstRowDriven() throws {
        let source = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/Player org/PasteView.swift")

        #expect(source.contains("playerComponents = players[0].components(separatedBy: delimeter)"))
        #expect(source.contains("if PasteLineupHeaderRowPolicy.isHeaderRow(mappedRow)"))
        #expect(source.contains("players.removeFirst()") == false)
    }
}
