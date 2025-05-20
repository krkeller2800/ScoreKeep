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

                drawTots(space: space, atbat: atbat, atbats: atbats, abb: abb, inning: Int(inning), colbox: colbox, batbox: batbox, totbox: totbox)
                
                if abb == "hr" {
                    Path() {
                        myPath in
                        myPath.move(to: CGPoint(x: 0.5 * w + x, y: 0.9 * h + y))
                        myPath.addLine(to: CGPoint(x: 0.9 * w + x, y: 0.5 * h + y))
                        myPath.addLine(to: CGPoint(x: 0.5 * w + x, y: 0.1 * h + y))
                        myPath.addLine(to: CGPoint(x: 0.1 * w + x, y: 0.5 * h + y))
                    }
                    .fill(.black)
                    Text(abb)
                        .frame(width: 28, alignment: .center).lineLimit(1).minimumScaleFactor(0.01)
                        .font(.system(size: 22)).bold().foregroundColor(.white)
                        .position(x: 0.5 * w + x, y: 0.55 * h + y)
                } else if (atbat.outAt == "Safe" || atbat.outAt == "Not Out") &&  !com.outabs.contains(abb) {
                    Path() {
                        myPath in
                        myPath.move(to: CGPoint(x: 0.5 * w + x, y: 0.9 * h + y))
                        myPath.addLine(to: CGPoint(x: 0.9 * w + x, y: 0.5 * h + y))
                        if abb == "2b" || abb == "3b" {
                            myPath.addLine(to: CGPoint(x: 0.5 * w + x, y: 0.1 * h + y))
                        }
                        if abb == "3b" {
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
                if atbat.maxbase != "No Bases" {
                    drawRunner(space: CGRect(x: x, y: y, width: w, height: h), atbat: atbat, abb: abb)
                }
                if atbat.outAt != "Safe" && atbat.outAt != "Not Out" {
                    drawout(space: CGRect(x: x, y: y, width: w, height: h), atbat: atbat, abb: abb)
                }
                if com.outabs.contains(abb) || (atbat.outAt != "Safe" && atbat.outAt != "Not Out") {
                    
                }
                if outs == 1 && (com.outresults.contains(atbat.result) || (atbat.outAt != "Safe" && atbat.outAt != "Not Out")) {
                    Text("*")
                        .font(.system(size: 18)).bold().foregroundColor(.red)
                        .position(x: 0.1 * w + x, y: 0.2 * h + y)
                } else if outs == 2 && (com.outresults.contains(atbat.result) || (atbat.outAt != "Safe" && atbat.outAt != "Not Out")) {
                    Text("**")
                        .font(.system(size: 18)).bold().foregroundColor(.red)
                        .position(x: 0.15 * w + x, y: 0.2 * h + y)
                } else if outs == 3 && (com.outresults.contains(atbat.result) || (atbat.outAt != "Safe" && atbat.outAt != "Not Out")) {
                    Path() {
                        myPath in
                        myPath.move(to: CGPoint(x: x, y: h + y))
                        myPath.addLine(to: CGPoint(x: w + x, y: h + y))
                    }
                    .stroke(Color.red, lineWidth: 5)
                    Text("***")
                        .font(.system(size: 15)).bold().foregroundColor(.red)
                        .position(x: 0.2 * w + x, y: 0.2 * h + y)
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
            }
            .stroke(Color.cyan, lineWidth: 2)
            Text("x")
                .font(.system(size: 20)).foregroundColor(.white)
                .position(x: 0.5 * space.width + space.minX, y: 0.5 * space.height + space.minY)

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
    let com = Common()
    var body: some View {
        
        let newCol = atbats.map({ $0.col }).max()! + 1
        let bSize = UIScreen.screenWidth > 1300 ? 14 : 14
        let yoffset = UIScreen.screenWidth > 1200 &&  UIScreen.screenWidth < 1400 ? 1.0 : 1.0
        let y = (Double(atbat.batOrder) - yoffset) * space.height + space.minY
        let maxCol = CGFloat(newCol < bSize ? bSize : newCol)
        let box = batbox[Int(atbat.batOrder)]
        let box2 = totbox[0]
        let box3 = colbox[atbat.col]
        let newy = (CGFloat(atbats.filter({$0.col == 1}).count) * space.height) + space.minY
        let from = CGRect(x: (( maxCol  + 2) * space.width) + space.minX, y: space.minY,width:0, height:0)
        let to = CGRect(x: (( maxCol  + 2) * space.width) + space.minX, y: space.height + newy,width:0, height:0)
        let eachLine = CGRect(x: (( maxCol  + 2) * space.width) + space.minX, y: space.height + y, width:0, height:0)
        let x = CGFloat(atbat.col) * space.width + space.minX
        let placeBox = CGRect(x: x - (0 * space.width), y: 0.1 * space.height + newy, width:space.width, height:space.height)
        
        if inning < 99 {
            Text(com.innAbr[inning] + " Inn")
                .font(.system(size: 10)).bold().foregroundColor(.black)
                .position(x: 0.5 * space.width + x, y: space.minY - 7)
        }
        Text("Runs")
            .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .leading)
            .position(x: from.minX + (space.width * -0.5), y:space.minY - 7)
        Text("Hits")
            .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .leading)
            .position(x: from.minX + (space.width * 0.1), y:space.minY - 7)
        Text("Errors")
            .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .leading)
            .position(x: from.minX + (space.width * 0.7), y:space.minY - 7)
        Text("Ks")
            .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .leading)
            .position(x: from.minX + (space.width * 1.3), y:space.minY - 7)
        Text("BB")
            .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .leading)
            .position(x: from.minX + (space.width * 1.9), y:space.minY - 7)
        Text("HR")
            .font(.system(size: 10)).bold().foregroundColor(.black).frame(alignment: .leading)
            .position(x: from.minX + (space.width * 2.5), y:space.minY - 7)
        Text("R  H  E")
            .foregroundColor(.black).frame(alignment: .leading)
            .position(x: space.minX + (0.5 * space.width), y: 0.35 * space.height + newy)
        Text("\(box.runs)")
            .position(x: from.minX - (space.width * 0.5), y:0.5 * space.height + y)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box.hits)")
            .position(x: from.minX + (space.width * 0.1), y:0.5 * space.height + y)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box.errors)")
            .position(x:from.minX + (space.width * 0.7), y:0.5 * space.height + y)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box.strikeouts)")
            .position(x:from.minX + (space.width * 1.3), y:0.5 * space.height + y)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box.walks)")
            .position(x:from.minX + (space.width * 1.9), y:0.5 * space.height + y)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box.HR)")
            .position(x:from.minX + (space.width * 2.5), y:0.5 * space.height + y)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box2.runs)")
            .position(x: from.minX - (space.width * 0.5), y:0.5 * space.height + newy)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box2.hits)")
            .position(x: from.minX + (space.width * 0.1), y:0.5 * space.height + newy)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box2.errors)")
            .position(x:from.minX + (space.width * 0.7), y:0.5 * space.height + newy)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box2.strikeouts)")
            .position(x:from.minX + (space.width * 1.3), y:0.5 * space.height + newy)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box2.walks)")
            .position(x:from.minX + (space.width * 1.9), y:0.5 * space.height + newy)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box2.HR)")
            .position(x:from.minX + (space.width * 2.5), y:0.5 * space.height + newy)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box3.runs)")
            .position(x: placeBox.minX + (space.width * 0.15), y:0.25 * space.height + placeBox.minY)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box3.hits)")
            .position(x: placeBox.minX + (space.width * 0.5), y:0.25 * space.height + placeBox.minY)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(box3.errors)")
            .position(x: placeBox.minX + (space.width * 0.8), y:0.25 * space.height + placeBox.minY)
            .font(.headline).foregroundColor(.black).background(.clear)
        if newCol < 13 {
            Text("Total >")
                .font(.headline).foregroundColor(.black).frame(width: 90, alignment: .leading)
                .position(x: (maxCol + 1) * space.width + space.minX - (space.width * 0.1), y:0.5 * space.height + newy)
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
        drawBox(start:CGRect(x: space.minX, y: 0.1 * space.height + newy, width:space.width, height:space.height))
            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
 
        if atbat.col == 1 && atbat.batOrder == 1 {
            drawPitchers(space: space, atbats: atbats, abb: "", inning: 1)
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
            myPath.addLine(to: CGPoint(x: start.minX + (0.33 * start.width), y:start.minY + (0 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (0.33 * start.width), y:start.minY + (0.5 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (0.66 * start.width), y:start.minY + (0.5 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (0.66 * start.width), y:start.minY + (0 * start.height)))
        }
    }
}
struct drawBoxScore: View {
    var game:Game
    let com = Common()
    var body: some View {
        
        let placeBox = CGRect(x: 115, y: -37.5, width:150, height:100)
        let boxHome = doBoxScore(doTeam: "Home")
        let boxVisit = doBoxScore(doTeam: "Visit")
        let com = Common()
        let homeOuts = game.atbats.filter({$0.team.name == game.hteam!.name && (com.outresults.contains($0.result) || ($0.outAt != "Safe" && $0.outAt != "Not Out"))}).count
        let visitOuts = game.atbats.filter({$0.team.name == game.vteam!.name && (com.outresults.contains($0.result) || ($0.outAt != "Safe" && $0.outAt != "Not Out"))}).count
        let v3outs = visitOuts % 3 == 0
        let h3outs = homeOuts % 3 == 0
        let vinning:Int = visitOuts / 3
        let theInning = homeOuts < visitOuts && h3outs && v3outs ? "of \(com.innAbr[Int(vinning)])" :
                        homeOuts <= visitOuts && !h3outs ? "of \(com.innAbr[Int(vinning)])" : "of \(com.innAbr[Int(vinning + 1)])"
        let theHalf = homeOuts < visitOuts && v3outs ? "Bottom" : "Top"

        Text(game.vteam?.name ?? "")
            .font(.headline).foregroundColor(.black).background(.clear).frame(width:100,alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
            .position(x: 60, y: -25)
        Text(game.hteam?.name ?? "")
            .font(.headline).foregroundColor(.black).background(.clear).frame(width:100,alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
            .position(x: 60, y: -0)
        Text("\(boxVisit.runs)")
            .position(x: 60 + 111, y: -25)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(boxVisit.hits)")
            .position(x: 60 + 148, y: -25)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(boxVisit.errors)")
            .position(x: 60 + 185, y: -25)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(boxHome.runs)")
            .position(x: 60 + 111, y: -0)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(boxHome.hits)")
            .position(x: 60 + 148, y: -0)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("\(boxHome.errors)")
            .position(x: 60 + 185, y: -0)
            .font(.headline).foregroundColor(.black).background(.clear)
        Text("Inning  Runs   Hits   Errors")
            .font(.caption).italic().foregroundColor(.black).frame(alignment: .leading)
            .position(x: placeBox.minX + 75, y:placeBox.minY - 10)
        Text(theHalf)
            .font(.caption).italic().foregroundColor(.black).frame(width: 35, alignment: .center).lineLimit(1).minimumScaleFactor(0.1)
            .position(x: placeBox.minX + 20, y:placeBox.minY + 15)
        Text(theInning)
            .font(.caption).italic().foregroundColor(.black).frame(width: 35, alignment: .center).lineLimit(1).minimumScaleFactor(0.1)
            .position(x: placeBox.minX + 20, y:placeBox.minY + 35)

        drawBox(start: placeBox)
            .stroke(Color.gray, lineWidth: 1)

        
    }
    func doBoxScore(doTeam:String)->BoxScore {
        let com = Common()
        if doTeam == "Home" {
            let runs = game.atbats.filter({$0.maxbase == "Home" && $0.team.name == game.hteam!.name}).count
            let hits = game.atbats.filter({com.hitresults.contains($0.result) && $0.team.name == game.hteam!.name}).count
            let errors = game.atbats.filter({$0.result == "Error" && $0.team.name == game.hteam!.name}).count
            
            return BoxScore(type:"",runs: runs, hits: hits, errors: errors, strikeouts:0, walks:0, HR:0)
        } else {
            let runs = game.atbats.filter({$0.maxbase == "Home" && $0.team.name == game.vteam!.name}).count
            let hits = game.atbats.filter({com.hitresults.contains($0.result) && $0.team.name == game.vteam!.name}).count
            let errors = game.atbats.filter({$0.result == "Error" && $0.team.name == game.vteam!.name}).count
            
            return BoxScore(type:"",runs: runs, hits: hits, errors: errors, strikeouts:0, walks:0, HR:0)
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
            myPath.addLine(to: CGPoint(x: start.minX + (0.25 * start.width), y:start.minY + (0 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (0.25 * start.width), y:start.minY + (0.5 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (0.5 * start.width), y:start.minY + (0.5 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (0.5 * start.width), y:start.minY + (0 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (0.75 * start.width), y:start.minY + (0 * start.height)))
            myPath.addLine(to: CGPoint(x: start.minX + (0.75 * start.width), y:start.minY + (0.5 * start.height)))
        }
    }
}
struct drawPitchers: View {
    var space: CGRect
    var atbats:[Atbat]
    var abb:String
    var inning:Int
    @State var showPitchers:Bool = false
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    let com = Common()
    var body: some View {
        
        let newy = (CGFloat(atbats.filter({$0.col == 1}).count) * space.height) + space.minY
        
        Button("Edit/Add a pitcher") {
            showPitchers.toggle()
        }
        .foregroundColor(.white).bold().padding().frame(maxHeight: 35)
        .background(Color.blue).cornerRadius(25)
        .position(x: space.minX + (0.5 * space.width), y:1.2 * space.height + newy)
        .sheet(isPresented: $showPitchers) {
            PitchersStaffView(showDetails: $showPitchers, passedGame: atbats[0].game, passedTeam: atbats[0].team, theTeam: atbats[0].team.name)
        }
        
        Text("\(atbats[0].team.name) Pitching Stats for This Game")
            .foregroundColor(.black).bold().frame(maxWidth: .infinity, alignment: .center).font(.largeTitle).italic()
            .position(x: space.minX + (8.5 * space.width), y:1.2 * space.height + newy)
        
        
        Text("Num").foregroundColor(.red).bold().frame(maxWidth: 65,maxHeight: 25)
            .position(x: space.minX + (2.0 * space.width), y:1.85 * space.height + newy)
        Text("Name").foregroundColor(.red).bold().frame(maxWidth: 200,maxHeight: 25)
            .position(x: space.minX + (3.5 * space.width), y:1.85 * space.height + newy)
        Text("Inn Bats   Inn Bats").foregroundColor(.red).bold().frame(maxWidth: 400,maxHeight: 25)
            .position(x: space.minX + (5.75 * space.width), y:1.85 * space.height + newy)
        Text("Run").foregroundColor(.red).bold().frame(maxWidth: 200,maxHeight: 25)
            .position(x: space.minX + (8 * space.width), y:1.85 * space.height + newy)
        Text("ERA").foregroundColor(.red).bold().frame(maxWidth: 200,maxHeight: 25)
            .position(x: space.minX + (9 * space.width), y:1.85 * space.height + newy)
        Text("Hit").foregroundColor(.red).bold().frame(maxWidth: 200,maxHeight: 25)
            .position(x: space.minX + (10 * space.width), y:1.85 * space.height + newy)
        Text("Ks").foregroundColor(.red).bold().frame(maxWidth: 200,maxHeight: 25)
            .position(x: space.minX + (11 * space.width), y:1.85 * space.height + newy)
        Text("BB").foregroundColor(.red).bold().frame(maxWidth: 200,maxHeight: 25)
            .position(x: space.minX + (12 * space.width), y:1.85 * space.height + newy)
        Text("HR").foregroundColor(.red).bold().frame(maxWidth: 200,maxHeight: 25)
            .position(x: space.minX + (13 * space.width), y:1.85 * space.height + newy)
        Text("1B").foregroundColor(.red).bold().frame(maxWidth: 200,maxHeight: 25)
            .position(x: space.minX + (14 * space.width), y:1.85 * space.height + newy)
        Text("2B").foregroundColor(.red).bold().frame(maxWidth: 200,maxHeight: 25)
            .position(x: space.minX + (15 * space.width), y:1.85 * space.height + newy)
        Text("3B").foregroundColor(.red).bold().frame(maxWidth: 200,maxHeight: 25)
            .position(x: space.minX + (16 * space.width), y:1.85 * space.height + newy)
        
        let oTHit = atbats[0].game.atbats.filter({$0.team != atbats[0].team})
        let oTHitting = oTHit.sorted{( ($0.col, $0.seq) < ($1.col, $1.seq) )}
        let pitchs = atbats[0].game.pitchers.filter({$0.team == atbats[0].team})
        let pitchers = fixInnings(pitchers: pitchs)
        ForEach(Array(pitchers.enumerated()), id: \.1) { index, pitcher in
            let stats = doPitchers(oAtbats: oTHitting, pitcher: pitcher)
            let off:CGFloat = ((CGFloat(index) + 4.6)/2.0)
            let sinn = String("\(pitcher.startinn)      \(pitcher.sBatIn)")
            let einn = pitcher.endinn == 0 ? String("\(stats.innings + pitcher.startinn)      \(pitcher.eBatIn)") : String("\(pitcher.endinn)     \(pitcher.eBatIn)")
            Text("\(pitcher.player.number)")
                .foregroundColor(.black).bold().frame(maxWidth: 50)
                .position(x: space.minX + (2.0 * space.width), y:(off) * space.height + newy)
            Text("\(pitcher.player.name)")
                .foregroundColor(.black).bold().frame(maxWidth: 100)
                .position(x: space.minX + (3.5 * space.width), y:(off) * space.height + newy)
            
            Text("\(sinn)   to   \(einn)")
                .foregroundColor(.black).bold().frame(maxWidth: 400)
                .position(x: space.minX + (5.75 * space.width), y:(off) * space.height + newy)
            Text(Double(stats.runs), format: .number.rounded(increment: 1.0)) // 12 (whole number)
                .foregroundColor(.black).bold().frame(maxWidth: 100)
                .position(x: space.minX + (8 * space.width), y:(off) * space.height + newy)
            Text(Double(stats.ERA), format: .number.rounded(increment: 0.01))
                .foregroundColor(.black).bold().frame(maxWidth: 100)
                .position(x: space.minX + (9 * space.width), y:(off) * space.height + newy)
            Text(Double(stats.hits), format: .number.rounded(increment: 1.0)) // 12 (whole number)
                .foregroundColor(.black).bold().frame(maxWidth: 100)
                .position(x: space.minX + (10 * space.width), y:(off) * space.height + newy)
            Text(Double(stats.Ks), format: .number.rounded(increment: 1.0)) // 12 (whole number)
                .foregroundColor(.black).bold().frame(maxWidth: 100)
                .position(x: space.minX + (11 * space.width), y:(off) * space.height + newy)
            Text(Double(stats.BB), format: .number.rounded(increment: 1.0)) // 12 (whole number)
                .foregroundColor(.black).bold().frame(maxWidth: 100)
                .position(x: space.minX + (12 * space.width), y:(off) * space.height + newy)
            Text(Double(stats.HR), format: .number.rounded(increment: 1.0)) // 12 (whole number)
                .foregroundColor(.black).bold().frame(maxWidth: 100)
                .position(x: space.minX + (13 * space.width), y:(off) * space.height + newy)
            Text(Double(stats.singles), format: .number.rounded(increment: 1.0)) // 12 (whole number)
                .foregroundColor(.black).bold().frame(maxWidth: 100)
                .position(x: space.minX + (14 * space.width), y:(off) * space.height + newy)
            Text(Double(stats.doubles), format: .number.rounded(increment: 1.0)) // 12 (whole number)
                .foregroundColor(.black).bold().frame(maxWidth: 100)
                .position(x: space.minX + (15 * space.width), y:(off) * space.height + newy)
            Text(Double(stats.triples), format: .number.rounded(increment: 1.0)) // 12 (whole number)
                .foregroundColor(.black).bold().frame(maxWidth: 100)
                .position(x: space.minX + (16 * space.width), y:(off) * space.height + newy)
        }
    }
    func doPitchers(oAtbats:[Atbat],pitcher: Pitcher)->PitchStats {

        let endinn = pitcher.endinn > 0 ? pitcher.endinn : Int(oAtbats[(oAtbats.count - 1)].inning) + 1
        let innings = CGFloat(oAtbats.filter({com.outresults.contains($0.result) && (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startinn) + pitcher.sBatIn) &&
                                                                                    (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBatIn ||
                                                                                    (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count) / 3
        let runs = oAtbats.filter({$0.maxbase == "Home" &&  (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startinn) + pitcher.sBatIn) &&
                                                            (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBatIn ||
                                                            (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
        let hits = oAtbats.filter({com.hitresults.contains($0.result) &&    (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startinn) + pitcher.sBatIn) &&
                                                                            (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBatIn ||
                                                                            (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
        let HR = oAtbats.filter({$0.result == "Home Run" && (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startinn) + pitcher.sBatIn) &&
                                                            (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBatIn ||
                                                            (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
        let BB = oAtbats.filter({$0.result == "Walk" && (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startinn) + pitcher.sBatIn) &&
                                                        (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBatIn ||
                                                        (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
        let Ks = oAtbats.filter({($0.result == "Strikeout" || $0.result == "Strikout Looking") &&   (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startinn) + pitcher.sBatIn) &&
                                                                                                    (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBatIn ||
                                                                                                    (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
        let singles = oAtbats.filter({$0.result == "Single" &&  (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startinn) + pitcher.sBatIn) &&
                                                                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBatIn ||
                                                                (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
        let doubles = oAtbats.filter({$0.result == "Double" &&  (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startinn) + pitcher.sBatIn) &&
                                                                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBatIn ||
                                                                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
        let triples = oAtbats.filter({$0.result == "Triple" &&  (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startinn) + pitcher.sBatIn) &&
                                                                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBatIn ||
                                                                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count

       let ERA = innings == 0 ? 0 : CGFloat(runs) / innings * 9

       return PitchStats(runs: runs, hits: hits, HR: HR, Ks: Ks, BB: BB, singles: singles, doubles: doubles, triples: triples, innings: Int(innings), ERA: ERA)
    }
    func fixInnings(pitchers:[Pitcher])->[Pitcher] {
        let pitchs = pitchers.sorted {$0.startinn < $1.startinn}
        if pitchs.count > 1 {
            if pitchs [0].startinn != 0 {
                let prevPitch = pitchs[0]
                for pitcher in pitchs {
                    if pitcher != prevPitch {
                        prevPitch.endinn = pitcher.startinn
                    }
                }
            }
        }
        return pitchs
    }
}

