//
//  PdfView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/19/25.
//

import SwiftUI
import PDFKit

struct PdfView: View {
    
    let url = Bundle.main.url(forResource: "Manual", withExtension: "pdf")!

    var body: some View {
        VStack {
            PDFKitView(url:  url)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("ScoreKeep")
                    .font(.title2)
            }

        }
    }
    struct PDFKitView: UIViewRepresentable {
        
        let url: URL
        
        func makeUIView(context: Context) -> PDFView {
            let pdfView = PDFView()
            pdfView.document = PDFDocument(url: self.url)
            pdfView.autoScales = true

            return pdfView
        }
        
        func updateUIView(_ pdfView: PDFView, context: Context) {
            // Update pdf if needed
        }
    }
}

#Preview {
    PdfView()
}
