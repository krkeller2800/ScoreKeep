//
//  ImportDisplayViews 
//  ScoreKeep
//
//  Created by Karl Keller on 8/10/25.
//

import SwiftUI

struct showSharedPlayers: View {
    
    @Binding var sharePlayers: [SharePlayer]
             var searchText: String
    
    var body: some View {
        GeometryReader { geometry in
            Form {
                let nameWidth =  geometry.size.width/4
//                let smallWidth =  geometry.size.width/12
                let mediumWidth =  geometry.size.width/9
                
                Section {
                    HStack {
                        Text("Order")
                            .frame(width:mediumWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.6).padding(.leading, 5)
                        Text("Name")
                            .frame(width:nameWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Num")
                            .frame(width:mediumWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.5)
                        Text("Pos")
                            .frame(width:mediumWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.5)
                        Text("Dir")
                            .frame(width:mediumWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.5)
                        Text("")
                            .frame(width:30)
                    }
                    ForEach(sharePlayers) { player in
                        if player.name.localizedStandardContains(searchText) || player.number.localizedStandardContains(searchText) || searchText.isEmpty {
                            HStack {
                                Text(Double(player.batOrder), format: .number.rounded(increment: 1.0)).frame(width:mediumWidth, alignment: .center).foregroundColor(.black).padding(.leading, 5)
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.name).frame(width: nameWidth, alignment: .leading).foregroundColor(.black).lineLimit(1).minimumScaleFactor(0.5)
                                    .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 0)
                                Text(player.number).frame(width:mediumWidth, alignment: .center).foregroundColor(.black)
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.position).frame(width:mediumWidth, alignment: .center).foregroundColor(.black)
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.batDir).frame(width:mediumWidth, alignment: .center).foregroundColor(.black)
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text("").frame(width:30)
                            }
                        }
                    }
                    .onDelete(perform: deletePlayer)
                }
                header: {
                    if sharePlayers.count > 0 {
                        Text("Swipe a Player to delete").frame(maxWidth:.infinity, alignment:.leading).font(UIDevice.type == "iPhone" ? .callout : .title3).foregroundColor(.black)
                    }
                 }
            }
        }
    }
    func deletePlayer(at offsets: IndexSet) {
        sharePlayers.remove(atOffsets: offsets)
    }

}
struct showSharedGame: View {
    
    @State var shareGames: [ShareGame]
             var searchText: String
    
    var body: some View {
        GeometryReader { geometry in
//            let com = Common()
            Form {
//                let nameWidth =  geometry.size.width/4
//                let smallWidth =  geometry.size.width/12
//                let mediumWidth =  geometry.size.width/9
                
                Section {
                    HStack {
                        Text("Game Date").frame(width:UIDevice.type == "iPhone" ? 105 : 225).border(.gray)
                            .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
//                        Text("Field").frame(maxWidth:.infinity).border(.gray)
//                            .foregroundColor(.red).background(.yellow.opacity(0.3))
//                        Text("All Hit").frame(maxWidth:60).border(.gray)
//                            .foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Visiting").frame(maxWidth:.infinity).border(.gray)
                            .foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Home").frame(maxWidth:.infinity).border(.gray)
                            .foregroundColor(.red).background(.yellow.opacity(0.3))
//                        Text("Score").frame(maxWidth:.infinity).border(.gray)
//                            .foregroundColor(.red).background(.yellow.opacity(0.3))
                    }
                    HStack {
                        ForEach(shareGames) { shareGame in
                            let date = ISO8601DateFormatter().date(from: shareGame.date) ?? Date()
                            Text(date.formatted(date:.abbreviated, time: .shortened)).frame(width: UIDevice.type == "iPhone" ? 115 : 230, alignment: .center).foregroundColor(.black).bold().padding(.leading,10).lineLimit(2).minimumScaleFactor(0.5)
                                .overlay(Divider().background(.black), alignment: .trailing)
//                            Text(shareGame.location).frame(maxWidth:.infinity, alignment: .leading).foregroundColor(.black).bold()
//                                .padding(.leading, 0).overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
//                            Text(shareGame.everyOneHits ? "True" : "False").frame(maxWidth:60, alignment: .center).foregroundColor(.black).bold()
//                                .padding(.leading, 0).overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                            HStack {
                                if !shareGame.vteam.logo.isEmpty {
                                    let imageData = shareGame.vteam.logo
                                    if let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .scaleImage(iHeight: 30, imageData: imageData)
                                    }
                                }
                                Text(shareGame.vteam.name).lineLimit(1).minimumScaleFactor(0.5)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing)
                            HStack {
                                if !shareGame.hteam.logo.isEmpty {
                                    let imageData = shareGame.hteam.logo
                                    if let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .scaleImage(iHeight: 30, imageData: imageData)
                                    }
                                }
                                Text(shareGame.hteam.name).lineLimit(1).minimumScaleFactor(0.5)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing)
//                            let hruns = shareGame.atbats.filter({$0.maxbase == "Home" && $0.team.name == shareGame.hteam.name}).count
//                            let vruns = shareGame.atbats.filter({$0.maxbase == "Home" && $0.team.name == shareGame.vteam.name}).count
//                            let outs = shareGame.atbats.filter({$0.team.name == shareGame.vteam.name && (com.outresults.contains($0.result) || $0.outAt != "Safe" )}).count
//                            let inning = (outs / 3) + 1
//                            let score:String = "\(vruns) to \(hruns)"
//                            let winner:String = vruns > hruns ? (shareGame.vteam.name) : vruns < hruns ? (shareGame.hteam.name) : "No winner yet"
//                            let fin = inning > 9 && winner != "No winner yet" ? " Final" : ""
//                            let win = winner + (fin != "" ? fin : " in the \(com.innAbr[inning])")
//                            Text(score + " " + win ).frame(maxWidth:.infinity, alignment: .leading).foregroundColor(.black).bold()
//                                .overlay(Divider().background(.black), alignment: .trailing).lineLimit(2).minimumScaleFactor(0.5)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
        }
    }
}
