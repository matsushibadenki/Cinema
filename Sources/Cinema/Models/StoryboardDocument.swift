import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct StoryboardDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.cinemaStoryboard] }
    static var writableContentTypes: [UTType] { [.cinemaStoryboard] }

    var project: StoryboardProject
    var imageData: [String: Data]
    var videoData: [String: Data]

    init(project: StoryboardProject = StoryboardProject(), imageData: [String: Data] = [:], videoData: [String: Data] = [:]) {
        self.project = project
        self.imageData = imageData
        self.videoData = videoData
    }

    init(configuration: ReadConfiguration) throws {
        guard configuration.file.isDirectory else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let wrappers = configuration.file.fileWrappers ?? [:]
        guard let jsonWrapper = wrappers["storyboard.json"],
              jsonWrapper.isRegularFile,
              let jsonData = jsonWrapper.regularFileContents else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        project = try JSONDecoder().decode(StoryboardProject.self, from: jsonData)
        imageData = [:]
        videoData = [:]

        if let imageWrapper = wrappers["Images"] {
            imageData = StoryboardDocument.readData(from: imageWrapper, prefix: "Images")
        }

        if let videoWrapper = wrappers["Videos"] {
            videoData = StoryboardDocument.readData(from: videoWrapper, prefix: "Videos")
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try packageWrapper()
    }

    func packageWrapper() throws -> FileWrapper {
        let root = FileWrapper(directoryWithFileWrappers: [:])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(project)
        let jsonWrapper = FileWrapper(regularFileWithContents: jsonData)
        jsonWrapper.preferredFilename = "storyboard.json"
        root.addFileWrapper(jsonWrapper)

        let imageDirectory = StoryboardDocument.makeImageDirectory(from: imageData)
        imageDirectory.preferredFilename = "Images"
        root.addFileWrapper(imageDirectory)

        let videoDirectory = StoryboardDocument.makeDirectory(from: videoData, rootFolderName: "Videos")
        videoDirectory.preferredFilename = "Videos"
        root.addFileWrapper(videoDirectory)

        return root
    }

    mutating func renumberCuts() {
        project.normalizeSceneIdentities()
        for index in project.cuts.indices {
            project.cuts[index].cutNumber = index + 1
        }
    }

    /// Keep a surviving block's heading when its first cut is removed.
    mutating func deleteCuts(withIDs ids: Set<StoryboardCut.ID>) {
        var heading: StoryboardCut?
        var survivingCuts: [StoryboardCut] = []
        let removedImagePaths = Set(project.cuts.filter { ids.contains($0.id) }.compactMap(\.imageFileName))
        for var cut in project.cuts {
            if !cut.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                heading = cut
            }
            guard !ids.contains(cut.id) else { continue }
            if let blockHeading = heading {
                cut.subtitle = blockHeading.subtitle
                cut.scriptHeading = blockHeading.scriptHeading
                cut.sceneName = blockHeading.sceneName
                heading = nil
            }
            survivingCuts.append(cut)
        }
        project.cuts = survivingCuts.isEmpty ? [StoryboardCut(cutNumber: 1)] : survivingCuts
        project.generatedCutVideos.removeAll { ids.contains($0.cutID) }
        let retainedImagePaths = Set(project.cuts.compactMap(\.imageFileName) + project.referenceImages.map(\.imageFileName))
        for path in removedImagePaths.subtracting(retainedImagePaths) {
            imageData[path] = nil
        }
        renumberCuts()
    }

    static func readData(from wrapper: FileWrapper, prefix: String) -> [String: Data] {
        var dataByPath: [String: Data] = [:]
        for (name, child) in wrapper.fileWrappers ?? [:] {
            let path = "\(prefix)/\(name)"
            if child.isDirectory {
                dataByPath.merge(readData(from: child, prefix: path)) { current, _ in current }
            } else if child.isRegularFile, let data = child.regularFileContents {
                dataByPath[path] = data
            }
        }
        return dataByPath
    }

    private static func makeImageDirectory(from imageData: [String: Data]) -> FileWrapper {
        makeDirectory(from: imageData, rootFolderName: "Images")
    }

    private static func makeDirectory(from fileData: [String: Data], rootFolderName: String) -> FileWrapper {
        var rootWrappers: [String: FileWrapper] = [:]

        for (fileName, data) in fileData {
            var components = fileName.split(separator: "/").map(String.init)
            if components.first == rootFolderName {
                components.removeFirst()
            }
            guard let leafName = components.popLast() else { continue }

            insertFile(data, named: leafName, at: components, into: &rootWrappers)
        }

        return FileWrapper(directoryWithFileWrappers: rootWrappers)
    }

    private static func insertFile(_ data: Data, named leafName: String, at folders: [String], into wrappers: inout [String: FileWrapper]) {
        guard let folder = folders.first else {
            wrappers[leafName] = FileWrapper(regularFileWithContents: data)
            return
        }

        var childWrappers = wrappers[folder]?.fileWrappers ?? [:]
        insertFile(data, named: leafName, at: Array(folders.dropFirst()), into: &childWrappers)
        wrappers[folder] = FileWrapper(directoryWithFileWrappers: childWrappers)
    }
}
