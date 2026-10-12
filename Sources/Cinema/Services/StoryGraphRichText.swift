import Foundation

/// Edits one existing text run without inventing formatting or paragraph boundaries.
enum StoryGraphRichText {
    private struct Run {
        var path: [Int]
        var range: Range<Int>
    }

    static func replacing(_ canonical: StoryGraphService.Object, with text: String) throws -> StoryGraphService.Object {
        let original = try StoryGraphService.plainText(canonical)
        guard original != text else { return canonical }
        let before = Array(original), after = Array(text)
        var start = 0
        while start < min(before.count, after.count), before[start] == after[start] { start += 1 }
        var end = before.count, replacementEnd = after.count
        while end > start, replacementEnd > start, before[end - 1] == after[replacementEnd - 1] {
            end -= 1; replacementEnd -= 1
        }
        var runs: [Run] = []
        var offset = 0
        func walk(_ node: StoryGraphService.Object, path: [Int], depth: Int) throws {
            guard depth < 32 else { throw StoryGraphService.BridgeError.tooLarge }
            let type = node["type"] as? String ?? ""
            if type == "text" {
                let count = (node["text"] as? String ?? "").count
                runs.append(Run(path: path, range: offset..<(offset + count)))
                offset += count
            } else if ["image", "hard_break", "horizontal_rule"].contains(type) || (type == "code_block" && node["source"] is String) {
                offset += try StoryGraphService.plainText(node).count
            } else {
                guard let children = node["content"] as? [StoryGraphService.Object] else { throw StoryGraphService.BridgeError.invalid }
                let separatorLength = ["paragraph", "heading", "code_block"].contains(type) ? 0 : 1
                for (index, child) in children.enumerated() {
                    if index > 0 { offset += separatorLength }
                    try walk(child, path: path + [index], depth: depth + 1)
                }
            }
        }
        try walk(canonical, path: [], depth: 0)
        // At a formatting boundary an insertion has two possible owners. Do not guess.
        let candidates = runs.filter { $0.range.lowerBound <= start && end <= $0.range.upperBound }
        guard candidates.count == 1, let run = candidates.first else { throw StoryGraphService.BridgeError.richTextChanged }
        func update(_ node: StoryGraphService.Object, path: ArraySlice<Int>) throws -> StoryGraphService.Object {
            var result = node
            if let index = path.first {
                guard var children = node["content"] as? [StoryGraphService.Object], children.indices.contains(index) else { throw StoryGraphService.BridgeError.invalid }
                children[index] = try update(children[index], path: path.dropFirst())
                result["content"] = children
            } else {
                let value = Array(node["text"] as? String ?? "")
                let localStart = start - run.range.lowerBound, localEnd = end - run.range.lowerBound
                result["text"] = String(value[..<localStart]) + String(after[start..<replacementEnd]) + String(value[localEnd...])
            }
            return result
        }
        let result = try update(canonical, path: run.path[...])
        guard try StoryGraphService.plainText(result) == text else { throw StoryGraphService.BridgeError.richTextChanged }
        return result
    }
}
