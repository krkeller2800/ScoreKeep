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
struct ToolBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(3)
            .foregroundStyle(.tint)
            .background(configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue.opacity(0.075), in: Capsule())
//            .background(configuration.isPressed ? Color.blue.opacity(0.5) : Color.blue)
//            .foregroundColor(.white)
//            .cornerRadius(8)
    }
}
struct UniversalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        // Use #available to determine the appropriate view to return
        if #available(iOS 26.0, *) {
            return AnyView(
                iOS26Button(configuration: configuration)
            )
        } else {
            return AnyView(
                iOS18Button(configuration: configuration)
            )
        }
    }
    
    // Private helper for the iOS 26+ style
    private struct iOS26Button: View {
        let configuration: UniversalButtonStyle.Configuration
        
        var body: some View {
            configuration.label
                .padding()
                .background(
                    // New iOS 26 liquid glass background
                    ContainerRelativeShape()
                        .fill(.regularMaterial)
                        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                        .animation(.spring(), value: configuration.isPressed)
                )
                .foregroundStyle(.primary)
                .clipShape(ContainerRelativeShape())
                .frame(maxWidth: .infinity)
//                .tint(.blue.opacity(0.075))
        }
    }
    // Private helper for the iOS 18 style
    private struct iOS18Button: View {
        let configuration: UniversalButtonStyle.Configuration
        
        var body: some View {
            configuration.label
                .padding(3)
                .background(
                    Capsule()
                        .fill(Color.blue)
                        .opacity(configuration.isPressed ? 0.5 : 0.075)
                )
                .foregroundStyle(.blue)
        }
    }
}
