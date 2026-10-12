# 同期Bundle v2 / Sync Bundle v2 / 同步Bundle v2

この形式は確定音声を使う外部同期処理向けです。従来の画像・動画生成用Scene Bundle v1は引き続き独立して使用できます。Cinema自体はTTSや口形補正を実行しません。

This format hands locked audio to an external synchronization worker. Existing Scene Bundle v1 remains available for reference-image generation. Cinema does not run TTS or lip-sync inference.

此格式用于向外部同步处理器传递确定音频。原有Scene Bundle v1仍可用于参考图像生成。Cinema不会执行TTS或口型修正推理。

## Scene export

Voice / Performanceのシーン選択から「同期Bundle v2を書き出す」を使用します。すべての発話に確定音声を割り当て、有効な時間範囲にしてください。書き出し後にCinemaプロジェクトを保存してください。結果の読み込みには、保存されたreceiptが必要です。

`performance_scene_v2_<UUID>/manifest.json` contains:

- `format`: `cinema.scene-bundle`; `schemaVersion`: `2.0.0`.
- `receipt`: bundle/project/scene identities, original cues, background audio clips, dialogue snapshots, character profiles, original audio metadata and SHA-256 hashes.
- `performance`: 48,000-tick timing, dialogue text, character voices, asset-relative alignment and source offsets. `audioClips` carries scene-relative music/ambience placements with `id`, `sceneID`, `audioAssetID`, `lane` (`music` or `ambience`), `start`, `end`, and `sourceOffset` (each time is an object containing integer `ticks`). Each clip plays once; loops are not applied. Optional `mix` on dialogue cues and background clips contains `volume` (linear gain 0–1), `fadeIn` and `fadeOut` (tick objects). Missing `mix` means unity gain and no fades. Fade durations are relative to the placed region; their sum must not exceed its length. Cinema applies linear ramps on export. Native video audio is retained at its original volume when enabled. Returned audio must be dry, without baking these gain/fade settings, to avoid applying them twice. Asset paths refer to `audio/<assetID>.<extension>`.
- `cuts`, `projectContext`, `drawingSettings`: scene script, camera and visual context. Reference image bytes are not included; use v1 when the worker requires visual references.

Keep IDs and ticks unchanged. Cue timing is scene-relative; alignment timing is audio-asset-relative. Swift Codable dates use seconds since 2001-01-01 UTC. Workers may ignore date fields.

## Result import

Choose the directory containing the result `manifest.json` with 「同期結果Bundleを読み込む」.

```json
{
  "format": "cinema.result-bundle",
  "schemaVersion": "2.0.0",
  "sourceBundleID": "<receipt.bundleID>",
  "projectID": "<receipt.projectID>",
  "sceneID": "<receipt.sceneID>",
  "runner": "worker-name",
  "modelRevision": "immutable-model-revision",
  "outputs": [
    {
      "dialogueID": "<dialogueID>",
      "audioPath": "outputs/voice.wav",
      "alignment": {
        "format": "cinema.audio-alignment",
        "schemaVersion": "1.0.0",
        "timescale": 48000,
        "audioAssetID": "<original-locked-audio-ID>",
        "segments": []
      },
      "videoPath": "outputs/cut.mp4"
    }
  ]
}
```

At least one of `audioPath`, `alignment`, `videoPath` is required per output. Omit fields that are absent. One output per dialogue is allowed. `audioPath` must be readable by AVAudioFile (PCM WAV recommended); video must have a valid video track and positive duration. Alignment references the original audio ID even when new audio is returned; intervals must fit the returned audio duration. Video is attached to that dialogue's cut, not automatically assembled into a scene.

Cinema checks project/scene/source IDs, original audio hashes, dialogue and voice metadata, cue revisions, alignment ranges and all media before committing. A failed import leaves the document unchanged. Relative paths must stay inside the result directory, including resolved symbolic links. Re-importing the same source bundle is rejected.

Successful imports create a new audio take and increment the cue revision. Original assets remain available. Runner/model provenance is recorded; save the project after import. Export a fresh bundle for the next iteration.

## Scene audio preview

「シーン音声プレビュー」で配置した発話・音楽・環境音をまとめて再生できます。音量とフェードは書き出しと同じ処理です。再生／一時停止、停止（先頭に戻る）、再生位置スライダーに対応します。準備中も停止してキャンセルできます。シーン・配置・素材を編集した場合は再生を停止し、次の再生で更新します。音声のみモードでは元動画の音声を含みません。動画モードでは最新のシーン動画と同期再生し、「元動画の音声も残す」で元音声を切り替えられます。素材単体の試聴と混合プレビューは同時に再生しません。

The scene audio preview uses the export composition and mix pipeline, without producing an output file. Temporary source files remain available while the player owns the composition and are removed on invalidation/close. Audio-only mode previews placed dialogue, music and ambience. Video-and-audio mode defaults to the latest scene video and can select any take belonging to the scene, with optional native video audio controlled by the same retention toggle as export. Embedded media and saved-project movies are copied into temporary sources before playback. One player controls video, mixed audio and seeking; the timeline extends to the video duration. Placements exceeding the video duration are rejected rather than trimmed. The preview does not perform lip-sync inference.

场景音频预览使用与导出相同的混音处理。支持播放、暂停、停止和位置调整；准备期间也可以停止并取消。编辑场景、安排或素材后重置预览。仅音频模式播放安排的对白、音乐和环境音。视频与音频模式同步播放最新场景视频，可通过保留原视频音频选项切换原音频。预览不执行口型修正。


## Lane mute / solo and playhead

`performance.plan.laneStates` contains scene-local controls: `sceneID`, `lane` (`dialogue`, `music`, `ambience`), `isMuted`, `isSolo`. Missing controls mean all lanes play normally. Multiple solo lanes can play together; mute takes priority over solo. A solo lane without clips still suppresses other lanes. Muted placements retain their tracks and duration with effective gain zero. Original video audio retained by the export toggle is unaffected by these placed-audio lane controls.

レーンのミュート／ソロはプレビューと書き出しに適用し、プロジェクトと同期Bundleに保存します。変更した場合は古い結果を拒否します。各バーの縦線は共通のシーン再生時刻です。プレビュー準備後はバーをクリックして移動できます。

轨道的静音与独奏应用于试听和导出，并保存到项目与同步Bundle。更改后拒绝旧结果。多个独奏轨道可同时播放，静音优先。各时间条的竖线对应同一场景播放时刻，预览准备后可点击时间条调整位置。


## Take selection and frame inspection

動画モードの「動画テイク」で最新または過去のシーン動画を選べます。切り替えると再生を停止し、次の再生で選択した動画を準備します。テイク選択はプレビュー用で、書き出しの最新動画選択は変更しません。「1コマ戻る／進む」は動画準備後に使用でき、再生を一時停止して前後のフレームに移動します。初回はフレーム時刻を読み込みます。停止・シーン切り替え・画面を閉じる操作で準備をキャンセルできます。

Frame inspection reads compressed sample timestamps without decoding every video frame, uses AVAssetReader output timestamps corrected for track edits, excludes non-frame control markers and caches sorted playback timestamps for the selected take. It supports irregular frame intervals, stops at the first/last frame and caps the index at 500,000 timestamps. Changing take clears the cache. Precise seeking uses a high-resolution media clock; the UI displays milliseconds. Inspection does not modify media or generate new frames.

视频模式可选择最新或以前的场景视频版本。切换后停止播放，下次播放时准备选定的视频。「上一帧／下一帧」在视频准备后可用，会暂停播放并跳转到前后帧。首次使用时读取帧时间，停止或关闭界面可取消。版本选择仅用于预览，不改变导出的默认最新视频。

## Preview range inspection

The scene preview can repeat a selected start/end range. Choose a dialogue cue to include 0.2 seconds before and after it (clamped to the preview duration), or enter seconds / use the current playhead as an endpoint. Ranges must be finite, within the preview duration and at least 0.05 seconds long. Pausing retains the range; stopping returns to scene time zero and retains the range; playing then starts inside the selected range. Editing media/timing or switching takes resets it.

This is temporary inspection state, excluded from project documents, bundles and exports. AVPlayer seeks back at the endpoint; the loop does not promise gapless playback or perform lip-sync correction.
