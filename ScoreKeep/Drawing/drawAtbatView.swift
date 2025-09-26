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
    var atbat:Atbat
    var abb:String
    var body: some View {
        clearLines(size: size, atbat: atbat, abb: abb)
        switch atbat.result {
        case "Dropped 3rd Strike":
            drawSingle(size: size, atbat: atbat, abb: abb)
        case "Catcher Interference":
            drawSingle(size: size, atbat: atbat, abb: abb)
        case "Walk":
            drawSingle(size: size, atbat: atbat, abb: abb)
        case "Error":
            drawSingle(size: size, atbat: atbat, abb: abb)
        case "Single":
            drawSingle(size: size, atbat: atbat, abb: abb)
        case "Double":
            drawDouble(size: size, atbat: atbat, abb: abb)
        case "Triple":
            drawTriple(size: size, atbat: atbat, abb: abb)
        case "Home Run":
            drawHomeRun(size: size, atbat: atbat, abb: abb)
        default:
            drawSingle(size: size, atbat: atbat, abb: abb)
        }
        if atbat.maxbase != "No Bases" {
            drawRunning(size: size, atbat: atbat, abb: abb)
        }
        if atbat.outAt != "Safe" {
            drawoutAt(size: size, atbat: atbat, abb: abb)
        }
    }
}
struct drawSingle: View {
    var size: CGSize
    var atbat:Atbat
    var abb:String
    var body: some View {
        
        let com = Common()
        if UIDevice.type == "iPhone" {
            if com.onresults.contains(atbat.result) {
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
            if com.onresults.contains(atbat.result) {
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
    var atbat:Atbat
    var abb:String
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
    var atbat:Atbat
    var abb:String
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
    var atbat:Atbat
    var abb:String
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
    var atbat:Atbat
    var abb:String
    var body: some View {
        
        if UIDevice.type == "iPhone" {
            if atbat.maxbase == "Home" {
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
                    if atbat.maxbase == "Second" || atbat.maxbase == "Third" {
                        myPath.addLine(to: CGPoint(x: size.width/2, y: 0.7 * size.height))
                        if atbat.maxbase == "Third" {
                            myPath.addLine(to: CGPoint(x: 0.43 * size.width, y: 0.8 * size.height))
                        }
                    }
                }
                .stroke(Color.indigo, lineWidth: 5)
                Text(abb).position(x: 0.5 * size.width, y: 0.8 * size.height).font(.system(size: 30))
            }
        } else {
            if atbat.maxbase == "Home" {
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
                    if atbat.maxbase == "Second" || atbat.maxbase == "Third" {
                        myPath.addLine(to: CGPoint(x: size.width/2, y: 0.5 * size.height))
                        if atbat.maxbase == "Third" {
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
    var atbat:Atbat
    var abb:String
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
    var atbat:Atbat
    var abb:String
    var body: some View {
        
        if UIDevice.type == "iPhone" {
            if atbat.outAt == "Home" {
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
                    if atbat.outAt == "Second" || atbat.outAt == "Third" {
                        myPath.addLine(to: CGPoint(x: size.width/2, y: 0.7 * size.height))
                        if atbat.outAt == "Third" {
                            myPath.addLine(to: CGPoint(x: 0.43 * size.width, y: 0.8 * size.height))
                        }
                    }
                }
                .stroke(Color.indigo, lineWidth: 5)
                if atbat.outAt == "First" {
                    Text("X").position(x: 0.57 * size.width, y: 0.8 * size.height).font(.system(size: 25, weight: .regular))
                } else if atbat.outAt == "Second" {
                    Text("X").position(x: size.width/2, y: 0.7 * size.height).font(.system(size:25, weight: .regular))
                } else if atbat.outAt == "Third" {
                    Text("X").position(x: 0.43 * size.width, y: 0.8 * size.height).font(.system(size: 25, weight: .regular))
                }
            }
        } else {
            if atbat.outAt == "Home" {
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
                    if atbat.outAt == "Second" || atbat.outAt == "Third" {
                        myPath.addLine(to: CGPoint(x: size.width/2, y: 0.5 * size.height))
                        if atbat.outAt == "Third" {
                            myPath.addLine(to: CGPoint(x: 0.25 * size.width, y: 0.7 * size.height))
                        }
                    }
                }
                .stroke(Color.indigo, lineWidth: 5)
                if atbat.outAt == "First" {
                    Text("X").position(x: 0.75 * size.width, y: 0.70 * size.height).font(.system(size: 35, weight: .regular))
                } else if atbat.outAt == "Second" {
                    Text("X").position(x: size.width/2, y: 0.5 * size.height).font(.system(size:35, weight: .regular))
                } else if atbat.outAt == "Third" {
                    Text("X").position(x: 0.25 * size.width, y: 0.7 * size.height).font(.system(size: 35, weight: .regular))
                }
            }
        }
    }
}

struct fielderButtons: View {
    var size: CGSize
    var atbat: Atbat
    @State var showShadow1 = false
    @State var showShadow2 = false
    @State var showShadow3 = false
    @State var showShadow4 = false
    @State var showShadow5 = false
    @State var showShadow6 = false
    @State var showShadow7 = false
    @State var showShadow8 = false
    @State var showShadow9 = false
    var body: some View {
        let sz = UIDevice.type == "iPhone" ? 32.5: 45.0
        let phone = UIDevice.type == "iPhone" ? true : false
        Button("\n\n\nLeft") {
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-F7" : atbat.result == "Line Out" ? "-L7" : "-7"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "F7" : atbat.result == "Line Out" ? "L7" : "7"
            }
        }
        .foregroundColor(showShadow7 ? .red : .black).italic().font(.caption)
        .position(x:(phone ? 0.33 :0.15) * size.width, y:(phone ? 0.59 : 0.4) * size.height)
        .shadow(color: Color.red, radius: showShadow7 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("outfielder")
                .resizable()
                .scaledToFill()
                .frame(width: sz, height: sz)
                .position(x:(phone ? 0.33 :0.15) * size.width, y:(phone ? 0.59 : 0.4) * size.height)
        }
        .onChange (of: atbat.playRec) {
            setflags()
        }
        .onAppear() {
            setflags()
        }
        Button("\n\n\nCenter") {
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-F8" : atbat.result == "Line Out" ? "-L8" : "-8"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "F8" : atbat.result == "Line Out" ? "L8" : "8"
            }
        }
        .foregroundColor(showShadow8 ? .red : .black).italic().font(.caption)
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
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-F9" : atbat.result == "Line Out" ? "-L9" : "-9"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "F9" : atbat.result == "Line Out" ? "L9" : "9"
            }
        }
        .foregroundColor(showShadow9 ? .red : .black).italic().font(.caption)
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
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-P5" : atbat.result == "Line Out" ? "-L5" : "-5"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "P5" : atbat.result == "Line Out" ? "L5": "5"
            }
        }
        .foregroundColor(showShadow5 ? .red : .black).italic().font(.caption)
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
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-P6" : atbat.result == "Line Out" ? "-L6" : "-6"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "P6" : atbat.result == "Line Out" ? "L6" : "6"
            }
        }
        .foregroundColor(showShadow6 ? .red : .black).italic().font(.caption)
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
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-P4" : atbat.result == "Line Out" ? "-L4" : "-4"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "P4" : atbat.result == "Line Out" ? "L4" : "4"
            }
        }
        .foregroundColor(showShadow4 ? .red : .black).bold().italic().font(.caption)
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
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-P3" : atbat.result == "Line Out" ? "-L3" : "-3"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "P3" : atbat.result == "Line Out" ? "L3" : "3"
            }        }
        .foregroundColor(showShadow3 ? .red : .black).italic().font(.caption)
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
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-P1" : atbat.result == "Line Out" ? "-L1" : "-1"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "P1" : atbat.result == "Line Out" ? "L1" : "1"
            }
        }
        .foregroundColor(showShadow1 ? .red : .black).italic().font(.caption)
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
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-P2" : atbat.result == "Line Out" ? "-L2" : "-2"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "P2" : atbat.result == "Line Out" ? "L2" : "2"
            }
        }
        .foregroundColor(showShadow2 ? .red : .black).bold().italic().font(.caption)
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
        showShadow1 = atbat.playRec.contains("1") ? true : false
        showShadow2 = atbat.playRec.contains("2") ? true : false
        showShadow3 = atbat.playRec.contains("3") ? true : false
        showShadow4 = atbat.playRec.contains("4") ? true : false
        showShadow5 = atbat.playRec.contains("5") ? true : false
        showShadow6 = atbat.playRec.contains("6") ? true : false
        showShadow7 = atbat.playRec.contains("7") ? true : false
        showShadow8 = atbat.playRec.contains("8") ? true : false
        showShadow9 = atbat.playRec.contains("9") ? true : false

    }
}
