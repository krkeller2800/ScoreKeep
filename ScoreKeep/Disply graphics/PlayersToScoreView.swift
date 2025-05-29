//
//  PlayersToScoreView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 4/2/25.
//

import SwiftUI
import SwiftData
struct PlayersToScoreView: View {
    @Environment(\.modelContext) var modelContext
    @Query var atbats: [Atbat]
    @Binding var lAtbats: [Atbat]
    @Binding var game: Game
    @State var screenSize: CGSize = .zero
    @State var screenWidth = UIScreen.screenWidth
    @State var screenHeight = UIScreen.screenHeight
    @State var showingScoring = false
    @State var firstTime = true
    var com:Common = Common()

    @State var colbox:[BoxScore] = Array(repeating: BoxScore(), count: 20)
    @State var batbox:[BoxScore] = Array(repeating: BoxScore(), count: 20)
    @State var totbox:[BoxScore] = Array(repeating: BoxScore(), count: 5)

    @State var theAtbat = Atbat(game: Game(date: "", location: "", highLights: "", hscore: 0, vscore: 0),
                                team: Team(name: "", coach: "", details: ""),
                                player: Player(name: "", number: "", position: "", batDir: "", batOrder: 99),
                                result: "Result", maxbase: "No Bases", batOrder: 99, outAt: "Safe", inning: 1, seq:0, col:1, rbis:0, outs:0,
                                sacFly: 0,sacBunt: 0,stolenBases: 0)
    var body: some View {
        Section {
            GeometryReader { geometry in
                ScrollView {
                    ZStack {
                        VStack (spacing: 0) {
                            HStack {
                                Text("Num").frame(maxWidth:30, alignment:.center).font(.caption).foregroundColor(.black).bold()
                                Text("Name").frame(maxWidth:70, alignment:.leading).font(.caption).foregroundColor(.black).bold()
                                Spacer()
                            }
                            ForEach(Array(atbats.enumerated()), id: \.1) { index, atbat in
                                HStack(spacing: 0) {
                                    if atbat.inning <= 1 && atbat.col == 1 && atbat.batOrder != 99 {
                                        let strikeIt: Bool = game.replaced.contains(atbat.player) ? true : false
                                        let iName: String = game.incomings.contains(atbat.player) ? String("    \(atbat.player.name)") : atbat.player.name
                                        Text(atbat.player.number).frame(width: 30, alignment: .center).foregroundColor(.black).bold()
                                            .overlay(Divider().background(.black), alignment: .trailing)
                                        Text(iName).frame(width: 150, alignment: .leading).foregroundColor(.black).bold()
                                            .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
                                            .lineLimit(1).minimumScaleFactor(0.5).strikethrough(strikeIt)
                                        let newCol = atbats.map({ $0.col }).max()! + 1
                                        let bSize = UIScreen.screenWidth > 1300 ? 14 : 14
                                        let maxCol = newCol < bSize ? bSize : newCol
                                        ForEach((1...maxCol), id: \.self) {ind in
                                            let bSize:CGFloat = screenWidth > 1300 ? 60 : 50
                                            Button(action: {
                                                showingScoring.toggle()
                                            }, label: {
                                                Image("field").resizable().scaledToFit()
                                            })
                                            .frame(width: bSize, height: bSize)
                                            .buttonStyle(GlowButtonStyle())
                                            .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                                .onEnded {
                                                    let posx = Int(ind)
                                                    let posy = Int(index+1)
                                                    print("Changed \($0.location)")
//                                                    print("\(posx),\(posy),\(geometry.size.width) \(atbat.player.name)")
                                                    
//                                                    let theSize:CGFloat = UIScreen.screenWidth > 1300 ? 60 : 50
//                                                    let offset = UIScreen.main.bounds.size.width - geometry.size.width + 184.0
//                                                    let posx = (($0.location.x-offset)/theSize).rounded(.up)
//                                                    let posy = (($0.location.y-220)/theSize).rounded(.up)

                                                    if let curratbat = atbats.firstIndex(where: {  $0.game == atbat.game &&
                                                        $0.team == atbat.team &&
                                                        $0.batOrder == posy &&
                                                        $0.col == posx })
                                                    {
                                                        theAtbat = atbats[curratbat]
                                                    } else {
                                                        let newAtbat = Atbat(game: atbat.game, team: atbat.team, player: atbat.player, result: "Result",
                                                                             maxbase: "No Bases", batOrder: posy, outAt: "Not Out", inning: 99, seq:99, col: posx, rbis:0, outs:0, sacFly: 0,sacBunt: 0,stolenBases: 0)
                                                        modelContext.insert(newAtbat)
                                                        game.atbats.append(newAtbat)
                                                        
                                                        do {
                                                            try self.modelContext.save()
                                                        }
                                                        catch {
                                                            print("Error saving new atbats: \(error)")
                                                        }
                                                        theAtbat = newAtbat
                                                    }
                                                }
                                            )
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .onAppear() {
                            lAtbats = atbats
                        }
                        .onChange(of: atbats) {
                                seqGame()
                                updMaxBases()
                                firstTime = false
                        }
                        .onChange(of: theAtbat.result) {
                            seqGame()
                            updMaxBases()
                        }
                        .onChange(of: theAtbat.outAt) {
                            seqGame()
                            updMaxBases()
                        }
                        Spacer()
                        let bSize:CGFloat = screenWidth > 1300 ? 60 : 50
                        let newx:CGFloat = screenWidth > 1300 ? 125 : 135
                        let space:CGRect = CGRect(x: newx, y: 15, width: bSize, height: bSize)
                        if !atbats.isEmpty {
                            drawSing(space: space, atbats: atbats.sorted{( ($0.col, $0.seq) < ($1.col, $1.seq) )},colbox: colbox,batbox: batbox, totbox: totbox)
                        }
                    }
               }
            }
            .sheet(isPresented: $showingScoring) {ScoreGameView(atbat: $theAtbat, showingScoring: $showingScoring)}

        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                
            // Give a moment for the screen boundaries to change after
            // the device is rotated
            Task { @MainActor in
                try await Task.sleep(for: .seconds(0.1))
                withAnimation {
                    screenHeight = UIScreen.main.bounds.height
                    screenWidth = UIScreen.main.bounds.width
                }
            }
        }
    }
    func updMaxBases() {
        let inning = theAtbat.outs == 0 ? (theAtbat.inning + 1).rounded(.up) : theAtbat.inning.rounded(.up)
        let atbatsToUpd = atbats.filter {$0.inning.rounded(.up) + (1 - (CGFloat($0.outs) / 3).rounded(.up)) == inning && com.onresults.contains($0.result) }
//        print("\(atbats[11].inning.rounded(.up) + (1 - (CGFloat(atbats[11].outs) / 3).rounded(.up))) and \(inning)")
        var currMaxBase = 0
        let maxbases:[String] = ["First","Second","Third","Home"]
        let maxHits:[String] = ["Single","Double","Triple","Home Run"]
        let atbatsToUpdSorted = atbatsToUpd.sorted{( ($0.col, $0.seq) < ($1.col, $1.seq) )}

        for (index, theBase) in atbatsToUpdSorted.reversed().enumerated() {
    
            let theMaxBase = maxbases.firstIndex(of: theBase.maxbase) ?? -1
            var theMaxHit = maxHits.firstIndex(of: theBase.result) ?? -1
            theMaxHit = (theBase.result == "Walk") ? 0 : (theBase.result == "Dropped 3rd Strike") ? 0 : (theBase.result == "Hit By Pitch") ? 0 : theMaxHit
            
            if theBase.maxbase == "No Bases" || theMaxHit > theMaxBase {
                theBase.maxbase = (theBase.result == "Dropped 3rd Strike") ? "First" :
                (theBase.result == "Walk") ? "First" :
                (theBase.result == "Fielder's Choice") ? "First" :
                (theBase.result == "Hit By Pitch") ? "First" :
                (theBase.result == "Single") ? "First" :
                (theBase.result == "Double") ? "Second" :
                (theBase.result == "Triple") ? "Third" :
                (theBase.result == "Home Run") ? "Home" :theBase.result
            }
            if index == 0 {
                currMaxBase = maxbases.firstIndex(of: theBase.maxbase) ?? -1
            }
            if currMaxBase >= maxbases.firstIndex(of: theBase.maxbase) ?? -1 && index != 0 && currMaxBase != 3 
                                                                             && (theBase.outAt == "Safe" || theBase.outAt == "Not Out") {
                theBase.maxbase = maxbases[currMaxBase + 1]
                currMaxBase = currMaxBase + 1
            } else if currMaxBase >= 3 && (theBase.outAt == "Safe" || theBase.outAt == "Not Out") {
                theBase.maxbase = maxbases[3]
            } else if index != 0 && (theBase.outAt == "Safe" || theBase.outAt == "Not Out") {
                currMaxBase = maxbases.firstIndex(of: theBase.maxbase) ?? -1
            }
        }
    }

    func seqGame() {
        var allOuts:Int = 0
        var outs:Int = 0
        var seq:Int = 1
        var inning:Int = 1
        var col:Int = 1
        
        colbox = Array(repeating: BoxScore(), count: 20)
        batbox = Array(repeating: BoxScore(), count: 20)
        totbox = Array(repeating: BoxScore(), count: 5)
        
        let atbatsSoFar = atbats.sorted{( ($0.col, $0.seq) < ($1.col, $1.seq) )}

        for (_, atbat) in atbatsSoFar.enumerated() {
            if atbat.result != "Result" {
                if outs == 3 {
                    outs = 0
                    inning += 1
                    col += 1
                    seq = 1
                }
                if seq == 10 || seq == 19 {
                    col += 1
                }
                atbat.col = col
                if com.outresults.contains(atbat.result) || (atbat.outAt != "Safe" && atbat.outAt != "Not Out")  {
                    outs += 1
                    allOuts += 1
                }
                atbat.inning = CGFloat(allOuts)/3.0
                atbat.outs = outs
                if atbat.result != "Result" {
                    atbat.seq = seq
                    seq += 1
                }
                if atbat.maxbase == "Home" {
                    colbox[col].runs += 1
                    batbox[atbat.batOrder].runs += 1
                    totbox[0].runs += 1
                }
                if atbat.result == "Home Run" {
                    colbox[col].HR += 1
                    batbox[atbat.batOrder].HR += 1
                    totbox[0].HR += 1
                }
                if com.hitresults.contains(atbat.result) {
                    colbox[col].hits += 1
                    batbox[atbat.batOrder].hits += 1
                    totbox[0].hits += 1
                }
                if atbat.result == "Walk" {
                    colbox[col].walks += 1
                    batbox[atbat.batOrder].walks += 1
                    totbox[0].walks += 1
                }
                if atbat.result == "Strikeout" || atbat.result == "Strikeout Looking" {
                    colbox[col].strikeouts += 1
                    batbox[atbat.batOrder].strikeouts += 1
                    totbox[0].strikeouts += 1
                }
            }
            do {
                try self.modelContext.save()
            }
            catch {
                print("Error saving seq atbats: \(error)")
            }
        }
    }
    init(passedGame: Binding<Game>, teamName: String, searchString: String = "", sortOrder: [SortDescriptor<Atbat>] = [], theAtbats: Binding<[Atbat]>) {
        _game = passedGame
        _lAtbats = theAtbats
        
        let date = game.date
        let location = game.location
        _atbats = Query(filter: #Predicate { atbat in
            if searchString.isEmpty {
                atbat.team.name == teamName &&
                atbat.game.date == date &&
                atbat.game.location == location
            } else {
                atbat.team.name == teamName &&
                atbat.game.date == date &&
                atbat.game.location == location &&
                (atbat.player.name.localizedStandardContains(searchString)
                 || atbat.player.number.localizedStandardContains(searchString))
            }
        },  sort: sortOrder)
    }
}




#Preview {
    do {
        let previewer = try Previewer()
        return PlayerView()
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
