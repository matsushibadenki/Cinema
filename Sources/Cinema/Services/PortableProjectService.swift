import Foundation

/// Produces an independent document whose referenced videos are all embedded.
enum PortableProjectService {
    enum ExportError: Error {
        case unavailableVideo(String)
    }

    static func prepare(_ source: StoryboardDocument, documentURL: URL?) throws -> StoryboardDocument {
        var copy = source
        if let documentURL {
            let report = VideoGenerationRecovery.scan(projectID: source.project.id, documentURL: documentURL)
            VideoGenerationRecovery.restore(report, into: &copy.project)
        }
        let paths = Set(copy.project.sceneVideos.map(\.videoFileName) + copy.project.generatedCutVideos.map(\.videoFileName))
        var replacements: [String: String] = [:]
        for path in paths.sorted() {
            let data: Data
            if let embedded = copy.videoData[path], !embedded.isEmpty {
                data = embedded
            } else {
                guard let url = GeneratedVideoStorageService.fileURL(for: path, documentURL: documentURL),
                      let documentURL else { throw ExportError.unavailableVideo(path) }
                let root = documentURL.deletingLastPathComponent().appendingPathComponent("movies")
                    .resolvingSymlinksInPath().standardizedFileURL
                let resolved = url.resolvingSymlinksInPath().standardizedFileURL
                guard resolved.path.hasPrefix(root.path + "/"),
                      let values = try? resolved.resourceValues(forKeys: [.isRegularFileKey]),
                      values.isRegularFile == true,
                      let bytes = try? Data(contentsOf: resolved), !bytes.isEmpty else {
                    throw ExportError.unavailableVideo(path)
                }
                data = bytes
            }
            let embeddedPath = "Videos/\(UUID().uuidString).mp4"
            copy.videoData[embeddedPath] = data
            replacements[path] = embeddedPath
        }
        for index in copy.project.sceneVideos.indices {
            let old = copy.project.sceneVideos[index].videoFileName
            copy.project.sceneVideos[index].videoFileName = replacements[old] ?? old
        }
        for index in copy.project.generatedCutVideos.indices {
            let old = copy.project.generatedCutVideos[index].videoFileName
            copy.project.generatedCutVideos[index].videoFileName = replacements[old] ?? old
        }
        // The copy must not recover future runs belonging to the original project.
        copy.project.id = UUID()
        copy.videoData = copy.videoData.filter { Set(replacements.values).contains($0.key) }
        return copy
    }
}
