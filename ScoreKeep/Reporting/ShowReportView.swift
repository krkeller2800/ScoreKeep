//
//  ShowReportView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/16/25.
//

import SwiftUI
import PDFKit
import SwiftData

//@MainActor
struct ShowReportView: View {
                    var teamName:String
    @State private var pdfURL: URL?
    @Environment(\.modelContext) var modelContext
    var body: some View {
        VStack{
            
            ReportView(teamName: teamName)
            
            Button("Generate PDF") {
                pdfURL = render()
            }
            .padding()
            if let pdfURL = pdfURL {
                ShareLink("Export PDF", item: pdfURL)
            }
        }
    }
    func render() -> URL {

        let renderer = ImageRenderer(content:
            ReportView(teamName: teamName, )
            .frame(width: 1100,height: 850, alignment: .topLeading)
            .modelContext(modelContext)
       )
        
        // 2: Save it to our documents directory
        let url = URL.documentsDirectory.appending(path: "stats.pdf")
        
        // 3: Start the rendering process
        renderer.render { size, context in
            // 4: Tell SwiftUI our PDF should be the same size as the views we're rendering
            var box = CGRect(x: 0, y: 0, width: 1100, height: 850)
            
            // 5: Create the CGContext for our PDF pages
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else {
                return
            }

            
            // 6: Start a new PDF page
            pdf.beginPDFPage(nil)

            // 7: Render the SwiftUI view data onto the page
            context(pdf)
            
            // 8: End the page and close the file
            pdf.endPDFPage()
            pdf.closePDF()
        }
        
        return url
    }
}
