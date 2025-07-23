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
        Text(abb).position(x: 0.5 * size.width, y: 0.62 * size.height).font(.system(size: 65))
        if !com.outabs.contains(abb) {
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                myPath.addLine(to: CGPoint(x: 0.75 * size.width, y: 0.7 * size.height))
            }
            .stroke(Color.indigo, lineWidth: 5)
        }

    }
}
struct drawDouble: View {
    var size: CGSize
    var atbat:Atbat
    var abb:String
    var body: some View {
        
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
struct drawTriple: View {
    var size: CGSize
    var atbat:Atbat
    var abb:String
    var body: some View {
        
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
struct drawHomeRun: View {
    var size: CGSize
    var atbat:Atbat
    var abb:String
    var body: some View {
        
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
struct drawRunning: View {
    var size: CGSize
    var atbat:Atbat
    var abb:String
    var body: some View {
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

struct clearLines: View {
    var size: CGSize
    var atbat:Atbat
    var abb:String
    var body: some View {
        
        Path() {
            myPath in
            myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
            myPath.addLine(to: CGPoint(x: 0.75 * size.width, y: 0.7 * size.height))
            myPath.addLine(to: CGPoint(x: size.width/2, y: 0.5 * size.height))
            myPath.addLine(to: CGPoint(x: 0.25 * size.width, y: 0.7 * size.height))
            myPath.addLine(to: CGPoint(x: 0.50 * size.width, y: 0.90 * size.height))
        }
        .stroke(Color.white,lineWidth: 6)

    }
}
struct drawoutAt: View {
    var size: CGSize
    var atbat:Atbat
    var abb:String
    var body: some View {
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
                Text("X").position(x: 0.75 * size.width, y: 0.70 * size.height).font(.system(size: 35, weight: .bold))
            } else if atbat.outAt == "Second" {
                Text("X").position(x: size.width/2, y: 0.5 * size.height).font(.system(size:35, weight: .bold))
            } else if atbat.outAt == "Third" {
                Text("X").position(x: 0.25 * size.width, y: 0.7 * size.height).font(.system(size: 35, weight: .bold))
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
        Button("\n\n\nLeft Fielder") {
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-F7" : atbat.result == "Line Out" ? "-L7" : atbat.result == "Foul Out" ? "-FO7" : "-7"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "F7" : atbat.result == "Line Out" ? "L7" : atbat.result == "Foul Out" ? "FO7" : "7"
            }
        }
        .foregroundColor(showShadow7 ? .red : .black).bold().italic().font(.caption)
        .position(x:0.15 * size.width, y:0.4 * size.height)
        .shadow(color: Color.red, radius: showShadow7 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("outfielder")
                .resizable()
                .scaledToFill()
                .frame(width: 45, height: 45)
                .position(x:0.15 * size.width, y:0.4 * size.height)
        }
        .onChange (of: atbat.playRec) {
            setflags()
        }
        .onAppear() {
            setflags()
        }
        Button("\n\n\nCenter Fielder") {
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-F8" : atbat.result == "Line Out" ? "-L8" : atbat.result == "Foul Out" ? "-FO8" : "-8"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "F8" : atbat.result == "Line Out" ? "L8" : atbat.result == "Foul Out" ? "FO8" : "8"
            }
        }
        .foregroundColor(showShadow8 ? .red : .black).bold().italic().font(.caption)
        .position(x:0.5 * size.width, y:0.35 * size.height)
        .shadow(color: Color.red, radius: showShadow8 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("outfielder")
                .resizable()
                .scaledToFill()
                .frame(width: 45, height: 45)
                .position(x:0.5 * size.width, y:0.35 * size.height)
        }
        Button("\n\n\nRight Fielder") {
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-F9" : atbat.result == "Line Out" ? "-L9" : atbat.result == "Foul Out" ? "-FO9" : "-9"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "F9" : atbat.result == "Line Out" ? "L9" : atbat.result == "Foul Out" ? "FO9" : "9"
            }
        }
        .foregroundColor(showShadow9 ? .red : .black).bold().italic().font(.caption)
        .position(x:0.85 * size.width, y:0.4 * size.height)
        .shadow(color: Color.red, radius: showShadow9 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("outfielder")
                .resizable()
                .scaledToFill()
                .frame(width: 45, height: 45)
                .position(x:0.85 * size.width, y:0.4 * size.height)
        }
        Button("\n\n\n3rd Base") {
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-P5" : atbat.result == "Line Out" ? "-L5" : atbat.result == "Foul Out" ? "-FO5" : "-5"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "P5" : atbat.result == "Line Out" ? "L5" : atbat.result == "Foul Out" ? "FO5" : "5"
            }
        }
        .foregroundColor(showShadow5 ? .red : .black).bold().italic().font(.caption)
        .position(x:0.25 * size.width, y:0.59 * size.height)
        .shadow(color: Color.red, radius: showShadow5 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("Infielder")
                .resizable()
                .scaledToFill()
                .frame(width: 45, height: 45)
                .position(x:0.25 * size.width, y:0.59 * size.height)
        }
        Button("\n\n\nShortstop") {
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-P6" : atbat.result == "Line Out" ? "-L6" : atbat.result == "Foul Out" ? "-FO6" : "-6"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "P6" : atbat.result == "Line Out" ? "L6" : atbat.result == "Foul Out" ? "FO6" : "6"
            }
        }
        .foregroundColor(showShadow6 ? .red : .black).bold().italic().font(.caption)
        .position(x:0.36 * size.width, y:0.46 * size.height)
        .shadow(color: Color.red, radius: showShadow6 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("Infielder")
                .resizable()
                .scaledToFill()
                .frame(width: 45, height: 45)
                .position(x:0.36 * size.width, y:0.46 * size.height)
        }
        Button("\n\n\n2nd Base") {
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-P4" : atbat.result == "Line Out" ? "-L4" : atbat.result == "Foul Out" ? "-FO4" : "-4"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "P4" : atbat.result == "Line Out" ? "L4" : atbat.result == "Foul Out" ? "FO4" : "4"
            }
        }
        .foregroundColor(showShadow4 ? .red : .black).bold().italic().font(.caption)
        .position(x:0.64 * size.width, y:0.46 * size.height)
        .shadow(color: Color.red, radius: showShadow4 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("Infielder")
                .resizable()
                .scaledToFill()
                .frame(width: 45, height: 45)
                .position(x:0.64 * size.width, y:0.46 * size.height)
        }
        Button("\n\n\n1st Base") {
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-P3" : atbat.result == "Line Out" ? "-L3" : atbat.result == "Foul Out" ? "-FO3" : "-3"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "P3" : atbat.result == "Line Out" ? "L3" : atbat.result == "Foul Out" ? "FO3" : "3"
            }        }
        .foregroundColor(showShadow3 ? .red : .black).bold().italic().font(.caption)
        .position(x:0.75 * size.width, y:0.59 * size.height)
        .shadow(color: Color.red, radius: showShadow3 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("Infielder")
                .resizable()
                .scaledToFill()
                .frame(width: 45, height: 45)
                .position(x:0.75 * size.width, y:0.59 * size.height)
        }
        Button("\n\n\nPitcher") {
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-P1" : atbat.result == "Line Out" ? "-L1" : atbat.result == "Foul Out" ? "-FO1" : "-1"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "P1" : atbat.result == "Line Out" ? "L1" : atbat.result == "Foul Out" ? "FO1" : "1"
            }
        }
        .foregroundColor(showShadow1 ? .red : .black).bold().italic().font(.caption)
        .position(x:0.5 * size.width, y:0.7 * size.height)
        .shadow(color: Color.red, radius: showShadow1 ? 5 : 0, x: 0, y: 0)
        .background {
            Image("pitcher")
                .resizable()
                .scaledToFill()
                .frame(width: 55, height: 55)
                .position(x:0.5 * size.width, y:0.7 * size.height)
        }
        Button("\n\nCatcher") {
            if atbat.playRec.count > 0 {
                atbat.playRec += atbat.result == "Fly Out" ? "-P2" : atbat.result == "Line Out" ? "-L2" : atbat.result == "Foul Out" ? "-FO2" : "-2"
            } else {
                atbat.playRec += atbat.result == "Fly Out" ? "P2" : atbat.result == "Line Out" ? "L2" : atbat.result == "Foul Out" ? "FO2" : "2"
            }
        }
        .foregroundColor(showShadow2 ? .red : .black).bold().italic().font(.caption)
        .position(x:0.5 * size.width, y:0.95 * size.height)
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
