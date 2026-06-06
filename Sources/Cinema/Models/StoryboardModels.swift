// file:///Users/Shared/Program/Xcode/Cinema/Sources/Cinema/Models/StoryboardModels.swift
// StoryboardModels.swift
// 絵コンテプロジェクトのデータ構造（プロジェクト情報、描画プリセット、カット情報、台本行など）を定義するモデルクラス群

import Foundation

struct StoryboardProject: Codable, Equatable {
    var title: String
    var drawingSettings: DrawingSettings
    var referenceImages: [ReferenceImage]
    var sceneVideos: [SceneVideo]
    var cuts: [StoryboardCut]

    init(
        title: String = "",
        drawingSettings: DrawingSettings = DrawingSettings(),
        referenceImages: [ReferenceImage] = [],
        sceneVideos: [SceneVideo] = [],
        cuts: [StoryboardCut] = StoryboardProject.defaultCuts()
    ) {
        self.title = title
        self.drawingSettings = drawingSettings
        self.referenceImages = referenceImages
        self.sceneVideos = sceneVideos
        self.cuts = cuts
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case drawingSettings
        case referenceImages
        case sceneVideos
        case cuts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        drawingSettings = try container.decodeIfPresent(DrawingSettings.self, forKey: .drawingSettings) ?? DrawingSettings()
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

struct DrawingSettings: Codable, Equatable {
    var selectedPresetID: UUID
    var presets: [DrawingPreset]

    init(selectedPresetID: UUID? = nil, presets: [DrawingPreset] = DrawingPreset.defaultPresets()) {
        self.presets = presets.isEmpty ? DrawingPreset.defaultPresets() : presets
        self.selectedPresetID = selectedPresetID ?? self.presets.first?.id ?? UUID()
    }

    var selectedPreset: DrawingPreset {
        presets.first { $0.id == selectedPresetID } ?? presets.first ?? DrawingPreset.storyboardPreset
    }

    mutating func ensureSelection() {
        // Remove the old presets
        presets.removeAll {
            $0.id == UUID(uuidString: "00000000-0000-0000-0000-000000000102")! || // Old 映画風
            $0.id == UUID(uuidString: "00000000-0000-0000-0000-000000000103")! || // Old テレビ風
            $0.id == UUID(uuidString: "00000000-0000-0000-0000-000000000104")! || // Old 写真集
            $0.id == UUID(uuidString: "00000000-0000-0000-0000-000000000201")! || // Old 邦画風 (v2)
            $0.id == UUID(uuidString: "00000000-0000-0000-0000-000000000202")! || // Old ハリウッド映画風 (v2)
            $0.id == UUID(uuidString: "00000000-0000-0000-0000-000000000203")! || // Old ヨーロッパ映画風 (v2)
            $0.id == UUID(uuidString: "00000000-0000-0000-0000-000000000204")! || // Old 昭和レトロ映画風 (v2)
            $0.id == UUID(uuidString: "00000000-0000-0000-0000-000000000205")!    // Old テレビドラマ風 (v2)
        }

        for preset in DrawingPreset.defaultPresets() where !presets.contains(where: { $0.id == preset.id }) {
            presets.append(preset)
        }

        if !presets.contains(where: { $0.id == selectedPresetID }) {
            selectedPresetID = presets.first?.id ?? UUID()
        }
    }

    func promptText() -> String {
        selectedPreset.promptText()
    }
}

struct DrawingPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var isBuiltin: Bool
    var sections: [DrawingSettingsSection]

    init(id: UUID = UUID(), name: String, isBuiltin: Bool = false, sections: [DrawingSettingsSection]) {
        self.id = id
        self.name = name
        self.isBuiltin = isBuiltin
        self.sections = sections
    }

    func promptText() -> String {
        sections.map { section in
            let fields = section.fields.map { field in
                "- \(field.key): \(field.value)"
            }
            .joined(separator: "\n")
            return "[\(section.title)]\n\(fields)"
        }
        .joined(separator: "\n\n")
    }

    func duplicatedForUser() -> DrawingPreset {
        DrawingPreset(
            name: "\(name) コピー",
            isBuiltin: false,
            sections: sections.map { $0.duplicated() }
        )
    }

    static var storyboardPreset: DrawingPreset {
        DrawingPreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            name: "絵コンテ",
            isBuiltin: true,
            sections: [
                DrawingSettingsSection(title: "Style", fields: [
                    DrawingSettingsField(key: "Look", value: "clean hand-drawn style, full-color storyboard sketch, natural artist drawing, no 3D render, no CGI"),
                    DrawingSettingsField(key: "Rendering", value: "natural colors, soft sketch lines, realistic perspective, no speech bubbles, no captions")
                ])
            ]
        )
    }

    static func defaultPresets() -> [DrawingPreset] {
        [
            storyboardPreset,
            DrawingPreset(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
                name: "邦画風",
                isBuiltin: true,
                sections: [
                    DrawingSettingsSection(title: "Camera & Lens", fields: [
                        DrawingSettingsField(key: "Camera", value: "Sony VENICE 2 with vintage anamorphic lenses, organic shallow depth of field, natural optical qualities")
                    ]),
                    DrawingSettingsSection(title: "Film & Color", fields: [
                        DrawingSettingsField(key: "Color Grading", value: "natural cinematic tone, authentic film look, slightly low contrast, realistic color palette, organic textures, natural skin tones, no airbrushed or plastic skin, no CGI look")
                    ]),
                    DrawingSettingsSection(title: "Lighting", fields: [
                        DrawingSettingsField(key: "Lighting", value: "natural and diffused lighting, soft overcast daylight, gentle room ambiance, motivated light sources")
                    ]),
                    DrawingSettingsSection(title: "Audio & Era", fields: [
                        DrawingSettingsField(key: "Acoustics", value: "realistic soundscape, rich environmental room tone, soft minimal acoustic score"),
                        DrawingSettingsField(key: "Era", value: "modern contemporary Japan")
                    ])
                ]
            ),
            DrawingPreset(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!,
                name: "ハリウッド映画風",
                isBuiltin: true,
                sections: [
                    DrawingSettingsSection(title: "Camera & Lens", fields: [
                        DrawingSettingsField(key: "Camera", value: "ARRI ALEXA 65 with Panavision Primo prime lenses, realistic depth of field, sharp details, true movie camera look")
                    ]),
                    DrawingSettingsSection(title: "Film & Color", fields: [
                        DrawingSettingsField(key: "Color Grading", value: "photorealistic film still, authentic movie cinematography, natural textures, organic colors, no CGI look, no 3D render look, no video game style, no plastic skin")
                    ]),
                    DrawingSettingsSection(title: "Lighting", fields: [
                        DrawingSettingsField(key: "Lighting", value: "motivated dramatic cinematic lighting, natural shadows, soft backlight, realistic fill lights")
                    ]),
                    DrawingSettingsSection(title: "Audio & Era", fields: [
                        DrawingSettingsField(key: "Acoustics", value: "immersive Dolby Atmos surround sound, booming sound effects, epic orchestral score"),
                        DrawingSettingsField(key: "Era", value: "modern blockbuster era")
                    ])
                ]
            ),
            DrawingPreset(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000303")!,
                name: "ヨーロッパ映画風",
                isBuiltin: true,
                sections: [
                    DrawingSettingsSection(title: "Camera & Lens", fields: [
                        DrawingSettingsField(key: "Camera", value: "RED V-Raptor with vintage Cooke Speed Panchro lenses, organic texture, artistic composition, authentic film look")
                    ]),
                    DrawingSettingsSection(title: "Film & Color", fields: [
                        DrawingSettingsField(key: "Color Grading", value: "natural desaturated colors, warm pastel palette, authentic 35mm film grain, realistic skin and fabric textures, no CGI, no 3D render, no plastic look")
                    ]),
                    DrawingSettingsSection(title: "Lighting", fields: [
                        DrawingSettingsField(key: "Lighting", value: "chiaroscuro lighting, natural window light, moody side light, overcast sky mood, realistic soft shadows")
                    ]),
                    DrawingSettingsSection(title: "Audio & Era", fields: [
                        DrawingSettingsField(key: "Acoustics", value: "art-house sound design, natural dialogue acoustics, silence as sound element, solo piano score"),
                        DrawingSettingsField(key: "Era", value: "contemporary art film era")
                    ])
                ]
            ),
            DrawingPreset(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000304")!,
                name: "昭和レトロ映画風",
                isBuiltin: true,
                sections: [
                    DrawingSettingsSection(title: "Camera & Lens", fields: [
                        DrawingSettingsField(key: "Camera", value: "Arriflex 35 with vintage lenses, authentic retro camera optics, gentle corner softness, realistic vintage film cameras")
                    ]),
                    DrawingSettingsSection(title: "Film & Color", fields: [
                        DrawingSettingsField(key: "Color Grading", value: "faded warm colors, 1960s-1970s warm sepia-like color tones, vintage 35mm film grain, low dynamic range, realistic film print texture, no digital look, no CGI")
                    ]),
                    DrawingSettingsSection(title: "Lighting", fields: [
                        DrawingSettingsField(key: "Lighting", value: "direct warm tungsten lighting, hard shadows, theatrical and dramatic light placement, realistic retro studio lighting")
                    ]),
                    DrawingSettingsSection(title: "Audio & Era", fields: [
                        DrawingSettingsField(key: "Acoustics", value: "monaural sound design, warm low-fidelity optical sound noise, classic retro film music"),
                        DrawingSettingsField(key: "Era", value: "1970s Showa era Japan")
                    ])
                ]
            ),
            DrawingPreset(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000305")!,
                name: "テレビドラマ風",
                isBuiltin: true,
                sections: [
                    DrawingSettingsSection(title: "Camera & Lens", fields: [
                        DrawingSettingsField(key: "Camera", value: "Sony FX9 broadcast digital camera, deep depth of field, clear focus across the frame, natural TV show look")
                    ]),
                    DrawingSettingsSection(title: "Film & Color", fields: [
                        DrawingSettingsField(key: "Color Grading", value: "clean natural digital broadcast look, realistic colors, standard Rec. 709 color space, authentic textures, no CGI look, no 3D render, no plastic skin")
                    ]),
                    DrawingSettingsSection(title: "Lighting", fields: [
                        DrawingSettingsField(key: "Lighting", value: "bright high-key flat lighting, evenly lit set, minimal dark shadows, natural interior lighting")
                    ]),
                    DrawingSettingsSection(title: "Audio & Era", fields: [
                        DrawingSettingsField(key: "Acoustics", value: "standard stereo sound design, clear dialogue mix, upbeat television soundtrack"),
                        DrawingSettingsField(key: "Era", value: "modern television era")
                    ])
                ]
            )
        ]
    }
}

struct DrawingSettingsSection: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var fields: [DrawingSettingsField]

    init(id: UUID = UUID(), title: String, fields: [DrawingSettingsField]) {
        self.id = id
        self.title = title
        self.fields = fields
    }

    func duplicated() -> DrawingSettingsSection {
        DrawingSettingsSection(title: title, fields: fields.map { $0.duplicated() })
    }
}

struct DrawingSettingsField: Codable, Identifiable, Equatable {
    var id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }

    func duplicated() -> DrawingSettingsField {
        DrawingSettingsField(key: key, value: value)
    }
}

struct ReferenceImage: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var imageFileName: String
    var details: [DrawingSettingsSection]

    init(id: UUID = UUID(), name: String, imageFileName: String, details: [DrawingSettingsSection] = ReferenceImage.defaultDetails()) {
        self.id = id
        self.name = name
        self.imageFileName = imageFileName
        self.details = details
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageFileName
        case details
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageFileName = try container.decode(String.self, forKey: .imageFileName)
        details = try container.decodeIfPresent([DrawingSettingsSection].self, forKey: .details) ?? ReferenceImage.defaultDetails()
    }

    func promptText() -> String {
        let content = details.map { section in
            let fields = section.fields
                .map { field in
                    let key = field.key.trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !key.isEmpty || !value.isEmpty else { return "" }
                    return "- \(key.isEmpty ? "Detail" : key): \(value)"
                }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            guard !fields.isEmpty else { return "" }
            return "[\(section.title)]\n\(fields)"
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            return trimmedName.isEmpty ? "" : "Reference name: \(trimmedName)"
        }

        return [
            trimmedName.isEmpty ? "" : "Reference name: \(trimmedName)",
            content
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    static func defaultDetails() -> [DrawingSettingsSection] {
        [
            DrawingSettingsSection(title: "Character", fields: [
                DrawingSettingsField(key: "Subject", value: ""),
                DrawingSettingsField(key: "Face_and_Skin", value: ""),
                DrawingSettingsField(key: "Makeup", value: ""),
                DrawingSettingsField(key: "Hair", value: ""),
                DrawingSettingsField(key: "Eyes_and_Expression", value: ""),
                DrawingSettingsField(key: "Pose", value: ""),
                DrawingSettingsField(key: "Outfit", value: "")
            ]),
            DrawingSettingsSection(title: "Scene", fields: [
                DrawingSettingsField(key: "Environment", value: ""),
                DrawingSettingsField(key: "Details", value: ""),
                DrawingSettingsField(key: "Atmosphere", value: "")
            ]),
            DrawingSettingsSection(title: "Photography", fields: [
                DrawingSettingsField(key: "Style", value: ""),
                DrawingSettingsField(key: "Camera_and_Lens", value: ""),
                DrawingSettingsField(key: "Framing", value: ""),
                DrawingSettingsField(key: "Lighting", value: ""),
                DrawingSettingsField(key: "Film_Simulation_and_Color", value: ""),
                DrawingSettingsField(key: "Effects", value: ""),
                DrawingSettingsField(key: "Aspect Ratio", value: "")
            ])
        ]
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
    var referenceImageIDs: [ReferenceImage.ID]
    var aiShotSettings: AIShotSettings

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
        sceneName: String = "",
        referenceImageIDs: [ReferenceImage.ID] = [],
        aiShotSettings: AIShotSettings = AIShotSettings()
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
        self.referenceImageIDs = referenceImageIDs
        self.aiShotSettings = aiShotSettings
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
        case referenceImageIDs
        case aiShotSettings
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
        referenceImageIDs = try container.decodeIfPresent([ReferenceImage.ID].self, forKey: .referenceImageIDs) ?? []
        aiShotSettings = try container.decodeIfPresent(AIShotSettings.self, forKey: .aiShotSettings) ?? AIShotSettings()
    }
}
