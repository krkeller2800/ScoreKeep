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

    var batSelection:Int = 0
    var com:Common = Common()
    
    var body: some View {
        Section {
            GeometryReader { geometry in
                VStack(spacing:0) {
                    HStack(spacing:0) {
                        Button("Done", action: {
                            showingScoring.toggle()
                            if atbat.result == "Result" {
                                if atbat.col != 1 {
                                    if let index = atbat.game.atbats.firstIndex(of: atbat) {
                                        atbat.game.atbats.remove(at: index)
                                    }
                                    modelContext.delete(atbat)
                                }
                            }
                        })
                        .frame(maxWidth: 120,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
                        .border(.gray).cornerRadius(10).accentColor(.black).padding(.all, 15)
                        Spacer()
                        Text("\(atbat.player.team!.name) Batting").font(.title2)
                        Spacer()
                        Button("Delete At Bat", action: {
                            showingScoring.toggle()
                            if atbat.col != 1 {
                                if let index = atbat.game.atbats.firstIndex(of: atbat) {
                                    atbat.game.atbats.remove(at: index)
                                }
                                modelContext.delete(atbat)
                            } else {
                                atbat.result = "Result"
                                atbat.maxbase = "No Bases"
                                atbat.outAt = "Not Out"
                            }
                            
                        })
                        .frame(maxWidth: 120,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
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
                            let rbis = ["Steals","1 Stolen","2 Stolen","3 Stolen","4 Stolen"]
                            ForEach(Array(rbis.enumerated()), id: \.1) { index, rbi in
                                Text(rbi).tag(index)
                            }
                        }
                        .frame(maxWidth: 120,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
                        .border(.gray).cornerRadius(10).accentColor(.black).padding(.trailing, 15)
                    }
                    HStack(spacing: 0) {
                        Spacer()
                        Text("At Bat").frame(maxWidth: 120, maxHeight: 50 ,alignment:.bottomLeading).padding(.leading, 75)
                        Spacer()
                        Text("Max Base").frame(maxWidth: 120, maxHeight: 50 ,alignment:.bottomLeading).padding(.leading, 25)
                        Spacer()
                        Text("Out At").frame(maxWidth: 120, maxHeight: 50 ,alignment:.bottomLeading).padding(.leading, 25)
                        Spacer()
                    }
                    HStack(spacing: 0) {
                        Spacer()
                        Picker("Batting", selection: $atbat.result) {
                            Text("Result").tag("Result")
                            let bats = com.battings
                            ForEach (bats, id: \.self) { batting in
                                (batting != "") ? Text(batting).tag(batting): nil
                            }
                        }
                         .frame(maxWidth: 120,maxHeight: 60, alignment:.center).background(.blue.opacity(0.2))
                         .border(.gray).cornerRadius(10).accentColor(.black)
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
                            if atbat.outAt == "Safe" || atbat.outAt == "Not Out" {
                                Text(atbat.outAt).tag(atbat.outAt)
                            }
                            let outs = ["","First","Second","Third","Home"]
                            ForEach (outs, id: \.self) { out in
                                (out != "") ? Text(out).tag(out): nil
                            }
                        }
                         .frame(maxWidth: 120,maxHeight: 60, alignment:.center).background(.blue.opacity(0.2))
                         .border(.gray).cornerRadius(10).accentColor(.black)
                        Spacer()
                    }
                    .padding(.leading, 15)
                    Spacer()
                }
                
                if let idx = com.battings.firstIndex(where: { $0 == atbat.result }) {
                    let abb = com.batAbbrevs[idx]
                    drawIt(size: geometry.size, atbat: atbat, abb: abb)
                }
                Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 30, height: 30).rotationEffect(.degrees(45))
                    .position(x:0.87 * geometry.size.width, y:0.6 * geometry.size.height)
                Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 30, height: 30).rotationEffect(.degrees(45))
                    .position(x:0.5 * geometry.size.width, y:0.35 * geometry.size.height)
                Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 30, height: 30).rotationEffect(.degrees(47))
                    .position(x:0.148 * geometry.size.width, y:0.6 * geometry.size.height)
                Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 30, height: 22)
                    .position(x:0.5 * geometry.size.width, y:0.9 * geometry.size.height)
                Path() {
                    myPath in
                    myPath.move(to: CGPoint(x: 0.475 * geometry.size.width, y: 0.92 * geometry.size.height))
                    myPath.addLine(to: CGPoint(x: 0.50 * geometry.size.width, y: 0.94 * geometry.size.height))
                    myPath.addLine(to: CGPoint(x: 0.525 * geometry.size.width, y: 0.92 * geometry.size.height))
                    myPath.addLine(to: CGPoint(x: 0.48 * geometry.size.width, y: 0.92 * geometry.size.height))
                }
                .fill(Color.gray.opacity(0.5))
            }
        }
    }
    init(atbat: Binding<Atbat>, showingScoring: Binding<Bool>) {
        _atbat = atbat
        _showingScoring = showingScoring
    }
 }

