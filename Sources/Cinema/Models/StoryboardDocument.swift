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
        guard let jsonData = wrappers["storyboard.json"]?.regularFileContents else {
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
        for index in project.cuts.indices {
            project.cuts[index].cutNumber = index + 1
        }
    }

    private static func readData(from wrapper: FileWrapper, prefix: String) -> [String: Data] {
        var dataByPath: [String: Data] = [:]
        for (name, child) in wrapper.fileWrappers ?? [:] {
            let path = "\(prefix)/\(name)"
            if let data = child.regularFileContents {
                dataByPath[path] = data
            } else if child.isDirectory {
                dataByPath.merge(readData(from: child, prefix: path)) { current, _ in current }
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
