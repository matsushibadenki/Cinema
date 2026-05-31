import AppKit
import SwiftUI

struct ReferenceSidebarView: View {
    @Binding var document: StoryboardDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("リファレンス", systemImage: "photo.on.rectangle")
                    .font(.headline)
                Spacer()
                Button {
                    addReferenceImage()
                } label: {
                    Image(systemName: "plus")
                }
                .help("写真を登録")
            }

            if document.project.referenceImages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 28))
                    Text("登録写真なし")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach($document.project.referenceImages) { $reference in
                            ReferenceImageRow(
                                reference: $reference,
                                image: ImageHelpers.nsImage(from: document.imageData[reference.imageFileName]),
                                delete: {
                                    deleteReferenceImage(reference.id)
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)
        .background(.bar)
    }

    private func addReferenceImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            let id = UUID()
            let fileExtension = normalizedImageExtension(from: url)
            let fileName = "Images/References/\(id.uuidString).\(fileExtension)"
            let reference = ReferenceImage(
                id: id,
                name: url.deletingPathExtension().lastPathComponent,
                imageFileName: fileName
            )
            document.project.referenceImages.append(reference)
            document.imageData[fileName] = data
        }
    }

    private func deleteReferenceImage(_ id: ReferenceImage.ID) {
        guard let index = document.project.referenceImages.firstIndex(where: { $0.id == id }) else { return }
        let reference = document.project.referenceImages.remove(at: index)
        document.imageData[reference.imageFileName] = nil
    }

    private func normalizedImageExtension(from url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? "png" : ext
    }
}

private struct ReferenceImageRow: View {
    @Binding var reference: ReferenceImage
    var image: NSImage?
    var delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(Color(nsColor: .textBackgroundColor))
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.separator, lineWidth: 0.5)
            }

            HStack(spacing: 6) {
                TextField("名前", text: $reference.name)
                    .textFieldStyle(.roundedBorder)

                Button(role: .destructive, action: delete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("削除")
            }
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
