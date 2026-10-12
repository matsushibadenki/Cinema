import AppKit

/// Uses the working folder picker while retaining NSDocument's coordinated move and URL updates.
@MainActor enum DocumentMoveService {
    private static var activePanel: NSOpenPanel?
    private static var isMoving = false
    enum MoveError: LocalizedError {
        case destinationExists(String)
        var errorDescription: String? { message(language: "en") }
        func message(language: String) -> String {
            switch self {
            case .destinationExists(let name):
                language == "ja" ? "同名のプロジェクトが存在します。別のフォルダを選んでください：\(name)" : language == "zh-Hans" ? "已存在同名项目，请选择其他文件夹：\(name)" : "A project with this name already exists. Choose another folder: \(name)"
            }
        }
    }
    static func panel(language: String, source: URL) -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        panel.directoryURL = source.deletingLastPathComponent()
        panel.title = language == "ja" ? "プロジェクトを移動" : language == "zh-Hans" ? "移动项目" : "Move Project"
        panel.prompt = language == "ja" ? "移動" : language == "zh-Hans" ? "移动" : "Move"
        panel.message = language == "ja" ? "移動先のフォルダを選んでください。プロジェクト名は保持し、同名のプロジェクトは上書きしません。" : language == "zh-Hans" ? "请选择目标文件夹。保留项目名称，不覆盖同名项目。" : "Choose a destination folder. The project name is preserved; an existing project with the same name will not be overwritten."
        return panel
    }
    static func destination(source: URL, folder: URL) throws -> URL? {
        let target = folder.appendingPathComponent(source.lastPathComponent)
        if target.resolvingSymlinksInPath().standardizedFileURL == source.resolvingSymlinksInPath().standardizedFileURL { return nil }
        if FileManager.default.fileExists(atPath: target.path) || (try? target.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
            throw MoveError.destinationExists(source.lastPathComponent)
        }
        return target
    }
    static func move(_ document: NSDocument, to folder: URL) async throws {
        guard let source = document.fileURL, let target = try destination(source: source, folder: folder) else { return }
        // Save edits before moving, so an immediate reopen reads the current document.
        if document.isDocumentEdited, let type = document.fileType {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                document.save(to: source, ofType: type, for: .saveOperation) { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        }
        guard try destination(source: source, folder: folder) != nil else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.move(to: target) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }
    static func chooseDestination(for document: NSDocument?, language: String) {
        guard !isMoving, let document else { return }
        if let activePanel { activePanel.makeKeyAndOrderFront(nil); return }
        guard let source = document.fileURL else { document.saveAs(nil); return }
        document.windowControllers.first?.window?.endEditing(for: nil)
        let picker = panel(language: language, source: source)
        activePanel = picker
        picker.begin { response in
            activePanel = nil
            guard response == .OK, let folder = picker.url else { return }
            isMoving = true
            Task { @MainActor in
                defer { isMoving = false }
                let scoped = folder.startAccessingSecurityScopedResource()
                defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
                do { try await move(document, to: folder) }
                catch {
                    let alert = NSAlert()
                    alert.messageText = language == "ja" ? "移動できませんでした" : language == "zh-Hans" ? "无法移动项目" : "Could Not Move Project"
                    alert.informativeText = (error as? MoveError)?.message(language: language) ?? error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }
}
