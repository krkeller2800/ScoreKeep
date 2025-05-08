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
        if atbat.outAt != "Safe" && atbat.outAt != "Not Out" {
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
//        let outabs:[String] = ["", "GO", "FO", "K","FC","ꓘ","SAC"]
        Text(abb).position(x: 0.5 * size.width, y: 0.60 * size.height).font(.system(size: 125))
        if !com.outabs.contains(abb) {
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                myPath.addLine(to: CGPoint(x: 0.90 * size.width, y: 0.60 * size.height))
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
        
        Text(abb).position(x: 0.5 * size.width, y: 0.60 * size.height).font(.system(size: 125))
        Path() {
            myPath in
            myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
            myPath.addLine(to: CGPoint(x: 0.90 * size.width, y: 0.60 * size.height))
            myPath.addLine(to: CGPoint(x: size.width/2, y: 0.33 * size.height))
        }
        .stroke(Color.indigo, lineWidth: 5)
    }
}
struct drawTriple: View {
    var size: CGSize
    var atbat:Atbat
    var abb:String
    var body: some View {
        
        Text(abb).position(x: 0.5 * size.width, y: 0.60 * size.height).font(.system(size: 125))
        Path() {
            myPath in
            myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
            myPath.addLine(to: CGPoint(x: 0.90 * size.width, y: 0.60 * size.height))
            myPath.addLine(to: CGPoint(x: size.width/2, y: 0.33 * size.height))
            myPath.addLine(to: CGPoint(x: 0.10 * size.width, y: 0.60 * size.height))
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
            myPath.addLine(to: CGPoint(x: 0.90 * size.width, y: 0.60 * size.height))
            myPath.addLine(to: CGPoint(x: size.width/2, y: 0.33 * size.height))
            myPath.addLine(to: CGPoint(x: 0.10 * size.width, y: 0.60 * size.height))
            myPath.addLine(to: CGPoint(x: 0.50 * size.width, y: 0.90 * size.height))
        }
        .fill(Color.black)
        Text(abb).position(x: 0.5 * size.width, y: 0.60 * size.height).font(.system(size: 125)).foregroundColor(.white)

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
                myPath.addLine(to: CGPoint(x: 0.90 * size.width, y: 0.60 * size.height))
                myPath.addLine(to: CGPoint(x: size.width/2, y: 0.33 * size.height))
                myPath.addLine(to: CGPoint(x: 0.10 * size.width, y: 0.60 * size.height))
                myPath.addLine(to: CGPoint(x: 0.50 * size.width, y: 0.90 * size.height))
            }
            .fill(Color.black)
            Text(abb).position(x: 0.5 * size.width, y: 0.60 * size.height).font(.system(size: 125)).foregroundColor(.white)
        } else {
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                myPath.addLine(to: CGPoint(x: 0.90 * size.width, y: 0.60 * size.height))
                if atbat.maxbase == "Second" || atbat.maxbase == "Third" {
                    myPath.addLine(to: CGPoint(x: size.width/2, y: 0.33 * size.height))
                    if atbat.maxbase == "Third" {
                        myPath.addLine(to: CGPoint(x: 0.10 * size.width, y: 0.60 * size.height))
                    }
                }
            }
            .stroke(Color.indigo, lineWidth: 5)
            Text(abb).position(x: 0.5 * size.width, y: 0.60 * size.height).font(.system(size: 125))
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
            myPath.addLine(to: CGPoint(x: 0.90 * size.width, y: 0.60 * size.height))
            myPath.addLine(to: CGPoint(x: size.width/2, y: 0.33 * size.height))
            myPath.addLine(to: CGPoint(x: 0.10 * size.width, y: 0.60 * size.height))
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
                myPath.addLine(to: CGPoint(x: 0.90 * size.width, y: 0.60 * size.height))
                myPath.addLine(to: CGPoint(x: size.width/2, y: 0.33 * size.height))
                myPath.addLine(to: CGPoint(x: 0.10 * size.width, y: 0.60 * size.height))
                myPath.addLine(to: CGPoint(x: 0.50 * size.width, y: 0.90 * size.height))
            }
            .stroke(Color.indigo, lineWidth: 5)
            Text("X").position(x: 0.50 * size.width, y: 0.90 * size.height).font(.system(size: 35, weight: .bold))
            
            
        } else {
            Path() {
                myPath in
                myPath.move(to: CGPoint(x: size.width/2, y: 0.90 * size.height))
                myPath.addLine(to: CGPoint(x: 0.90 * size.width, y: 0.60 * size.height))
                if atbat.outAt == "Second" || atbat.outAt == "Third" {
                    myPath.addLine(to: CGPoint(x: size.width/2, y: 0.33 * size.height))
                    if atbat.outAt == "Third" {
                        myPath.addLine(to: CGPoint(x: 0.10 * size.width, y: 0.60 * size.height))
                    }
                }
            }
            .stroke(Color.indigo, lineWidth: 5)
            if atbat.outAt == "First" {
                Text("X").position(x: 0.90 * size.width, y: 0.60 * size.height).font(.system(size: 35, weight: .bold))
            } else if atbat.outAt == "Second" {
                Text("X").position(x: size.width/2, y: 0.33 * size.height).font(.system(size:35, weight: .bold))
            } else if atbat.outAt == "Third" {
                Text("X").position(x: 0.10 * size.width, y: 0.60 * size.height).font(.system(size: 35, weight: .bold))
            }
        }
    }
}
