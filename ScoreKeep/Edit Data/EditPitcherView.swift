//
//  EditPitcherView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 4/28/25.
//
import PhotosUI
import SwiftUI
import SwiftData

struct EditPitcherView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Bindable var pitcher:Pitcher
    @Bindable var game:Game
    @State   var delPitcher = false
    @State   var begInning:Int = 0
    @State   var begOuts:Int = 0
    @State   var endInning:Int = 0
    @State   var endOuts:Int = 0
    
    var body: some View {
        Section {
            VStack() {
                List {
                    HStack () {
                        Text("Num")
                            .frame(width: 60,height: 55).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                        Text("Name")
                            .frame(width: 200,height: 55).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                        Text("Start\nInning")
                            .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Start Outs")
                            .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Num of\nBatters")
                            .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("End\nInning")
                            .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("End Outs")
                            .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Num of\nBatters")
                            .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Spacer(minLength: 5)
                    }
                    HStack (spacing:0) {
                        Text("\(pitcher.player.number)").frame(width:60, alignment: .center).foregroundColor(.black).bold().minimumScaleFactor(0.5).lineLimit(1).padding(.leading,5)
                            .overlay(Divider().background(.black), alignment: .trailing)
                        Text(pitcher.player.name).frame(width:200, alignment: .leading).foregroundColor(.black).bold().minimumScaleFactor(0.5).lineLimit(1).padding(.leading,10)
                            .overlay(Divider().background(.black), alignment: .trailing)
                        Picker("Start Inning", selection: $pitcher.startInn) {
                            let innings = ["0","1st","2nd","3rd","4th",
                                           "5th","6th","7th","8th","9th",
                                           "10th","11th","12th","13th","14th",
                                           "15","15th","17th","18th","19th"]
                            ForEach(Array(innings.enumerated()), id: \.1) { index, inning in
                                Text(inning).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Picker("Starts Outs", selection: $pitcher.sOuts) {
                            let outs = ["0","1 Out","2 Out","3 Out"]
                            ForEach(Array(outs.enumerated()), id: \.1) { index, out in
                                Text(out).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Picker("Starts Bats", selection: $pitcher.sBats) {
                            let bats = ["0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                            ForEach(Array(bats.enumerated()), id: \.1) { index, out in
                                Text(out).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Picker("End Inning", selection: $pitcher.endInn) {
                            let innings = ["0","1st","2nd","3rd","4th",
                                           "5th","6th","7th","8th","9th",
                                           "10th","11th","12th","13th","14th",
                                           "15","15th","17th","18th","19th"]
                            ForEach(Array(innings.enumerated()), id: \.1) { index, inning in
                                Text(inning).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Picker("End Outs", selection: $pitcher.eOuts) {
                            let outs = ["0","1","2","3"]
                            ForEach(Array(outs.enumerated()), id: \.1) { index, out in
                                Text(out).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Picker("End Bats", selection: $pitcher.eBats) {
                            let bats = ["0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                            ForEach(Array(bats.enumerated()), id: \.1) { index, out in
                                Text(out).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                    }
                    .onDisappear() {
                        if delPitcher {
                            modelContext.delete(pitcher)
                            do {
                                try modelContext.save()
                            }
                            catch {
                                print("Error deleting pitcher: \(error)")
                            }
                        }
                    }
                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Edit \(pitcher.player.name) Innings Pitched")
                            .font(.title2)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Remove \(pitcher.player.name)") {
                            game.pitchers.removeAll() { $0 == pitcher }
                            delPitcher = true
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
