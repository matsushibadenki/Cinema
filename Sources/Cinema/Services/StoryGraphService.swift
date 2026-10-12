import Foundation

/// Standalone JSON bridge. Contract snapshots live in doc/StoryGraphReference.
enum StoryGraphService {
    typealias Object = [String: Any]
    static let format = "komyaku-story-workspace"
    static let workspaceSchema = "https://komyaku.example/schemas/story-workspace/v1"
    static let documentSchema = "https://komyaku.example/schemas/document/v1"
    static let adapter = "komyaku.storygraph.native-v1"
    static let store = "komyaku.canonicalDocuments"
    static let limit = 128 * 1024 * 1024

    enum BridgeError: Error {
        case invalid, unsupported, tooLarge, structureChanged, richTextChanged

        func message(language: String) -> String {
            let messages: (String, String, String)
            switch self {
            case .invalid:
                messages = ("Story Graphファイルの構造または参照が不正です。", "The Story Graph file contains invalid structure or references.", "Story Graph文件的结构或引用无效。")
            case .unsupported:
                messages = ("このStory Graph形式には対応していません。workspace.story.jsonまたはstory.workspace.jsonを選択してください。", "Unsupported Story Graph format. Choose workspace.story.json or story.workspace.json.", "不支持此Story Graph格式。请选择workspace.story.json或story.workspace.json。")
            case .tooLarge:
                messages = ("Story Graphファイルがサイズ上限を超えています。", "The Story Graph file exceeds the size limit.", "Story Graph文件超出大小限制。")
            case .structureChanged:
                messages = ("読み込んだシーンの追加・削除・並べ替えは元の分岐グラフに反映できません。「新しいグラフとして書き出す」を使用してください。", "Added, removed, or reordered scenes cannot be merged into the original branching graph. Use Export as New Graph.", "无法将场景的增删或排序合并到原分支图。请使用“导出为新图”。")
            case .richTextChanged:
                messages = ("本文の変更が書式・段落・画像の境界をまたいでいます。同じ書式のテキスト内で編集するか、「新しいグラフとして書き出す」を使用してください。", "The edit crosses formatting, paragraph, or image boundaries. Edit within one text run or use Export as New Graph.", "编辑跨越了格式、段落或图像边界。请在同一格式的文本内编辑，或使用“导出为新图”。")
            }
            return language == "en" ? messages.1 : language == "zh-Hans" ? messages.2 : messages.0
        }
    }

    struct Snapshot {
        var root: Object
        var native: Object
        var workspace: Object?
        var scenes: [Object]
    }

    static func read(_ data: Data) throws -> StoryboardDocument {
        let snapshot = try parse(data)
        let cuts = try snapshot.scenes.enumerated().map { index, node -> StoryboardCut in
            guard let id = node["id"] as? String, let uuid = UUID(uuidString: id),
                  let properties = node["properties"] as? Object else { throw BridgeError.invalid }
            let canonical = try canonical(node, native: snapshot.native)
            var cut = StoryboardCut(id: uuid, cutNumber: index + 1,
                                    action: try plainText(canonical),
                                    subtitle: (properties["title"] as? String).flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 } ?? "Untitled",
                                    sceneName: properties["title"] as? String ?? "")
            cut.sceneID = uuid
            return cut
        }
        var result = StoryboardDocument(project: StoryboardProject(title: snapshot.native["title"] as? String ?? "", cuts: cuts))
        // Empty titles must not collapse independent Story Graph scenes.
        for index in result.project.cuts.indices { result.project.cuts[index].sceneID = cuts[index].id }
        result.storyGraphSource = data
        return result
    }

    static func write(_ document: StoryboardDocument, asNewGraph: Bool = false) throws -> Data {
        guard let source = document.storyGraphSource, !asNewGraph else {
            return try encode(newGraph(document.project))
        }
        var snapshot = try parse(source)
        let sections = document.project.scenes(language: "en")
        let originalIDs = snapshot.scenes.compactMap { ($0["id"] as? String).flatMap(UUID.init(uuidString:)) }
        guard sections.map(\.id) == originalIDs else { throw BridgeError.structureChanged }
        var graph = snapshot.native["graph"] as! Object
        var nodes = graph["nodes"] as! [String: Object]
        var extensions = snapshot.native["extensions"] as? Object ?? [:]
        var documents = extensions[store] as? Object
        var changedCanonicals: [String: Object] = [:]
        for (section, original) in zip(sections, snapshot.scenes) {
            let id = original["id"] as! String
            var node = original
            var properties = node["properties"] as! Object
            var canonical = try canonical(original, native: snapshot.native)
            let text = sceneText(section)
            if text != (try plainText(canonical)) {
                if isPlain(canonical) {
                    var blocks = canonical["content"] as! [Object]
                    // Keep the original paragraph identity and attributes for references.
                    blocks[0]["content"] = paragraph(text)["content"]
                    canonical["content"] = blocks
                } else {
                    canonical = try StoryGraphRichText.replacing(canonical, with: text)
                }
            }
            let subtitle = section.cuts.first?.subtitle ?? ""
            let originalTitle = properties["title"] as? String ?? ""
            properties["title"] = subtitle == "Untitled" && originalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? originalTitle : subtitle
            if documents != nil { documents?[id] = canonical }
            else { properties["canonical"] = canonical }
            node["properties"] = properties
            nodes[id] = node
            changedCanonicals[id] = canonical
        }
        if let documents { extensions[store] = documents }
        if snapshot.native["extensions"] != nil { snapshot.native["extensions"] = extensions }
        graph["nodes"] = nodes
        snapshot.native["graph"] = graph
        snapshot.native["title"] = document.project.title
        if var workspace = snapshot.workspace {
            var sharedGraph = workspace["graph"] as! Object
            var sharedNodes = sharedGraph["nodes"] as! [Object]
            var sharedDocument = workspace["document"] as! Object
            var blocks = sharedDocument["content"] as! [Object]
            for index in sharedNodes.indices {
                guard let id = sharedNodes[index]["id"] as? String,
                      let canonical = changedCanonicals[id],
                      let refs = sharedNodes[index]["documentRefs"] as? [Object],
                      let root = refs.first?["nodeId"] as? String,
                      let blockIndex = blocks.firstIndex(where: { $0["id"] as? String == root }) else { continue }
                sharedNodes[index]["title"] = (nodes[id]?["properties"] as? Object)?["title"] as? String == "" ? "Untitled" : (nodes[id]?["properties"] as? Object)?["title"]
                blocks[blockIndex]["content"] = canonical["content"]
            }
            // The adapter stores references; manuscript content occurs only once.
            var skeleton = snapshot.native
            var skeletonGraph = graph
            var skeletonNodes = nodes
            for id in changedCanonicals.keys {
                var node = skeletonNodes[id]!
                var properties = node["properties"] as! Object
                properties.removeValue(forKey: "canonical")
                node["properties"] = properties
                skeletonNodes[id] = node
            }
            skeletonGraph["nodes"] = skeletonNodes
            skeleton["graph"] = skeletonGraph
            var skeletonExtensions = extensions
            skeletonExtensions.removeValue(forKey: store)
            if skeletonExtensions.isEmpty { skeleton.removeValue(forKey: "extensions") }
            else { skeleton["extensions"] = skeletonExtensions }
            var sharedExtensions = sharedGraph["extensions"] as! Object
            sharedExtensions[adapter] = skeleton
            sharedGraph["extensions"] = sharedExtensions
            sharedGraph["nodes"] = sharedNodes
            sharedDocument["content"] = blocks
            workspace["graph"] = sharedGraph
            workspace["document"] = sharedDocument
            if snapshot.root["format"] != nil {
                snapshot.root["workspace"] = workspace
                snapshot.root["generation"] = UUID().uuidString.lowercased()
            } else { snapshot.root = workspace }
        } else {
            snapshot.root["document"] = snapshot.native
            snapshot.root["generation"] = UUID().uuidString.lowercased()
        }
        return try encode(snapshot.root)
    }

    static func parse(_ data: Data) throws -> Snapshot {
        guard data.count <= limit else { throw BridgeError.tooLarge }
        guard let root = try JSONSerialization.jsonObject(with: data) as? Object else { throw BridgeError.invalid }
        var workspace: Object?
        var native: Object
        if root["schemaId"] as? String == workspaceSchema {
            workspace = root
            native = [:]
        } else if root["format"] as? String == format {
            guard let version = root["version"] as? Int, [1, 2, 3].contains(version) else { throw BridgeError.unsupported }
            if version == 3 {
                guard root["document"] == nil, let value = root["workspace"] as? Object else { throw BridgeError.invalid }
                workspace = value
                native = [:]
            } else {
                guard root["workspace"] == nil, let value = root["document"] as? Object else { throw BridgeError.invalid }
                native = value
            }
        } else { throw BridgeError.unsupported }
        if let workspace {
            guard workspace["schemaId"] as? String == workspaceSchema, workspace["schemaVersion"] as? Int == 1,
                  let graph = workspace["graph"] as? Object,
                  let sharedDocument = workspace["document"] as? Object,
                  graph["documentId"] as? String == sharedDocument["id"] as? String,
                  let extensions = graph["extensions"] as? Object,
                  let skeleton = extensions[adapter] as? Object,
                  var nativeGraph = skeleton["graph"] as? Object,
                  var nodes = nativeGraph["nodes"] as? [String: Object],
                  let sharedNodes = graph["nodes"] as? [Object],
                  let blocks = sharedDocument["content"] as? [Object] else { throw BridgeError.invalid }
            native = skeleton
            var usedRoots = Set<String>()
            for sharedNode in sharedNodes where sharedNode["subtype"] as? String == "scene" {
                guard let id = sharedNode["id"] as? String, var node = nodes[id],
                      let refs = sharedNode["documentRefs"] as? [Object], refs.count == 1,
                      let rootID = refs.first?["nodeId"] as? String, usedRoots.insert(rootID).inserted,
                      let block = blocks.first(where: { $0["id"] as? String == rootID }),
                      let ext = block["extensions"] as? Object,
                      var canonical = ext["komyaku.scene.document"] as? Object,
                      canonical["id"] as? String == rootID,
                      var properties = node["properties"] as? Object else { throw BridgeError.invalid }
                canonical["content"] = block["content"]
                properties["canonical"] = canonical
                node["properties"] = properties
                nodes[id] = node
            }
            nativeGraph["nodes"] = nodes
            native["graph"] = nativeGraph
        }
        guard native["schema_version"] as? Int == 1,
              let graph = native["graph"] as? Object,
              let nodes = graph["nodes"] as? [String: Object], nodes.count <= 256,
              let edges = graph["edges"] as? [String: Object], edges.count <= 1024 else { throw BridgeError.invalid }
        var identities = Set<UUID>()
        for (key, node) in nodes {
            guard node["id"] as? String == key, let id = UUID(uuidString: key), identities.insert(id).inserted,
                  let properties = node["properties"] as? Object else { throw BridgeError.invalid }
            if let parent = properties["parent"] as? String, !parent.isEmpty, nodes[parent] == nil { throw BridgeError.invalid }
        }
        for edge in edges.values {
            guard let from = edge["from"] as? Object, let to = edge["to"] as? Object,
                  let fromID = from["node"] as? String, let toID = to["node"] as? String,
                  nodes[fromID] != nil, nodes[toID] != nil else { throw BridgeError.invalid }
        }
        func order(_ node: Object) -> Int { (node["properties"] as? Object)?["outlineOrder"] as? Int ?? 0 }
        func ancestry(_ node: Object) throws -> [Int] {
            var current = node
            var path = [order(node)]
            var seen = Set<String>()
            while let parent = (current["properties"] as? Object)?["parent"] as? String, !parent.isEmpty {
                guard seen.insert(parent).inserted, let ancestor = nodes[parent], path.count < 3 else { throw BridgeError.invalid }
                current = ancestor
                path.insert(order(current), at: 0)
            }
            return path
        }
        var ordered: [(Object, [Int])] = []
        for node in nodes.values where node["type_id"] as? String == "story.scene" {
            _ = try plainText(canonical(node, native: native))
            ordered.append((node, try ancestry(node)))
        }
        ordered.sort {
            $0.1 == $1.1 ? ($0.0["id"] as! String) < ($1.0["id"] as! String) : $0.1.lexicographicallyPrecedes($1.1)
        }
        return Snapshot(root: root, native: native, workspace: workspace, scenes: ordered.map(\.0))
    }

    static func canonical(_ node: Object, native: Object) throws -> Object {
        guard let properties = node["properties"] as? Object,
              var value = properties["canonical"] as? Object else { throw BridgeError.invalid }
        if let reference = value["documentRef"] as? String {
            guard reference == node["id"] as? String,
                  let extensions = native["extensions"] as? Object, let documents = extensions[store] as? Object,
                  let document = documents[reference] as? Object else { throw BridgeError.invalid }
            value = document
        }
        guard value["schemaId"] as? String == documentSchema, value["schemaVersion"] as? Int == 1,
              value["type"] as? String == "document" else { throw BridgeError.invalid }
        return value
    }

    static func plainText(_ node: Object, depth: Int = 0) throws -> String {
        guard depth < 32 else { throw BridgeError.tooLarge }
        let type = node["type"] as? String ?? ""
        if type == "text" { return node["text"] as? String ?? "" }
        if type == "hard_break" { return "\n" }
        if type == "image" {
            let caption = try (node["caption"] as? [Object] ?? []).map { try plainText($0, depth: depth + 1) }.joined()
            return (node["altText"] as? String ?? "") + caption
        }
        if type == "horizontal_rule" { return "" }
        if type == "code_block", let text = node["source"] as? String { return text }
        guard let children = node["content"] as? [Object] else { throw BridgeError.invalid }
        let separator = ["paragraph", "heading", "code_block"].contains(type) ? "" : type == "table_row" ? "\t" : "\n"
        return try children.map { try plainText($0, depth: depth + 1) }.joined(separator: separator)
    }

    static func isPlain(_ canonical: Object) -> Bool {
        guard let blocks = canonical["content"] as? [Object], blocks.count == 1 else { return false }
        return blocks.allSatisfy { block in
            guard block["type"] as? String == "paragraph", let content = block["content"] as? [Object],
                  (block["extensions"] as? Object ?? [:]).isEmpty,
                  (block["metadata"] as? Object ?? [:]).isEmpty else { return false }
            return content.allSatisfy { ($0["type"] as? String == "text") && ($0["marks"] as? [Any] ?? []).isEmpty && ($0["extensions"] as? Object ?? [:]).isEmpty && ($0["metadata"] as? Object ?? [:]).isEmpty }
        }
    }

    static func sceneText(_ section: StoryboardScene) -> String {
        section.cuts.map { cut in
            ([cut.situation, cut.action] + cut.dialogueLines.compactMap { line in
                guard !line.dialogue.isEmpty else { return nil }
                return line.speaker.isEmpty ? line.dialogue : "\(line.speaker): \(line.dialogue)"
            }).filter { !$0.isEmpty }.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    static func paragraph(_ text: String) -> Object {
        ["id": UUID().uuidString.lowercased(), "schemaVersion": 1, "type": "paragraph",
         "attrs": ["lang": NSNull(), "dir": "auto"], "metadata": Object(), "extensions": Object(),
         "renderArtifacts": [Any](), "content": text.isEmpty ? [Object]() : [["type": "text", "text": text, "marks": [Any](), "metadata": Object(), "extensions": Object()]]]
    }

    static func newGraph(_ project: StoryboardProject) throws -> Object {
        let sections = project.scenes(language: "en")
        guard sections.count <= 254 else { throw BridgeError.tooLarge }
        let blockID = UUID().uuidString.lowercased(), sequenceID = UUID().uuidString.lowercased()
        var nodes: [String: Object] = [:], edges: [String: Object] = [:], placement: Object = [:]
        func structure(_ id: String, type: String, title: String, parent: String?) -> Object {
            var props: Object = ["title": title, "notes": "", "order": 0, "outlineOrder": 0, "structure": type]
            if let parent { props["parent"] = parent }
            return ["id": id, "type_id": "story.\(type)", "properties": props, "inputs": [Any](), "outputs": [Any]()]
        }
        nodes[blockID] = structure(blockID, type: "block", title: project.title, parent: nil)
        nodes[sequenceID] = structure(sequenceID, type: "sequence", title: project.title, parent: blockID)
        func port(_ name: String, multiple: Bool = false, json: Bool = false) -> Object {
            ["name": name, "cardinality": multiple ? "multiple" : "single", "required": false,
             "data_type": json ? ["kind": "json"] : ["kind": "custom", "name": "story.flow"]]
        }
        var previous: String?
        for (index, section) in sections.enumerated() {
            let id = section.id.uuidString.lowercased()
            let canonical: Object = ["schemaId": documentSchema, "schemaVersion": 1, "id": UUID().uuidString.lowercased(), "type": "document", "attrs": ["language": "und", "direction": "auto", "writingMode": "horizontal-tb"], "metadata": Object(), "extensions": Object(), "content": [paragraph(sceneText(section))]]
            nodes[id] = ["id": id, "type_id": "story.scene", "inputs": [port("previous", multiple: true)], "outputs": [port("next"), port("document", json: true)], "properties": ["title": section.cuts.first?.subtitle ?? "", "notes": "", "order": index, "outlineOrder": index, "parent": sequenceID, "path": "both", "canonical": canonical]]
            placement[id] = ["x": Double(index % 4) * 280, "y": Double(index / 4) * 180, "width": 240.0, "height": 140.0]
            if let previous {
                let edgeID = UUID().uuidString.lowercased()
                edges[edgeID] = ["id": edgeID, "from": ["node": previous, "port": "next"], "to": ["node": id, "port": "previous"]]
            }
            previous = id
        }
        for (index, id) in [blockID, sequenceID].enumerated() { placement[id] = ["x": 0, "y": -320 + index * 150, "width": 240, "height": 110] }
        return ["format": format, "version": 1, "generation": UUID().uuidString.lowercased(), "document": ["title": project.title, "schema_version": 1, "engine_version": "0.1.0", "plugin_versions": Object(), "graph": ["id": UUID().uuidString.lowercased(), "name": project.title, "nodes": nodes, "edges": edges, "groups": Object()], "placement": placement]]
    }

    static func encode(_ value: Object) throws -> Data {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        guard data.count <= limit else { throw BridgeError.tooLarge }
        return data
    }
}
