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
    @Bindable var pitcher: Pitcher
    @Bindable var team: Team
    @Binding var editPitcher: Bool
    @Binding var addPitcher: Bool
    @Binding var navigationPath: NavigationPath
    @State   var begInning:Int = 0
    @State   var begOuts:Int = 0
    @State   var endInning:Int = 0
    @State   var endOuts:Int = 0
    enum FocusField: Hashable {case field}
    
    @FocusState private var focusedField: FocusField?
    
    @Query(sort: [
        SortDescriptor(\Team.name)
    ]) var teams: [Team]
    
//    var formatter: NumberFormatter {
//        let formatter = NumberFormatter ()
//        formatter.minimumIntegerDigits = 1
//        formatter.maximumFractionDigits = 3
//        
//        return formatter
//    }
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
                }
                .frame(width: 75, height: 30, alignment:.center).background(.yellow.opacity(0.4)).border(.gray).cornerRadius(10)
                .padding(.leading, 20)
                Spacer()
            }
        }
        .frame(maxWidth:.infinity, maxHeight:40,alignment:.bottomLeading)
        Section {
            VStack(spacing: 0) {
                HStack (alignment: .bottom,spacing:0) {
                    Text("Name").frame(maxWidth:.infinity).border(.gray)
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Team").frame(maxWidth:.infinity).border(.gray)
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Beg Inning").frame(maxWidth:.infinity).border(.gray)
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Batters in").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("End Inning").frame(maxWidth:.infinity).border(.gray)
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Batters in").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                }
                .padding(.horizontal,10)
                HStack {
                    Spacer()
                    Text(pitcher.player.name).frame(maxWidth:.infinity, alignment: .leading)
                        .frame(maxWidth:.infinity).overlay(Divider().background(.black), alignment: .trailing)
                    Spacer()
                    Text(pitcher.player.team?.name ?? "").frame(maxWidth:.infinity, alignment: .leading)
                        .frame(maxWidth:.infinity).overlay(Divider().background(.black), alignment: .trailing)
                    Spacer()
                    Picker("beg inn", selection: $pitcher.startinn) {
                        let innings = ["None","1st","2nd","3rd","4th",
                                       "5th","6th","7th","8th","9th",
                                       "10th","11th","12th","13th","14th",
                                       "15","15th","17th","18th","19th"]
                        ForEach(Array(innings.enumerated()), id: \.1) { index, inning in
                            Text(inning).tag(index)
                        }
                    }
                    .frame(maxWidth:.infinity).overlay(Divider().background(.black), alignment: .trailing)
                    Spacer()
                    Picker("Bat In", selection: $pitcher.sBatIn) {
                        let batters = ["None","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                        ForEach(Array(batters.enumerated()), id: \.1) { index, batter in
                            Text(batter).tag(index)
                        }
                    }
                    .frame(maxWidth:.infinity).overlay(Divider().background(.black), alignment: .trailing)
                    Spacer()
                    Picker("End inn", selection: $pitcher.endinn) {
                        let innings = ["None","1st","2nd","3rd","4th",
                                       "5th","6th","7th","8th","9th",
                                       "10th","11th","12th","13th","14th",
                                       "15","15th","17th","18th","19th"]
                        ForEach(Array(innings.enumerated()), id: \.1) { index, inning in
                            Text(inning).tag(index)
                        }
                    }
                    .frame(maxWidth:.infinity).overlay(Divider().background(.black), alignment: .trailing)
                    Spacer()
                    Picker("End Outs", selection: $pitcher.eBatIn) {
                        let batters = ["None","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
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
