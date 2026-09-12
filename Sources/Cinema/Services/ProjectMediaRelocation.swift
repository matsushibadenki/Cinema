import Foundation

/// Copy only this project's media; never move or overwrite shared source files.
enum ProjectMediaRelocation {
    enum RelocationError: LocalizedError {
        case unavailable(String)
        case conflict(String)
        var errorDescription: String? {
            switch self {
            case .unavailable(let path): "Media unavailable: \(path)"
            case .conflict(let path): "A different file already exists: \(path)"
            }
        }
    }

    static func copyMedia(for document: StoryboardDocument, from source: URL, to destination: URL) throws {
        let sourceRoot = source.deletingLastPathComponent().appendingPathComponent("movies").resolvingSymlinksInPath().standardizedFileURL
        let targetRoot = destination.deletingLastPathComponent().appendingPathComponent("movies").resolvingSymlinksInPath().standardizedFileURL
        guard sourceRoot != targetRoot else { return }
        var paths = Set(document.project.sceneVideos.map(\.videoFileName) + document.project.generatedCutVideos.map(\.videoFileName))
            .filter { document.videoData[$0] == nil }
        let journalPrefix = "generation/\(document.project.id.uuidString)"
        let journalRoot = sourceRoot.appendingPathComponent(journalPrefix)
        if let enumerator = FileManager.default.enumerator(at: journalRoot, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) {
            for case let url as URL in enumerator {
                if url.lastPathComponent.hasPrefix("staging-") {
                    enumerator.skipDescendants()
                    continue
                }
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isSymbolicLink != true else { throw RelocationError.unavailable(url.lastPathComponent) }
                if values.isRegularFile == true {
                    let resolved = url.resolvingSymlinksInPath().standardizedFileURL
                    guard resolved.path.hasPrefix(sourceRoot.path + "/") else { throw RelocationError.unavailable(url.lastPathComponent) }
                    paths.insert(String(resolved.path.dropFirst(sourceRoot.path.count + 1)))
                }
            }
        }
        // Validate the complete transfer before publishing any files.
        var transfers: [(URL, URL)] = []
        for path in paths.sorted() {
            guard let input = GeneratedVideoStorageService.fileURL(for: path, documentURL: source),
                  let output = GeneratedVideoStorageService.fileURL(for: path, documentURL: destination),
                  input.resolvingSymlinksInPath().path.hasPrefix(sourceRoot.path + "/"),
                  output.resolvingSymlinksInPath().path.hasPrefix(targetRoot.path + "/"),
                  (try? input.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                throw RelocationError.unavailable(path)
            }
            if FileManager.default.fileExists(atPath: output.path) {
                guard FileManager.default.contentsEqual(atPath: input.path, andPath: output.path) else { throw RelocationError.conflict(path) }
            } else { transfers.append((input, output)) }
        }
        for (input, output) in transfers {
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            let staging = output.deletingLastPathComponent().appendingPathComponent(".transfer-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: staging) }
            try FileManager.default.copyItem(at: input, to: staging)
            try FileManager.default.moveItem(at: staging, to: output)
        }
    }
}
