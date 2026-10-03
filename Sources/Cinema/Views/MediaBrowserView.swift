import AppKit
import SwiftUI
import QuickLookThumbnailing

struct BrowserFile: Identifiable, Hashable {
    var url: URL
    var isDirectory: Bool
    var id: URL { url }

    static func contents(of url: URL) throws -> [BrowserFile] {
        try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            .map { BrowserFile(url: $0, isDirectory: (try $0.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true) }
            .sorted { $0.isDirectory == $1.isDirectory ? $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending : $0.isDirectory }
    }
}

struct MediaBrowserView: View {
    var document: StoryboardDocument
    var documentURL: URL?
    @AppStorage("appLanguage") private var language = "ja"
    @State private var tab = 0
    @State private var root: URL?
    @State private var directory: URL?
    @State private var files: [BrowserFile] = []
    @State private var error: String?
    @State private var query = ""
    @State private var selectedImage: GeneratedImage?
    @State private var accessURL: URL?
    @State private var embeddedURLs: [String: URL] = [:]
    @State private var previewDirectory: URL?
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)]

    private func text(_ ja: String, _ en: String, _ zh: String) -> String {
        language == "en" ? en : language == "zh-Hans" ? zh : ja
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker(text("ブラウザ", "Browser", "浏览器"), selection: $tab) {
                    Text(text("ファイル", "Files", "文件")).tag(0)
                    Text(text("生成画像", "Generated Images", "生成图像")).tag(1)
                    Text(text("生成動画", "Generated Videos", "生成视频")).tag(2)
                }
                .pickerStyle(.segmented).frame(maxWidth: 440)
                Spacer(minLength: 16)
                TextField(text("検索", "Search", "搜索"), text: $query).textFieldStyle(.roundedBorder).frame(width: 160)
                if tab == 0 {
                    Button { chooseFolder() } label: { Label(text("フォルダを開く", "Open Folder", "打开文件夹"), systemImage: "folder.badge.plus") }
                    Button { loadDirectory() } label: { Image(systemName: "arrow.clockwise") }.help(text("更新", "Refresh", "刷新"))
                }
            }.padding(16)
            Divider()
            if tab == 0 {
                HSplitView {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            if let root { BrowserDirectoryRow(url: root, selected: directory, select: { directory = $0 }, language: language) }
                            else { Text(text("フォルダを選択してください", "Choose a folder", "请选择文件夹")).foregroundStyle(.secondary) }
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(width: 180)
                    VStack(alignment: .leading, spacing: 0) {
                        if let directory { Text(directory.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).padding(16) }
                        if let error { Text(error).foregroundStyle(.red).padding(16) }
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(files.filter { query.isEmpty || $0.url.lastPathComponent.localizedCaseInsensitiveContains(query) }) { file in
                                    Button {
                                        if file.isDirectory { directory = file.url } else { NSWorkspace.shared.open(file.url) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            BrowserThumbnail(url: file.url, isDirectory: file.isDirectory)
                                            Text(file.url.lastPathComponent).lineLimit(2).font(.caption).foregroundStyle(.primary)
                                        }.padding(10).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                                    }.buttonStyle(.plain).help(file.url.path)
                                }
                            }.frame(maxWidth: .infinity).padding(16)
                            if files.isEmpty && error == nil { empty(text("このフォルダは空です", "This folder is empty", "此文件夹为空")) }
                        }
                    }.frame(minWidth: 300, maxWidth: .infinity).padding(.horizontal, 16)
                }
            } else if tab == 1 {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(document.project.generatedImages.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.prompt.localizedCaseInsensitiveContains(query) }) { image in
                            Button { selectedImage = image } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    imageThumbnail(image.imageFileName)
                                    Text(image.title).font(.headline).lineLimit(1)
                                    Text("\(image.provider) · \(image.model)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    Text(image.prompt).font(.caption).lineLimit(3)
                                    Text(image.generatedAt, style: .date).font(.caption2).foregroundStyle(.secondary)
                                }.padding(10).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain)
                        }
                        ForEach(document.project.cuts.filter { cut in
                            guard let path = cut.imageFileName else { return false }
                            return !document.project.generatedImages.contains { $0.imageFileName == path } && (query.isEmpty || cut.cutName.localizedCaseInsensitiveContains(query))
                        }) { cut in
                            VStack(alignment: .leading, spacing: 8) {
                                imageThumbnail(cut.imageFileName ?? "")
                                Text(cut.cutName.isEmpty ? "\(cut.cutNumber)" : cut.cutName).font(.headline)
                                Text(text("既存・読み込み画像：生成時の設定は未保存", "Existing / imported image: generation settings not recorded", "现有或导入图像：未记录生成设置")).font(.caption).foregroundStyle(.secondary)
                            }.padding(10)
                        }
                    }.padding(16)
                    if document.project.generatedImages.isEmpty && !document.project.cuts.contains(where: { $0.imageFileName != nil }) { empty(text("生成画像はまだありません", "No generated images yet", "暂无生成图像")) }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(document.project.generatedCutVideos.filter { query.isEmpty || $0.sceneTitle.localizedCaseInsensitiveContains(query) }) { video in
                            videoCard(title: video.sceneTitle, path: video.videoFileName, date: video.generatedAt)
                        }
                        ForEach(document.project.sceneVideos.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }) { video in
                            videoCard(title: video.title, path: video.videoFileName, date: video.generatedAt)
                        }
                    }.padding(16)
                    if document.project.generatedCutVideos.isEmpty && document.project.sceneVideos.isEmpty { empty(text("生成動画はまだありません", "No generated videos yet", "暂无生成视频")) }
                }
            }
        }
        .background(CinemaDesign.canvasBackground)
        .onAppear {
            if root == nil, let documentURL { root = documentURL.deletingLastPathComponent(); directory = root }
            if let root, accessURL == nil, root.startAccessingSecurityScopedResource() { accessURL = root }
            loadDirectory()
        }
        .task(id: document.videoData) {
            guard !document.videoData.isEmpty else { return }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CinemaBrowser-" + UUID().uuidString)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                var urls: [String: URL] = [:]
                for (path, data) in document.videoData {
                    let url = folder.appendingPathComponent(UUID().uuidString + "." + URL(fileURLWithPath: path).pathExtension)
                    try data.write(to: url, options: .atomic); urls[path] = url
                }
                if let previous = previewDirectory { try? FileManager.default.removeItem(at: previous) }
                previewDirectory = folder; embeddedURLs = urls
            } catch { try? FileManager.default.removeItem(at: folder) }
        }
        .onChange(of: directory) { _, _ in loadDirectory() }
        .onDisappear { accessURL?.stopAccessingSecurityScopedResource(); accessURL = nil }
        .sheet(item: $selectedImage) { image in
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text(image.title).font(.title2); Spacer(); Button(text("閉じる", "Close", "关闭")) { selectedImage = nil } }
                ScrollView {
                    imageThumbnail(image.imageFileName).frame(height: 260)
                    Text("\(image.provider) · \(image.model) · \(String(format: "%.3f", image.aspectRatio))").foregroundStyle(.secondary)
                    Text(image.generatedAt, style: .date)
                    Text(text("プロンプト", "Prompt", "提示词")).font(.headline)
                    Text(image.prompt).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                    Text(text("生成時の設定・コンテキスト", "Generation Settings / Context", "生成设置与上下文")).font(.headline)
                    Text(image.context).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                }
                Button(text("プロンプトをコピー", "Copy Prompt", "复制提示词")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(image.prompt + "\n\n" + image.context, forType: .string) }
            }.padding(16).frame(width: 620, height: 620)
        }
    }

    private func empty(_ message: String) -> some View {
        ContentUnavailableView(message, systemImage: "rectangle.grid.2x2").padding(16)
    }

    private func imageThumbnail(_ path: String) -> some View {
        Group {
            if let data = document.imageData[path], let image = NSImage(data: data) { Image(nsImage: image).resizable().scaledToFit() }
            else { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
        }.frame(height: 120).frame(maxWidth: .infinity).padding(.horizontal, 16)
    }

    private func videoCard(title: String, path: String, date: Date) -> some View {
        let url = embeddedURLs[path] ?? GeneratedVideoStorageService.fileURL(for: path, documentURL: documentURL)
        let exists = url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        return Button { if let url { NSWorkspace.shared.open(url) } } label: {
            VStack(alignment: .leading, spacing: 8) {
                if let url { BrowserThumbnail(url: url, isDirectory: false) }
                Text(title).font(.headline).lineLimit(1)
                Text(URL(fileURLWithPath: path).lastPathComponent).font(.caption).lineLimit(2)
                Text(date, style: .date).font(.caption2).foregroundStyle(.secondary)
                if !exists { Text(text("動画ファイルが見つかりません", "Video file is missing", "找不到视频文件")).font(.caption).foregroundStyle(.secondary) }
            }.padding(10).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).disabled(!exists)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        accessURL?.stopAccessingSecurityScopedResource()
        accessURL = url.startAccessingSecurityScopedResource() ? url : nil
        root = url; directory = url; loadDirectory()
    }

    private func loadDirectory() {
        guard let directory else { return }
        do { files = try BrowserFile.contents(of: directory); error = nil }
        catch { files = []; self.error = error.localizedDescription }
    }
}

private struct BrowserDirectoryRow: View {
    var url: URL
    var selected: URL?
    var select: (URL) -> Void
    var language: String
    @State private var expanded = false
    @State private var children: [BrowserFile] = []
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    expanded.toggle()
                    if expanded {
                        do { children = try BrowserFile.contents(of: url).filter { $0.isDirectory && !((try? $0.url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false) }; error = nil }
                        catch { self.error = error.localizedDescription }
                    }
                } label: { Image(systemName: expanded ? "chevron.down" : "chevron.right").frame(width: 12) }.buttonStyle(.plain)
                Button { select(url) } label: { Label(url.lastPathComponent, systemImage: "folder").lineLimit(1).foregroundStyle(selected == url ? Color.accentColor : .primary) }.buttonStyle(.plain)
            }.padding(.vertical, 5)
            if expanded {
                if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
                ForEach(children) { child in BrowserDirectoryRow(url: child.url, selected: selected, select: select, language: language).padding(.leading, 16) }
            }
        }
    }
}

private struct BrowserThumbnail: View {
    var url: URL
    var isDirectory: Bool
    @State private var image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFit() }
            else { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit().padding(24) }
        }.frame(height: 120).frame(maxWidth: .infinity).padding(.horizontal, 16)
            .task(id: url) {
                image = nil
                guard !isDirectory else { return }
                let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 360, height: 240), scale: 2, representationTypes: .thumbnail)
                if let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request), !Task.isCancelled { image = representation.nsImage }
            }
    }
}
