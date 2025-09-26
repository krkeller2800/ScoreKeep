//
//  PdfView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/19/25.
//

import SwiftUI
import PDFKit

struct PdfView: View {

    @State private var isExpanded = false
    var compileDate:Date
    {
        let bundleName = Bundle.main.infoDictionary!["CFBundleName"] as? String ?? "Info.plist"
        if let infoPath = Bundle.main.path(forResource: bundleName, ofType: nil),
           let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
           let infoDate = infoAttr[FileAttributeKey.creationDate] as? Date
        { return infoDate }
        return Date()
    }
    let url = Bundle.main.url(forResource: "Manual", withExtension: "pdf")!

    var body: some View {
        VStack {
            PDFKitView(url:  url)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("ScoreKeep")
                    .font(.title)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let fileURL = Bundle.main.url(forResource: "Manual", withExtension: "pdf") {
                    ShareLink("Share PDF", item: fileURL.absoluteString)
                }
            }
            ToolbarItemGroup(placement: .topBarLeading) {
                if #available(iOS 26.0, *) {
                    Button {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    } label: {
                        if isExpanded {
                            Text("Compiled on " + compileDate.formatted(date: .abbreviated, time: .shortened))
                                .frame(maxWidth: .infinity).font(.caption2).foregroundColor(.black).italic()
                        } else {
                            Text("Compile Date").frame(maxWidth: .infinity).foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.blue.opacity(0.075))
                } else {
                    Button {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    } label: {
                        if isExpanded {
                            Text("Compiled on " + compileDate.formatted(date: .abbreviated, time: .shortened))
                                .frame(width: 240).font(.caption2).foregroundColor(.black).italic()
                        } else {
                            Text("Compile Date").frame(maxWidth: 115).foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(ToolBarButtonStyle())
                }
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
