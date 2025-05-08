//
//  PasteView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/8/25.
//

import SwiftUI

struct PasteView: View {
    @State private var pastedText: String = ""
    
    
    var body: some View {
        HStack {
            PasteButton(payloadType: String.self) { strings in
                pastedText = strings[0]
            }
            Divider()
            Text(pastedText)
            Spacer()
        }
    }
}

#Preview {
    PasteView()
}
