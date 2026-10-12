import Foundation
import Combine

/// Owns extracted embedded media for the lifetime of the browser, with cancellable disk work.
@MainActor final class BrowserVideoSources: ObservableObject {
    @Published private(set) var isPreparing = false
    @Published private(set) var urls: [String: URL] = [:]
    private(set) var directory: URL?
    private var generation = UUID()
    private var extraction: Task<(URL, [String: URL]), Error>?

    deinit {
        extraction?.cancel()
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    func clear() {
        generation = UUID()
        extraction?.cancel(); extraction = nil
        isPreparing = false; urls = [:]
        if let directory { try? FileManager.default.removeItem(at: directory) }
        directory = nil
    }

    func prepare(_ data: [String: Data]) async throws {
        clear()
        guard !data.isEmpty else { return }
        let token = generation
        isPreparing = true
        let worker = Task.detached(priority: .utility) { () throws -> (URL, [String: URL]) in
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CinemaBrowser-" + UUID().uuidString)
            var retained = false
            defer { if !retained { try? FileManager.default.removeItem(at: folder) } }
            try Task.checkCancellation()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var urls: [String: URL] = [:]
            for (path, bytes) in data {
                try Task.checkCancellation()
                let url = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(URL(fileURLWithPath: path).pathExtension)
                try bytes.write(to: url, options: .atomic)
                urls[path] = url
            }
            try Task.checkCancellation()
            retained = true
            return (folder, urls)
        }
        extraction = worker
        defer { if generation == token { extraction = nil; isPreparing = false } }
        let (folder, urls) = try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: { worker.cancel() }
        guard generation == token, !Task.isCancelled else {
            try? FileManager.default.removeItem(at: folder)
            throw CancellationError()
        }
        directory = folder; self.urls = urls
    }
}
