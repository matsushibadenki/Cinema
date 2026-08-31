// file:///Users/Shared/Program/Xcode/Cinema/Sources/Cinema/Views/GeneratedVideoFilmstripView.swift
// GeneratedVideoFilmstripView.swift
// 生成されたシーン動画の各カットバージョンをフィルムストリップ形式で並べて再生・確認するビューです。

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
    var screenAspectRatio: CGFloat
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
                                    screenAspectRatio: screenAspectRatio,
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
    var screenAspectRatio: CGFloat
    var isCompact: Bool
    var availableHeight: CGFloat

    private var bottomMargin: CGFloat { isCompact ? 6 : 8 }
    private var cardHeight: CGFloat {
        max(availableHeight - bottomMargin, isCompact ? 74 : 84)
    }
    private var versionAreaHeight: CGFloat {
        let verticalPadding = isCompact ? 10.0 : 12.0
        return max(cardHeight - verticalPadding, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if column.versions.isEmpty {
                Rectangle()
                    .fill(CinemaDesign.insetSurface.opacity(0.62))
                    .overlay {
                        Text("未生成")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(CinemaDesign.quietInk)
                    }
                    .overlay(alignment: .bottomLeading) {
                        cutTitleOverlay
                    }
            } else if column.versions.count == 1, let version = column.versions.first {
                GeneratedVideoVersionCard(
                    version: version,
                    cutNumber: column.cutNumber,
                    versionNumber: 1,
                    screenAspectRatio: screenAspectRatio,
                    isCompact: isCompact,
                    availableHeight: versionAreaHeight
                )
                .frame(height: versionAreaHeight, alignment: .top)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: isCompact ? 6 : 8) {
                        ForEach(Array(column.versions.enumerated()), id: \.element.id) { index, version in
                            GeneratedVideoVersionCard(
                                version: version,
                                cutNumber: column.cutNumber,
                                versionNumber: index + 1,
                                screenAspectRatio: screenAspectRatio,
                                isCompact: isCompact,
                                availableHeight: nil
                            )
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

    private var cutTitleOverlay: some View {
        HStack(spacing: 5) {
            Text("\(column.cutNumber)")
                .font(.system(size: isCompact ? 9 : 10, weight: .bold, design: .rounded))
            Text(column.cutName.isEmpty ? "カット \(column.cutNumber)" : column.cutName)
                .font(.system(size: isCompact ? 10 : 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.58))
    }
}

private struct GeneratedVideoVersionCard: View {
    var version: GeneratedVideoStripVersion
    var cutNumber: Int
    var versionNumber: Int
    var screenAspectRatio: CGFloat
    var isCompact: Bool
    var availableHeight: CGFloat?
    @State private var image: NSImage?
    @State private var isLoading = false

    private var thumbnailHeight: CGFloat {
        let cardWidth = isCompact ? 136.0 : 162.0
        return cardWidth / max(screenAspectRatio, 0.1)
    }

    var body: some View {
        Button {
            NSWorkspace.shared.open(version.fileURL)
        } label: {
            ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(CinemaDesign.insetSurface)
                        .overlay {
                            Rectangle()
                                .stroke(CinemaDesign.strongBorder.opacity(0.82), lineWidth: 0.7)
                        }

                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CinemaDesign.keyColor)
                    } else {
                        Image(systemName: "film")
                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                            .foregroundStyle(CinemaDesign.quietInk)
                    }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: min(thumbnailHeight * 0.62, 54))
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text("カット\(cutNumber)-\(versionNumber)")
                            .font(.system(size: isCompact ? 10 : 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    Text(version.generatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: isCompact ? 8 : 9, weight: .medium))
                        .opacity(0.82)
                        .lineLimit(1)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: thumbnailHeight)
            .clipped()
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
