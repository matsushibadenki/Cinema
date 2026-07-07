import AppKit
import SwiftUI

struct GeneratedVideoStripColumn: Identifiable, Equatable {
    var cutID: StoryboardCut.ID
    var cutNumber: Int
    var cutName: String
    var versions: [GeneratedVideoStripVersion]

    var id: StoryboardCut.ID { cutID }
}

struct GeneratedVideoStripVersion: Identifiable, Equatable {
    var id: GeneratedCutVideo.ID
    var generatedAt: Date
    var fileURL: URL
}

struct GeneratedVideoFilmstripView: View {
    var sceneTitle: String?
    var columns: [GeneratedVideoStripColumn]
    var currentCutID: StoryboardCut.ID?
    var isCompact = false

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack(spacing: 8) {
                Text("選択シーンの動画")
                    .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                    .foregroundStyle(CinemaDesign.ink)

                if let sceneTitle, !sceneTitle.isEmpty {
                    Text(sceneTitle)
                        .font(.system(size: isCompact ? 11 : 12, weight: .medium))
                        .foregroundStyle(CinemaDesign.mutedInk)
                        .lineLimit(1)
                }
            }

            GeometryReader { proxy in
                let contentHeight = max(proxy.size.height, 1)

                if columns.isEmpty {
                    Rectangle()
                        .fill(CinemaDesign.insetSurface)
                        .overlay {
                            Rectangle()
                                .stroke(CinemaDesign.strongBorder.opacity(0.88), lineWidth: 0.8)
                        }
                        .overlay {
                            Text("このシーンの動画はまだありません")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(CinemaDesign.quietInk)
                        }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: isCompact ? 8 : 12) {
                            ForEach(columns) { column in
                                GeneratedVideoFilmstripColumnView(
                                    column: column,
                                    isCurrentCut: column.cutID == currentCutID,
                                    isCompact: isCompact,
                                    availableHeight: contentHeight
                                )
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
        .padding(isCompact ? 6 : 8)
        .background(CinemaDesign.mainBlockSurface)
        .clipShape(Rectangle())
        .overlay {
            Rectangle()
                .stroke(CinemaDesign.strongBorder.opacity(0.9), lineWidth: 0.8)
        }
    }
}

private struct GeneratedVideoFilmstripColumnView: View {
    var column: GeneratedVideoStripColumn
    var isCurrentCut: Bool
    var isCompact: Bool
    var availableHeight: CGFloat

    private var bottomMargin: CGFloat { isCompact ? 6 : 8 }
    private var cardHeight: CGFloat {
        max(availableHeight - bottomMargin, isCompact ? 74 : 84)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            HStack(spacing: 6) {
                Text("\(column.cutNumber)")
                    .font(.system(size: isCompact ? 10 : 11, weight: .bold))
                    .foregroundStyle(isCurrentCut ? CinemaDesign.inverseInk : CinemaDesign.keyColor)
                    .frame(width: isCompact ? 18 : 20, height: isCompact ? 18 : 20)
                    .background(
                        Circle()
                            .fill(isCurrentCut ? CinemaDesign.keyColor : CinemaDesign.keyColorSoft)
                    )

                Text(column.cutName.isEmpty ? "カット \(column.cutNumber)" : column.cutName)
                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                    .foregroundStyle(CinemaDesign.ink)
                    .lineLimit(1)
            }

            if column.versions.isEmpty {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(CinemaDesign.insetSurface.opacity(0.62))
                    .overlay {
                        Text("未生成")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(CinemaDesign.quietInk)
                    }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: isCompact ? 6 : 8) {
                        ForEach(column.versions) { version in
                            GeneratedVideoVersionCard(version: version, isCompact: isCompact)
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
        }
        .padding(.top, isCompact ? 6 : 7)
        .padding(.horizontal, isCompact ? 6 : 7)
        .padding(.bottom, isCompact ? 4 : 5)
        .frame(
            width: isCompact ? 148 : 176,
            height: cardHeight,
            alignment: .topLeading
        )
        .background(CinemaDesign.editorSurface)
        .clipShape(Rectangle())
        .overlay {
            Rectangle()
                .stroke(
                    isCurrentCut ? CinemaDesign.warmBorder.opacity(0.95) : CinemaDesign.strongBorder.opacity(0.82),
                    lineWidth: isCurrentCut ? 1.0 : 0.7
                )
        }
        .padding(.bottom, bottomMargin)
    }
}

private struct GeneratedVideoVersionCard: View {
    var version: GeneratedVideoStripVersion
    var isCompact: Bool
    @State private var image: NSImage?
    @State private var isLoading = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(version.fileURL)
        } label: {
            VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
                ZStack {
                    Rectangle()
                        .fill(CinemaDesign.insetSurface)
                        .overlay {
                            Rectangle()
                                .stroke(CinemaDesign.strongBorder.opacity(0.82), lineWidth: 0.7)
                        }

                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    } else if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CinemaDesign.keyColor)
                    } else {
                        Image(systemName: "film")
                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                            .foregroundStyle(CinemaDesign.quietInk)
                    }
                }
                .frame(height: isCompact ? 48 : 58)
                .clipShape(Rectangle())

                Text(version.generatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: isCompact ? 9 : 10, weight: .medium))
                    .foregroundStyle(CinemaDesign.mutedInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: version.id) {
            guard image == nil, !isLoading else { return }
            isLoading = true
            defer { isLoading = false }
            image = try? await VideoAssemblyService.previewImage(from: version.fileURL)
        }
    }
}
