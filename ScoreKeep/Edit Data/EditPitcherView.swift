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
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(ScoreKeepVisualStyle.secondaryText)
                    
                    Text("Start/End Batter define batters faced in the inning.")
                        .font(.subheadline)
                        .foregroundColor(ScoreKeepVisualStyle.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(ScoreKeepVisualStyle.elevatedSurface)
                )
                .padding(.horizontal, 16)
                
                List {
                    HStack () {
                        scorebookHeaderCell("Num")
                            .frame(width: 60,height: 55)
                        scorebookHeaderCell("Name")
                            .frame(width: 200,height: 55)
                        scorebookHeaderCell("Start\nInning", lineLimit: 2)
                            .frame(maxWidth:.infinity,maxHeight: 55)
                        scorebookHeaderCell("Start\nOuts", lineLimit: 2)
                            .frame(maxWidth:.infinity,maxHeight: 55)
                        scorebookHeaderCell("Start\nBatter", lineLimit: 2)
                            .frame(maxWidth:.infinity,maxHeight: 55)
                        scorebookHeaderCell("End\nInning", lineLimit: 2)
                            .frame(maxWidth:.infinity,maxHeight: 55)
                        scorebookHeaderCell("End\nOuts", lineLimit: 2)
                            .frame(maxWidth:.infinity,maxHeight: 55)
                        scorebookHeaderCell("End\nBatter", lineLimit: 2)
                            .frame(maxWidth:.infinity,maxHeight: 55)
                        Spacer(minLength: 5)
                    }
                    HStack (spacing:0) {
                        Text("\(pitcher.player.number)").frame(width:60, alignment: .center).foregroundColor(.black).bold().minimumScaleFactor(0.5).lineLimit(1).padding(.leading,5)
                            .overlay(Divider().background(.black), alignment: .trailing)
                        Text(pitcher.player.name).frame(width:200, alignment: .leading).foregroundColor(.black).bold().minimumScaleFactor(0.5).lineLimit(1).padding(.leading,10)
                            .overlay(Divider().background(.black), alignment: .trailing)
                        Picker("", selection: $pitcher.startInn) {
                            let innings = ["0","1st","2nd","3rd","4th",
                                           "5th","6th","7th","8th","9th",
                                           "10th","11th","12th","13th","14th",
                                           "15","15th","17th","18th","19th"]
                            ForEach(Array(innings.enumerated()), id: \.0) { index, inning in
                                Text(inning).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Picker("", selection: $pitcher.sOuts) {
                            let outs = ["0","1","2","3"]
                            ForEach(Array(outs.enumerated()), id: \.0) { index, out in
                                Text(out).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Picker("", selection: $pitcher.sBats) {
                            let bats = ["0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                            ForEach(Array(bats.enumerated()), id: \.0) { index, out in
                                Text(out).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Picker("", selection: $pitcher.endInn) {
                            let innings = ["0","1st","2nd","3rd","4th",
                                           "5th","6th","7th","8th","9th",
                                           "10th","11th","12th","13th","14th",
                                           "15","15th","17th","18th","19th"]
                            ForEach(Array(innings.enumerated()), id: \.0) { index, inning in
                                Text(inning).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Picker("", selection: $pitcher.eOuts) {
                            let outs = ["0","1","2","3"]
                            ForEach(Array(outs.enumerated()), id: \.0) { index, out in
                                Text(out).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Picker("", selection: $pitcher.eBats) {
                            let bats = ["0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                            ForEach(Array(bats.enumerated()), id: \.0) { index, out in
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
