import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct StoryboardDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.cinemaStoryboard] }
    static var writableContentTypes: [UTType] { [.cinemaStoryboard] }

    var project: StoryboardProject
    var imageData: [String: Data]

    init(project: StoryboardProject = StoryboardProject(), imageData: [String: Data] = [:]) {
        self.project = project
        self.imageData = imageData
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

        if let imageWrappers = wrappers["Images"]?.fileWrappers {
            for (name, wrapper) in imageWrappers {
                if let data = wrapper.regularFileContents {
                    imageData["Images/\(name)"] = data
                }
            }
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

        var imageWrappers: [String: FileWrapper] = [:]
        for (fileName, data) in imageData {
            let imageName = fileName.replacingOccurrences(of: "Images/", with: "")
            imageWrappers[imageName] = FileWrapper(regularFileWithContents: data)
        }
        let imageDirectory = FileWrapper(directoryWithFileWrappers: imageWrappers)
        imageDirectory.preferredFilename = "Images"
        root.addFileWrapper(imageDirectory)

        return root
    }

    mutating func renumberCuts() {
        for index in project.cuts.indices {
            project.cuts[index].cutNumber = index + 1
        }
    }
}
