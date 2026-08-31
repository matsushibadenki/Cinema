import AppKit

@MainActor
final class EmptyDocumentWindowCoordinator {
    static let shared = EmptyDocumentWindowCoordinator()

    private var documentObservation: NSKeyValueObservation?
    private var knownDocumentIDs: Set<ObjectIdentifier> = []

    private init() {}

    func start() {
        guard documentObservation == nil else { return }

        let controller = NSDocumentController.shared
        knownDocumentIDs = Set(controller.documents.map(ObjectIdentifier.init))
        documentObservation = controller.observe(\.documents, options: [.new]) { [weak self] controller, _ in
            Task { @MainActor in
                self?.documentsDidChange(controller.documents)
            }
        }
    }

    private func documentsDidChange(_ documents: [NSDocument]) {
        let currentIDs = Set(documents.map(ObjectIdentifier.init))
        let addedDocuments = documents.filter { !knownDocumentIDs.contains(ObjectIdentifier($0)) }
        let previousDocumentIDs = knownDocumentIDs
        knownDocumentIDs = currentIDs

        guard addedDocuments.contains(where: { $0.fileURL != nil }) else { return }

        for document in documents where previousDocumentIDs.contains(ObjectIdentifier(document)) {
            guard document.fileURL == nil, !document.isDocumentEdited else { continue }
            document.close()
        }
    }
}
