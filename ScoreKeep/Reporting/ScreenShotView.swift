//
//  ScreenShotView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 7/30/25.
//

import SwiftUI
import UIKit // For UIImage
//import ScreenshotSwiftUI

struct ScreenShotView: View {
    @Environment(\.modelContext) var modelContext
    @State var showit: Bool = false
  var body: some View {
        VStack {
            ReportView(teamName: "Tigers", isLoading: $showit)
                .modelContext(modelContext)
        }
        .screenshotMaker { screenshotMaker in
            if let uiImage = screenshotMaker.screenshot() {
                UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                print("Image written to photos")
            }
        }

    }

}

#Preview {
    ScreenShotView()
}
