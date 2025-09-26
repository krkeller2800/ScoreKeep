//
//  PlayersToScoreView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 8/29/25.
//

import SwiftUI
import SwiftData
struct PlayersToScoreView: View {
    @Environment(\.modelContext) var modelContext
    @Query var atbats: [Atbat]
    @Binding var lAtbats: [Atbat]
    @Binding var game: Game
    @Binding var isLoading: Bool
    @Binding var hasChanged: Bool
    @Binding var columnVisability:NavigationSplitViewVisibility
    @State var screenSize: CGSize = .zero
    @State var screenWidth = UIScreen.screenWidth
    @State var screenHeight = UIScreen.screenHeight
    @State var showingScoring = false
    @State var firstTime = true
    @State var teamName = ""
    @State var playerName = ""
    var com:Common = Common()

    @State private var offset = CGFloat.zero

    @State var colbox:[BoxScore] = Array(repeating: BoxScore(), count: 20)
    @State var batbox:[BoxScore] = Array(repeating: BoxScore(), count: 20)
    @State var totbox:[BoxScore] = Array(repeating: BoxScore(), count: 5)
    @State var iStat:InnStatus = InnStatus()

    @State var theAtbat = Atbat(game: Game(date: "", location: "", highLights: "", hscore: 0, vscore: 0),
                                team: Team(name: "", coach: "", details: ""),
                                player: Player(name: "", number: "", position: "", batDir: "", batOrder: 99),
                                result: "Result", maxbase: "No Bases", batOrder: 99, outAt: "Safe", inning: 1, seq:0, col:1, rbis:0, outs:0,
                                sacFly: 0,sacBunt: 0,stolenBases: 0)
    var body: some View {
        Section {
            GeometryReader { geometry in
                let gWidth = geometry.size.width
                drawIndicator(iStat:iStat,size:geometry.size,colbox:colbox,space:calcSpace(gWidth: gWidth))
                drawBoxScore(game:game,size:geometry.size)
                drawInnings(game: game, atbats: atbats, space: calcSpace(gWidth: gWidth),offset: offset,gWidth: gWidth)
                VStack ( spacing: 0) {
                    HStack(alignment: .top) {
                        Text("Num").frame(width:30, height: 15, alignment:.center).font(.caption).foregroundColor(.black).bold().padding(.leading, 3)
                        Text("Name").frame(width:50, height: 15, alignment:.leading).font(.caption).foregroundColor(.black).bold()
                        Spacer()
                    }
                    ScrollView() {
                        HStack {
                            VStack (spacing: 0){
                                ForEach(Array(atbats.enumerated()), id: \.1) { index, atbat in
                                    HStack(spacing: 2) {
                                        if atbat.inning <= 1 && atbat.col == 1 && atbat.batOrder != 99 {
                                            let bSiz:CGFloat = gWidth > 1100 ? 60 : 50
                                            let strikeIt: Bool = game.replaced.contains(atbat.player) ? true : false
                                            let iName: String = game.incomings.contains(atbat.player) ? String("    \(atbat.player.name)") : atbat.player.name
                                            Text(atbat.player.number).frame(width: 30, height: bSiz,alignment: .center).foregroundColor(.black)
                                                .overlay(Divider().background(.black), alignment: .trailing)
                                            Text(iName).frame(width: 150, alignment: .leading).foregroundColor(.black).strikethrough(strikeIt)
                                                .fixedSize(horizontal: true, vertical: true).padding(.leading,5).lineLimit(2)

                                        }
                                    }
                                }
                                Spacer()
                            }
                            ScrollView(.horizontal) {
                                ZStack {
                                    let bigCol = atbats.filter{$0.result != "Result"}.max { $0.col < $1.col }
                                    let gridSz = CGFloat(gWidth > 1100 ? 60 : 50)
                                    let bSize = Int(((gWidth - (gWidth > 1100 ? 425 : 325)) / gridSz).rounded(.down))
                                    let newCol = (bigCol?.col ?? 1) + 1
                                    let maxCol = newCol < bSize ? bSize : newCol
                                    VStack (spacing: 0) {
                                        ForEach(Array(atbats.enumerated()), id: \.1) { index, atbat in
                                            HStack(spacing: 0) {
                                                if atbat.inning <= 1 && atbat.col == 1 && atbat.batOrder != 99 {
                                                    ForEach((1...maxCol), id: \.self) {ind in
                                                        let bSiz:CGFloat = gWidth > 1100 ? 60 : 50
                                                        Button(action: {
                                                            showingScoring.toggle()
                                                            hasChanged = true
                                                            doAtbat(ind: ind, index: index, atbat: atbat)
                                                        }, label: {
                                                            Image("field").resizable().scaledToFit()
                                                        })
                                                        .frame(width: bSiz, height: bSiz)
                                                        .buttonStyle(GlowButtonStyle())
                                                    }
                                                }
                                                let mCol = Double(gWidth) - 150 - (Double(maxCol+1) * gridSz)
                                                Spacer(minLength:mCol < 0 ? 0 : mCol)
                                            }
                                        }
                                        if atbats.count > 0 {
                                            let opTeam = atbats[0].team == game.hteam ? game.vteam! : game.hteam!
                                            let numOfPitchers = CGFloat(game.pitchers.filter { $0.team == opTeam }.count)
                                            Spacer(minLength:numOfPitchers * 25 + 100)
                                        }
                                    }
                                    .background(GeometryReader {
                                        Color.clear.preference(key: ViewOffsetKey.self, value: -$0.frame(in: .named("scroll")).origin.x)
                                    })
                                    .onPreferenceChange(ViewOffsetKey.self) {
                                        offset = $0
                                    }
                                    if !atbats.isEmpty {
                                        drawSing(space: calcSpace(gWidth:gWidth), atbats: atbats.sorted{ ($0.col, $0.seq) < ($1.col, $1.seq) },colbox: colbox,batbox: batbox, totbox: totbox,sWidth: gWidth, isLoading: $isLoading)
                                        let opTeam = atbats[0].team == game.hteam ? game.vteam! : game.hteam!
                                        drawPitchers(space: calcSpace(gWidth:gWidth), atbats: atbats, abb: "", inning: 1,game: game, team: opTeam, width: gWidth)
                                    }
                                }
                            }
                            .coordinateSpace(name: "scroll")
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) // <5>
                .onAppear() {
                    lAtbats = atbats
                }
                .onChange(of: atbats) {
                    if firstTime {
                        seqGame()
                        updMaxBases()
                        firstTime = false
                    }
                }
                .onChange(of: theAtbat.result) {
                    seqGame()
                    updMaxBases()
                }
                .onChange(of: theAtbat.outAt) {
                    seqGame()
                    updMaxBases()
                }
                .onChange(of: atbats.count > 0 ? atbats[0].team.name : "") {
                    seqGame()
                    updMaxBases()
                }
                .onChange(of: theAtbat.sacFly) {
                    seqGame()
                    updMaxBases()
                }

            }
            .sheet(isPresented: $showingScoring) { ScoreGameView(atbat: $theAtbat, showingScoring: $showingScoring) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                
            // Give a moment for the screen boundaries to change after
            // the device is rotated
            Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(0.2))
                    withAnimation {
                        screenHeight = UIScreen.main.bounds.height
                        screenWidth = UIScreen.main.bounds.width
                        columnVisability = .detailOnly
                    }
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }
    func calcSpace(gWidth:CGFloat) -> CGRect {
        let bSize:CGFloat = gWidth > 1100 ? 60 : 50
        let newx:CGFloat = gWidth > 1100 ? -60 : -50
        return CGRect(x: newx, y: 0, width: bSize, height: bSize)
    }
    func updMaxBases() {
        let usedAtbats = atbats.filter {$0.result != "Result"}
        let inning = usedAtbats.last?.inning.rounded(.up) ?? 0
        let atbatsToUpd = usedAtbats.filter {($0.inning.rounded(.up) == inning || ($0.inning.rounded(.up) == 0 && inning == 1)) && com.onresults.contains($0.result) }
        var currMaxBase = 0
        let maxbases:[String] = ["First","Second","Third","Home"]
        let maxHits:[String] = ["Single","Double","Triple","Home Run"]
        let atbatsToUpdSorted = atbatsToUpd.sorted{ ($0.col, $0.seq) < ($1.col, $1.seq) }
        
        iStat = InnStatus(outs: usedAtbats.last?.outs ?? 0)
        
        for (index, theBase) in atbatsToUpdSorted.reversed().enumerated() {
    
            let theMaxBase = maxbases.firstIndex(of: theBase.maxbase) ?? -1
            var theMaxHit = maxHits.firstIndex(of: theBase.result) ?? -1
            theMaxHit = (theBase.result == "Walk") ? 0 : (theBase.result == "Dropped 3rd Strike") ? 0 : (theBase.result == "Hit By Pitch") ? 0 :
                        (theBase.result == "Catcher Interference") ? 0 : theMaxHit
            
            if theBase.maxbase == "No Bases" || theMaxHit > theMaxBase {
                theBase.maxbase =   (theBase.result == "Dropped 3rd Strike") ? "First" :
                                    (theBase.result == "Walk") ? "First" :
                                    (theBase.result == "Error") ? "First" :
                                    (theBase.result == "Fielder's Choice") ? "First" :
                                    (theBase.result == "Catcher Interference") ? "First" :
                                    (theBase.result == "Hit By Pitch") ? "First" :
                                    (theBase.result == "Single") ? "First" :
                                    (theBase.result == "Double") ? "Second" :
                                    (theBase.result == "Triple") ? "Third" :
                                    (theBase.result == "Home Run") ? "Home" :theBase.result
            }
            if index == 0 {
                currMaxBase = maxbases.firstIndex(of: theBase.maxbase) ?? -1
            }
            if currMaxBase >= maxbases.firstIndex(of: theBase.maxbase) ?? -1 && index != 0 && currMaxBase != 3 && theBase.outAt == "Safe"  {
                theBase.maxbase = maxbases[currMaxBase + 1]
                currMaxBase = currMaxBase + 1
            } else if currMaxBase >= 3 && theBase.outAt == "Safe" {
                theBase.maxbase = maxbases[3]
            } else if index != 0 && theBase.outAt == "Safe" {
                currMaxBase = maxbases.firstIndex(of: theBase.maxbase) ?? -1
            }
            if theBase.outAt == "Safe" {
                if theBase.maxbase == "Third" {
                    iStat.onThird = true
                } else if theBase.maxbase == "Second" {
                    iStat.onSecond = true
                } else if theBase.maxbase == "First" {
                    iStat.onFirst = true
                }
            }
        }
    }
    func seqGame() {
        var allOuts:Int = 0
        var outs:Int = 0
        var seq:Int = 1
        var inning:Int = 1
        var col:Int = 1
        var endOfInning:Bool = false

//        print("Game.atbats.count = \(game.atbats.count)")
        
        colbox = Array(repeating: BoxScore(), count: 20)
        batbox = Array(repeating: BoxScore(), count: 20)
        totbox = Array(repeating: BoxScore(), count: 5)
        
        let atbatsSoFar = atbats.sorted{ ($0.col, $0.seq) < ($1.col, $1.seq) }

        for (_, atbat) in atbatsSoFar.enumerated() {
            if atbat.result != "Result" {
                if outs == 3 && endOfInning {
                    outs = 0
                    inning += 1
                    col += 1
                    seq = 1
                }
                let numOfHitters = atbatsSoFar.filter{$0.col == 1}.count
                if seq == numOfHitters+1 || seq == 2*numOfHitters+1 {
                    col += 1
                }
             
                atbat.col = atbat.col == 1 && atbat.result == "Pitch Hitter" ? 1 : col
                if com.outresults.contains(atbat.result) || atbat.outAt != "Safe"  {
                    outs += 1
                    allOuts += 1
                }
                atbat.inning = CGFloat(allOuts)/3.0
                if (CGFloat(inning) > atbat.inning  && (atbat.col != 1 && atbat.result != "Pitch Hitter")) || (atbat.col == 1 && atbat.inning == 0 && com.onresults.contains(atbat.result)) {
                    atbat.inning += 0.1
                }
                atbat.outs = outs
                atbat.seq = atbat.col == 1 && atbat.result == "Pitch Hitter" ? atbat.batOrder : seq
                seq += 1
                endOfInning = atbat.endOfInning
                
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
                if atbat.result == "Strikeout" || atbat.result == "Strikeout Looking" || atbat.result == "Dropped 3rd Strike" {
                    colbox[col].strikeouts += 1
                    batbox[atbat.batOrder].strikeouts += 1
                    totbox[0].strikeouts += 1
                }
                if com.onresults.contains(atbat.result) && atbat.stolenBases > 0 {
                    colbox[col].stoleBase += atbat.stolenBases
                    batbox[atbat.batOrder].stoleBase += atbat.stolenBases
                    totbox[0].stoleBase += atbat.stolenBases
                }
                colbox[col].inning = inning
            }
            do {
                try self.modelContext.save()
            }
            catch {
                print("Error saving seq atbats: \(error)")
            }
        }
    }
    init(passedGame: Binding<Game>, teamName: String, searchString: String = "", sortOrder: [SortDescriptor<Atbat>] = [], theAtbats: Binding<[Atbat]>, isLoading: Binding<Bool>, hasChanged: Binding<Bool>, columnVisability: Binding<NavigationSplitViewVisibility>) {
        _game = passedGame
        _lAtbats = theAtbats
        _isLoading = isLoading
        _hasChanged = hasChanged
        _columnVisability = columnVisability

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
    func doAtbat(ind:Int, index:Int, atbat:Atbat) {
        let posx = Int(ind)
        let posy = Int(index+1)
        
        if let curratbat = atbats.firstIndex(where: {  $0.game == atbat.game &&
            $0.team == atbat.team &&
            $0.batOrder == posy &&
            $0.col == posx })
        {
            theAtbat = atbats[curratbat]
        } else {
            let newAtbat = Atbat(game: atbat.game, team: atbat.team, player: atbat.player, result: "Result",
                                 maxbase: "No Bases", batOrder: posy, outAt: "Safe", inning: 99, seq:99, col: posx, rbis:0, outs:0, sacFly: 0,sacBunt: 0,stolenBases: 0)
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
}
struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}



