# Cinema Scene Bundle v1

Cinema Scene Bundleは、Cinemaと外部のGoogle Colab、GPUワーカー、オープンウェイトモデル実行環境の間で、シーン生成に必要な情報を受け渡すための形式です。Cinema本体にモデル固有の実行処理を組み込まず、制作データと推論環境を分離します。

## Directory Layout

```text
<scene>_cinema_bundle_v1/
├── manifest.json
├── README.txt
├── prompts/
│   ├── scene.txt
│   ├── world-state.txt
│   ├── cut-001-image.txt
│   └── cut-001-video.txt
├── storyboard/
│   └── cut-001.png
└── references/
    └── <reference-uuid>.png
```

画像が未生成、または画像データが見つからない場合、そのファイルは省略され、`manifest.json`の`warnings`へ記録されます。

## Compatibility Contract

- `format`は`cinema.scene-bundle`です。
- `schemaVersion`はマニフェスト構造のSemantic Versioningです。未知のmajor versionは読み込みを停止し、未知のminor/patch fieldは無視してください。
- `promptVersion`はプロンプト組み立て規約のversionです。生成結果の再現性を追跡する際に保存してください。
- マニフェスト内のasset pathとprompt pathは、すべてbundle rootからの相対pathです。
- API key、認証token、ユーザー環境の絶対pathは書き出しません。
- JSON consumerは未知のfieldを許容してください。既存fieldの意味変更はmajor version更新時だけ行います。

## Manifest Contents

`manifest.json`には次の情報が含まれます。

- Project context、drawing preset、film profile / recipe / creative preset ID
- Scene State、persistent rules、event graph、audio continuity
- Aspect ratioと表示label
- Image / video providerとmodel名、Cinema version
- Cut metadata、dialogue、duration、seed、AI shot settings、Shot Delta
- Reference IDとbundle内asset path
- Scene / world-state / cut単位のprompt path
- 欠落assetなどのwarning

## Runner Flow

1. `manifest.json`の`format`と`schemaVersion`を検証します。
2. runnerが対応するimageまたはvideo promptを読み込みます。
3. `references`と`storyboardImagePath`の相対pathをbundle rootから解決します。
4. provider固有のparameterへaspect ratio、duration、seed、negative promptを割り当てます。
5. 出力と共に元のmanifest、model revision、実効parameterを保存します。

外部runnerはCinemaのAPI key設定を参照せず、実行環境側のsecret storageを使用してください。
