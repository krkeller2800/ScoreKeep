//
//  DownloadFiles.swift
//  ScoreKeep
//
//  Created by Karl Keller on 8/20/25.
//

import Foundation

class DownloadFiles {
  
    func fetchFileList(from url: URL, completion: @escaping ([String]?, Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "FileListError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            if let decodedString = String(data: data, encoding: .utf8) {
                let fileNames = decodedString.components(separatedBy: "Teams/")
                completion(fileNames, nil)
            } else {
                print("Failed to decode data into a string.")
            }
            // Decode the data based on its format (e.g., JSON)
//            do {
//                let fileNames = try JSONDecoder().decode([String].self, from: data) // Assuming a simple array of strings
//                completion(fileNames, nil)
//            } catch {
//                completion(nil, error)
//            }
        }
        task.resume()
    }
    
    // Example usage:
    // if let listURL = URL(string: "https://example.com/api/filelist") {
    //     fetchFileList(from: listURL) { fileNames, error in
    //         if let fileNames = fileNames {
    //             print("Files available: \(fileNames)")
    //         } else if let error = error {
    //             print("Error fetching file list: \(error.localizedDescription)")
    //         }
    //     }
    // }
    func downloadFile(from urlString: String, to destinationFileName: String) async throws {
        let fileManager = FileManager.default
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        // Initiate the download
        let (downloadURL, _) = try await URLSession.shared.download(from: url)

        // Define the destination URL in a permanent location (e.g., Documents directory)
        let documentsDirectory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let destinationURL = documentsDirectory.appendingPathComponent(destinationFileName)
        if fileManager.fileExists(atPath: destinationURL.path) {
            // If it exists, remove it to allow overwriting
            try fileManager.removeItem(at: destinationURL)
//            print("Existing file at destination removed.")
        }
        // Move the downloaded file from its temporary location to the permanent destination
        try fileManager.moveItem(at: downloadURL, to: destinationURL)
//        print("File downloaded successfully to: \(destinationURL.path)")
    }
}
