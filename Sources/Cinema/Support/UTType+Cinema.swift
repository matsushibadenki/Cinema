import UniformTypeIdentifiers

extension UTType {
    static let cinemaStoryboard = UTType("com.littlebuddha.cinema.storyboard")
        ?? UTType(filenameExtension: "cinemaboard", conformingTo: .package)
        ?? .package
}
