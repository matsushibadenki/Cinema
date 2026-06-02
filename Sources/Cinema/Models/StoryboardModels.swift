import Foundation

struct StoryboardProject: Codable, Equatable {
    var title: String
    var documentPrompt: String
    var referenceImages: [ReferenceImage]
    var sceneVideos: [SceneVideo]
    var cuts: [StoryboardCut]

    init(
        title: String = "Untitled Storyboard",
        documentPrompt: String = "",
        referenceImages: [ReferenceImage] = [],
        sceneVideos: [SceneVideo] = [],
        cuts: [StoryboardCut] = StoryboardProject.defaultCuts()
    ) {
        self.title = title
        self.documentPrompt = documentPrompt
        self.referenceImages = referenceImages
        self.sceneVideos = sceneVideos
        self.cuts = cuts
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case documentPrompt
        case referenceImages
        case sceneVideos
        case cuts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        documentPrompt = try container.decodeIfPresent(String.self, forKey: .documentPrompt) ?? ""
        referenceImages = try container.decodeIfPresent([ReferenceImage].self, forKey: .referenceImages) ?? []
        sceneVideos = try container.decodeIfPresent([SceneVideo].self, forKey: .sceneVideos) ?? []
        cuts = try container.decode([StoryboardCut].self, forKey: .cuts)
    }

    static func defaultCuts() -> [StoryboardCut] {
        (1...5).map { index in
            StoryboardCut(cutNumber: index)
        }
    }
}

struct ReferenceImage: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var imageFileName: String

    init(id: UUID = UUID(), name: String, imageFileName: String) {
        self.id = id
        self.name = name
        self.imageFileName = imageFileName
    }
}

struct SceneVideo: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var videoFileName: String
    var generatedAt: Date

    init(id: UUID = UUID(), title: String, videoFileName: String, generatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.videoFileName = videoFileName
        self.generatedAt = generatedAt
    }
}

struct DialogueLine: Codable, Identifiable, Equatable {
    var id: UUID
    var speaker: String
    var dialogue: String

    init(id: UUID = UUID(), speaker: String = "", dialogue: String = "") {
        self.id = id
        self.speaker = speaker
        self.dialogue = dialogue
    }
}

struct StoryboardCut: Codable, Identifiable, Equatable {
    var id: UUID
    var cutNumber: Int
    var cutName: String
    var situation: String
    var action: String
    var dialogueLines: [DialogueLine]
    var duration: String
    var imageFileName: String?
    var generationPrompt: String
    var textSplitRatio: Double
    var dialogueSpeakerRatio: Double
    var subtitle: String
    var scriptHeading: String
    var sceneName: String

    init(
        id: UUID = UUID(),
        cutNumber: Int,
        cutName: String = "",
        situation: String = "",
        action: String = "",
        dialogueLines: [DialogueLine] = [DialogueLine()],
        duration: String = "",
        imageFileName: String? = nil,
        generationPrompt: String = "",
        textSplitRatio: Double = 0.34,
        dialogueSpeakerRatio: Double = 0.28,
        subtitle: String = "",
        scriptHeading: String = "",
        sceneName: String = ""
    ) {
        self.id = id
        self.cutNumber = cutNumber
        self.cutName = cutName
        self.situation = situation
        self.action = action
        self.dialogueLines = dialogueLines
        self.duration = duration
        self.imageFileName = imageFileName
        self.generationPrompt = generationPrompt
        self.textSplitRatio = textSplitRatio
        self.dialogueSpeakerRatio = dialogueSpeakerRatio
        self.subtitle = subtitle
        self.scriptHeading = scriptHeading
        self.sceneName = sceneName
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case cutNumber
        case cutName
        case situation
        case action
        case dialogueLines
        case duration
        case imageFileName
        case generationPrompt
        case textSplitRatio
        case dialogueSpeakerRatio
        case subtitle
        case scriptHeading
        case sceneName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        cutNumber = try container.decode(Int.self, forKey: .cutNumber)
        cutName = try container.decodeIfPresent(String.self, forKey: .cutName) ?? ""
        situation = try container.decode(String.self, forKey: .situation)
        let decodedAction = try container.decode(String.self, forKey: .action)
        action = decodedAction
        dialogueLines = try container.decodeIfPresent([DialogueLine].self, forKey: .dialogueLines)
            ?? (decodedAction.isEmpty ? [DialogueLine()] : [DialogueLine(dialogue: decodedAction)])
        duration = try container.decode(String.self, forKey: .duration)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        generationPrompt = try container.decodeIfPresent(String.self, forKey: .generationPrompt) ?? ""
        textSplitRatio = try container.decodeIfPresent(Double.self, forKey: .textSplitRatio) ?? 0.34
        dialogueSpeakerRatio = try container.decodeIfPresent(Double.self, forKey: .dialogueSpeakerRatio) ?? 0.28
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        scriptHeading = try container.decodeIfPresent(String.self, forKey: .scriptHeading) ?? ""
        sceneName = try container.decodeIfPresent(String.self, forKey: .sceneName) ?? ""
    }
}
