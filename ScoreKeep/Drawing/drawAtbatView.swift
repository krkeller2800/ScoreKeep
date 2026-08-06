//
//  drawAtbatView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 4/9/25.
//
import SwiftUI
import SwiftData
import Foundation

struct drawIt: View {
    var size: CGSize
    var result: String
    var maxbase: String
    var outAt: String
    var abb: String
    var body: some View {
        clearLines(size: size, result: result, maxbase: maxbase, outAt: outAt, abb: abb)
        switch result {
        case "Dropped 3rd Strike":
            drawSingle(size: size, result: result, maxbase: maxbase, outAt: outAt, abb: abb)
        case "Catcher Interference":
            drawSingle(size: size, result: result, maxbase: maxbase, outAt: outAt, abb: abb)
        case "Walk":
            drawSingle(size: size, result: result, maxbase: maxbase, outAt: outAt, abb: abb)
        case "Error":
            drawSingle(size: size, result: result, maxbase: maxbase, outAt: outAt, abb: abb)
        case "Single":
            drawSingle(size: size, result: result, maxbase: maxbase, outAt: outAt, abb: abb)
        case "Double":
            drawDouble(size: size, result: result, maxbase: maxbase, outAt: outAt, abb: abb)
        case "Triple":
            drawTriple(size: size, result: result, maxbase: maxbase, outAt: outAt, abb: abb)
        case "Home Run":
            drawHomeRun(size: size, result: result, maxbase: maxbase, outAt: outAt, abb: abb)
        default:
            drawSingle(size: size, result: result, maxbase: maxbase, outAt: outAt, abb: abb)
        }
        if maxbase != "No Bases" {
            drawRunning(size: size, result: result, maxbase: maxbase, outAt: outAt, abb: abb)
        }
        if outAt != "Safe" {
            drawoutAt(size: size, result: result, maxbase: maxbase, outAt: outAt, abb: abb)
        }
    }
}
struct drawSingle: View {
    var size: CGSize
    var result: String
    var maxbase: String
    var outAt: String
    var abb: String
    var body: some View {

        let com = Common()
        if UIDevice.type == "iPhone" {
            if com.onresults.contains(result) {
                Text(abb).position(x: 0.5 * size.width, y: 0.8 * size.height).font(.system(size: 30))
                Path() {
                    myPath in
                    myPath.move(to: CGPoint(x: size.width/2, y: 0.92 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.57 * size.width, y: 0.81 * size.height))
                }
                .stroke(Color.indigo, lineWidth: 5)
            } else {
                Text(abb).position(x: 0.65 * size.width, y: 0.91 * size.height).font(.system(size: 45))
            }
        } else {
            Text(abb).position(x: 0.5 * size.width, y: 0.62 * size.height).font(.system(size: 65))
            if com.onresults.contains(result) {
                Path() {
                    myPath in
                    myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.75 * size.width, y: 0.7 * size.height))
                }
                .stroke(Color.indigo, lineWidth: 5)
            }
        }
    }
}
struct drawDouble: View {
    var size: CGSize
    var result: String
    var maxbase: String
    var outAt: String
    var abb: String
    var body: some View {

        if UIDevice.type == "iPhone" {
            Text(abb).position(x: 0.5 * size.width, y: 0.8 * size.height).font(.system(size: 30))
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: size.width/2, y: 0.92 * size.height))
                myPath.addLine(to: CGPoint(x: 0.57 * size.width, y: 0.8 * size.height))
                myPath.addLine(to: CGPoint(x: size.width/2, y: 0.7 * size.height))
            }
            .stroke(Color.indigo, lineWidth: 5)
        } else {
            Text(abb).position(x: 0.5 * size.width, y: 0.62 * size.height).font(.system(size: 65))
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                myPath.addLine(to: CGPoint(x: 0.75 * size.width, y: 0.7 * size.height))
                myPath.addLine(to: CGPoint(x: size.width/2, y: 0.5 * size.height))
            }
            .stroke(Color.indigo, lineWidth: 5)
        }
    }
}
struct drawTriple: View {
    var size: CGSize
    var result: String
    var maxbase: String
    var outAt: String
    var abb: String
    var body: some View {

        if UIDevice.type == "iPhone" {
            Text(abb).position(x: 0.5 * size.width, y: 0.8 * size.height).font(.system(size: 30))
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: size.width/2, y: 0.92 * size.height))
                myPath.addLine(to: CGPoint(x: 0.57 * size.width, y: 0.8 * size.height))
                myPath.addLine(to: CGPoint(x: size.width/2, y: 0.7 * size.height))
                myPath.addLine(to: CGPoint(x: 0.43 * size.width, y: 0.80 * size.height))
            }
            .stroke(Color.indigo, lineWidth: 5)
        } else {
            Text(abb).position(x: 0.5 * size.width, y: 0.62 * size.height).font(.system(size: 65))
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                myPath.addLine(to: CGPoint(x: 0.75 * size.width, y: 0.7 * size.height))
                myPath.addLine(to: CGPoint(x: size.width/2, y: 0.5 * size.height))
                myPath.addLine(to: CGPoint(x: 0.25 * size.width, y: 0.70 * size.height))
            }
            .stroke(Color.indigo, lineWidth: 5)

        }
    }
}
struct drawHomeRun: View {
    var size: CGSize
    var result: String
    var maxbase: String
    var outAt: String
    var abb: String
    var body: some View {

        if UIDevice.type == "iPhone" {
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: size.width/2, y: 0.92 * size.height))
                myPath.addLine(to: CGPoint(x: 0.57 * size.width, y: 0.8 * size.height))
                myPath.addLine(to: CGPoint(x: size.width/2, y: 0.7 * size.height))
                myPath.addLine(to: CGPoint(x: 0.43 * size.width, y: 0.8 * size.height))
                myPath.addLine(to: CGPoint(x: 0.50 * size.width, y: 0.92 * size.height))
            }
            .fill(Color.black)
            Text(abb).position(x: 0.5 * size.width, y: 0.8 * size.height).font(.system(size: 30)).foregroundColor(.white)
        } else {
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                myPath.addLine(to: CGPoint(x: 0.75 * size.width, y: 0.7 * size.height))
                myPath.addLine(to: CGPoint(x: size.width/2, y: 0.5 * size.height))
                myPath.addLine(to: CGPoint(x: 0.25 * size.width, y: 0.7 * size.height))
                myPath.addLine(to: CGPoint(x: 0.50 * size.width, y: 0.90 * size.height))
            }
            .fill(Color.black)
            Text(abb).position(x: 0.5 * size.width, y: 0.62 * size.height).font(.system(size: 65)).foregroundColor(.white)
        }
    }
}
struct drawRunning: View {
    var size: CGSize
    var result: String
    var maxbase: String
    var outAt: String
    var abb: String
    var body: some View {

        if UIDevice.type == "iPhone" {
            if maxbase == "Home" {
                Path() {
                    myPath in
                    myPath.move(to: CGPoint(x: size.width/2, y: 0.92 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.57 * size.width, y: 0.8 * size.height))
                    myPath.addLine(to: CGPoint(x: size.width/2, y: 0.7 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.43 * size.width, y: 0.8 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.50 * size.width, y: 0.92 * size.height))
                }
                .fill(Color.black)
                Text(abb).position(x: 0.5 * size.width, y: 0.8 * size.height).font(.system(size: 30)).foregroundColor(.white)
            } else {
                Path() {
                    myPath in
                    myPath.move(to: CGPoint(x: size.width/2, y: 0.92 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.57 * size.width, y: 0.8 * size.height))
                    if maxbase == "Second" || maxbase == "Third" {
                        myPath.addLine(to: CGPoint(x: size.width/2, y: 0.7 * size.height))
                        if maxbase == "Third" {
                            myPath.addLine(to: CGPoint(x: 0.43 * size.width, y: 0.8 * size.height))
                        }
                    }
                }
                .stroke(Color.indigo, lineWidth: 5)
                Text(abb).position(x: 0.5 * size.width, y: 0.8 * size.height).font(.system(size: 30))
            }
        } else {
            if maxbase == "Home" {
                Path() {
                    myPath in
                    myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.75 * size.width, y: 0.7 * size.height))
                    myPath.addLine(to: CGPoint(x: size.width/2, y: 0.5 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.25 * size.width, y: 0.7 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.50 * size.width, y: 0.90 * size.height))
                }
                .fill(Color.black)
                Text(abb).position(x: 0.5 * size.width, y: 0.62 * size.height).font(.system(size: 65)).foregroundColor(.white)
            } else {
                Path() {
                    myPath in
                    myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.75 * size.width, y: 0.7 * size.height))
                    if maxbase == "Second" || maxbase == "Third" {
                        myPath.addLine(to: CGPoint(x: size.width/2, y: 0.5 * size.height))
                        if maxbase == "Third" {
                            myPath.addLine(to: CGPoint(x: 0.25 * size.width, y: 0.7 * size.height))
                        }
                    }
                }
                .stroke(Color.indigo, lineWidth: 5)
                Text(abb).position(x: 0.5 * size.width, y: 0.62 * size.height).font(.system(size: 65))
            }
        }
    }
}

struct clearLines: View {
    var size: CGSize
    var result: String
    var maxbase: String
    var outAt: String
    var abb: String
    var body: some View {

        if UIDevice.type == "iPhone" {
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: size.width/2, y: 0.92 * size.height))
                myPath.addLine(to: CGPoint(x: 0.57 * size.width, y: 0.8 * size.height))
                myPath.addLine(to: CGPoint(x: size.width/2, y: 0.7 * size.height))
                myPath.addLine(to: CGPoint(x: 0.43 * size.width, y: 0.8 * size.height))
                myPath.addLine(to: CGPoint(x: 0.50 * size.width, y: 0.92 * size.height))
            }
            .stroke(Color.yellow.opacity(0.1),lineWidth: 6)
        } else {
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                myPath.addLine(to: CGPoint(x: 0.75 * size.width, y: 0.7 * size.height))
                myPath.addLine(to: CGPoint(x: size.width/2, y: 0.5 * size.height))
                myPath.addLine(to: CGPoint(x: 0.25 * size.width, y: 0.7 * size.height))
                myPath.addLine(to: CGPoint(x: 0.50 * size.width, y: 0.90 * size.height))
            }
            .stroke(Color.yellow.opacity(0.1),lineWidth: 6)
        }
    }
}
struct drawoutAt: View {
    var size: CGSize
    var result: String
    var maxbase: String
    var outAt: String
    var abb: String
    var body: some View {

        if UIDevice.type == "iPhone" {
            if outAt == "Home" {
                Path() {
                    myPath in
                    myPath.move(to: CGPoint(x: size.width/2, y: 0.92 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.57 * size.width, y: 0.8 * size.height))
                    myPath.addLine(to: CGPoint(x: size.width/2, y: 0.7 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.43 * size.width, y: 0.8 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.50 * size.width, y: 0.92 * size.height))
                }
                .stroke(Color.indigo, lineWidth: 5)
                Text("X").position(x: 0.50 * size.width, y: 0.92 * size.height).font(.system(size: 25, weight: .regular))


            } else {
                Path() {
                    myPath in

                    myPath.move(to: CGPoint(x: size.width/2, y: 0.92 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.57 * size.width, y: 0.8 * size.height))
                    if outAt == "Second" || outAt == "Third" {
                        myPath.addLine(to: CGPoint(x: size.width/2, y: 0.7 * size.height))
                        if outAt == "Third" {
                            myPath.addLine(to: CGPoint(x: 0.43 * size.width, y: 0.8 * size.height))
                        }
                    }
                }
                .stroke(Color.indigo, lineWidth: 5)
                if outAt == "First" {
                    Text("X").position(x: 0.57 * size.width, y: 0.8 * size.height).font(.system(size: 25, weight: .regular))
                } else if outAt == "Second" {
                    Text("X").position(x: size.width/2, y: 0.7 * size.height).font(.system(size:25, weight: .regular))
                } else if outAt == "Third" {
                    Text("X").position(x: 0.43 * size.width, y: 0.8 * size.height).font(.system(size: 25, weight: .regular))
                }
            }
        } else {
            if outAt == "Home" {
                Path() {
                    myPath in
                    myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.75 * size.width, y: 0.7 * size.height))
                    myPath.addLine(to: CGPoint(x: size.width/2, y: 0.5 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.25 * size.width, y: 0.7 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.50 * size.width, y: 0.90 * size.height))
                }
                .stroke(Color.indigo, lineWidth: 5)
                Text("X").position(x: 0.50 * size.width, y: 0.90 * size.height).font(.system(size: 35, weight: .bold))


            } else {
                Path() {
                    myPath in
                    myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                    myPath.addLine(to: CGPoint(x: 0.75 * size.width, y: 0.7 * size.height))
                    if outAt == "Second" || outAt == "Third" {
                        myPath.addLine(to: CGPoint(x: size.width/2, y: 0.5 * size.height))
                        if outAt == "Third" {
                            myPath.addLine(to: CGPoint(x: 0.25 * size.width, y: 0.7 * size.height))
                        }
                    }
                }
                .stroke(Color.indigo, lineWidth: 5)
                if outAt == "First" {
                    Text("X").position(x: 0.75 * size.width, y: 0.70 * size.height).font(.system(size: 35, weight: .regular))
                } else if outAt == "Second" {
                    Text("X").position(x: size.width/2, y: 0.5 * size.height).font(.system(size:35, weight: .regular))
                } else if outAt == "Third" {
                    Text("X").position(x: 0.25 * size.width, y: 0.7 * size.height).font(.system(size: 35, weight: .regular))
                }
            }
        }
    }
}

struct fielderButtons: View {
    @Environment(\.colorScheme) private var colorScheme
    var size: CGSize
    var result: String
    @Binding var playRecord: String
    @State var showShadow1 = false
    @State var showShadow2 = false
    @State var showShadow3 = false
    @State var showShadow4 = false
    @State var showShadow5 = false
    @State var showShadow6 = false
    @State var showShadow7 = false
    @State var showShadow8 = false
    @State var showShadow9 = false
    init(size: CGSize, atbat: Atbat) {
        self.size = size
        self.result = atbat.result
        _playRecord = Binding(
            get: { atbat.playRec },
            set: { atbat.playRec = $0 }
        )
    }

    init(size: CGSize, result: String, playRecord: Binding<String>) {
        self.size = size
        self.result = result
        _playRecord = playRecord
    }

    private func fielderLabelColor(selected: Bool) -> Color {
        selected ? .red : (colorScheme == .dark ? ScoreKeepVisualStyle.primaryText : .black)
    }

    var body: some View {
        let sz = UIDevice.type == "iPhone" ? 32.5: 45.0
        let phone = UIDevice.type == "iPhone" ? true : false
        Button("\n\n\nLeft") {
            if playRecord.count > 0 {
                playRecord += result == "Fly Out" ? "-F7" : result == "Line Out" ? "-L7" : "-7"
            } else {
                playRecord += result == "Fly Out" ? "F7" : result == "Line Out" ? "L7" : "7"
            }
        }
        .foregroundColor(fielderLabelColor(selected: showShadow7)).italic().font(.caption)
        .position(x:(phone ? 0.33 :0.15) * size.width, y:(phone ? 0.59 : 0.4) * size.height)
        .shadow(color: Color.red, radius: showShadow7 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("outfielder")
                .resizable()
                .scaledToFill()
                .frame(width: sz, height: sz)
                .position(x:(phone ? 0.33 :0.15) * size.width, y:(phone ? 0.59 : 0.4) * size.height)
        }
        .onChange (of: playRecord) {
            setflags()
        }
        .onAppear() {
            setflags()
        }
        Button("\n\n\nCenter") {
            if playRecord.count > 0 {
                playRecord += result == "Fly Out" ? "-F8" : result == "Line Out" ? "-L8" : "-8"
            } else {
                playRecord += result == "Fly Out" ? "F8" : result == "Line Out" ? "L8" : "8"
            }
        }
        .foregroundColor(fielderLabelColor(selected: showShadow8)).italic().font(.caption)
        .position(x:(phone ? 0.5 :0.5) * size.width, y:(phone ? 0.5 : 0.35) * size.height)
        .shadow(color: Color.red, radius: showShadow8 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("outfielder")
                .resizable()
                .scaledToFill()
                .frame(width: sz, height: sz)
                .position(x:(phone ? 0.5 :0.5) * size.width, y:(phone ? 0.5 : 0.35) * size.height)
        }
        Button("\n\n\nRight") {
            if playRecord.count > 0 {
                playRecord += result == "Fly Out" ? "-F9" : result == "Line Out" ? "-L9" : "-9"
            } else {
                playRecord += result == "Fly Out" ? "F9" : result == "Line Out" ? "L9" : "9"
            }
        }
        .foregroundColor(fielderLabelColor(selected: showShadow9)).italic().font(.caption)
        .position(x:(phone ? 0.67 :0.85) * size.width, y:(phone ? 0.59 : 0.4) * size.height)
        .shadow(color: Color.red, radius: showShadow9 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("outfielder")
                .resizable()
                .scaledToFill()
                .frame(width: sz, height: sz)
                .position(x:(phone ? 0.67 :0.85) * size.width, y:(phone ? 0.59 : 0.4) * size.height)
        }
        Button("\n\n\n3rd") {
            if playRecord.count > 0 {
                playRecord += result == "Fly Out" ? "-P5" : result == "Line Out" ? "-L5" : "-5"
            } else {
                playRecord += result == "Fly Out" ? "P5" : result == "Line Out" ? "L5": "5"
            }
        }
        .foregroundColor(fielderLabelColor(selected: showShadow5)).italic().font(.caption)
        .position(x:(phone ? 0.40 : 0.25) * size.width, y:(phone ? 0.68 : 0.59) * size.height)
        .shadow(color: Color.red, radius: showShadow5 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("Infielder")
                .resizable()
                .scaledToFill()
                .frame(width: sz, height: sz)
                .position(x:(phone ? 0.4 :0.25) * size.width, y:(phone ? 0.68 : 0.59) * size.height)
        }
        Button("\n\n\nShort") {
            if playRecord.count > 0 {
                playRecord += result == "Fly Out" ? "-P6" : result == "Line Out" ? "-L6" : "-6"
            } else {
                playRecord += result == "Fly Out" ? "P6" : result == "Line Out" ? "L6" : "6"
            }
        }
        .foregroundColor(fielderLabelColor(selected: showShadow6)).italic().font(.caption)
        .position(x:(phone ? 0.46 : 0.36) * size.width, y:(phone ? 0.64 : 0.46) * size.height)
        .shadow(color: Color.red, radius: showShadow6 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("Infielder")
                .resizable()
                .scaledToFill()
                .frame(width: sz, height: sz)
                .position(x:(phone ? 0.46 : 0.36) * size.width, y:(phone ? 0.64 : 0.46) * size.height)
        }
        Button("\n\n\n2nd") {
            if playRecord.count > 0 {
                playRecord += result == "Fly Out" ? "-P4" : result == "Line Out" ? "-L4" : "-4"
            } else {
                playRecord += result == "Fly Out" ? "P4" : result == "Line Out" ? "L4" : "4"
            }
        }
        .foregroundColor(fielderLabelColor(selected: showShadow4)).bold().italic().font(.caption)
        .position(x:(phone ? 0.54 : 0.64) * size.width, y:(phone ? 0.64 : 0.46) * size.height)
        .shadow(color: Color.red, radius: showShadow4 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("Infielder")
                .resizable()
                .scaledToFill()
                .frame(width: sz, height: sz)
                .position(x:(phone ? 0.54 : 0.64) * size.width, y:(phone ? 0.64 : 0.46) * size.height)
        }
        Button("\n\n\n1st") {
            if playRecord.count > 0 {
                playRecord += result == "Fly Out" ? "-P3" : result == "Line Out" ? "-L3" : "-3"
            } else {
                playRecord += result == "Fly Out" ? "P3" : result == "Line Out" ? "L3" : "3"
            }        }
        .foregroundColor(fielderLabelColor(selected: showShadow3)).italic().font(.caption)
        .position(x:(phone ? 0.6 : 0.75) * size.width, y:(phone ? 0.7 : 0.59) * size.height)
        .shadow(color: Color.red, radius: showShadow3 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("Infielder")
                .resizable()
                .scaledToFill()
                .frame(width: sz, height: sz)
                .position(x:(phone ? 0.6 : 0.75) * size.width, y:(phone ? 0.7 : 0.59) * size.height)
        }
        Button("\n\n\nPitch") {
            if playRecord.count > 0 {
                playRecord += result == "Fly Out" ? "-P1" : result == "Line Out" ? "-L1" : "-1"
            } else {
                playRecord += result == "Fly Out" ? "P1" : result == "Line Out" ? "L1" : "1"
            }
        }
        .foregroundColor(fielderLabelColor(selected: showShadow1)).italic().font(.caption)
        .position(x:(phone ? 0.5 : 0.5) * size.width, y:(phone ? 0.77 : 0.7) * size.height)
        .shadow(color: Color.red, radius: showShadow1 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("pitcher")
                .resizable()
                .scaledToFill()
                .frame(width: 55, height: 55)
                .position(x:(phone ? 0.5 : 0.5) * size.width, y:(phone ? 0.77 : 0.7) * size.height)
        }
        Button("\n\nCatch") {
            if playRecord.count > 0 {
                playRecord += result == "Fly Out" ? "-P2" : result == "Line Out" ? "-L2" : "-2"
            } else {
                playRecord += result == "Fly Out" ? "P2" : result == "Line Out" ? "L2" : "2"
            }
        }
        .foregroundColor(fielderLabelColor(selected: showShadow2)).bold().italic().font(.caption)
        .position(x:(phone ? 0.5 : 0.5) * size.width, y:(phone ? 0.93 : 0.94) * size.height)
        .shadow(color: Color.red, radius: showShadow2 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("catcher")
                .resizable()
                .scaledToFill()
                .frame(width: 35, height: 35)
                .position(x:0.5 * size.width, y:0.94 * size.height)
        }
    }
    func setflags() {
        showShadow1 = playRecord.contains("1") ? true : false
        showShadow2 = playRecord.contains("2") ? true : false
        showShadow3 = playRecord.contains("3") ? true : false
        showShadow4 = playRecord.contains("4") ? true : false
        showShadow5 = playRecord.contains("5") ? true : false
        showShadow6 = playRecord.contains("6") ? true : false
        showShadow7 = playRecord.contains("7") ? true : false
        showShadow8 = playRecord.contains("8") ? true : false
        showShadow9 = playRecord.contains("9") ? true : false

    }
}
