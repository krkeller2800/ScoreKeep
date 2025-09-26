//
//  drawCardView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 4/21/25.
//

import SwiftUI
import SwiftData
import Foundation

struct drawSing: View {
    var space: CGRect
    var atbats:[Atbat]
    var colbox:[BoxScore]
    var batbox:[BoxScore]
    var totbox:[BoxScore]
    var sWidth: CGFloat
    @Binding var isLoading: Bool
    let com = Common()
    
    var body: some View {
        
        ForEach(Array(atbats.enumerated()), id: \.1) { index, atbat in
            if let xx = com.battings.firstIndex(where: { $0 == atbat.result }) {
                let abb = com.batAbbrevs[xx]
                let yoffset = UIScreen.screenWidth > 1200 && UIScreen.screenWidth < 1400 ? 1.0 : 1.0
                let y = (Double(atbat.batOrder) - yoffset) * space.height + space.minY
                let w = space.width
                let h = space.height
                let outs = atbat.outs
                let inning = outs != 0 ? atbat.inning.rounded(.up) : atbat.inning + 1
                let x = CGFloat(atbat.col) * space.width + space.minX

                drawTots(space: space, atbat: atbat, atbats: atbats, abb: abb, inning: Int(inning), colbox: colbox, batbox: batbox, totbox: totbox, sWidth: sWidth)
                
                if abb == "hr" {
                    Path() {
                        myPath in
                        myPath.move(to: CGPoint(x: 0.5 * w + x, y: 0.9 * h + y))
                        myPath.addLine(to: CGPoint(x: 0.9 * w + x, y: 0.5 * h + y))
                        myPath.addLine(to: CGPoint(x: 0.5 * w + x, y: 0.1 * h + y))
                        myPath.addLine(to: CGPoint(x: 0.1 * w + x, y: 0.5 * h + y))
                        myPath.addLine(to: CGPoint(x: 0.5 * w + x, y: 0.9 * h + y))
                    }
                    .fill(.black)
                    Text(abb)
                        .frame(width: 28, alignment: .center).lineLimit(1).minimumScaleFactor(0.01)
                        .font(.system(size: 22)).bold().foregroundColor(.white)
                        .position(x: 0.5 * w + x, y: 0.55 * h + y)
                } else if atbat.outAt == "Safe" &&  !com.outabs.contains(abb) {
                    Path() {
                        myPath in
                        myPath.move(to: CGPoint(x: 0.5 * w + x, y: 0.9 * h + y))
                        myPath.addLine(to: CGPoint(x: 0.9 * w + x, y: 0.5 * h + y))
                        if abb == "2B" || abb == "3B" {
                            myPath.addLine(to: CGPoint(x: 0.5 * w + x, y: 0.1 * h + y))
                        }
                        if abb == "3B" {
                            myPath.addLine(to: CGPoint(x: 0.1 * w + x, y: 0.5 * h + y))
                        }
                    }
                    .stroke(Color.cyan, lineWidth: 2)
                    Text(abb)
                        .frame(width: 28, alignment: .center).lineLimit(1).minimumScaleFactor(0.01)
                        .font(.system(size: 22)).bold()
                        .position(x: 0.5 * w + x, y: 0.55 * h + y)
                } else {
                    Text(abb)
                        .frame(width: 28, alignment: .center).lineLimit(1).minimumScaleFactor(0.01)
                        .font(.system(size: 22)).bold()
                        .position(x: 0.5 * w + x, y: 0.55 * h + y)
                }
                if com.recOuts.contains(atbat.result) || atbat.outAt != "Safe" {
                    let pctIn = atbat.result == "Fielder's Choice" || atbat.outAt != "Safe" ? 0.8 : 0.5
                    Text(atbat.playRec)
                        .font(.system(size: 12))
                        .position(x: pctIn * w + x, y: 0.86 * h + y)
                 }
                if atbat.maxbase != "No Bases" {
                    drawRunner(space: CGRect(x: x, y: y, width: w, height: h), atbat: atbat, abb: abb)
                }
                if atbat.outAt != "Safe" {
                    drawout(space: CGRect(x: x, y: y, width: w, height: h), atbat: atbat, abb: abb)
                }
                if com.outabs.contains(abb) || atbat.outAt != "Safe" {

                }
                if outs == 1 && (com.outresults.contains(atbat.result) || atbat.outAt != "Safe") {
                    Text("*")
                        .font(.system(size: 18)).bold().foregroundColor(.red)
                        .position(x: 0.1 * w + x, y: 0.2 * h + y)
                } else if outs == 2 && (com.outresults.contains(atbat.result) || atbat.outAt != "Safe") {
                    Text("**")
                        .font(.system(size: 18)).bold().foregroundColor(.red)
                        .position(x: 0.15 * w + x, y: 0.2 * h + y)
                } else if outs == 3 && (com.outresults.contains(atbat.result) || atbat.outAt != "Safe") {
                    Text("***")
                        .font(.system(size: 15)).bold().foregroundColor(.red)
                        .position(x: 0.2 * w + x, y: 0.2 * h + y)
                }
                if outs == 3 && atbat.endOfInning {
                        Path() {
                            myPath in
                            myPath.move(to: CGPoint(x: x, y: h + y))
                            myPath.addLine(to: CGPoint(x: w + x, y: h + y))
                        }
                        .stroke(Color.red, lineWidth: 5)
                }
            }
        }
    }
}
struct drawout: View {
    var space: CGRect
    var atbat:Atbat
    var abb:String
    var body: some View {
        if atbat.outAt == "Home" {
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: 0.5 * space.width + space.minX, y: 0.9 * space.height + space.minY))
                myPath.addLine(to: CGPoint(x: 0.9 * space.width + space.minX, y: 0.5 * space.height + space.minY))
                myPath.addLine(to: CGPoint(x: 0.5 * space.width + space.minX, y: 0.1 * space.height + space.minY))
                myPath.addLine(to: CGPoint(x: 0.1 * space.width + space.minX, y: 0.5 * space.height + space.minY))
                myPath.addLine(to: CGPoint(x: 0.5 * space.width + space.minX, y: 0.9 * space.height + space.minY))
            }
            .stroke(Color.cyan, lineWidth: 2)
            Text("x")
                .font(.system(size: 20)).foregroundColor(.black)
                .position(x: 0.5 * space.width + space.minX, y: 0.9 * space.height + space.minY)

        } else {
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: 0.5 * space.width + space.minX, y: 0.9 * space.height + space.minY))
                myPath.addLine(to: CGPoint(x: 0.9 * space.width + space.minX, y: 0.5 * space.height + space.minY))
                if atbat.outAt == "Second" || atbat.outAt == "Third" {
                    myPath.addLine(to: CGPoint(x: 0.5 * space.width + space.minX, y: 0.1 * space.height + space.minY))
                }
                if atbat.outAt == "Third" {
                    myPath.addLine(to: CGPoint(x: 0.1 * space.width + space.minX, y: 0.5 * space.height + space.minY))
                }
            }
            .stroke(Color.cyan, lineWidth: 2)
            if atbat.outAt == "First" {
                Text("x")
                    .font(.system(size: 20))
                    .position(x: 0.9 * space.width + space.minX, y: 0.5 * space.height + space.minY)
            } else if atbat.outAt == "Second" {
                Text("x")
                    .font(.system(size: 20))
                    .position(x: 0.5 * space.width + space.minX, y: 0.1 * space.height + space.minY)
            } else if atbat.outAt == "Third" {
                Text("x")
                    .font(.system(size: 20))
                    .position(x: 0.1 * space.width + space.minX, y: 0.5 * space.height + space.minY)
            }
        }
    }
}
struct drawRunner: View {
    var space: CGRect
    var atbat:Atbat
    var abb:String
    var body: some View {
        if atbat.maxbase == "Home" {
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: 0.5 * space.width + space.minX, y: 0.9 * space.height + space.minY))
                myPath.addLine(to: CGPoint(x: 0.9 * space.width + space.minX, y: 0.5 * space.height + space.minY))
                myPath.addLine(to: CGPoint(x: 0.5 * space.width + space.minX, y: 0.1 * space.height + space.minY))
                myPath.addLine(to: CGPoint(x: 0.1 * space.width + space.minX, y: 0.5 * space.height + space.minY))
            }
            .fill(.black)
            Text(abb)
                .frame(width: 28, alignment: .center).lineLimit(1).minimumScaleFactor(0.01)
               .font(.system(size: 22)).bold().foregroundColor(.white)
               .position(x: 0.5 * space.width + space.minX, y: 0.55 * space.height + space.minY)

        } else {
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: 0.5 * space.width + space.minX, y: 0.9 * space.height + space.minY))
                myPath.addLine(to: CGPoint(x: 0.9 * space.width + space.minX, y: 0.5 * space.height + space.minY))
                if atbat.maxbase == "Second" || atbat.maxbase == "Third" {
                    myPath.addLine(to: CGPoint(x: 0.5 * space.width + space.minX, y: 0.1 * space.height + space.minY))
                }
                if atbat.maxbase == "Third" {
                    myPath.addLine(to: CGPoint(x: 0.1 * space.width + space.minX, y: 0.5 * space.height + space.minY))
                }
            }
            .stroke(Color.cyan, lineWidth: 2)
            Text(abb)
                .frame(width: 28, alignment: .center).lineLimit(1).minimumScaleFactor(0.01)
                .font(.system(size: 22)).bold()
                .position(x: 0.5 * space.width + space.minX, y: 0.55 * space.height + space.minY)
        }
    }
}
struct drawTots: View {
    var space: CGRect
    var atbat:Atbat
    var atbats:[Atbat]
    var abb:String
    var inning:Int
    var colbox:[BoxScore]
    var batbox:[BoxScore]
    var totbox:[BoxScore]
    var sWidth:CGFloat
    @State var screenHeight:CGFloat = 0
    @State var screenWidth:CGFloat = 0
    let com = Common()
    var body: some View {

        let bigCol = atbats.filter{$0.result != "Result"}.max { $0.col < $1.col }
//        let bSize = sWidth > 1100 ? 14 : 9
        let gridSz = CGFloat(sWidth > 1100 ? 60 : 50)
        let bSize = Int(((sWidth - (sWidth > 1100 ? 425 : 325)) / gridSz).rounded(.down))
        let newCol = (bigCol?.col ?? 0) + 1
        let maxCol = CGFloat(newCol < bSize ? bSize : newCol)
        let yoffset = UIScreen.screenWidth > 1200 &&  UIScreen.screenWidth < 1400 ? 1.0 : 1.0
        let y = (Double(atbat.batOrder) - yoffset) * space.height + space.minY
        let box = batbox[Int(atbat.batOrder)]
        let box2 = totbox[0]
        let box3 = colbox[atbat.col]
        let newy = (CGFloat(atbats.filter({$0.col == 1}).count) * space.height) + space.minY
        let from = CGRect(x: (( maxCol + 2) * space.width) + space.minX, y: space.minY,width:0, height:0)
        let to = CGRect(x: (( maxCol + 2) * space.width) + space.minX, y: space.height + newy-15,width:0, height:0)
        let eachLine = CGRect(x: (( maxCol  + 2) * space.width) + space.minX, y: space.height + y, width:0, height:0)
        let x = CGFloat(atbat.col) * space.width + space.minX
        let placeBox = CGRect(x: x - (0 * space.width), y: 0.1 * space.height + newy, width:space.width, height:space.height)
        
//        if inning < 99 {
//            Text(com.innAbr[inning] + " Inn")
//                .font(.system(size: 10)).bold().foregroundColor(.black)
//                .position(x: 0.5 * space.width + x, y: space.minY - 7)
//        }
//        Text("Runs")
//            .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .leading)
//            .position(x: from.minX + (space.width * -0.5), y:space.minY - 7)
//        Text("Hits")
//            .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .leading)
//            .position(x: from.minX + (space.width * 0.1), y:space.minY - 7)
//        Text("HR")
//            .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .leading)
//            .position(x: from.minX + (space.width * 0.7), y:space.minY - 7)
//        Text("BB")
//            .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .leading)
//            .position(x: from.minX + (space.width * 1.3), y:space.minY - 7)
//        Text("Ks")
//            .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .leading)
//            .position(x: from.minX + (space.width * 1.9), y:space.minY - 7)
//        Text("SB")
//            .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .leading)
//            .position(x: from.minX + (space.width * 2.5), y:space.minY - 7)
        Text("  R   H ")
            .foregroundColor(.black).frame(alignment: .leading)
            .position(x: space.minX + (0.5 * space.width), y: 0.35 * space.height + newy)
        Text("\(box.runs)")
            .position(x: from.minX - (space.width * 0.5), y:0.5 * space.height + y)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box.hits)")
            .position(x: from.minX + (space.width * 0.1), y:0.5 * space.height + y)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box.HR)")
            .position(x:from.minX + (space.width * 0.7), y:0.5 * space.height + y)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box.walks)")
            .position(x:from.minX + (space.width * 1.3), y:0.5 * space.height + y)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box.strikeouts)")
            .position(x:from.minX + (space.width * 1.9), y:0.5 * space.height + y)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box.stoleBase)")
            .position(x:from.minX + (space.width * 2.5), y:0.5 * space.height + y)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box2.runs)")
            .position(x: from.minX - (space.width * 0.5), y:0.4 * space.height + newy)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box2.hits)")
            .position(x: from.minX + (space.width * 0.1), y:0.4 * space.height + newy)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box2.HR)")
            .position(x:from.minX + (space.width * 0.7), y:0.4 * space.height + newy)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box2.walks)")
            .position(x:from.minX + (space.width * 1.3), y:0.4 * space.height + newy)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box2.strikeouts)")
            .position(x:from.minX + (space.width * 1.9), y:0.4 * space.height + newy)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box2.stoleBase)")
            .position(x:from.minX + (space.width * 2.5), y:0.4 * space.height + newy)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box3.runs)")
            .position(x: placeBox.minX + (space.width * 0.25), y:0.25 * space.height + placeBox.minY)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box3.hits)")
            .position(x: placeBox.minX + (space.width * 0.75), y:0.25 * space.height + placeBox.minY)
            .font(.headline).foregroundColor(.black).background(.clear)
 
        Text(".").position(x:from.minX + 500 + (space.width * 2.5), y:0.5 * space.height + y)

        if newCol < 13 {
            Text("Total >")
                .font(.headline).foregroundColor(.black).frame(width: 90, alignment: .leading)
                .position(x: (maxCol + 1) * space.width + space.minX - (space.width * 0.1), y:0.4 * space.height + newy)
        }
        
        drawLines(from: from, to: to, ffacter: (-0.8 * space.width), tfacter: (-0.8 * space.width))
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        drawLines(from: from, to: to, ffacter: (-0.2 * space.width), tfacter: (-0.2 * space.width))
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        drawLines(from: from, to: to, ffacter: (0.4 * space.width), tfacter: (0.4 * space.width))
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        drawLines(from: from, to: to, ffacter: (1 * space.width), tfacter: (1 * space.width))
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        drawLines(from: from, to: to, ffacter: (1.6 * space.width), tfacter: (1.6 * space.width))
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        drawLines(from: from, to: to, ffacter: (2.2 * space.width), tfacter: (2.2 * space.width))
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        drawLines(from: from, to: to, ffacter: (2.8 * space.width), tfacter: (2.8 * space.width))
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        drawLines(from: to, to: to, ffacter: (-0.8 * space.width), tfacter: (2.8 * space.width))
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        drawLines(from: from, to: from, ffacter: (-0.8 * space.width), tfacter: (2.8 * space.width))
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        drawLines(from: eachLine, to: eachLine, ffacter: (-0.8 * space.width), tfacter: (2.8 * space.width))
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        drawBox(start: placeBox)
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        drawBox(start:CGRect(x: space.minX + 2, y: 0.1 * space.height + newy, width:space.width, height:space.height))
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
 
        if atbat.col == 1 && atbat.batOrder == 1 {
//            drawPitchers(space: space, atbats: atbats, abb: "", inning: 1)
        }
    }
    func drawLines(from: CGRect, to: CGRect, ffacter:CGFloat,tfacter:CGFloat) -> Path {
        Path() {
            myPath in
            myPath.move(to: CGPoint(x: from.minX + ffacter, y: from.minY ))
            myPath.addLine(to: CGPoint(x: to.minX + tfacter, y:to.minY))
        }
    }
    func drawBox(start: CGRect) -> Path {
        Path() {
            myPath in
            myPath.move(to: CGPoint(x: start.minX, y: start.minY ))
            myPath.addLine(to: CGPoint(x: start.minX, y:start.minY + (0.5 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (1 * start.width), y:start.minY + (0.5 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (1 * start.width), y:start.minY + (0 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (0 * start.width), y:start.minY + (0 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (0.5 * start.width), y:start.minY + (0 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (0.5 * start.width), y:start.minY + (0.5 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (1 * start.width), y:start.minY + (0.5 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (1 * start.width), y:start.minY + (0 * start.height)))
        }
    }
}
struct drawBoxScore: View {
    var game:Game
    var size:CGSize
    let com = Common()
    var body: some View {
        
        let adj:CGFloat = UIDevice.type == "iPhone" ? 5 : 0
        let font:Font = UIDevice.type == "iPhone" ? .caption : .headline
        let placeBox = CGRect(x: (UIDevice.type == "iPhone" ? 0.195 : 0.20) * size.width, y: UIDevice.type == "iPhone" ? -87 : -130, width:150, height:100)
        let boxHome = doBoxScore(doTeam: "Home")
        let boxVisit = doBoxScore(doTeam: "Visit")
        let com = Common()
        let homeOuts = game.atbats.filter({$0.team.name == game.hteam!.name && (com.outresults.contains($0.result) || $0.outAt != "Safe" )}).count
        let visitOuts = game.atbats.filter({$0.team.name == game.vteam!.name && (com.outresults.contains($0.result) || $0.outAt != "Safe" )}).count
        let v3outs = visitOuts % 3 == 0
        let h3outs = homeOuts % 3 == 0
        let vinning:Int = visitOuts / 3
        let theInning = homeOuts < visitOuts && h3outs && v3outs ? "\(com.innAbr[Int(vinning)])" :
                        homeOuts <= visitOuts && !h3outs ? "\(com.innAbr[Int(vinning)])" : "\(com.innAbr[Int(vinning + 1)])"
        let theHalf = homeOuts < visitOuts && v3outs ? "Bot" : "Top"

        Text(game.vteam?.name ?? "")
            .font(font).foregroundColor(.black).background(.clear).frame(width:100,alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
            .position(x: placeBox.minX - 55, y: placeBox.minY + 13).bold()
        Text(game.hteam?.name ?? "")
            .font(font).foregroundColor(.black).background(.white, ignoresSafeAreaEdges: []).frame(width:100,alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
            .position(x: placeBox.minX - 55, y: placeBox.minY + 38 - 2*adj).bold()
        Text("\(boxVisit.runs)")
            .position(x: placeBox.minX + 56 - 4*adj, y: placeBox.minY + 13)
            .font(font).foregroundColor(.black).background(.clear)
        Text("\(boxVisit.hits)")
            .position(x: placeBox.minX + 93 - 9*adj, y: placeBox.minY + 13)
            .font(font).foregroundColor(.black).background(.clear)
        Text("\(boxVisit.error)")
            .position(x: placeBox.minX + 130 - 13*adj, y: placeBox.minY + 13)
            .font(font).foregroundColor(.black).background(.clear)
        Text("\(boxHome.runs)")
            .position(x: placeBox.minX + 56 - 4*adj, y: placeBox.minY + 38 - 2*adj)
            .font(font).foregroundColor(.black).background(.clear)
        Text("\(boxHome.hits)")
            .position(x: placeBox.minX + 93 - 9*adj, y: placeBox.minY + 38 - 2*adj)
            .font(font).foregroundColor(.black).background(.clear)
        Text("\(boxHome.error)")
            .position(x: placeBox.minX + 130 - 13*adj, y: placeBox.minY + 38 - 2*adj)
            .font(font).foregroundColor(.black).background(.clear)
        Text(UIDevice.type == "iPhone" ? "  Inn  R  H  E" : "Inning  Runs   Hits   Errors")
            .font(.caption).italic().foregroundColor(.black).frame(width:150,alignment: .leading)
            .position(x: placeBox.minX + 75, y:placeBox.minY - 10 + 2*adj)
        Text(theHalf)
            .font(.caption).italic().foregroundColor(.black).frame(width: 35, alignment: .center).lineLimit(1).minimumScaleFactor(0.1)
            .position(x: placeBox.minX + 20 - 1*adj, y:placeBox.minY + 15)
        Text(theInning)
            .font(.caption).italic().foregroundColor(.black).frame(width: 35, alignment: .center).lineLimit(1).minimumScaleFactor(0.1)
            .position(x: placeBox.minX + 20 - 1*adj, y:placeBox.minY + 35 - adj)

        drawBox(start: placeBox, adj:adj)
            .stroke(Color.gray, lineWidth: 1)

        
    }
    func doBoxScore(doTeam:String)->BoxScore {
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
    func drawBox(start: CGRect, adj:CGFloat) -> Path {
        Path() {
            myPath in
            myPath.move(to: CGPoint(x: start.minX, y: start.minY + 1.4*adj ))
            myPath.addLine(to: CGPoint(x: start.minX, y:start.minY - 2.8*adj + (0.5 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX - 15*adj + (1 * start.width), y:start.minY - 2.8*adj + (0.5 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX - 15*adj + (1 * start.width), y:start.minY + 1.4*adj + (0 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (0 * start.width), y:start.minY + 1.4*adj + (0 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX - 2*adj + (0.25 * start.width), y:start.minY + 1.4*adj + (0 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX - 2*adj + (0.25 * start.width), y:start.minY - 2.8*adj + (0.5 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX - 6.5*adj + (0.5 * start.width), y:start.minY - 2.8*adj + (0.5 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX - 6.5*adj + (0.5 * start.width), y:start.minY + 1.4*adj + (0 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX - 11*adj + (0.75 * start.width), y:start.minY + 1.4*adj + (0 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX - 11*adj + (0.75 * start.width), y:start.minY - 2.8*adj + (0.5 * start.height)))
        }
    }
}
struct drawPitchers: View {
    var space: CGRect
    var atbats:[Atbat]
    var abb:String
    var inning:Int
    var game:Game
    var team:Team
    var width: CGFloat
    @State var showPitchers:Bool = false
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    let com = Common()

    var body: some View {
        
        GeometryReader { geometry in
//            let w = geometry.size.width
//            let width = UIScreen.screenWidth
            VStack {
                Spacer()
                Text("\(team.name) Pitching Stats For This Game").font(.title2).frame(maxWidth:.infinity, alignment: .center).italic()
                HStack {
//                    Text("Num").frame(maxWidth:.infinity).border(.gray)
//                        .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                    Text("Pitcher").frame(width: UIDevice.type == "iPhone" ? 125 : 150).border(.gray)
                        .foregroundColor(.red).bold().padding(.leading,0).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                    Text("Inn").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                    Text("Outs").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                    Text("Bats").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 30)
                    Text("Inn").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                    Text("Outs").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                    Text("Bats").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                    Text("ERA").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                    Text("ER").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                    Text("UER").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                    if width > 1000 {
                        Text("Hit").frame(maxWidth:.infinity).border(.gray)
                            .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                        Text("Ks").frame(maxWidth:.infinity).border(.gray)
                            .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                        Text("BB").frame(maxWidth:.infinity).border(.gray)
                            .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                        Text("HR").frame(maxWidth:.infinity).border(.gray)
                            .foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Text("").frame(width:15)
                }
                let oTHit = game.atbats.filter({$0.team == atbats[0].team})
                let oTHitting = oTHit.sorted{ ($0.col, $0.seq) < ($1.col, $1.seq) }
                let pitchs = game.pitchers.filter({$0.team != atbats[0].team})
                let pitchers = fixInnings(pitchers: pitchs, atbats: oTHitting)
                ForEach(Array(pitchers.enumerated()), id: \.offset) { index, pitcher in
                    NavigationLink(value: pitcher) {
                        VStack(spacing:0) {
                            HStack{
                                let stats = doPitchers(oAtbats: oTHitting, pitcher: pitcher)
                                let lName = pitcher.player.name.split(separator: " ").last ?? ""
                                Text(lName).lineLimit(1).minimumScaleFactor(0.6)
                                    .foregroundColor(.black).frame(width: UIDevice.type == "iPhone" ? 125 : 150,alignment: .leading).lineLimit(1).minimumScaleFactor(0.8)
                                Text(Double(pitcher.startInn), format: .number.rounded(increment: 1.0)).lineLimit(1).minimumScaleFactor(0.8) // 12 (whole number)
                                    .foregroundColor(.black).frame(maxWidth: .infinity)
                                Text(Double(pitcher.sOuts), format: .number.rounded(increment: 1.0)).lineLimit(1).minimumScaleFactor(0.8) // 12 (whole number)
                                    .foregroundColor(.black).frame(maxWidth: .infinity)
                                Text(Double(pitcher.sBats), format: .number.rounded(increment: 1.0)).lineLimit(1).minimumScaleFactor(0.8) // 12 (whole number)
                                    .foregroundColor(.black).frame(maxWidth: .infinity)
                                Text("to").foregroundColor(.black)
                                Text(Double(pitcher.endInn), format: .number.rounded(increment: 1.0)).lineLimit(1).minimumScaleFactor(0.8) // 12 (whole number)
                                    .foregroundColor(.black).frame(maxWidth: .infinity)
                                Text(Double(pitcher.eOuts), format: .number.rounded(increment: 1.0)).lineLimit(1).minimumScaleFactor(0.8) // 12 (whole number)
                                    .foregroundColor(.black).frame(maxWidth: .infinity)
                                Text(Double(pitcher.eBats), format: .number.rounded(increment: 1.0)).lineLimit(1).minimumScaleFactor(0.8) // 12 (whole number)
                                    .foregroundColor(.black).frame(maxWidth: .infinity)
                                Text(Double(stats.ERA), format: Int(stats.ERA) > 99 ? .number.rounded(increment: 1.0) :
                                                                stats.ERA > 9.99 ? .number.rounded(increment: 0.1) : .number.rounded(increment: 0.01)).lineLimit(1).minimumScaleFactor(0.8)
                                    .foregroundColor(.black).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.8)
                                Text(Double(stats.runs), format: .number.rounded(increment: 1.0)).lineLimit(1).minimumScaleFactor(0.8) // 12 (whole number)
                                    .foregroundColor(.black).frame(maxWidth:.infinity)
                                Text(Double(stats.uruns), format: .number.rounded(increment: 1.0)).lineLimit(1).minimumScaleFactor(0.8) // 12 (whole number)
                                    .foregroundColor(.black).frame(maxWidth:.infinity)
                                if width > 1000 {
                                    Text(Double(stats.hits), format: .number.rounded(increment: 1.0)).lineLimit(1).minimumScaleFactor(0.8) // 12 (whole number)
                                        .foregroundColor(.black).frame(maxWidth:.infinity)
                                    Text(Double(stats.Ks), format: .number.rounded(increment: 1.0)).lineLimit(1).minimumScaleFactor(0.8) // 12 (whole number)
                                        .foregroundColor(.black).frame(maxWidth:.infinity)
                                    Text(Double(stats.BB), format: .number.rounded(increment: 1.0)).lineLimit(1).minimumScaleFactor(0.8) // 12 (whole number)
                                        .foregroundColor(.black).frame(maxWidth:.infinity)
                                    Text(Double(stats.HR), format: .number.rounded(increment: 1.0)).lineLimit(1).minimumScaleFactor(0.8) // 12 (whole number)
                                        .foregroundColor(.black).frame(maxWidth:.infinity)
                                }
                                Image(systemName: "chevron.right").padding(.horizontal,0)
                            }
//                            Divider()
                        }
                    }
                }
                .navigationDestination(for: Pitcher.self) { pitcher in
                    EditPitcherView(pitcher: pitcher, game: atbats[0].game)
                }
//                .hid
                .onAppear() {
                    
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }
    func doPitchers(oAtbats:[Atbat],pitcher: Pitcher)->PitchStats {
        if oAtbats.count > 0 {
            let endinn = pitcher.endInn > 0 ? pitcher.endInn : Int(oAtbats[(oAtbats.count - 1)].inning) + 1
            let pitchOuts = ((pitcher.endInn - pitcher.startInn) * 3) + (pitcher.eOuts - pitcher.sOuts)
            let innings:CGFloat = CGFloat(pitchOuts) / 3.0
//            let innings = CGFloat(oAtbats.filter({(com.outresults.contains($0.result) || $0.outAt != "Safe") &&
//                                                (10 * (Int($0.inning.rounded(.up))) + $0.outs >= (10 * pitcher.startInn) + pitcher.sOuts) &&
//                                                (10 * (Int($0.inning.rounded(.up))) + $0.outs <= (10 * endinn) + pitcher.eOuts ||
//                                                (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count) / 3
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
            
            let ERA = innings == 0 ? 999 : CGFloat(runs) / innings * 9
            return PitchStats(runs: runs, uruns: uruns, hits: hits, HR: HR, Ks: Ks, BB: BB, singles: singles, doubles: doubles, triples: triples, innings: Int(innings), ERA: ERA)
        } else {
            return PitchStats(ERA: 0.0)
        }
     
    }
    func fixInnings(pitchers:[Pitcher], atbats:[Atbat])->[Pitcher] {
        let pitchs = pitchers.sorted { ($0.startInn, $0.sOuts, $0.sBats) < ($1.startInn, $1.sOuts, $1.sBats) }
        if let currbatter = atbats.filter({$0.result != "Result"}).last {
            if currbatter.seq == 1 && currbatter.col == 1 {
                if let currPitch = pitchs.last {
                    currPitch.startInn = 1
                }
            } else {
                for pitch in pitchs {
                    if pitch.startInn == 0 {
                        if currbatter.outs == 3 {
                            pitch.startInn = Int(currbatter.inning.rounded(.up)) + 1
                            pitch.sOuts = 0
                            pitch.sBats = 0
                        } else {
                            pitch.startInn = Int(currbatter.inning.rounded(.up))
                            pitch.sOuts = currbatter.outs
                            pitch.sBats = currbatter.seq
                        }
                    }
                }
            }
            if let currPitch = pitchs.last {
                if currbatter.outs == 3 {
                    currPitch.endInn = Int(currbatter.inning.rounded(.up)) + 1
                    currPitch.eOuts = 0
                    currPitch.eBats = 0
                } else {
                    currPitch.endInn = Int(currbatter.inning.rounded(.up))
                    currPitch.eOuts = currbatter.outs
                    currPitch.eBats = currbatter.seq
                }
              
            }
        }
        return pitchs
    }
}

struct drawIndicator: View {
    var iStat:InnStatus
    var size:CGSize
    var colbox:[BoxScore]
    var space:CGRect
    
    var body: some View {
        
        //        let com = Common()
        let placeBox = CGRect(x: (UIDevice.type == "iPhone" ? 0.76 : 0.70) * size.width, y: UIDevice.type == "iPhone" ? -60 : -110, width:150, height:100)
        Rectangle().fill(iStat.onThird && iStat.outs != 3 ? Color.yellow : Color.clear).border(Color.gray, width: 1)
            .frame(width: 20, height: 20).rotationEffect(.degrees(45)).position(x:placeBox.minX, y:placeBox.minY)
        Rectangle().fill(iStat.onSecond && iStat.outs != 3 ? Color.yellow : Color.clear).border(Color.gray, width: 1)
            .frame(width: 20, height: 20).rotationEffect(.degrees(45)).position(x:placeBox.minX+17, y:placeBox.minY-17)
        Rectangle().fill(iStat.onFirst && iStat.outs != 3 ? Color.yellow : Color.clear).border(Color.gray, width: 1)
            .frame(width: 20, height: 20).rotationEffect(.degrees(45)).position(x:placeBox.minX+34, y:placeBox.minY)
        Circle().fill(iStat.outs == 1 || iStat.outs == 2 ? Color.red : Color.clear).frame(width: 10, height: 10)
            .position(x:placeBox.minX+13, y:placeBox.minY+15)
        Circle().fill(iStat.outs == 2 ? Color.red : Color.clear).frame(width: 10, height: 10)
            .position(x:placeBox.minX+25, y:placeBox.minY+15)
        //        ForEach(Array(colbox.enumerated()), id: \.1) { index, colb in
        //            if colb.inning != 0 {
        //                Text(com.innAbr[colb.inning]).position(x:(CGFloat(index) * space.width) + space.minX + 0.5*space.width, y:space.minY-25)
        //            }
        //        }
    }
}
struct drawInnings: View {
    var game:Game
    var atbats:[Atbat]
    var space:CGRect
    var offset:CGFloat
    var gWidth:CGFloat
    var body: some View {
        let com = Common()
        let bigCol = atbats.filter{$0.result != "Result"}.max { $0.col < $1.col }
        let fix = bigCol?.col ?? 0 > 1 ? 185.0 : 192.0
        ForEach(Array(atbats.enumerated()), id: \.1) { index, atbat in
            if atbat.result != "Result" && (atbat.seq == 1 || (atbat.seq > 10 && atbat.outs == 3)) {
                let x = CGFloat(atbat.col) * space.width + space.minX
                let outs = atbat.outs
                let inning = outs != 0 ? atbat.inning.rounded(.up) : atbat.inning + 1
                let xVal = ((0.5 * space.width + x + 185) - offset)
                if inning < 99 && xVal > 185 {
                    Text(com.innAbr[Int(inning)] + " Inn")
                        .font(.system(size: 10)).bold().foregroundColor(.black)
                        .position(x: (0.5 * space.width + x + fix) - offset, y: space.minY + 10)
                }
            }
        }
        if bigCol?.col ?? 0 > 0 {
            let gridSz = CGFloat(gWidth > 1100 ? 60 : 50)
            let bSize = Int(((gWidth - (gWidth > 1100 ? 425 : 325)) / gridSz).rounded(.down))
            let newCol = (bigCol?.col ?? 1) + 1
            let maxCol = CGFloat(newCol < bSize ? bSize : newCol)
            let from = CGRect(x: (( maxCol + 2) * space.width) + space.minX + fix, y: space.minY+3,width:0, height:0)
            Text("Runs")
                .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .center)
                .position(x: (from.minX + (space.width * -0.5)) - offset, y:space.minY + 10)
            Text("Hits")
                .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .center)
                .position(x: (from.minX + (space.width * 0.1)) - offset, y:space.minY + 10)
            Text("HR")
                .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .center)
                .position(x: (from.minX + (space.width * 0.7)) - offset, y:space.minY + 10)
            Text("BB")
                .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .center)
                .position(x: (from.minX + (space.width * 1.3)) - offset, y:space.minY + 10)
            Text("Ks")
                .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .center)
                .position(x: (from.minX + (space.width * 1.9)) - offset, y:space.minY + 10)
            Text("SB")
                .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .center)
                .position(x: (from.minX + (space.width * 2.5)) - offset, y:space.minY + 10)
        }
    }
}
