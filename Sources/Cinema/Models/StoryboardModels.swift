import Foundation

struct StoryboardProject: Codable, Equatable {
    var title: String
    var documentPrompt: String
    var referenceImages: [ReferenceImage]
    var cuts: [StoryboardCut]

    init(
        title: String = "Untitled Storyboard",
        documentPrompt: String = "",
        referenceImages: [ReferenceImage] = [],
        cuts: [StoryboardCut] = StoryboardProject.defaultCuts()
    ) {
        self.title = title
        self.documentPrompt = documentPrompt
        self.referenceImages = referenceImages
        self.cuts = cuts
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case documentPrompt
        case referenceImages
        case cuts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        documentPrompt = try container.decodeIfPresent(String.self, forKey: .documentPrompt) ?? ""
        referenceImages = try container.decodeIfPresent([ReferenceImage].self, forKey: .referenceImages) ?? []
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
    var situation: String
    var action: String
    var dialogueLines: [DialogueLine]
    var duration: String
    var imageFileName: String?
    var generationPrompt: String
    var textSplitRatio: Double
    var dialogueSpeakerRatio: Double
    var subtitle: String

    init(
        id: UUID = UUID(),
        cutNumber: Int,
        situation: String = "",
        action: String = "",
        dialogueLines: [DialogueLine] = [DialogueLine()],
        duration: String = "",
        imageFileName: String? = nil,
        generationPrompt: String = "",
        textSplitRatio: Double = 0.34,
        dialogueSpeakerRatio: Double = 0.28,
        subtitle: String = ""
    ) {
        self.id = id
        self.cutNumber = cutNumber
        self.situation = situation
        self.action = action
        self.dialogueLines = dialogueLines
        self.duration = duration
        self.imageFileName = imageFileName
        self.generationPrompt = generationPrompt
        self.textSplitRatio = textSplitRatio
        self.dialogueSpeakerRatio = dialogueSpeakerRatio
        self.subtitle = subtitle
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case cutNumber
        case situation
        case action
        case dialogueLines
        case duration
        case imageFileName
        case generationPrompt
        case textSplitRatio
        case dialogueSpeakerRatio
        case subtitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        cutNumber = try container.decode(Int.self, forKey: .cutNumber)
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
    }
}
