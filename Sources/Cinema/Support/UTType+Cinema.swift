// file:///Users/Shared/Program/Xcode/Cinema/Sources/Cinema/Support/UTType+Cinema.swift
// UTType+Cinema.swift
// Cinemaアプリのカスタムドキュメントパッケージ形式（.cinemaboard）のUTType定義拡張です。

import UniformTypeIdentifiers

extension UTType {
    static let cinemaStoryboard = UTType("com.littlebuddha.cinema.storyboard")
        ?? UTType(filenameExtension: "cinemaboard", conformingTo: .package)
        ?? .package
}
