import Foundation

enum GeneratedVideoStorageService {
    enum StorageError: LocalizedError {
        case documentMustBeSaved
        case invalidStoredPath

        var errorDescription: String? {
            switch self {
            case .documentMustBeSaved: "Save the document before storing generated video."
            case .invalidStoredPath: "The stored video path is invalid."
            }
        }
    }

    static func fileURL(for storedPath: String, documentURL: URL?) -> URL? {
        guard let documentURL else { return nil }
        let path = storedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else { return nil }
        let root = documentURL.deletingLastPathComponent().appendingPathComponent("movies", isDirectory: true).standardizedFileURL
        let candidate = root.appendingPathComponent(path).standardizedFileURL
        return candidate.path.hasPrefix(root.path + "/") ? candidate : nil
    }

    static func persist(
        sceneTitle: String,
        cuts: [StoryboardCut],
        clips: [Data],
        combinedVideoData: Data,
        generatedAt: Date,
        documentURL: URL?,
        fileManager: FileManager = .default
    ) throws -> (sceneVideoPath: String, cutVideos: [GeneratedCutVideo]) {
        guard let documentURL else { throw StorageError.documentMustBeSaved }
        let moviesURL = documentURL.deletingLastPathComponent().appendingPathComponent("movies", isDirectory: true)
        try fileManager.createDirectory(at: moviesURL, withIntermediateDirectories: true)
        let sceneFolder = safeComponent(sceneTitle, fallback: "scene")
        let sceneDirectory = moviesURL.appendingPathComponent(sceneFolder, isDirectory: true)
        try fileManager.createDirectory(at: sceneDirectory, withIntermediateDirectories: true)
        let timestamp = timestampComponent(generatedAt)
        var cutVideos: [GeneratedCutVideo] = []

        for (cut, clip) in zip(cuts, clips) {
            let fileName = "cut-\(String(format: "%03d", cut.cutNumber))-\(timestamp)-\(UUID().uuidString).mp4"
            try clip.write(to: sceneDirectory.appendingPathComponent(fileName), options: .atomic)
            cutVideos.append(GeneratedCutVideo(
                sceneTitle: sceneTitle,
                cutID: cut.id,
                videoFileName: "\(sceneFolder)/\(fileName)",
                generatedAt: generatedAt
            ))
        }

        let sceneFile = "scene-\(timestamp)-\(UUID().uuidString).mp4"
        try combinedVideoData.write(to: sceneDirectory.appendingPathComponent(sceneFile), options: .atomic)
        return ("\(sceneFolder)/\(sceneFile)", cutVideos)
    }

    private static func safeComponent(_ value: String, fallback: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let sanitized = value.components(separatedBy: invalid).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? fallback : sanitized
    }

    private static func timestampComponent(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
