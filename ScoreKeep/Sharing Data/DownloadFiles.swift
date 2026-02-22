//
//  DownloadFiles.swift
//  ScoreKeep
//
//  Created by Karl Keller on 8/20/25.
//

import Foundation

class DownloadFiles {
  
    // MARK: - JSON models for komakode.com/Teams/index.json
    private struct TeamsIndex: Decodable {
        let updated: String?
        let divisions: [IndexDivision]
    }
    private struct IndexDivision: Decodable {
        let name: String
        let teams: [IndexTeam]
    }
    private struct IndexTeam: Decodable {
        let name: String
        let url: String
    }
  
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
    
    func fetchTeamsIndex(from url: URL, completion: @escaping ([(name: String, url: String)]?, Error?) -> Void) {
        // Use a session that waits for connectivity to avoid failing immediately on first launch
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        let session = URLSession(configuration: config)

        func isTransient(_ error: URLError) -> Bool {
            switch error.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }

        func perform(attempt: Int) {
            let task = session.dataTask(with: url) { data, response, error in
                if let urlError = error as? URLError, attempt < 2, isTransient(urlError) {
                    // Retry transient network failures with a small backoff
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) {
                        perform(attempt: attempt + 1)
                    }
                    return
                } else if let error = error {
                    completion(nil, error)
                    return
                }

                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    completion(nil, URLError(.badServerResponse))
                    return
                }

                guard let data = data else {
                    completion(nil, URLError(.unknown))
                    return
                }

                do {
                    let decoder = JSONDecoder()
                    let index = try decoder.decode(TeamsIndex.self, from: data)
                    let pairs: [(name: String, url: String)] = index.divisions.flatMap { division in
                        division.teams.map { (name: $0.name, url: $0.url) }
                    }
                    completion(pairs, nil)
                } catch {
                    completion(nil, error)
                }
            }
            task.resume()
        }

        perform(attempt: 0)
    }
    
    func downloadFile(from urlString: String, to destinationFileName: String) async throws {
        let fileManager = FileManager.default
        // Ensure spaces and other path characters are percent-encoded
        let safeURLString = urlString.replacingOccurrences(of: " ", with: "%20")
        guard let url = URL(string: safeURLString) else {
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

