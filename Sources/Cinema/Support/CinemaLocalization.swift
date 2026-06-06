import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case japanese = "ja"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .japanese:
            return "日本語"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    static func value(for rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .japanese
    }
}

enum CinemaTextKey: String {
    case storyboard
    case drawingSettings
    case previousPage
    case nextPage
    case fullCanvas
    case zoomOut
    case zoomIn
    case actualSize
    case hideReference
    case showReference
    case print
    case title
    case block
    case sequence
    case scene
    case cut
    case screen
    case content
    case dialogue
    case seconds
    case page
    case deletePage
    case goToCut
    case addCutAbove
    case addCutBelow
    case deleteCut
    case addBlock
    case addCut
    case ai
    case costLimitExceeded
    case drawingPreset
    case video
    case estimatedTokens
    case estimatedCost
    case limit
    case exportPrompt
    case generating
    case createSelectedSceneVideo
    case saveGeneratedVideo
    case selectScene
    case includeCutInVideo
    case reorderCut
    case cutName
    case reference
    case properties
    case addPhoto
    case noPhotos
    case delete
    case details
    case deleteSection
    case deleteField
    case addField
    case addSection
    case typography
    case font
    case size
    case textColor
    case style
    case bold
    case italic
    case underline
    case letterSpacing
    case lineSpacing
    case alignment
    case applyToSelection
    case language
    case documentAspectRatio
    case screenSize
    case screenFrameDescription
    case placeholder
    case showGeneratePlaceholder
    case screenBackground
    case brightness
    case contentAndDialogue
    case width
    case textSize
    case small
    case standard
    case large
    case extraLarge
    case contentDialogueWidthDescription
    case aiGeneration
    case displaySettings
    case imageGenerationService
    case videoGenerationService
    case getGoogleAIStudio
    case getOpenAIPlatform
    case fetchingModels
    case refreshModels
    case recommendedModels
    case fetchedModels
    case customDirectInput
    case enterModelName
    case geminiModelHelp
    case openAIModelHelp
    case costLimiter
    case enableCostLimit
    case limitUSD
    case currentEstimatedCost
    case costLimiterHelp
}

enum CinemaStrings {
    static func text(_ key: CinemaTextKey, language rawLanguage: String) -> String {
        let language = AppLanguage.value(for: rawLanguage)
        switch language {
        case .japanese:
            return japanese[key] ?? key.rawValue
        case .english:
            return english[key] ?? japanese[key] ?? key.rawValue
        case .simplifiedChinese:
            return simplifiedChinese[key] ?? japanese[key] ?? key.rawValue
        }
    }

    static func blockName(_ number: Int, language rawLanguage: String) -> String {
        switch AppLanguage.value(for: rawLanguage) {
        case .japanese:
            return "ブロック\(number)"
        case .english:
            return "Block \(number)"
        case .simplifiedChinese:
            return "区块\(number)"
        }
    }

    static func pageSummary(page: Int, rangeText: String, sceneTitle: String?, language rawLanguage: String) -> String {
        let pageLabel = text(.page, language: rawLanguage)
        if let sceneTitle, !sceneTitle.isEmpty {
            return "\(pageLabel) \(page)  /  \(sceneTitle)  /  \(rangeText)"
        }
        return "\(pageLabel) \(page)  /  \(rangeText)"
    }

    static func fetchError(_ error: String, language rawLanguage: String) -> String {
        switch AppLanguage.value(for: rawLanguage) {
        case .japanese:
            return "取得エラー: \(error)"
        case .english:
            return "Fetch error: \(error)"
        case .simplifiedChinese:
            return "获取错误：\(error)"
        }
    }

    static func fetchComplete(count: Int, language rawLanguage: String) -> String {
        switch AppLanguage.value(for: rawLanguage) {
        case .japanese:
            return "取得完了 (\(count)個のモデル)"
        case .english:
            return "Fetched \(count) models"
        case .simplifiedChinese:
            return "获取完成（\(count) 个模型）"
        }
    }

    private static let japanese: [CinemaTextKey: String] = [
        .storyboard: "絵コンテ",
        .drawingSettings: "描画設定",
        .previousPage: "前ページ",
        .nextPage: "次ページ",
        .fullCanvas: "全面",
        .zoomOut: "縮小",
        .zoomIn: "拡大",
        .actualSize: "実寸",
        .hideReference: "リファレンスを非表示",
        .showReference: "リファレンスを表示",
        .print: "プリント",
        .title: "タイトル",
        .block: "ブロック",
        .sequence: "シーケンス",
        .scene: "シーン",
        .cut: "カット",
        .screen: "画面",
        .content: "内容",
        .dialogue: "セリフ",
        .seconds: "秒",
        .page: "Page",
        .deletePage: "このページを削除",
        .goToCut: "このカットへ移動",
        .addCutAbove: "この上にカットを追加",
        .addCutBelow: "この下にカットを追加",
        .deleteCut: "このカットを削除",
        .addBlock: "ブロックを追加",
        .addCut: "カットを追加",
        .ai: "AI",
        .costLimitExceeded: "推定料金が上限を超えています",
        .drawingPreset: "描画プリセット",
        .video: "動画化",
        .estimatedTokens: "推定トークン",
        .estimatedCost: "推定料金",
        .limit: "上限",
        .exportPrompt: "プロンプト書き出し",
        .generating: "生成中...",
        .createSelectedSceneVideo: "選択シーンの動画作成",
        .saveGeneratedVideo: "生成動画を保存",
        .selectScene: "シーンを選択してください",
        .includeCutInVideo: "このカットを動画化に含める",
        .reorderCut: "ドラッグしてカットを並べ替え",
        .cutName: "カット名",
        .reference: "リファレンス",
        .properties: "プロパティ",
        .addPhoto: "写真を登録",
        .noPhotos: "登録写真なし",
        .delete: "削除",
        .details: "詳細情報",
        .deleteSection: "セクションを削除",
        .deleteField: "項目を削除",
        .addField: "項目を追加",
        .addSection: "セクションを追加",
        .typography: "書体",
        .font: "フォント",
        .size: "サイズ",
        .textColor: "文字色",
        .style: "形態",
        .bold: "ボールド",
        .italic: "イタリック",
        .underline: "下線",
        .letterSpacing: "字間",
        .lineSpacing: "行間",
        .alignment: "揃え",
        .applyToSelection: "選択文字に適用",
        .language: "言語",
        .documentAspectRatio: "ドキュメントの画面比率",
        .screenSize: "画面サイズ",
        .screenFrameDescription: "画面欄は選択した比率の白いフレームで表示し、余白は黒ベタになります。",
        .placeholder: "プレースホルダー",
        .showGeneratePlaceholder: "未生成の画面にGenerate表示を出す",
        .screenBackground: "画面背景",
        .brightness: "明度",
        .contentAndDialogue: "内容 / セリフ",
        .width: "幅",
        .textSize: "文字サイズ",
        .small: "小",
        .standard: "標準",
        .large: "大",
        .extraLarge: "特大",
        .contentDialogueWidthDescription: "内容 / セリフの幅を広げると、その分だけ画面欄が狭くなります。文字量が多い場合は選択サイズから自動で縮小します。",
        .aiGeneration: "AI生成",
        .displaySettings: "画面表示",
        .imageGenerationService: "画像生成サービス",
        .videoGenerationService: "動画生成サービス",
        .getGoogleAIStudio: "Google AI Studioで取得",
        .getOpenAIPlatform: "OpenAI Platformで取得",
        .fetchingModels: "モデル一覧を取得中...",
        .refreshModels: "モデル一覧を更新",
        .recommendedModels: "推奨モデル",
        .fetchedModels: "取得されたモデル",
        .customDirectInput: "その他 (直接入力)",
        .enterModelName: "モデル名を直接入力",
        .geminiModelHelp: "画像と動画で別のモデル名を指定できます。Google側の正式モデル名が異なる場合はここで変更できます。",
        .openAIModelHelp: "画像と動画で別のモデル名を指定できます。Soraなど動画モデル名もここで変更できます。",
        .costLimiter: "利用料金リミッター",
        .enableCostLimit: "推定料金の上限を有効にする",
        .limitUSD: "上限 USD",
        .currentEstimatedCost: "現在の推定料金",
        .costLimiterHelp: "上限を超えるとドキュメント側のAI枠が赤く警告され、追加の画像/動画生成は止めます。"
    ]

    private static let english: [CinemaTextKey: String] = [
        .storyboard: "Storyboard",
        .drawingSettings: "Drawing Settings",
        .previousPage: "Previous Page",
        .nextPage: "Next Page",
        .fullCanvas: "Fill",
        .zoomOut: "Zoom Out",
        .zoomIn: "Zoom In",
        .actualSize: "Actual Size",
        .hideReference: "Hide Reference",
        .showReference: "Show Reference",
        .print: "Print",
        .title: "Title",
        .block: "Block",
        .sequence: "Sequence",
        .scene: "Scene",
        .cut: "Cut",
        .screen: "Screen",
        .content: "Content",
        .dialogue: "Dialogue",
        .seconds: "Sec",
        .page: "Page",
        .deletePage: "Delete This Page",
        .goToCut: "Go to This Cut",
        .addCutAbove: "Add Cut Above",
        .addCutBelow: "Add Cut Below",
        .deleteCut: "Delete This Cut",
        .addBlock: "Add Block",
        .addCut: "Add Cut",
        .ai: "AI",
        .costLimitExceeded: "Estimated cost exceeds the limit",
        .drawingPreset: "Drawing Preset",
        .video: "Video",
        .estimatedTokens: "Estimated Tokens",
        .estimatedCost: "Estimated Cost",
        .limit: "Limit",
        .exportPrompt: "Export Prompts",
        .generating: "Generating...",
        .createSelectedSceneVideo: "Create Video for Scene",
        .saveGeneratedVideo: "Save Generated Video",
        .selectScene: "Select a scene",
        .includeCutInVideo: "Include this cut in the video",
        .reorderCut: "Drag to reorder cuts",
        .cutName: "Cut Name",
        .reference: "Reference",
        .properties: "Properties",
        .addPhoto: "Add Photo",
        .noPhotos: "No Photos",
        .delete: "Delete",
        .details: "Details",
        .deleteSection: "Delete Section",
        .deleteField: "Delete Field",
        .addField: "Add Field",
        .addSection: "Add Section",
        .typography: "Typography",
        .font: "Font",
        .size: "Size",
        .textColor: "Text Color",
        .style: "Style",
        .bold: "Bold",
        .italic: "Italic",
        .underline: "Underline",
        .letterSpacing: "Letter Spacing",
        .lineSpacing: "Line Spacing",
        .alignment: "Alignment",
        .applyToSelection: "Apply to Selection",
        .language: "Language",
        .documentAspectRatio: "Document Screen Aspect Ratio",
        .screenSize: "Screen Size",
        .screenFrameDescription: "The screen column uses the selected ratio as a white frame, with black fill in the margins.",
        .placeholder: "Placeholder",
        .showGeneratePlaceholder: "Show Generate on empty screens",
        .screenBackground: "Screen Background",
        .brightness: "Brightness",
        .contentAndDialogue: "Content / Dialogue",
        .width: "Width",
        .textSize: "Text Size",
        .small: "Small",
        .standard: "Standard",
        .large: "Large",
        .extraLarge: "Extra Large",
        .contentDialogueWidthDescription: "Widening Content / Dialogue narrows the screen column. Dense text automatically scales down from the selected size.",
        .aiGeneration: "AI Generation",
        .displaySettings: "Display",
        .imageGenerationService: "Image Generation Service",
        .videoGenerationService: "Video Generation Service",
        .getGoogleAIStudio: "Get from Google AI Studio",
        .getOpenAIPlatform: "Get from OpenAI Platform",
        .fetchingModels: "Fetching models...",
        .refreshModels: "Refresh Models",
        .recommendedModels: "Recommended Models",
        .fetchedModels: "Fetched Models",
        .customDirectInput: "Other (direct input)",
        .enterModelName: "Enter model name",
        .geminiModelHelp: "You can specify separate model names for images and videos. Change them here if Google's official model names differ.",
        .openAIModelHelp: "You can specify separate model names for images and videos. Video models such as Sora can also be changed here.",
        .costLimiter: "Cost Limiter",
        .enableCostLimit: "Enable estimated cost limit",
        .limitUSD: "Limit USD",
        .currentEstimatedCost: "Current Estimated Cost",
        .costLimiterHelp: "When the limit is exceeded, the document AI panel turns red and additional image/video generation is stopped."
    ]

    private static let simplifiedChinese: [CinemaTextKey: String] = [
        .storyboard: "分镜",
        .drawingSettings: "绘图设置",
        .previousPage: "上一页",
        .nextPage: "下一页",
        .fullCanvas: "铺满",
        .zoomOut: "缩小",
        .zoomIn: "放大",
        .actualSize: "实际大小",
        .hideReference: "隐藏参考",
        .showReference: "显示参考",
        .print: "打印",
        .title: "标题",
        .block: "区块",
        .sequence: "序列",
        .scene: "场景",
        .cut: "镜头",
        .screen: "画面",
        .content: "内容",
        .dialogue: "台词",
        .seconds: "秒",
        .page: "页",
        .deletePage: "删除此页",
        .goToCut: "跳转到此镜头",
        .addCutAbove: "在上方添加镜头",
        .addCutBelow: "在下方添加镜头",
        .deleteCut: "删除此镜头",
        .addBlock: "添加区块",
        .addCut: "添加镜头",
        .ai: "AI",
        .costLimitExceeded: "预计费用已超过上限",
        .drawingPreset: "绘图预设",
        .video: "视频化",
        .estimatedTokens: "预计 Token",
        .estimatedCost: "预计费用",
        .limit: "上限",
        .exportPrompt: "导出提示词",
        .generating: "生成中...",
        .createSelectedSceneVideo: "生成所选场景视频",
        .saveGeneratedVideo: "保存生成视频",
        .selectScene: "请选择场景",
        .includeCutInVideo: "将此镜头加入视频",
        .reorderCut: "拖动以重新排序镜头",
        .cutName: "镜头名",
        .reference: "参考",
        .properties: "属性",
        .addPhoto: "添加照片",
        .noPhotos: "没有照片",
        .delete: "删除",
        .details: "详细信息",
        .deleteSection: "删除分区",
        .deleteField: "删除项目",
        .addField: "添加项目",
        .addSection: "添加分区",
        .typography: "字体",
        .font: "字体",
        .size: "大小",
        .textColor: "文字颜色",
        .style: "样式",
        .bold: "粗体",
        .italic: "斜体",
        .underline: "下划线",
        .letterSpacing: "字距",
        .lineSpacing: "行距",
        .alignment: "对齐",
        .applyToSelection: "应用到所选文字",
        .language: "语言",
        .documentAspectRatio: "文档画面比例",
        .screenSize: "画面尺寸",
        .screenFrameDescription: "画面栏会以所选比例显示白色边框，空白区域以黑色填充。",
        .placeholder: "占位符",
        .showGeneratePlaceholder: "在未生成的画面中显示 Generate",
        .screenBackground: "画面背景",
        .brightness: "亮度",
        .contentAndDialogue: "内容 / 台词",
        .width: "宽度",
        .textSize: "文字大小",
        .small: "小",
        .standard: "标准",
        .large: "大",
        .extraLarge: "特大",
        .contentDialogueWidthDescription: "加宽内容 / 台词栏会相应缩窄画面栏。文字较多时会从所选大小自动缩小。",
        .aiGeneration: "AI 生成",
        .displaySettings: "画面显示",
        .imageGenerationService: "图像生成服务",
        .videoGenerationService: "视频生成服务",
        .getGoogleAIStudio: "从 Google AI Studio 获取",
        .getOpenAIPlatform: "从 OpenAI Platform 获取",
        .fetchingModels: "正在获取模型列表...",
        .refreshModels: "刷新模型列表",
        .recommendedModels: "推荐模型",
        .fetchedModels: "已获取的模型",
        .customDirectInput: "其他（直接输入）",
        .enterModelName: "直接输入模型名",
        .geminiModelHelp: "图像和视频可以指定不同的模型名。如果 Google 官方模型名不同，可在此修改。",
        .openAIModelHelp: "图像和视频可以指定不同的模型名。Sora 等视频模型名也可在此修改。",
        .costLimiter: "费用限制器",
        .enableCostLimit: "启用预计费用上限",
        .limitUSD: "上限 USD",
        .currentEstimatedCost: "当前预计费用",
        .costLimiterHelp: "超过上限时，文档侧的 AI 面板会变红警告，并停止追加图像/视频生成。"
    ]
}
