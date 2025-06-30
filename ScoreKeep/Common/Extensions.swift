//
//  Extensions.swift
//  ScoreKeep
//
//  Created by Karl Keller on 6/12/25.
//

import Foundation
import UIKit
import SwiftUI
import SwiftData

extension Image {
    func scaleImage(iHeight: Double, imageData: Data) -> some View {
        let uiImage = UIImage(data: imageData)!
        
        var size = uiImage.size
        let ratio = iHeight / size.height
        size = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        return self
            .resizable()
            .frame(width: size.width, height: size.height)
    }
}
extension UIScreen{
   static let screenWidth = UIScreen.main.bounds.size.width
   static let screenHeight = UIScreen.main.bounds.size.height
   static let screenSize = UIScreen.main.bounds.size
}
extension ModelContext {
    var sqliteCommand: String {
        if let url = container.configurations.first?.url.path(percentEncoded: false) {
            "sqlite3 \"\(url)\""
        } else {
            "No SQLite database found."
        }
    }
}
extension String {
    func removeAccents() -> String {
        // Normalize the string to decomposed form (NFD)
        let normalizedString = self.folding(options: .diacriticInsensitive, locale: .current)
        
        return normalizedString
    }
}
