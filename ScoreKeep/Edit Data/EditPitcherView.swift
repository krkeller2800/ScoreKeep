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
    @Binding var team: Team
    @Binding var editPitcher: Bool
    @Binding var addPitcher: Bool
    @Binding var navigationPath: NavigationPath
    @Binding var game: Game
    @State   var begInning:Int = 0
    @State   var begOuts:Int = 0
    @State   var endInning:Int = 0
    @State   var endOuts:Int = 0
    enum FocusField: Hashable {case field}
    
    @FocusState private var focusedField: FocusField?
    
    @Query(sort: [
        SortDescriptor(\Team.name)
    ]) var teams: [Team]
    
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    var body: some View {
        ZStack {
            Text("").frame(height: 10)
            HStack {
                Button("< Back") {
                    editPitcher = false
                    addPitcher = false
                    modelContext.insert(pitcher)
                }
                .frame(width: 75, height: 30, alignment:.center).background(.yellow.opacity(0.4)).border(.gray).cornerRadius(10)
                .padding(.leading, 20)
                Spacer()
                Button("Remove") {
                    if let index = game.pitchers.firstIndex(of: pitcher) {
                        modelContext.delete(game.pitchers[index])
                        game.pitchers.remove(at: index)
                    }
                    editPitcher = false
                    addPitcher = false
                }
                .frame(width: 90, height: 30, alignment:.center).background(.yellow.opacity(0.4)).border(.gray).cornerRadius(10)
                .padding(.trailing, 20)
            }
        }
        .frame(maxWidth:.infinity, maxHeight:40,alignment:.bottomLeading)
        Section {
            VStack(spacing: 0) {
                HStack (alignment: .bottom,spacing:0) {
                    Text("Name").frame(width: 125).border(.gray)
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Team").frame(maxWidth:.infinity).border(.gray)
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Beg Inn").frame(maxWidth:.infinity).border(.gray)
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Batters").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("End Inn").frame(maxWidth:.infinity).border(.gray)
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Batters").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                }
                .padding(.horizontal,10)
                HStack {
                    Spacer()
                    Text(pitcher.player.name).frame(width: 125, alignment: .leading).lineLimit(1).minimumScaleFactor(0.5)
                        .frame(maxWidth:.infinity).overlay(Divider().background(.black), alignment: .trailing)
                    Spacer()
                    Text(pitcher.player.team?.name ?? "").frame(maxWidth:.infinity, alignment: .leading)
                        .frame(maxWidth:.infinity).overlay(Divider().background(.black), alignment: .trailing)
                    Spacer()
                    Picker("beg inn", selection: $pitcher.startInn) {
                        let innings = ["No","1st","2nd","3rd","4th",
                                       "5th","6th","7th","8th","9th",
                                       "10th","11th","12th","13th","14th",
                                       "15","15th","17th","18th","19th"]
                        ForEach(Array(innings.enumerated()), id: \.1) { index, inning in
                            Text(inning).tag(index)
                        }
                    }
                    .frame(maxWidth:.infinity).overlay(Divider().background(.black), alignment: .trailing)
                    Spacer()
                    Picker("Batters", selection: $pitcher.sOuts) {
                        let batters = ["No","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                        ForEach(Array(batters.enumerated()), id: \.1) { index, batter in
                            Text(batter).tag(index)
                        }
                    }
                    .frame(maxWidth:.infinity).overlay(Divider().background(.black), alignment: .trailing)
                    Spacer()
                    Picker("End inn", selection: $pitcher.endInn) {
                        let innings = ["No","1st","2nd","3rd","4th",
                                       "5th","6th","7th","8th","9th",
                                       "10th","11th","12th","13th","14th",
                                       "15","15th","17th","18th","19th"]
                        ForEach(Array(innings.enumerated()), id: \.1) { index, inning in
                            Text(inning).tag(index)
                        }
                    }
                    .frame(maxWidth:.infinity).overlay(Divider().background(.black), alignment: .trailing)
                    Spacer()
                    Picker("Batters", selection: $pitcher.eOuts) {
                        let batters = ["No","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                        ForEach(Array(batters.enumerated()), id: \.1) { index, batter in
                            Text(batter).tag(index)
                        }
                    }
                    .foregroundColor(.black).bold()
                    .overlay(Divider().background(.black), alignment: .trailing)
                  Spacer()
                }
                Spacer()
            }
        }
        header: {
            Text("Update Pitcher Start and End Innings").frame(maxWidth:.infinity, alignment:.center).font(.title3).foregroundColor(.black).bold()
            }
        .background{Color.white}

    }
}
