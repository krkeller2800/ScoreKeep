//
//  GeneratePDF.swift
//  ScoreKeep
//
//  Created by Karl Keller on 8/16/25.
//
import PDFKit
import Foundation
import UIKit

class PDFGenerator {

    var numOfPlayers = 0
    func generatePDFData(game: Game, team: Team, title: String, body: String) -> URL? {
        
        // Define the page size (e.g., A4)
        let pageRect = CGRect(x: 0, y: 0, width: 841.8, height: 595.2) // A4 size in points

        // Create a PDF renderer
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let pdfData = renderer.pdfData { context in
            // Begin a new page
            context.beginPage()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            
            // Define text attributes
            let bodyCenterATTR: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.black, .paragraphStyle: paragraph
            ]
            let smallCenterATTR: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 6),
                .foregroundColor: UIColor.black, .paragraphStyle: paragraph
            ]
            let bodyLeftATTR: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.black
            ]
            let theTeamATTR: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 18),
                .foregroundColor: UIColor.blue
            ]
            let otherTeamATTR: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 18),
                .foregroundColor: UIColor.gray
            ]

            drawTeamHDR(game: game, theTeam: team, theTeamATTR: theTeamATTR, otherTeamATTR: otherTeamATTR)
            drawNames(game: game, theTeam: team, bodyLeftATTR: bodyLeftATTR, bodyCenterATTR: bodyCenterATTR)
            drawAtbats(game: game, theTeam: team, bodyATTR: bodyCenterATTR, smallCenterATTR: smallCenterATTR)
            drawPitchers (game: game, team: team)
        }
        let vTeam = game.vteam?.name ?? "Unkown"
        let hTeam = game.hteam?.name ?? "Unkown"
        let theDate = ISO8601DateFormatter().date(from: game.date) ?? Date()
        let name = String("\(vTeam) at \(hTeam) on \(theDate.formatted(date:.abbreviated, time: .omitted))")
        
        return savePDF(data: pdfData, fileName: name)
    }
    func savePDF(data: Data, fileName: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentDirectory.appendingPathComponent("\(fileName).pdf")
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving PDF: \(error.localizedDescription)")
            return nil
        }
    }
    func drawTeamHDR (game:Game, theTeam: Team, theTeamATTR: [NSAttributedString.Key : Any], otherTeamATTR: [NSAttributedString.Key : Any]) {
        
        let atATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        let hdrATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        let vTeam = game.vteam?.name ?? "Unkown"
        let hTeam = game.hteam?.name ?? "Unkown"
        let theTeamWidth: CGSize = "\(vTeam)".size(withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
        let otherTeamWidth: CGSize = "\(hTeam)".size(withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
        let atWidth: CGSize = " at ".size(withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
        
        var theTeamLWidth: CGFloat = 0
        var otherTeamLWidth: CGFloat = 0
        var theTeamTNail: UIImage = UIImage()
        var otherTeamTNail: UIImage = UIImage()
        
        if let theImageData = game.vteam?.logo, let uiImage = UIImage(data: theImageData) {
            theTeamLWidth = 25 * uiImage.size.width / uiImage.size.height
            theTeamTNail = uiImage.preparingThumbnail(of: CGSize(width: theTeamLWidth, height: 25))!
        }
        if let otherImageData = game.hteam?.logo, let uiImage = UIImage(data: otherImageData) {
            otherTeamLWidth = 25 * uiImage.size.width / uiImage.size.height
            otherTeamTNail = uiImage.preparingThumbnail(of: CGSize(width: otherTeamLWidth, height: 25))!
        }
        let totSize: CGFloat = theTeamLWidth + theTeamWidth.width + otherTeamLWidth + otherTeamWidth.width + atWidth.width
        let theTeamString = NSAttributedString(string: "\(vTeam)", attributes: game.vteam == theTeam ? theTeamATTR : otherTeamATTR)
        let otherTeamString = NSAttributedString(string: "\(hTeam)", attributes: game.hteam == theTeam ? theTeamATTR : otherTeamATTR)
        let atString = NSAttributedString(string: " at ", attributes: atATTR)
        
        theTeamTNail.draw(at: CGPoint(x: ((840 - totSize) / 2), y: 75))
        theTeamString.draw(at: CGPoint(x: ((840 - totSize) / 2) + theTeamLWidth + 3, y: 75))
        atString.draw(at: CGPoint(x: ((840 - totSize) / 2) + theTeamLWidth + 3 + theTeamWidth.width + 3, y: 75))
        otherTeamTNail.draw(at: CGPoint(x: ((840 - totSize) / 2) + theTeamLWidth + 3 + theTeamWidth.width + 3 + atWidth.width + 3, y: 75))
        otherTeamString.draw(at: CGPoint(x: ((840 - totSize) / 2) + theTeamLWidth + 3 + theTeamWidth.width + 3 + atWidth.width + 3 + otherTeamLWidth + 3, y: 75))
        
        let locString = NSAttributedString(string: game.location, attributes: hdrATTR)
        locString.draw(at: CGPoint(x: 10, y: 75))
        
        let date = ISO8601DateFormatter().date(from: game.date) ?? Date()
        let theDate = date.formatted(date:.abbreviated, time: .omitted)
        let dateString = NSAttributedString(string: theDate, attributes: hdrATTR)
        let size = dateString.size()
        dateString.draw(at: CGPoint(x: 835 - size.width, y: 65))
        
        let theDate2 = date.formatted(date:.omitted, time: .shortened)
        let dateString2 = NSAttributedString(string: theDate2, attributes: hdrATTR)
        let size2 = dateString2.size()
        dateString2.draw(at: CGPoint(x: 835 - size2.width, y: 80))
    
    }
    func drawNames (game:Game, theTeam: Team, bodyLeftATTR: [NSAttributedString.Key : Any], bodyCenterATTR: [NSAttributedString.Key : Any]) {
        
        let strikeATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black,
            .strikethroughStyle: NSUnderlineStyle.single.rawValue]
        let atbats = game.atbats.filter { $0.team == theTeam && $0.col == 1}.sorted {( ($0.col, $0.seq) < ($1.col, $1.seq) )}
        var x = 0
        for atbat in atbats {
        
            let aPath = UIBezierPath()
            aPath.move(to: CGPoint(x:160, y: 120 + (x * 30)))
            aPath.addLine(to: CGPoint(x: 610, y: 120 + (x * 30)))
            UIColor.gray.set()
            aPath.lineWidth = 1
            aPath.stroke()
            aPath.move(to: CGPoint(x:620, y: 120 + (x * 30)))
            aPath.addLine(to: CGPoint(x: 740, y: 120 + (x * 30)))
            aPath.stroke()
            
            let number = NSAttributedString(string: atbat.player.number, attributes: bodyCenterATTR)
            number.draw(in: CGRect(x: 50, y: 125 + (x * 30), width: 20, height: 30))
            
            let strikeIt: Bool = game.replaced.contains(atbat.player) ? true : false
            let iName: String = game.incomings.contains(atbat.player) ? String("    \(atbat.player.name)") : atbat.player.name
            
            let name = NSAttributedString(string: iName, attributes: strikeIt ? strikeATTR : bodyLeftATTR)
            name.draw(in: CGRect(x: 70, y: 125 + (x * 30), width: 90, height: 30))
            x += 1
        }
        numOfPlayers = x
        let aPath = UIBezierPath()
        aPath.move(to: CGPoint(x:160, y: 120 + (x * 30)))
        aPath.addLine(to: CGPoint(x: 610, y: 120 + (x * 30)))
        UIColor.gray.set()
        aPath.lineWidth = 1
        aPath.stroke()
        aPath.move(to: CGPoint(x:620, y: 120 + (x * 30)))
        aPath.addLine(to: CGPoint(x: 740, y: 120 + (x * 30)))
        aPath.stroke()
        aPath.move(to: CGPoint(x:620, y: 110 + ((x + 1) * 30)))
        aPath.addLine(to: CGPoint(x: 740, y: 110 + ((x + 1) * 30)))
        aPath.stroke()

        for tot in 0...6 {
            aPath.move(to: CGPoint(x:620 + (tot * 20), y: 120))
            aPath.addLine(to: CGPoint(x: 620 + (tot * 20), y: 140 + ((numOfPlayers) * 30)))
            aPath.stroke()
        }
    }
    func drawAtbats (game:Game, theTeam: Team, bodyATTR: [NSAttributedString.Key : Any],  smallCenterATTR: [NSAttributedString.Key : Any]) {
        let com = Common()
        let atbats = game.atbats.filter { $0.team == theTeam && $0.result != "Result"}.sorted {( ($0.col, $0.seq) < ($1.col, $1.seq) )}
        var abb = ""
        var colbox = Array(repeating: BoxScore(), count: 20)
        var batbox = Array(repeating: BoxScore(), count: 20)
        var totbox = Array(repeating: BoxScore(), count: 5)
        for atbat in atbats {
            
            if let xx = com.battings.firstIndex(where: { $0 == atbat.result }) {
                abb = com.batAbbrevs[xx]
            }
            let abbString = NSAttributedString(string: abb, attributes: bodyATTR)
            abbString.draw(in: CGRect(x: CGFloat(130 + (atbat.col * 30)), y: CGFloat(130 + ((atbat.batOrder - 1) * 30)), width: 30, height: 30) )
            drawBasePath(atbat: atbat, abb: abb)
            drawStuff(atbat: atbat,smallCenterATTR: smallCenterATTR)
            drawOuts(atbat: atbat)
            drawRec(atbat: atbat)
            getTots(atbat: atbat, colbox: &colbox, batbox: &batbox, totbox: &totbox)
            
        }
        drawTots(batbox: batbox, totbox:totbox, bodyATTR: bodyATTR)
        drawColTots(colbox: colbox, atbats: atbats, bodyATTR: bodyATTR)
        let boxString = NSAttributedString(string: "Runs    Hits     HR    Walks    Ks      SB", attributes: smallCenterATTR)
        boxString.draw(at: CGPoint(x: 620, y: 110))
        drawBoxScore(game: game)
        doStats(atbats: atbats, team:theTeam)
    }
    func drawBasePath(atbat: Atbat, abb:String) {

        if atbat.maxbase != "No Bases" {
            let aPath = UIBezierPath()
            aPath.move(to: CGPoint(x: CGFloat(145 + (atbat.col * 30)), y: CGFloat(150 + ((atbat.batOrder - 1) * 30))))
            aPath.addLine(to: CGPoint(x:CGFloat(160 + (atbat.col * 30)), y: CGFloat(135 + ((atbat.batOrder - 1) * 30))))
            if atbat.maxbase != "First" {
                aPath.addLine(to: CGPoint(x:CGFloat(145 + (atbat.col * 30)), y: CGFloat(120 + ((atbat.batOrder - 1) * 30))))
                if atbat.maxbase != "Second" {
                    aPath.addLine(to: CGPoint(x: CGFloat(130 + (atbat.col * 30)), y: CGFloat(135 + ((atbat.batOrder - 1) * 30))))
                    if atbat.maxbase != "Third" {
                        aPath.addLine(to: CGPoint(x:CGFloat(145 + (atbat.col * 30)), y: CGFloat(150 + ((atbat.batOrder - 1) * 30))))
                        aPath.close()
                        UIColor.black.setFill( )
                        aPath.fill( )
                        let paragraph = NSMutableParagraphStyle()
                        paragraph.alignment = .center
                        let hrATTR: [NSAttributedString.Key: Any] = [
                            .font: UIFont.boldSystemFont(ofSize: 11),
                            .foregroundColor: UIColor.white, .paragraphStyle: paragraph
                        ]
                        let abbString = NSAttributedString(string: abb, attributes: hrATTR)
                        abbString.draw(in: CGRect(x: CGFloat(130 + (atbat.col * 30)), y: CGFloat(130 + ((atbat.batOrder - 1) * 30)), width: 30, height: 30) )
                    }
                }
            }
            UIColor.cyan.darker(by: 0.3).set()
            aPath.lineWidth = 1
            aPath.stroke()
        }
    }
    func drawStuff (atbat: Atbat, smallCenterATTR: [NSAttributedString.Key : Any]) {
        let com = Common()
        for inning in 0...15 {
            let aPath = UIBezierPath()
            aPath.move(to: CGPoint(x:160 + (inning * 30), y: 120 ))
            aPath.addLine(to: CGPoint(x: 160 + (inning * 30), y: 120 + (numOfPlayers * 30)))
            aPath.close()
            UIColor.gray.set()
            aPath.lineWidth = 1
            aPath.stroke()
        }
        if atbat.inning.rounded(.up) > 0 {
            let inn = com.innAbr[Int(atbat.inning.rounded(.up))]
            var abbString = NSAttributedString(string: "\(inn) Inn", attributes: smallCenterATTR)
            abbString.draw(in: CGRect(x: CGFloat(130 + (atbat.col * 30)), y: 110, width: 30, height: 30))
            abbString = NSAttributedString(string: "Num   Name", attributes: smallCenterATTR)
            abbString.draw(in: CGRect(x: CGFloat(50), y: 110, width: 50, height: 30))
        }
    }
    func drawOuts (atbat: Atbat) {
        let com = Common()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        let outATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.red, .paragraphStyle: paragraph
        ]
        let outAtATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.black, .paragraphStyle: paragraph
        ]
        if atbat.outs == 1 && (com.outresults.contains(atbat.result) || atbat.outAt != "Safe") {
            let abbString = NSAttributedString(string: "*", attributes: outATTR)
            abbString.draw(in: CGRect(x: CGFloat(130 + (atbat.col * 30)), y: CGFloat(120 + ((atbat.batOrder - 1) * 30)), width: 30, height: 30) )
        } else if atbat.outs == 2 && (com.outresults.contains(atbat.result) || atbat.outAt != "Safe") {
            let abbString = NSAttributedString(string: "**", attributes: outATTR)
            abbString.draw(in: CGRect(x: CGFloat(130 + (atbat.col * 30)), y: CGFloat(120 + ((atbat.batOrder - 1) * 30)), width: 30, height: 30) )
        } else if atbat.outs == 3 && (com.outresults.contains(atbat.result) || atbat.outAt != "Safe") {
            let abbString = NSAttributedString(string: "***", attributes: outATTR)
            abbString.draw(in: CGRect(x: CGFloat(130 + (atbat.col * 30)), y: CGFloat(120 + ((atbat.batOrder - 1) * 30)), width: 30, height: 30) )
        }
        if atbat.outs == 3 && atbat.endOfInning {
            let aPath = UIBezierPath()
            aPath.move(to: CGPoint(x: CGFloat(130 + (atbat.col * 30)), y: CGFloat(150 + ((atbat.batOrder - 1) * 30))))
            aPath.addLine(to: CGPoint(x:CGFloat(160 + (atbat.col * 30)), y: CGFloat(150 + ((atbat.batOrder - 1) * 30))))
            UIColor.red.darker().set()
            aPath.lineWidth = 2
            aPath.stroke()
        }
        if atbat.outAt != "Safe" {
            let aPath = UIBezierPath()
            if atbat.outAt == "First" {
                let abbString = NSAttributedString(string: "X", attributes: outAtATTR)
                abbString.draw(at: CGPoint(x:CGFloat(157 + (atbat.col * 30)), y: CGFloat(132 + ((atbat.batOrder - 1) * 30))))
            } else if atbat.outAt == "Second" {
                let abbString = NSAttributedString(string: "X", attributes: outAtATTR)
                abbString.draw(at: CGPoint(x:CGFloat(142 + (atbat.col * 30)), y: CGFloat(117 + ((atbat.batOrder - 1) * 30))))
                aPath.move(to: CGPoint(x:CGFloat(160 + (atbat.col * 30)), y: CGFloat(135 + ((atbat.batOrder - 1) * 30))))
                aPath.addLine(to: CGPoint(x:CGFloat(145 + (atbat.col * 30)), y: CGFloat(120 + ((atbat.batOrder - 1) * 30))))
            } else if atbat.outAt == "Third" {
                let abbString = NSAttributedString(string: "X", attributes: outAtATTR)
                abbString.draw(at: CGPoint(x:CGFloat(127 + (atbat.col * 30)), y: CGFloat(132 + ((atbat.batOrder - 1) * 30))))
                aPath.move(to: CGPoint(x:CGFloat(160 + (atbat.col * 30)), y: CGFloat(135 + ((atbat.batOrder - 1) * 30))))
                aPath.addLine(to: CGPoint(x:CGFloat(145 + (atbat.col * 30)), y: CGFloat(120 + ((atbat.batOrder - 1) * 30))))
                aPath.addLine(to: CGPoint(x: CGFloat(130 + (atbat.col * 30)), y: CGFloat(135 + ((atbat.batOrder - 1) * 30))))
            } else if atbat.outAt == "Home" {
                let abbString = NSAttributedString(string: "X", attributes: outAtATTR)
                abbString.draw(at: CGPoint(x:CGFloat(142 + (atbat.col * 30)), y: CGFloat(145 + ((atbat.batOrder - 1) * 30))))
                aPath.move(to: CGPoint(x:CGFloat(160 + (atbat.col * 30)), y: CGFloat(135 + ((atbat.batOrder - 1) * 30))))
                aPath.addLine(to: CGPoint(x:CGFloat(145 + (atbat.col * 30)), y: CGFloat(120 + ((atbat.batOrder - 1) * 30))))
                aPath.addLine(to: CGPoint(x: CGFloat(130 + (atbat.col * 30)), y: CGFloat(135 + ((atbat.batOrder - 1) * 30))))
                aPath.addLine(to: CGPoint(x:CGFloat(145 + (atbat.col * 30)), y: CGFloat(150 + ((atbat.batOrder - 1) * 30))))
            }
            UIColor.cyan.darker(by: 0.3).set()
            aPath.lineWidth = 1
            aPath.stroke()
        }
    }
    func drawRec (atbat:Atbat) {
        let com = Common()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let recATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6),
            .foregroundColor: UIColor.black, .paragraphStyle: paragraph
        ]
        if com.recOuts.contains(atbat.result) || atbat.outAt != "Safe" {
            let indent = atbat.result == "Fielder's Choice" || atbat.outAt != "Safe" ? 139 : 130
            let abbString = NSAttributedString(string: atbat.playRec, attributes: recATTR)
            abbString.draw(in: CGRect(x: CGFloat(indent + (atbat.col * 30)), y: CGFloat(142 + ((atbat.batOrder - 1) * 30)), width: 30, height: 15) )
        }
    }
    func getTots (atbat:Atbat, colbox: inout [BoxScore], batbox: inout [BoxScore], totbox: inout [BoxScore]) {
        
        let com = Common()
        if atbat.maxbase == "Home" {
            colbox[atbat.col].runs += 1
            batbox[atbat.batOrder].runs += 1
            totbox[0].runs += 1
        }
        if atbat.result == "Home Run" {
            colbox[atbat.col].HR += 1
            batbox[atbat.batOrder].HR += 1
            totbox[0].HR += 1
        }
        if com.hitresults.contains(atbat.result) {
            colbox[atbat.col].hits += 1
            batbox[atbat.batOrder].hits += 1
            totbox[0].hits += 1
        }
        if atbat.result == "Walk" {
            colbox[atbat.col].walks += 1
            batbox[atbat.batOrder].walks += 1
            totbox[0].walks += 1
        }
        if atbat.result == "Strikeout" || atbat.result == "Strikeout Looking" || atbat.result == "Dropped 3rd Strike" {
            colbox[atbat.col].strikeouts += 1
            batbox[atbat.batOrder].strikeouts += 1
            totbox[0].strikeouts += 1
        }
        if com.onresults.contains(atbat.result) && atbat.stolenBases > 0 {
            colbox[atbat.col].stoleBase += atbat.stolenBases
            batbox[atbat.batOrder].stoleBase += atbat.stolenBases
            totbox[0].stoleBase += atbat.stolenBases
        }
        colbox[atbat.col].inning = Int(atbat.inning.rounded(.up))
    }
    func drawTots(batbox:[BoxScore], totbox: [BoxScore], bodyATTR: [NSAttributedString.Key : Any]) {
        for batters in 1...numOfPlayers {
            let box = batbox[Int(batters)]
            var boxString = NSAttributedString(string: "\(box.runs)", attributes: bodyATTR)
            boxString.draw(at: CGPoint(x: 625, y: 130 + ((batters - 1) * 30)))
            boxString = NSAttributedString(string: "\(box.hits)", attributes: bodyATTR)
            boxString.draw(at: CGPoint(x: 645, y: 130 + ((batters - 1) * 30)))
            boxString = NSAttributedString(string: "\(box.HR)", attributes: bodyATTR)
            boxString.draw(at: CGPoint(x: 665, y: 130 + ((batters - 1) * 30)))
            boxString = NSAttributedString(string: "\(box.walks)", attributes: bodyATTR)
            boxString.draw(at: CGPoint(x: 685, y: 130 + ((batters - 1) * 30)))
            boxString = NSAttributedString(string: "\(box.strikeouts)", attributes: bodyATTR)
            boxString.draw(at: CGPoint(x: 705, y: 130 + ((batters - 1) * 30)))
            boxString = NSAttributedString(string: "\(box.stoleBase)", attributes: bodyATTR)
            boxString.draw(at: CGPoint(x: 725, y: 130 + ((batters - 1) * 30)))
        }
        let box2 = totbox[0]
        var boxString = NSAttributedString(string: "\(box2.runs)", attributes: bodyATTR)
        boxString.draw(at: CGPoint(x: 625, y: 125 + (numOfPlayers * 30)))
        boxString = NSAttributedString(string: "\(box2.hits)", attributes: bodyATTR)
        boxString.draw(at: CGPoint(x: 645, y: 125 + (numOfPlayers * 30)))
        boxString = NSAttributedString(string: "\(box2.HR)", attributes: bodyATTR)
        boxString.draw(at: CGPoint(x: 665, y: 125 + (numOfPlayers * 30)))
        boxString = NSAttributedString(string: "\(box2.walks)", attributes: bodyATTR)
        boxString.draw(at: CGPoint(x: 685, y: 125 + (numOfPlayers * 30)))
        boxString = NSAttributedString(string: "\(box2.strikeouts)", attributes: bodyATTR)
        boxString.draw(at: CGPoint(x: 705, y: 125 + (numOfPlayers * 30)))
        boxString = NSAttributedString(string: "\(box2.stoleBase)", attributes: bodyATTR)
        boxString.draw(at: CGPoint(x: 725, y: 125 + (numOfPlayers * 30)))
    }
    func drawColTots(colbox: [BoxScore], atbats: [Atbat], bodyATTR: [NSAttributedString.Key : Any]) {
        let bigCol = atbats.filter{$0.result != "Result"}.max { $0.col < $1.col }
        let maxCol = bigCol?.col ?? 0
        for col in 0...maxCol {
            makeNewRect(rec: CGRect(x: 100 + ((col + 1 ) * 30), y: 140 + (numOfPlayers * 30), width: 15, height: 15), fillColor: .clear, lineColor: .gray)
            makeNewRect(rec: CGRect(x: 115 + ((col + 1 ) * 30), y: 140 + (numOfPlayers * 30), width: 15, height: 15), fillColor: .clear, lineColor: .gray)

            let box2 = colbox[col]
            var boxString = NSAttributedString(string: "R  H", attributes: bodyATTR)
            boxString.draw(at: CGPoint(x: 135, y: 127 + (numOfPlayers * 30)))
            boxString = NSAttributedString(string: "\(box2.runs)   \(box2.hits)", attributes: bodyATTR)
            if col > 0 {
                boxString.draw(at: CGPoint(x: 134 + (col * 30), y: 127 + (numOfPlayers * 30)))
            }
        }

    }
    func drawBoxScore (game: Game) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let boxATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black, .paragraphStyle: paragraph
        ]
        let innATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black, .paragraphStyle: paragraph
        ]
        let titleATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.black
        ]
        let boxHome = doBoxScore(game: game, doTeam: "Home")
        let boxVisit = doBoxScore(game: game, doTeam: "Visit")
        var boxString = NSAttributedString(string: "\(game.vteam?.name ?? "")", attributes: boxATTR)
        boxString.draw(at: CGPoint(x: 165 - boxString.size().width, y: 30))
        boxString = NSAttributedString(string: "\(game.hteam?.name ?? "")", attributes: boxATTR)
        boxString.draw(at: CGPoint(x: 165 - boxString.size().width, y: 45))
        boxString = NSAttributedString(string: "\(boxVisit.runs)", attributes: boxATTR)
        boxString.draw(in: CGRect(x: 195, y:30, width: 20, height: 15))
        boxString = NSAttributedString(string: "\(boxHome.runs)", attributes: boxATTR)
        boxString.draw(in: CGRect(x: 195, y:45, width: 20, height: 15))
        boxString = NSAttributedString(string: "\(boxVisit.hits)", attributes: boxATTR)
        boxString.draw(in: CGRect(x: 218, y:30, width: 20, height: 15))
        boxString = NSAttributedString(string: "\(boxHome.hits)", attributes: boxATTR)
        boxString.draw(in: CGRect(x: 218, y:45, width: 20, height: 15))
        boxString = NSAttributedString(string: "\(boxVisit.error)", attributes: boxATTR)
        boxString.draw(in: CGRect(x: 240, y:30, width: 20, height: 15))
        boxString = NSAttributedString(string: "\(boxHome.error)", attributes: boxATTR)
        boxString.draw(in: CGRect(x: 240, y:45, width: 20, height: 15))
        boxString = NSAttributedString(string: calcInning(game: game), attributes: innATTR)
        boxString.draw(in: CGRect(x: 165, y:33, width: 30, height: 40))
        boxString = NSAttributedString(string: "Inning  Runs  Hits Errors", attributes: titleATTR)
        boxString.draw(in: CGRect(x: 168, y:20, width: 130, height: 20))
        makeNewRect(rec: CGRect(x: 168, y: 60, width: 25, height: 30), fillColor: .clear, lineColor: .gray)
        makeNewRect(rec: CGRect(x: 193, y: 60, width: 24, height: 30), fillColor: .clear, lineColor: .gray)
        makeNewRect(rec: CGRect(x: 217, y: 60, width: 24, height: 30), fillColor: .clear, lineColor: .gray)
        makeNewRect(rec: CGRect(x: 241, y: 60, width: 24, height: 30), fillColor: .clear, lineColor: .gray)

    }
    func doBoxScore(game: Game, doTeam:String)->BoxScore {
        let com = Common()
        if doTeam == "Home" {
            let runs = game.atbats.filter({$0.maxbase == "Home" && $0.team.name == game.hteam?.name}).count
            let hits = game.atbats.filter({com.hitresults.contains($0.result) && $0.team.name == game.hteam?.name}).count
            let errors = game.atbats.filter({$0.result == "Error" && $0.team.name == game.vteam?.name}).count

            return BoxScore(type:"",runs: runs, hits: hits, error: errors, strikeouts:0, walks:0, HR:0)
        } else {
            let runs = game.atbats.filter({$0.maxbase == "Home" && $0.team.name == game.vteam?.name}).count
            let hits = game.atbats.filter({com.hitresults.contains($0.result) && $0.team.name == game.vteam?.name}).count
            let errors = game.atbats.filter({$0.result == "Error" && $0.team.name == game.hteam?.name}).count

            return BoxScore(type:"",runs: runs, hits: hits, error: errors , strikeouts:0, walks:0, HR:0)
        }
   
     }
    func calcInning (game:Game)->String {
        let com = Common()
        let homeOuts = game.atbats.filter({$0.team.name == game.hteam!.name && (com.outresults.contains($0.result) || $0.outAt != "Safe" )}).count
        let visitOuts = game.atbats.filter({$0.team.name == game.vteam!.name && (com.outresults.contains($0.result) || $0.outAt != "Safe" )}).count
        let v3outs = visitOuts % 3 == 0
        let h3outs = homeOuts % 3 == 0
        let vinning:Int = visitOuts / 3
        let theInning = homeOuts < visitOuts && h3outs && v3outs ? "\(com.innAbr[Int(vinning)])" :
                        homeOuts <= visitOuts && !h3outs ? "\(com.innAbr[Int(vinning)])" : "\(com.innAbr[Int(vinning + 1)])"
        let theHalf = homeOuts < visitOuts && v3outs ? "Bot" : "Top"
        return "\(theHalf) \n\(theInning)"
    }
    func doStats (atbats:[Atbat], team:Team) {
        let com = Common()
        let outATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36),
            .foregroundColor: UIColor.red
        ]
        var iStat = InnStatus(outs: atbats.last?.outs ?? 0)

        let inning = atbats.last?.inning.rounded(.up) ?? 0
        let atbatsToUpd = atbats.filter {($0.inning.rounded(.up) == inning || ($0.inning.rounded(.up) == 0 && inning == 1)) && com.onresults.contains($0.result) }
        
        for (_, theBase) in atbatsToUpd.reversed().enumerated() {
            if theBase.outAt == "Safe" {
                if theBase.maxbase == "Third" {
                    iStat.onThird = true
                } else if theBase.maxbase == "Second" {
                    iStat.onSecond = true
                } else if theBase.maxbase == "First" {
                    iStat.onFirst = true
                }
            }
        }
        makeNewRect(rec: CGRect(x: 550, y: 50, width: 15, height: 15), fillColor: iStat.onThird ? .yellow : .clear, lineColor: .gray, ang:45,isDeg: true)
        makeNewRect(rec: CGRect(x: 552 + 11.18, y: 48 - 11.18, width: 15, height: 15), fillColor: iStat.onSecond ? .yellow : .clear, lineColor: .gray, ang:45,isDeg: true)
        makeNewRect(rec: CGRect(x: 577.36, y: 50, width: 15, height: 15), fillColor: iStat.onFirst ? .yellow : .clear, lineColor: .gray, ang:45,isDeg: true)

        if iStat.outs == 1 {
            let innString = NSAttributedString(string: "•", attributes: outATTR)
            innString.draw(at: CGPoint(x: 563, y: 34))
        } else if iStat.outs == 2 {
            var innString = NSAttributedString(string: "•", attributes: outATTR)
            innString.draw(at: CGPoint(x: 563, y: 34))
            innString = NSAttributedString(string: "•", attributes: outATTR)
            innString.draw(at: CGPoint(x: 571, y: 34))
        }
    }
    func drawPitchers (game:Game, team:Team) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let pitchATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.red, .paragraphStyle: paragraph]
        let headATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black, .paragraphStyle: paragraph]
        var tName = ""
        if game.vteam?.name == team.name {
            tName = game.hteam?.name ?? ""
        } else {
            tName = game.vteam?.name ?? ""
        }
        var pitchString = NSAttributedString(string: "\(tName) Pitching Stats For This Game", attributes: headATTR)
        pitchString.draw(in: CGRect(x: 35, y: (numOfPlayers * 30) + 150, width: 800, height: 18))

        makeNewRect(rec: CGRect(x:35, y: (numOfPlayers * 30) + 190, width: 50, height: 15), fillColor: .yellow, lineColor: .gray)
        pitchString = NSAttributedString(string: "Num", attributes: pitchATTR)
        pitchString.draw(in: CGRect(x: 35, y: (numOfPlayers * 30) + 175, width: 50, height: 15))
        makeNewRect(rec: CGRect(x:90, y: (numOfPlayers * 30) + 190, width: 150, height: 15), fillColor: .yellow, lineColor: .gray)
        pitchString = NSAttributedString(string: "Pitcher", attributes: pitchATTR)
        pitchString.draw(in: CGRect(x: 90, y: (numOfPlayers * 30) + 175, width: 150, height: 15))
        makeNewRect(rec: CGRect(x:245, y: (numOfPlayers * 30) + 190, width: 200, height: 15), fillColor: .yellow, lineColor: .gray)
        pitchString = NSAttributedString(string: "Inn  Outs  Bats   Inn  Outs  Bats", attributes: pitchATTR)
        pitchString.draw(in: CGRect(x: 245, y: (numOfPlayers * 30) + 175, width: 200, height: 15))
        makeNewRect(rec: CGRect(x:450, y: (numOfPlayers * 30) + 190, width: 50, height: 15), fillColor: .yellow, lineColor: .gray)
        pitchString = NSAttributedString(string: "ERA", attributes: pitchATTR)
        pitchString.draw(in: CGRect(x: 450, y: (numOfPlayers * 30) + 175, width: 50, height: 15))
        makeNewRect (rec: CGRect(x:505, y: (numOfPlayers * 30) + 190, width: 50, height: 15), fillColor: .yellow, lineColor: .gray)
        pitchString = NSAttributedString(string: "ER", attributes: pitchATTR)
        pitchString.draw(in: CGRect(x: 505, y: (numOfPlayers * 30) + 175, width: 50, height: 15))
        makeNewRect (rec: CGRect(x:560, y: (numOfPlayers * 30) + 190, width: 50, height: 15), fillColor: .yellow, lineColor: .gray)
        pitchString = NSAttributedString(string: "UER", attributes: pitchATTR)
        pitchString.draw(in: CGRect(x: 560, y: (numOfPlayers * 30) + 175, width: 50, height: 15))
        makeNewRect(rec: CGRect(x:615, y: (numOfPlayers * 30) + 190, width: 50, height: 15), fillColor: .yellow, lineColor: .gray)
        pitchString = NSAttributedString(string: "Hit", attributes: pitchATTR)
        pitchString.draw(in: CGRect(x: 615, y: (numOfPlayers * 30) + 175, width: 50, height: 15))
        makeNewRect(rec: CGRect(x:670, y: (numOfPlayers * 30) + 190, width: 50, height: 15), fillColor: .yellow, lineColor: .gray)
        pitchString = NSAttributedString(string: "Ks", attributes: pitchATTR)
        pitchString.draw(in: CGRect(x: 670, y: (numOfPlayers * 30) + 175, width: 50, height: 15))
        makeNewRect(rec: CGRect(x:725, y: (numOfPlayers * 30) + 190, width: 50, height: 15), fillColor: .yellow, lineColor: .gray)
        pitchString = NSAttributedString(string: "BB", attributes: pitchATTR)
        pitchString.draw(in: CGRect(x: 725, y: (numOfPlayers * 30) + 175, width: 50, height: 15))
        makeNewRect(rec: CGRect(x:780, y: (numOfPlayers * 30) + 190, width: 50, height: 15), fillColor: .yellow, lineColor: .gray)
        pitchString = NSAttributedString(string: "HR", attributes: pitchATTR)
        pitchString.draw(in: CGRect(x: 780, y: (numOfPlayers * 30) + 175, width: 50, height: 15))
        
        drawPitchStats (game: game, team: team)
        

    }
    func doPitchers(oAtbats:[Atbat],pitcher: Pitcher)->PitchStats {
        let com = Common()
        if oAtbats.count > 0 {
            let endinn = pitcher.endInn > 0 ? pitcher.endInn : Int(oAtbats[(oAtbats.count - 1)].inning) + 1
            let innings = CGFloat(oAtbats.filter({(com.outresults.contains($0.result) || $0.outAt != "Safe") &&
                                                (10 * (Int($0.inning.rounded(.up))) + $0.outs >= (10 * pitcher.startInn) + pitcher.sOuts) &&
                                                (10 * (Int($0.inning.rounded(.up))) + $0.outs <= (10 * endinn) + pitcher.eOuts ||
                                                (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count) / 3
            let runs = oAtbats.filter({$0.maxbase == "Home" &&  (10 * (Int($0.inning.rounded(.up))) + $0.seq > (10 * pitcher.startInn) + pitcher.sBats) &&
                                                                (10 * (Int($0.inning.rounded(.up))) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                                                                (Int($0.inning) == endinn - 1 && $0.outs == 3)) && $0.earnedRun}).count
            let uruns = oAtbats.filter({$0.maxbase == "Home" &&  (10 * (Int($0.inning.rounded(.up))) + $0.seq > (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning.rounded(.up))) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3)) && !$0.earnedRun}).count
            let hits = oAtbats.filter({com.hitresults.contains($0.result) &&    (10 * (Int($0.inning.rounded(.up))) + $0.seq > (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning.rounded(.up))) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let HR = oAtbats.filter({$0.result == "Home Run" && (10 * (Int($0.inning.rounded(.up))) + $0.seq > (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning.rounded(.up))) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let BB = oAtbats.filter({$0.result == "Walk" && (10 * (Int($0.inning.rounded(.up))) + $0.seq > (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning.rounded(.up))) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let Ks = oAtbats.filter({($0.result == "Strikeout" || $0.result == "Strikeout Looking") && (10 * (Int($0.inning.rounded(.up))) + $0.seq > (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning.rounded(.up))) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let singles = oAtbats.filter({$0.result == "Single" &&  (10 * (Int($0.inning.rounded(.up))) + $0.seq > (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning.rounded(.up))) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let doubles = oAtbats.filter({$0.result == "Double" &&  (10 * (Int($0.inning.rounded(.up))) + $0.seq > (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning.rounded(.up))) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let triples = oAtbats.filter({$0.result == "Triple" &&  (10 * (Int($0.inning.rounded(.up))) + $0.seq > (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning.rounded(.up))) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            
            let ERA = innings == 0 ? 0 : CGFloat(runs) / innings * 9
            return PitchStats(runs: runs, uruns: uruns, hits: hits, HR: HR, Ks: Ks, BB: BB, singles: singles, doubles: doubles, triples: triples, innings: Int(innings), ERA: ERA)
        } else {
            return PitchStats(ERA: 0.0)
        }
     
    }
    func fixInnings(pitchers:[Pitcher])->[Pitcher] {
        let pitchs = pitchers.sorted {( ($0.startInn, $0.sBats) < ($1.startInn, $1.eBats) )}
        return pitchs
    }
    func makeRect (rec: CGRect, fillColor: UIColor, lineColor: UIColor) {
        let aPath = UIBezierPath()
        lineColor.set()
        aPath.lineWidth = 1
        aPath.move(to: CGPoint(x:rec.minX, y: rec.minY))
        aPath.addLine(to: CGPoint(x:rec.minX + rec.width, y: rec.minY))
        aPath.addLine(to: CGPoint(x:rec.minX + rec.width, y: rec.minY + rec.height))
        aPath.addLine(to: CGPoint(x:rec.minX, y: rec.minY + rec.height))
        aPath.close( )
        aPath.stroke()
        fillColor.setFill( )
        aPath.fill( )

    }
    func makeNewRect (rec: CGRect, fillColor: UIColor, lineColor: UIColor, ang:CGFloat = 0 , isDeg:Bool = false) {
        
        var angle:CGFloat = 0
        
        if(isDeg) {
            angle = ang * (CGFloat.pi / 180)
        } else {
            angle = ang
        }
        let point1:CGPoint = CGPoint(x: rec.minX, y: rec.minY)
        let sinAng = sin(angle)
        let cosAng = cos(angle)
        
        var upDiff = sinAng * rec.width
        var sideDiff = cosAng * rec.width
        let point2:CGPoint = CGPoint(x: rec.minX + sideDiff, y: rec.minY + upDiff)
        
        upDiff = cosAng * rec.height
        sideDiff = sinAng * rec.height
        let point3 = CGPoint(x: rec.minX + sideDiff, y: rec.minY - upDiff)
        let point4 = CGPoint(x: point2.x + sideDiff, y: point2.y - upDiff)
        
        let aPath = UIBezierPath()
        lineColor.set()
        aPath.lineWidth = 1
        aPath.move(to: point1)
        aPath.addLine(to: point2)
        aPath.addLine(to: point4)
        aPath.addLine(to: point3)
        aPath.close( )
        aPath.stroke()
        fillColor.setFill( )
        aPath.fill( )
    }
    func drawPitchStats (game:Game, team:Team) {
        
        let decmatter = NumberFormatter()
        decmatter.numberStyle = .decimal
        decmatter.minimumFractionDigits = 2
        decmatter.maximumFractionDigits = 2
        decmatter.locale = Locale(identifier: "en_US")

        let wholematter = NumberFormatter()
        wholematter.numberStyle = .decimal
        wholematter.minimumFractionDigits = 0
        wholematter.maximumFractionDigits = 0
        wholematter.locale = Locale(identifier: "en_US")

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let pitchATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black, .paragraphStyle: paragraph]
        let hitATTR: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black]

        let oTHit = game.atbats.filter({$0.team == team})
        let oTHitting = oTHit.sorted{( ($0.col, $0.seq) < ($1.col, $1.seq) )}
        let pitchs = game.pitchers.filter({$0.team != team})
        let pitchers = fixInnings(pitchers: pitchs)
        for (index, pitcher) in pitchers.enumerated() {
            let stats = doPitchers(oAtbats: oTHitting, pitcher: pitcher)
            let sinn = String("\(pitcher.startInn)      \(pitcher.sOuts)      \(pitcher.sBats)")
            let einn = pitcher.endInn == 0 ? String("\(stats.innings + pitcher.startInn)      \(pitcher.eOuts)      \(pitcher.eBats)") :
            String("\(pitcher.endInn)      \(pitcher.eOuts)      \(pitcher.eBats)")
            var pitchString = NSAttributedString(string: "\(pitcher.player.number)", attributes: pitchATTR)
            pitchString.draw(in: CGRect(x: 35, y: (numOfPlayers * 30) + 190 + (index * 15), width: 50, height: 15))
            pitchString = NSAttributedString(string: "\(pitcher.player.name)", attributes: hitATTR)
            pitchString.draw(in: CGRect(x: 90, y: (numOfPlayers * 30) + 190 + (index * 15), width: 150, height: 15))
            pitchString = NSAttributedString(string: "\(sinn)    to   \(einn)", attributes: pitchATTR)
            pitchString.draw(in: CGRect(x: 245, y: (numOfPlayers * 30) + 190 + (index * 15), width: 200, height: 15))
            pitchString = NSAttributedString(string: decmatter.string(for: stats.ERA) ?? "0.00", attributes: pitchATTR)
            pitchString.draw(in: CGRect(x: 450, y: (numOfPlayers * 30) + 190 + (index * 15), width: 50, height: 15))
            pitchString = NSAttributedString(string: wholematter.string(for: stats.runs) ?? "0", attributes: pitchATTR)
            pitchString.draw(in: CGRect(x: 505, y: (numOfPlayers * 30) + 190 + (index * 15), width: 50, height: 15))
            pitchString = NSAttributedString(string: wholematter.string(for: stats.uruns) ?? "0", attributes: pitchATTR)
            pitchString.draw(in: CGRect(x: 560, y: (numOfPlayers * 30) + 190 + (index * 15), width: 50, height: 15))
            pitchString = NSAttributedString(string: wholematter.string(for: stats.hits) ?? "0", attributes: pitchATTR)
            pitchString.draw(in: CGRect(x: 615, y: (numOfPlayers * 30) + 190 + (index * 15), width: 50, height: 15))
            pitchString = NSAttributedString(string: wholematter.string(for: stats.Ks) ?? "0", attributes: pitchATTR)
            pitchString.draw(in: CGRect(x: 670, y: (numOfPlayers * 30) + 190 + (index * 15), width: 50, height: 15))
            pitchString = NSAttributedString(string: wholematter.string(for: stats.BB) ?? "0", attributes: pitchATTR)
            pitchString.draw(in: CGRect(x: 725, y: (numOfPlayers * 30) + 190 + (index * 15), width: 50, height: 15))
            pitchString = NSAttributedString(string: wholematter.string(for: stats.HR) ?? "0", attributes: pitchATTR)
            pitchString.draw(in: CGRect(x: 780, y: (numOfPlayers * 30) + 190 + (index * 15), width: 50, height: 15))

        }
    }
}

