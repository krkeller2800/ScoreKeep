//
//  ScoreGameView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 4/6/25.
//

import SwiftUI
import SwiftData

struct ScoreGameView: View {
    @Environment(\.modelContext) var modelContext
    @State private var path = NavigationPath()
    @Binding private var atbat:Atbat
    @Binding private var showingScoring:Bool
    @State private var thisInning:Int = 0
    @State private var earnedRun: Bool = true
    @State private var recPlay: Bool = false
    @State private var delAtbat: Bool = false
    @State private var playRec: String = ""
    @State private var onBase: String = "Result"
    @State private var batOut: String = "Result"

    let com:Common = Common()
    
    var body: some View {
        Section {
            GeometryReader { geometry in
                VStack(spacing:0) {
                    HStack(spacing:0) {
                        Button("Done", action: {
                            showingScoring.toggle()
                            if atbat.result == "Result" {
                                if atbat.col != 1 {
                                    atbat.game.atbats.removeAll() {$0 == atbat}
                                    delAtbat = true
                                }
                            }
                        })
                        .frame(maxWidth: 120,maxHeight: 30, alignment:.center).background(.green.opacity(0.5))
                        .border(.gray).cornerRadius(10).accentColor(.black).padding(.all, 15)
                        Spacer()
                        Text("\(atbat.player.team?.name ?? "") Batting").font(.title2)
                        Spacer()
                        Button("Delete At Bat", action: {
                            showingScoring.toggle()
                            if atbat.col != 1 {
                                atbat.game.atbats.removeAll() {$0 == atbat}
                                delAtbat = true
                            } else {
                                atbat.result = "Result"
                                atbat.maxbase = "No Bases"
                                atbat.outAt = "Safe"
                                checkForCol1Dup ()
                            }
                        })
                        .frame(maxWidth: 120,maxHeight: 30, alignment:.center).background(.red.opacity(0.5))
                        .border(.gray).cornerRadius(10).accentColor(.black).padding(.all, 15)

                    }
                    HStack {
                        Picker("RBI", selection: $atbat.rbis) {
                            let rbis = ["RBIs","1 RBI","2 RBIs","3 RBIs","4 RBIs"]
                            ForEach(Array(rbis.enumerated()), id: \.1) { index, rbi in
                                Text(rbi).tag(index)
                            }
                        }
                        .frame(maxWidth: 120,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
                        .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, 15)
                        Spacer()
                        Text("\(atbat.player.number) \(atbat.player.name)").font(.title3)
                        Spacer()
                        Picker("Steal", selection: $atbat.stolenBases) {
                            let rbis = ["Steals","1 Stolen","2 Stolen","3 Stolen"]
                            ForEach(Array(rbis.enumerated()), id: \.1) { index, rbi in
                                Text(rbi).tag(index)
                            }
                        }
                        .frame(maxWidth: 120,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
                        .border(.gray).cornerRadius(10).accentColor(.black).padding(.trailing, 15)
                    }
                    HStack(spacing: 0) {
                        Spacer()
                        Text("On Base").frame(maxWidth: 120, maxHeight: 50 ,alignment:.bottomLeading).padding(.leading, 30)
                        Spacer()
                        Text("Batting Out").frame(maxWidth: 120, maxHeight: 50 ,alignment:.bottomLeading).padding(.leading, 0)
                        Spacer()
                        Text("Max Base").frame(maxWidth: 120, maxHeight: 50 ,alignment:.bottomLeading).padding(.leading, 0)
                        Spacer()
                        Text("Base path Out").frame(maxWidth: 120, maxHeight: 50 ,alignment:.bottomLeading).padding(.leading, 0)
                        Spacer()
                    }
                    HStack(spacing: 0) {
                        Spacer()
                        Picker("Batting", selection: $onBase) {
                            Text("Result").tag("Result")
                            Divider()
                            let bats = com.onresults
                            ForEach (bats, id: \.self) { batting in
                                (batting != "") ? Text(batting).tag(batting): nil
                                if batting == "Dropped 3rd Stike" || batting == "Fielder's Choice" || batting == "Home Run" {
                                    Divider()
                                }
                            }
                        }
                         .frame(maxWidth: 120,maxHeight: 60, alignment:.center).background(.blue.opacity(0.2))
                         .border(.gray).cornerRadius(10).accentColor(.black)
                         .onChange(of: onBase) {
                             if onBase != "Result" {
                                 atbat.result = onBase
                                 batOut = "Result"
                             }
                         }
                        Spacer()
                        Picker("Batting", selection: $batOut) {
                            Text("Result").tag("Result")
                            Divider()
                            let bats = com.outresults
                            ForEach (bats, id: \.self) { batting in
                                (batting != "") ? Text(batting).tag(batting): nil
                                if batting == "Strikeout Looking" {
                                    Divider()
                                }
                            }
                        }
                         .frame(maxWidth: 120,maxHeight: 60, alignment:.center).background(.blue.opacity(0.2))
                         .border(.gray).cornerRadius(10).accentColor(.black)
                         .onChange(of: batOut) {
                             if batOut != "Result" {
                                 atbat.result = batOut
                                 onBase = "Result"
                             }
                         }
                         Spacer()
                        Picker("Running", selection: $atbat.maxbase) {
                            Text("No Bases").tag("No Bases")
                            let bases = ["","First","Second","Third","Home"]
                            ForEach (bases, id: \.self) { base in
                                (base != "") ? Text(base).tag(base): nil
                            }
                        }
                         .frame(maxWidth: 120,maxHeight: 60, alignment:.center).background(.blue.opacity(0.2))
                         .border(.gray).cornerRadius(10).accentColor(.black)
                        Spacer()
                        Picker("Out", selection: $atbat.outAt) {
                            Text("Safe").tag("Safe")
                            let outs = ["","First","Second","Third","Home"]
                            ForEach (outs, id: \.self) { out in
                                (out != "") ? Text(out).tag(out): nil
                            }
                        }
                         .frame(maxWidth: 120,maxHeight: 60, alignment:.center).background(.blue.opacity(0.2))
                         .border(.gray).cornerRadius(10).accentColor(.black)
                        Spacer()
                    }
                    .padding(.leading, 0)
                    .onChange(of: atbat.result) {
                        if atbat.result == "Result" {
                            if atbat.col != 1 {
                                atbat.game.atbats.removeAll() {$0 == atbat}
                                delAtbat = true
                           }
                        }
                        if atbat.result == "Dropped 3rd Strike" || atbat.result == "Error" {
                            earnedRun = false
                            atbat.earnedRun = false
                        }
                        if !com.recOuts.contains(atbat.result) || atbat.outAt != "Safe"  {
                            atbat.playRec = ""
                            recPlay = false
                            showingScoring.toggle()
                        } else {
                            recPlay = true
                        }
                        if atbat.result != "Result" {
                            setEndOfInning()
                        }
                    }
                    .onChange(of: atbat.outAt) {
                        if atbat.outAt != "Safe" {
                            recPlay = true
                        } else {
                            atbat.playRec = ""
                            recPlay = false
                            showingScoring.toggle()
                        }
                        setEndOfInning()
                    }
                    .onAppear {
                        if atbat.playRec != "" || com.recOuts.contains(atbat.result) || atbat.outAt != "Safe" {
                            recPlay = true
                        }
                        if com.onresults.contains(atbat.result) {
                            onBase = atbat.result
                            batOut = "Result"
                        } else if com.outresults.contains(atbat.result) {
                            batOut = atbat.result
                            onBase = "Result"
                        } else {
                            onBase = "Result"
                            batOut = "Result"
                        }
                    }
                    .onDisappear {
                        setEndOfInning()
                        if delAtbat {
                            modelContext.delete(atbat)
                        }
                    }
                    Spacer()
                    HStack (spacing: 0){
                        if com.onresults.contains(atbat.result) {
                            Text("\nIf batter scores:").padding(.leading, 10).font(.title3)
                        }
                        Spacer()
                        if recPlay {
                            Text("Select player(s)\nto record the out").padding([.bottom,.trailing],10)
                        }
                    }
                    HStack {
                        if com.onresults.contains(atbat.result) {
                            Button(earnedRun ? "Run Earned" : "Run Unearned", action: {
                                earnedRun.toggle()
                                atbat.earnedRun = earnedRun
                            })
                            .frame(maxWidth: 130,maxHeight: 30, alignment:.center).background(earnedRun ? .green.opacity(0.5) : .red.opacity(0.5))
                            .border(.gray).cornerRadius(10).accentColor(.black).padding([.leading, .trailing, .bottom], 15)
                        }
                        Spacer()
                        if recPlay {
                            Spacer()
                            Text(atbat.playRec).padding(.trailing,15)
                            Button("Clear", action: {
                                 atbat.playRec = ""
                             })
                             .frame(maxWidth: 50,maxHeight: 30, alignment:.center).background(.red.opacity(0.5))
                             .border(.gray).cornerRadius(10).accentColor(.black).padding([.bottom,.trailing], 15)
                        }
                    }
   
                }
                .background(RoundedRectangle(cornerRadius: 15).fill(Color.yellow.opacity(0.1)).stroke(.black, lineWidth: 8))
                if recPlay {
                    fielderButtons(size: geometry.size, atbat: atbat)
                }
                if let idx = com.battings.firstIndex(where: { $0 == atbat.result }) {
                    let abb = com.batAbbrevs[idx]
                    drawIt(size: geometry.size, atbat: atbat, abb: abb)
                }
                if UIDevice.type == "iPhone" {
                    Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 15, height: 15).rotationEffect(.degrees(45))
                        .position(x:0.57 * geometry.size.width, y:0.81 * geometry.size.height)
                    Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 15, height: 15).rotationEffect(.degrees(45))
                        .position(x:0.5 * geometry.size.width, y:0.7 * geometry.size.height)
                    Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 15, height: 15).rotationEffect(.degrees(47))
                        .position(x:0.43 * geometry.size.width, y:0.81 * geometry.size.height)
                    if com.onresults.contains(atbat.result) || atbat.result == "Result" {
                        Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 15, height: 11)
                            .position(x:0.5 * geometry.size.width, y:0.92 * geometry.size.height)
                        Path() {
                            myPath in
                            myPath.move(to: CGPoint(x: 0.487 * geometry.size.width, y: 0.93 * geometry.size.height))
                            myPath.addLine(to: CGPoint(x: 0.50 * geometry.size.width, y: 0.96 * geometry.size.height))
                            myPath.addLine(to: CGPoint(x: 0.512 * geometry.size.width, y: 0.93 * geometry.size.height))
                            myPath.addLine(to: CGPoint(x: 0.49 * geometry.size.width, y: 0.93 * geometry.size.height))
                        }
                        .fill(Color.gray.opacity(0.5))
                    }
                } else {
                    Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 30, height: 30).rotationEffect(.degrees(45))
                         .position(x:0.75 * geometry.size.width, y:0.7 * geometry.size.height)
                     Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 30, height: 30).rotationEffect(.degrees(45))
                         .position(x:0.5 * geometry.size.width, y:0.5 * geometry.size.height)
                     Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 30, height: 30).rotationEffect(.degrees(47))
                         .position(x:0.25 * geometry.size.width, y:0.7 * geometry.size.height)
                     Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 30, height: 22)
                         .position(x:0.5 * geometry.size.width, y:0.88 * geometry.size.height)
                     Path() {
                         myPath in
                         myPath.move(to: CGPoint(x: 0.475 * geometry.size.width, y: 0.9 * geometry.size.height))
                         myPath.addLine(to: CGPoint(x: 0.50 * geometry.size.width, y: 0.92 * geometry.size.height))
                         myPath.addLine(to: CGPoint(x: 0.525 * geometry.size.width, y: 0.90 * geometry.size.height))
                         myPath.addLine(to: CGPoint(x: 0.48 * geometry.size.width, y: 0.90 * geometry.size.height))
                     }
                     .fill(Color.gray.opacity(0.5))
                }
            }
        }
    }
    init(atbat: Binding<Atbat>, showingScoring: Binding<Bool>) {
        _atbat = atbat
        _showingScoring = showingScoring
    }
    func setEndOfInning () {
     
        var inning = 0
        var outs = 0
        let bats = atbat.game.atbats.filter { $0.team == atbat.team && $0.result != "Result" }.sorted {( ($0.col, $0.seq) < ($1.col, $1.seq) )}
        for atbat in bats {
            atbat.endOfInning = false
            inning += outs % 3 == 0 ? 1 : 0
            if (com.outresults.contains(atbat.result) || atbat.outAt != "Safe") && atbat.team == atbat.team {
                outs += 1
            }
//            atbat.inning = CGFloat(outs)/3.0
//            if CGFloat(inning) > atbat.inning {
//                atbat.inning += 0.1
//            }
        }
        let innings:Int = outs / 3
        let out = outs % 3

        if innings > 0 {
            for inning in 1...innings {
                if inning <= innings || out == 0 {
                    let gAtbats = atbat.game.atbats.filter { $0.team == atbat.team && $0.result != "Result" && $0.result != "Pitch Hitter" &&
                        ($0.inning >= CGFloat(inning-1) && $0.inning <= CGFloat(inning)) }.sorted {( ($0.col, $0.seq) < ($1.col, $1.seq) )}
                    gAtbats.last?.endOfInning = true
                }
            }
            atbat.sacFly = atbat.sacFly != 0 ? 0 : -1
        }
    }
    func checkForCol1Dup () {
        let dups = atbat.game.atbats.filter({ $0.team == atbat.team && $0.col == 1 && $0.player == atbat.player})
        if dups.count > 1 {
            for dup in dups {
                if dup.result != "Result" {
                    if let index = atbat.game.atbats.firstIndex(of: dup) {
                        atbat.game.atbats.remove(at: index)
                    }
                    modelContext.delete(dup)
                }
            }
        }
    }
 }

