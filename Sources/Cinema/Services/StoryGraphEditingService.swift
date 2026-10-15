import Foundation

/// Explicit edits target canonical text runs; Cinema media and graph annotations stay intact.
enum StoryGraphEditingService {
    typealias Object = StoryGraphService.Object
    struct Run: Identifiable, Equatable {
        var path: [Int]
        var text: String
        var styles: Set<String>
        var link: String? = nil
        var id: String { path.map(String.init).joined(separator: ".") }
    }
    struct Draft {
        var sceneID: UUID
        var canonical: Data
        var runs: [Run]
    }
    enum EditError: Error {
        case incompatible, stale, invalidLink, referencedParagraph, emptyDocument
        func message(_ language: String) -> String {
            if self == .emptyDocument {
                return language == "en" ? "Keep at least one block, or add a replacement paragraph before applying." : language == "zh-Hans" ? "请至少保留一个内容块，或先添加替换段落再应用。" : "少なくとも1つの要素を残すか、置き換える段落を追加してから適用してください。"
            }
            if self == .invalidLink {
                return language == "en" ? "Use a valid https, http or mailto link (up to 2048 bytes)." : language == "zh-Hans" ? "请输入有效的https、http或mailto链接（最多2048字节）。" : "有効なhttps・http・mailtoリンクを入力してください（2048バイト以内）。"
            }
            if self == .referencedParagraph {
                return language == "en" ? "This paragraph is referenced or contains annotations. It cannot be removed safely." : language == "zh-Hans" ? "此段落被引用或包含注释，无法安全删除。" : "この段落は参照されているか、注釈を含むため削除できません。"
            }
            let text: (String, String, String) = self == .stale
                ? ("本文が変更されました。閉じて開き直してください。", "The manuscript changed. Close and reopen the editor.", "正文已更改。请关闭并重新打开编辑器。")
                : ("この編集は、読み込んだシーンが1カットで、本文のみを使用している場合に対応しています。", "This editor requires an imported scene with one cut using only its action text.", "此编辑器需要导入的场景仅含一个镜头，且只使用动作正文。")
            return language == "en" ? text.1 : language == "zh-Hans" ? text.2 : text.0
        }
    }
    static let supportedStyles = ["bold", "italic", "underline", "strike", "code"]

    static func draft(_ document: StoryboardDocument, sceneID: UUID) throws -> Draft {
        guard document.storyGraphSource != nil else { throw EditError.incompatible }
        let cuts = document.project.cuts.filter { $0.sceneID == sceneID }
        guard cuts.count == 1, cuts[0].situation.isEmpty,
              cuts[0].dialogueLines.allSatisfy({ $0.dialogue.isEmpty }) else { throw EditError.incompatible }
        let snapshot = try StoryGraphService.parse(StoryGraphService.write(document))
        guard let node = snapshot.scenes.first(where: { UUID(uuidString: $0["id"] as? String ?? "") == sceneID }) else { throw EditError.incompatible }
        let canonical = try StoryGraphService.canonical(node, native: snapshot.native)
        var runs: [Run] = []
        func walk(_ value: Object, path: [Int], depth: Int) throws {
            guard depth < 32, runs.count <= 512 else { throw StoryGraphService.BridgeError.tooLarge }
            if value["type"] as? String == "text" {
                let marks = value["marks"] as? [Object] ?? []
                runs.append(Run(path: path, text: value["text"] as? String ?? "", styles: Set(marks.compactMap { $0["type"] as? String }.filter(supportedStyles.contains)), link: marks.first(where: { $0["type"] as? String == "link" })?["href"] as? String))
            } else if !["image", "code_block"].contains(value["type"] as? String ?? "") {
                for (index, child) in (value["content"] as? [Object] ?? []).enumerated() {
                    try walk(child, path: path + [index], depth: depth + 1)
                }
            }
        }
        try walk(canonical, path: [], depth: 0)
        guard runs.count <= 512 else { throw StoryGraphService.BridgeError.tooLarge }
        return Draft(sceneID: sceneID, canonical: try StoryGraphService.encode(canonical), runs: runs)
    }

    static func applying(_ edited: [Run], draft baseline: Draft, to document: StoryboardDocument, removing paragraphs: Set<Int> = [], appending additions: [String] = []) throws -> StoryboardDocument {
        let current = try draft(document, sceneID: baseline.sceneID)
        guard current.canonical == baseline.canonical, current.runs == baseline.runs, edited.map(\.path) == baseline.runs.map(\.path),
              edited.allSatisfy({ $0.styles.isSubset(of: Set(supportedStyles)) }) else { throw EditError.stale }
        var canonical = try JSONSerialization.jsonObject(with: baseline.canonical) as! Object
        for run in edited {
            if let link = run.link { try validateLink(link) }
            func update(_ node: Object, path: ArraySlice<Int>) throws -> Object {
                var node = node
                if let index = path.first {
                    var children = node["content"] as! [Object]
                    children[index] = try update(children[index], path: path.dropFirst())
                    node["content"] = children
                } else {
                    node["text"] = run.text
                    var marks = node["marks"] as? [Object] ?? []
                    // Preserve link destinations, extensions and attributes on retained marks.
                    marks.removeAll { supportedStyles.contains($0["type"] as? String ?? "") && !run.styles.contains($0["type"] as? String ?? "") }
                    for style in supportedStyles where run.styles.contains(style) && !marks.contains(where: { $0["type"] as? String == style }) { marks.append(["type": style]) }
                    let originalLink = baseline.runs.first(where: { $0.path == run.path })?.link
                    if run.link != originalLink {
                        let position = marks.firstIndex(where: { $0["type"] as? String == "link" }) ?? marks.count
                        var retained = marks.first(where: { $0["type"] as? String == "link" }) ?? ["type": "link"]
                        marks.removeAll { $0["type"] as? String == "link" }
                        if let link = run.link { retained["href"] = link; marks.insert(retained, at: min(position, marks.count)) }
                    }
                    guard marks.count <= 8 else { throw StoryGraphService.BridgeError.tooLarge }
                    node["marks"] = marks
                }
                return node
            }
            canonical = try update(canonical, path: run.path[...])
        }
        var snapshot = try StoryGraphService.parse(StoryGraphService.write(document))
        var blocks = canonical["content"] as! [Object]
        guard additions.count + blocks.count <= 512 else { throw StoryGraphService.BridgeError.tooLarge }
        for index in paragraphs {
            guard blocks.indices.contains(index), blocks[index]["type"] as? String == "paragraph" else { throw EditError.stale }
            let block = blocks[index]
            // Removal is conservative: preserve annotations and any incoming ID reference.
            guard !hasAnnotations(block) else { throw EditError.referencedParagraph }
            for identity in identities(in: block) {
                guard occurrences(identity, in: snapshot.root) <= occurrences(identity, in: block) else { throw EditError.referencedParagraph }
            }
        }
        for index in paragraphs.sorted(by: >) { blocks.remove(at: index) }
        blocks += additions.map(StoryGraphService.paragraph)
        guard !blocks.isEmpty else { throw EditError.emptyDocument }
        canonical["content"] = blocks
        guard try StoryGraphService.plainText(canonical).utf8.count <= 6 * 1024 * 1024 else { throw StoryGraphService.BridgeError.tooLarge }
        let scene = snapshot.scenes.first { UUID(uuidString: $0["id"] as? String ?? "") == baseline.sceneID }!
        let id = scene["id"] as! String
        if var workspace = snapshot.workspace {
            let sharedGraph = workspace["graph"] as! Object
            let sharedNodes = sharedGraph["nodes"] as! [Object]
            guard let node = sharedNodes.first(where: { $0["id"] as? String == id }),
                  let ref = (node["documentRefs"] as? [Object])?.first?["nodeId"] as? String else { throw StoryGraphService.BridgeError.invalid }
            var sharedDocument = workspace["document"] as! Object
            var blocks = sharedDocument["content"] as! [Object]
            guard let index = blocks.firstIndex(where: { $0["id"] as? String == ref }) else { throw StoryGraphService.BridgeError.invalid }
            blocks[index]["content"] = canonical["content"]
            sharedDocument["content"] = blocks
            workspace["document"] = sharedDocument
            if snapshot.root["format"] == nil { snapshot.root = workspace }
            else { snapshot.root["workspace"] = workspace }
        } else {
            var native = snapshot.native
            var graph = native["graph"] as! Object
            var nodes = graph["nodes"] as! [String: Object]
            var node = nodes[id]!
            var properties = node["properties"] as! Object
            if (properties["canonical"] as? Object)?["documentRef"] != nil {
                var ext = native["extensions"] as! Object
                var store = ext[StoryGraphService.store] as! Object
                store[id] = canonical; ext[StoryGraphService.store] = store; native["extensions"] = ext
            } else { properties["canonical"] = canonical }
            node["properties"] = properties; nodes[id] = node; graph["nodes"] = nodes; native["graph"] = graph
            snapshot.root["document"] = native
        }
        if snapshot.root["format"] != nil { snapshot.root["generation"] = UUID().uuidString.lowercased() }
        let source = try StoryGraphService.encode(snapshot.root)
        _ = try StoryGraphService.parse(source)
        var result = document
        result.storyGraphSource = source
        let index = result.project.cuts.firstIndex { $0.sceneID == baseline.sceneID }!
        result.project.cuts[index].action = try StoryGraphService.plainText(canonical)
        return result
    }
    static func validateLink(_ text: String) throws {
        guard text.utf8.count <= 2048, text.rangeOfCharacter(from: .whitespacesAndNewlines.union(.controlCharacters)) == nil,
              let url = URLComponents(string: text), let scheme = url.scheme?.lowercased(),
              ["https", "http", "mailto"].contains(scheme),
              scheme == "mailto" ? !url.path.isEmpty : !(url.host ?? "").isEmpty else { throw EditError.invalidLink }
    }
    private static func identities(in value: Any) -> Set<String> {
        if let object = value as? Object {
            var result = Set(object.values.flatMap { identities(in: $0) })
            if let id = object["id"] as? String { result.insert(id) }
            return result
        }
        return Set((value as? [Any] ?? []).flatMap { identities(in: $0) })
    }
    private static func hasAnnotations(_ value: Any) -> Bool {
        if let object = value as? Object {
            for key in ["metadata", "extensions", "renderArtifacts"] {
                if let dictionary = object[key] as? Object, !dictionary.isEmpty { return true }
                if let array = object[key] as? [Any], !array.isEmpty { return true }
                if let text = object[key] as? String, !text.isEmpty { return true }
            }
            return object.values.contains(where: hasAnnotations)
        }
        return (value as? [Any] ?? []).contains(where: hasAnnotations)
    }
    private static func matches(_ identity: String, _ text: String) -> Bool {
        // Unknown plugin references may use URI fragments or differently cased UUIDs.
        UUID(uuidString: identity) == nil ? text == identity : text.range(of: identity, options: .caseInsensitive) != nil
    }
    private static func occurrences(_ identity: String, in value: Any) -> Int {
        if let object = value as? Object {
            return object.reduce(0) { $0 + (matches(identity, $1.key) ? 1 : 0) + occurrences(identity, in: $1.value) }
        }
        if let array = value as? [Any] { return array.reduce(0) { $0 + occurrences(identity, in: $1) } }
        return (value as? String).map { matches(identity, $0) ? 1 : 0 } ?? 0
    }

}
