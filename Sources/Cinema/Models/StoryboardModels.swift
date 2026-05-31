import Foundation

struct StoryboardProject: Codable, Equatable {
    var title: String
    var documentPrompt: String
    var cuts: [StoryboardCut]

    init(
        title: String = "Untitled Storyboard",
        documentPrompt: String = "",
        cuts: [StoryboardCut] = StoryboardProject.defaultCuts()
    ) {
        self.title = title
        self.documentPrompt = documentPrompt
        self.cuts = cuts
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case documentPrompt
        case cuts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        documentPrompt = try container.decodeIfPresent(String.self, forKey: .documentPrompt) ?? ""
        cuts = try container.decode([StoryboardCut].self, forKey: .cuts)
    }

    static func defaultCuts() -> [StoryboardCut] {
        (1...5).map { index in
            StoryboardCut(cutNumber: index)
        }
    }
}

struct StoryboardCut: Codable, Identifiable, Equatable {
    var id: UUID
    var cutNumber: Int
    var situation: String
    var action: String
    var duration: String
    var imageFileName: String?
    var generationPrompt: String
    var textSplitRatio: Double

    init(
        id: UUID = UUID(),
        cutNumber: Int,
        situation: String = "",
        action: String = "",
        duration: String = "",
        imageFileName: String? = nil,
        generationPrompt: String = "",
        textSplitRatio: Double = 0.34
    ) {
        self.id = id
        self.cutNumber = cutNumber
        self.situation = situation
        self.action = action
        self.duration = duration
        self.imageFileName = imageFileName
        self.generationPrompt = generationPrompt
        self.textSplitRatio = textSplitRatio
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case cutNumber
        case situation
        case action
        case duration
        case imageFileName
        case generationPrompt
        case textSplitRatio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        cutNumber = try container.decode(Int.self, forKey: .cutNumber)
        situation = try container.decode(String.self, forKey: .situation)
        action = try container.decode(String.self, forKey: .action)
        duration = try container.decode(String.self, forKey: .duration)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        generationPrompt = try container.decodeIfPresent(String.self, forKey: .generationPrompt) ?? ""
        textSplitRatio = try container.decodeIfPresent(Double.self, forKey: .textSplitRatio) ?? 0.34
    }
}
