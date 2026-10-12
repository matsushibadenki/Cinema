# Story Graph interoperability

Cinema's **File → Import → Story Graph…** command imports a JSON file into a new, unsaved Cinema document. The current document and the source file are left intact. Save the imported project as `.cinemaboard`; its `story-graph-source.json` member retains the complete imported JSON for subsequent exports.

## Supported files

- `workspace.story.json`: `komyaku-story-workspace` versions 1, 2, and 3.
- `story.workspace.json`: Canonical Story Workspace v1 containing the `komyaku.storygraph.native-v1` adapter.
- Legacy v2 `komyaku.canonicalDocuments` references are resolved and retained.
- Files are limited to 128 MiB; native graphs to 256 nodes and 1,024 edges. Future versions, invalid references, and unrelated JSON are rejected.

This is a snapshot exchange. `.komyaku` ZIP archives, journal replay, history databases, and shared workspaces without the native adapter are not supported. Export a JSON snapshot from Story Graph before importing into Cinema. Do not use a live workspace checkpoint as a substitute for its outstanding journal.

## Mapping and preservation

Each Story Graph scene becomes one Cinema cut/scene with the original scene UUID. The scene title maps to the Cinema section heading; canonical manuscript text maps to action text. Block/sequence ancestry determines ordering. Graph hierarchy, branches, characters, relationships, paths, state rules, positions, and extensions remain in the retained source even when Cinema does not expose editors for them.

**File → Export → Story Graph…** preserves the imported envelope version and shared/native representation. Unchanged shared-workspace fixtures round-trip with semantic JSON equality. The native envelope gets a new generation token. Project title, scene headings, and manuscript edits are reflected in their corresponding native/shared fields. Added Cinema cuts within an existing scene are concatenated in cut order. Situation, action, and nonempty dialogue are exported in that order; dialogue uses `speaker: dialogue`.

Unchanged rich text, embedded image records, metadata, and paragraph IDs survive export. Editing a single plain paragraph retains its ID and attributes. Edits confined to one existing text run also retain its marks, paragraph IDs/attributes, images, and surrounding paragraphs; Unicode character boundaries are respected. An insertion exactly between two runs is ambiguous and is rejected. Edits crossing formatting or paragraph boundaries, or modifying image projections, require **File → Edit Story Graph Manuscript…** edits existing canonical text runs explicitly, including bold, italic, underline, strike and code marks. Multiple runs and paragraphs can be edited in one Apply operation without the ambiguity of a plain-text diff. Existing link destinations and mark attributes, images, code blocks, paragraph IDs and graph topology are retained. Apply updates the retained graph snapshot and the Cinema action text together, preserving Cinema media/settings. Reset discards the current draft; Discard and Close leaves the document unchanged. Scene switching is disabled until the draft is applied or reset. The editor currently requires an imported scene represented by one Cinema cut with empty situation/dialogue fields. It rejects drafts if the canonical manuscript changed. Paragraph creation/removal, image/code editing, link destination editing and branch editing remain unfinished.

**File → Export → Story Graph (New Graph)…**, preventing a silent loss of formatting or paragraph references. Adding, removing, or reordering imported scenes also requires the new-graph option, because Cinema cannot safely infer changes to existing branches and state rules.

**File → Export → Story Graph (New Graph)…** produces a standalone native v1 file with one block, one sequence, and sequential scene edges. It exports current scene titles and plain manuscript text. It does not transfer original graph annotations, rich formatting, or Cinema images, videos, audio, timing, or generation settings. Preserve those in the Cinema project; the original source remains embedded there.

## 日本語

「ファイル → Story Graph 本文を編集…」から、既存のテキスト範囲と太字・斜体・下線・取り消し線・コード書式を編集できます。「適用」で本文と保持中のグラフを一括更新します。リンク・段落ID・画像・分岐・Cinemaのメディアは保持されます。対象は読み込んだ1カットのシーンで、状況・台詞欄が空の場合です。段落の追加・削除、リンク先・分岐の編集は未対応です。

「ファイル → インポート → Story Graph…」でJSONを新しいCinema書類として開きます。「ファイル → エクスポート → Story Graph…」は元のグラフ構造・書式・未編集情報を保持します。シーンの追加・削除・並べ替え、書式付き本文は、同じ書式のテキスト範囲内の編集を元の書式・段落ID・画像を保持して書き戻せます。書式・段落・画像の境界をまたぐ編集後は「ファイル → エクスポート → Story Graph（新しいグラフ）…」で現在の内容をプレーンテキストの直列グラフとして出力してください。動画・画像・音声などCinema独自の情報は`.cinemaboard`に保存します。`.komyaku`アーカイブや履歴・ジャーナルの読み込みには未対応です。

## 简体中文

通过“文件 → 编辑 Story Graph 正文…”编辑已有文本范围及粗体、斜体、下划线、删除线和代码格式。“应用”同时更新正文与保存的图。保留链接、段落ID、图像、分支和Cinema媒体。当前仅支持导入后包含一个镜头且情境、台词为空的场景。尚不支持增删段落、编辑链接目标或分支。

通过“文件 → 导入 → Story Graph…”将JSON打开为新的Cinema文档。“文件 → 导出 → Story Graph…”保留原图结构、格式和未编辑数据。增删或重新排序场景、富文本可在同一格式的文本范围内编辑并保留格式、段落ID和图像。跨越格式、段落或图像边界后，请选择“文件 → 导出 → Story Graph（新图）…”，以纯文本和顺序连接生成新图。Cinema的视频、图像和音频等信息保存在`.cinemaboard`中。目前不支持`.komyaku`归档、历史记录和日志重放。

## Copied reference material

Copied on 2026-10-09 from the user-provided `story-graph` symlink (KOMYAKU `samples/story-graph`). `StoryGraphReference/` contains verbatim storage, adapter, canonical-document, rich-text, and domain source snapshots, the loader excerpt, and upstream package metadata (MIT OR Apache-2.0). The implementation does not compile or load those Rust sources. Tests use the copied `Tests/CinemaTests/Fixtures/story-workspace-v1.json`. No build, runtime, or test path depends on the symlink.

Validation: Swift bridge tests cover the copied real fixture, versions 1–3, central document references, editing, new graph export, rich-text protection, invalid versions/references, and Cinema package reopening. Actual import into the external Story Graph application remains a separate integration check.
