//
//  Buttons.swift
//  ScoreKeep
//
//  Created by Karl Keller on 4/28/25.
//
import SwiftUI
import Foundation

struct SelectButton: View {
    @Binding var isSelected: Bool
    @State var color: Color
    @State var text: String
    var body: some View {
        ZStack {
            Capsule()
                .frame (maxWidth: 300 ,maxHeight: 50)
                .foregroundColor (isSelected ? color : .gray)
            Text (text)
                .lineLimit(1).minimumScaleFactor(0.3)
                .foregroundColor(.white)
        }
    }
}

struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
//            .frame(width: bSize, height: bSize)
            .background(configuration.isPressed ? Color.blue.opacity(0.5) : Color.blue) // button's background
            .foregroundColor(.white) // text color
            .overlay(
                RoundedRectangle(cornerRadius: 12) // border shape
                    .stroke(Color.blue, lineWidth: configuration.isPressed ? 2 : 0) // line width
                    .shadow(color: .blue, radius: configuration.isPressed ? 10 : 0) // Adds a glow effect
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0) // Adjust size on press
    }
}
struct GlowButtonStyleLarge: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 300, height: 75)
            .background(configuration.isPressed ? Color.blue.opacity(0.3) : Color.white.opacity(0.2)).cornerRadius(40) // button's background
//            .foregroundColor(.white) // text color
            .overlay(
                RoundedRectangle(cornerRadius: 40) // border shape
                    .stroke(Color.blue, lineWidth: configuration.isPressed ? 2 : 1) // line width
                    .shadow(color: .white, radius: configuration.isPressed ? 10 : 1) // Adds a glow effect
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0) // Adjust size on press
    }
}
