import Foundation

struct CinemaResultBundleManifest: Codable, Equatable {
    static let format = "cinema.result-bundle"
    static let schemaVersion = "1.0.0"

    var format: String
    var schemaVersion: String
    var sourceBundleID: UUID
    var sourceProjectTitle: String
    var sceneTitle: String
    var sceneKey: String
    var runner: String
    var modelRevision: String
    var effectiveParameters: [String: String]
    var warnings: [String]
    var generatedAt: Date
    var outputs: [CinemaResultOutput]
}

struct CinemaResultOutput: Codable, Equatable {
    enum MediaType: String, Codable {
        case image
        case video
    }

    var cutID: StoryboardCut.ID
    var mediaType: MediaType
    var path: String
    var warnings: [String]
}

struct CinemaResultImportSummary: Equatable {
    var imageCount: Int
    var videoCount: Int
    var warningCount: Int
    var sceneTitle: String
}

enum CinemaResultBundleImporter {
    enum ImportError: LocalizedError {
        case manifestMissing
        case unsupportedFormat
        case unsupportedVersion(String)
        case alreadyImported
        case noOutputs
        case unknownCut(UUID)
        case unsafePath(String)
        case missingMedia(String)
        case documentMustBeSaved

        var errorDescription: String? {
            switch self {
            case .manifestMissing: "Result Bundle manifest.json was not found."
            case .unsupportedFormat: "This folder is not a Cinema Result Bundle."
            case .unsupportedVersion(let version): "Result Bundle version \(version) is not supported."
            case .alreadyImported: "This Result Bundle has already been imported."
            case .noOutputs: "The Result Bundle contains no output media."
            case .unknownCut(let id): "The Result Bundle references an unknown cut: \(id.uuidString)."
            case .unsafePath(let path): "The Result Bundle contains an unsafe media path: \(path)."
            case .missingMedia(let path): "Result media is missing: \(path)."
            case .documentMustBeSaved: "Save the Cinema document before importing video results."
            }
        }
    }

    static func importBundle(
        at bundleURL: URL,
        into document: inout StoryboardDocument,
        documentURL: URL?,
        fileManager: FileManager = .default,
        importedAt: Date = Date()
    ) throws -> CinemaResultImportSummary {
        let manifestURL = bundleURL.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else { throw ImportError.manifestMissing }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(CinemaResultBundleManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.format == CinemaResultBundleManifest.format else { throw ImportError.unsupportedFormat }
        guard manifest.schemaVersion == CinemaResultBundleManifest.schemaVersion else {
            throw ImportError.unsupportedVersion(manifest.schemaVersion)
        }
        guard !document.project.importedGenerationResults.contains(where: { $0.sourceBundleID == manifest.sourceBundleID }) else {
            throw ImportError.alreadyImported
        }
        guard !manifest.outputs.isEmpty else { throw ImportError.noOutputs }

        var imagePayloads: [(cutIndex: Int, path: String, data: Data)] = []
        var videoPayloads: [(cutIndex: Int, output: CinemaResultOutput, sourceURL: URL)] = []
        for output in manifest.outputs {
            guard let cutIndex = document.project.cuts.firstIndex(where: { $0.id == output.cutID }) else {
                throw ImportError.unknownCut(output.cutID)
            }
            let sourceURL = try safeAssetURL(for: output.path, in: bundleURL)
            guard fileManager.fileExists(atPath: sourceURL.path) else { throw ImportError.missingMedia(output.path) }
            switch output.mediaType {
            case .image:
                let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension.lowercased()
                imagePayloads.append((cutIndex, "Images/Imported/\(UUID().uuidString).\(ext)", try Data(contentsOf: sourceURL)))
            case .video:
                videoPayloads.append((cutIndex, output, sourceURL))
            }
        }

        if !videoPayloads.isEmpty && documentURL == nil { throw ImportError.documentMustBeSaved }
        var importedVideos: [GeneratedCutVideo] = []
        if let documentURL, !videoPayloads.isEmpty {
            let relativeDirectory = "imports/\(manifest.sourceBundleID.uuidString)"
            let moviesURL = documentURL.deletingLastPathComponent().appendingPathComponent("movies", isDirectory: true)
            let destinationDirectory = moviesURL.appendingPathComponent(relativeDirectory, isDirectory: true)
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            for payload in videoPayloads {
                let ext = payload.sourceURL.pathExtension.isEmpty ? "mp4" : payload.sourceURL.pathExtension.lowercased()
                let fileName = "\(payload.output.cutID.uuidString)-\(UUID().uuidString).\(ext)"
                let destinationURL = destinationDirectory.appendingPathComponent(fileName)
                try fileManager.copyItem(at: payload.sourceURL, to: destinationURL)
                importedVideos.append(GeneratedCutVideo(
                    sceneTitle: manifest.sceneTitle,
                    cutID: payload.output.cutID,
                    videoFileName: "\(relativeDirectory)/\(fileName)",
                    generatedAt: manifest.generatedAt
                ))
            }
        }

        for payload in imagePayloads {
            document.imageData[payload.path] = payload.data
            document.project.cuts[payload.cutIndex].imageFileName = payload.path
        }
        document.project.generatedCutVideos.append(contentsOf: importedVideos)
        let outputWarnings = manifest.outputs.flatMap(\.warnings)
        document.project.importedGenerationResults.append(ImportedGenerationResult(
            sourceBundleID: manifest.sourceBundleID,
            sceneTitle: manifest.sceneTitle,
            runner: manifest.runner,
            modelRevision: manifest.modelRevision,
            effectiveParameters: manifest.effectiveParameters,
            warnings: manifest.warnings + outputWarnings,
            importedAt: importedAt
        ))

        return CinemaResultImportSummary(
            imageCount: imagePayloads.count,
            videoCount: importedVideos.count,
            warningCount: manifest.warnings.count + outputWarnings.count,
            sceneTitle: manifest.sceneTitle
        )
    }

    private static func safeAssetURL(for relativePath: String, in bundleURL: URL) throws -> URL {
        let path = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
            throw ImportError.unsafePath(relativePath)
        }
        let root = bundleURL.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = root.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
        guard candidate.path.hasPrefix(root.path + "/") else { throw ImportError.unsafePath(relativePath) }
        return candidate
    }
}
