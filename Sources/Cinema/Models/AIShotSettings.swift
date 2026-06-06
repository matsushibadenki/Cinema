import Foundation

struct AIShotSettings: Codable, Equatable {
    var shotSize: String
    var cameraAngle: String
    var lens: String
    var cameraMovement: String
    var subjectMovement: String
    var startState: String
    var endState: String
    var transition: String
    var negativePrompt: String
    var soundDirection: String
    var continuityStrength: Double
    var seed: Int?

    init(
        shotSize: String = "",
        cameraAngle: String = "",
        lens: String = "",
        cameraMovement: String = "",
        subjectMovement: String = "",
        startState: String = "",
        endState: String = "",
        transition: String = "",
        negativePrompt: String = "",
        soundDirection: String = "",
        continuityStrength: Double = 0.85,
        seed: Int? = nil
    ) {
        self.shotSize = shotSize
        self.cameraAngle = cameraAngle
        self.lens = lens
        self.cameraMovement = cameraMovement
        self.subjectMovement = subjectMovement
        self.startState = startState
        self.endState = endState
        self.transition = transition
        self.negativePrompt = negativePrompt
        self.soundDirection = soundDirection
        self.continuityStrength = continuityStrength
        self.seed = seed
    }

    var promptText: String {
        let details = [
            line("Shot size", shotSize),
            line("Camera angle", cameraAngle),
            line("Lens", lens),
            line("Camera movement", cameraMovement),
            line("Subject movement", subjectMovement),
            line("Opening state", startState),
            line("Ending state", endState),
            line("Transition to next cut", transition),
            line("Sound direction", soundDirection),
            line("Negative constraints", negativePrompt),
            seed.map { "Seed: \($0)" }
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }

        guard !details.isEmpty else { return "" }
        return (details + [
            "Continuity strength: \(Int((min(max(continuityStrength, 0), 1) * 100).rounded()))%"
        ])
        .joined(separator: "\n")
    }

    private func line(_ label: String, _ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : "\(label): \(trimmed)"
    }
}
