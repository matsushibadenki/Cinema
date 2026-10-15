# Cinema Roadmap

## Image generation models

- 🟢 [Done] Add Nano Banana 2.1 (`gemini-nano-banana-2.1`), Nano Banana 2 Lite (`gemini-3.1-flash-lite-image`), `gpt-image-2.5-sunburst`, and `gpt-image-2.5-flare` to image model settings while preserving saved selections. Use Gemini Interactions with inline 1K output for the new Google models and retain OpenAI Images generation/edit routes.
- 🟢 [Done] Adjust the new Gemini models’ approximate 1K image cost using published input/output rates. OpenAI costs remain approximate per-image estimates, not invoice totals.
- ⭕️ [Pending] Confirm real image generation/editing with account model access and API keys; mocked requests do not verify provider availability or actual billing.

References: [Google image generation](https://ai.google.dev/gemini-api/docs/image-generation), [Google pricing](https://ai.google.dev/gemini-api/docs/pricing), [OpenAI Images API](https://developers.openai.com/api/reference/resources/images/methods/generate), [OpenAI pricing](https://developers.openai.com/api/docs/pricing).

## Camera and transition direction

- 🟢 [Done] Add the supplied 24-technique reference as three preset groups: camera movement, shooting/time direction, and next-cut transitions. Provide Japanese, English and Simplified Chinese labels, editable free text, and hover-only information. Preserve existing camera/transition text; decode older projects without the optional shooting-technique field. Include directions in generation prompts and structured Scene Bundle shot settings; verify project save/reopen and narrow light/dark rendering.
- ⭕️ [Pending] Evaluate actual generated camera movements, timing effects and audio transitions with selected providers or external workers. Presets are generation instructions, not automatic post-production effects.

## Story Graph interoperability

- 🟢 [Done] Place Story Graph commands under File → Import / Export and media recovery under File → Manage Project Files; scope export and recovery to the active document and allow import without an open document.

- 🟢 [Done] Import native Story Graph JSON v1/v2/v3 and shared Workspace v1 into a new Cinema document; retain source JSON inside the Cinema package.
- 🟢 [Done] Export manuscript edits while preserving original graph data, or explicitly create a new sequential graph; provide Japanese, English, and Simplified Chinese actions and errors.
- 🟢 [Done] Copy format reference sources and a real fixture into Cinema; run standalone round-trip, editing, validation, and package persistence tests without reading the symlink.
- 🟢 [Done] Write edits confined to an existing rich-text run back into the retained graph without dropping marks, paragraph identities/attributes, images or adjacent paragraphs. Respect Unicode character boundaries, reject ambiguous run-boundary insertions and changes across formatting/paragraph/image boundaries; verify package save/reopen and shared-workspace export.
- 🟢 [Done] Add File → Edit Story Graph Manuscript with explicit text-run and bold/italic/underline/strike/code controls in Japanese, English and Simplified Chinese. Apply multiple run edits atomically to canonical JSON and Cinema action text; preserve links, mark attributes, paragraph IDs, images, graph topology and Cinema media. Reject stale drafts and incompatible multi-cut/situation/dialogue scenes; verify native v1/v2/shared/v3 and package persistence.
- 🟢 [Done] Append and remove top-level manuscript paragraphs and edit/remove text-run links in the Story Graph editor. Preserve surviving IDs and link attributes; validate http/https/mailto destinations, reject stale edits, protect annotated paragraphs and incoming ID references (including UUID URI fragments), and apply changes atomically with Cinema text/media intact. Replace persistent explanatory copy with hover information and compact icon controls.
- 🟠 [Next] Add branching-topology controls with reference integrity and port/cardinality validation; extend paragraph insertion/reordering to structured nested blocks.
- 🔴 [Later] Support `.komyaku` archives and journal/history exchange.
- ⭕️ [Pending] Verify exported snapshots in the external Story Graph application and exercise native import/export panels in all three languages.

See [Story Graph interoperability](STORY_GRAPH_INTEROP.md) for supported formats and conversion limits.

## Reliability Review

- 🟢 [Done] Use the native compact unified document title bar so the filename and edited indicator share one row without the expanded toolbar height; retain macOS document title/menu behavior.

- 🟢 [Done] Split AI toolbar into a project-wide row (usage, drawing preset, frame size, project design) and a block row (selected cuts, Scene State, scene bundle exchange, recovery/video actions and generation).

- 🟢 [Done] Combine Project Design and Voice / Performance Timeline into a shared, localized tabbed sheet with the same document bindings; move Save Portable Project Copy to the File menu with active-document and generation guards.

- 🟢 [Done] Unify light-mode blocks with #eff0f0 canvas, #f5f5f5 inset surfaces, #fcfcfc panels, and #ffffff editors; use neutral text/borders and restrained indigo actions; verify native workspace rendering in Japanese, English, and Simplified Chinese.

- 🟢 [Done] Restore content/dialogue editing by sizing empty NSTextViews to the visible editor area, refreshing cell bindings, and preserving IME composition. Verify both fields in a running test app and cover empty/resized editors and long manuscripts with regression tests.

- 🟢 [Done] Add a portable project copy workflow that embeds referenced videos, includes recovered completed clips, detects missing media, and assigns an independent project identity. Verify reopening without the original movies folder.
- 🟢 [Done] Keep usage metrics and the generation action fixed while scrolling central controls; distinguish enabled buttons from disabled buttons in both appearance modes.
- 🟢 [Done] Observe document location changes and copy referenced media and project recovery records to the new sibling movies folder. Preserve original files, reject conflicting destination files, and copy clips completed after relocation when generation finishes.
- 🟢 [Done] Add media-copy retry and original movies-folder selection for recovery after reopening. Add the standard Move To command to the File menu.
- 🟢 [Done] Verify native Save As with a disposable document and confirm byte-identical media at the destination while preserving originals.
- 🟢 [Done] Localize the remaining visible generation and image-import statuses, the selected-cut caption, script display controls, and the workspace placeholder in English, Japanese, and Simplified Chinese.
- 🟢 [Done] Replace the failing macOS Move panel (ViewBridge error 14 observed on this development host) with a localized native destination-folder picker and NSDocument coordinated move. Save current edits first, preserve the project filename, reject existing destination projects, update the document URL and prevent overlapping destination panels / move requests. Verify actual NSDocument saves/moves and reopened external-video playback.
- 🟢 [Done] Exercise Move / media-copy conflict / Retry Media Copy / Choose Original movies Folder in an isolated QA app using a disposable project. Confirm the source video and conflicting destination remain intact, retry removes the pending menu entry and both recovery paths produce byte-identical videos. Preserve the user’s original unsaved window.
- 🟢 [Done] Render recovery controls, disabled-state explanations and copy-conflict details in English, Japanese and Simplified Chinese, both appearances and a 420-point fixture. Localize folder-picker titles/prompts/messages and relocation errors; retain security-scoped access during original-folder recovery.
- 🟢 [Done] Exercise native destination-folder selection and actual project moves in English and Simplified Chinese in an isolated QA app; verify byte-identical destination media and preserved source videos. Render the full workspace in all three languages and both appearances at 1000/1280-point widths. Fix clipped image-generation actions with a separate action row and make the compact preview/inspector vertically scrollable; localize image-generation labels and video-card captions/dates. System-provided panel labels follow the host OS language.

- 🟢 [Done] Fix block metadata preservation on deletion, Scene State delivery to generation, continuity resets, storyboard reference targeting, media download validation, and invalid export durations.
- 🟢 [Done] Introduce stable scene UUIDs and migrate legacy title-based state/history associations. Preserve identity through renaming, deletion of a heading cut, and reordering; keep same-name blocks independent. Ambiguous legacy combined videos remain available for manual assignment.
- 🟢 [Done] Separate external video path validation and persistence from ContentView, and support user cancellation of scene generation.
- 🟢 [Done] Snapshot provider, model, API credential, aspect ratio, references, and prompt context when scene generation starts.
- 🟢 [Done] Persist each completed clip and its generation journal atomically before proceeding to the next cut. Restore history after failure, cancellation, or reopening a document; retry assembly from a fully saved run without another AI request.
- 🟢 [Done] Migrate provider API keys from UserDefaults to the macOS Keychain, removing legacy values after a successful migration.
- 🟢 [Done] Persist project-specific aspect ratio and custom dimensions in documents, migrating legacy values from current user defaults.

See [Project Review](PROJECT_REVIEW.md) for verification scope and remaining design work.

## AI / Local Generation

- 🟢 [Done] Strengthen Cinema as an export-first authoring tool for external open-weight inference projects.
  Prioritize structured export bundles for prompts, cut metadata, scene metadata, reference images, aspect ratio, duration, continuity hints, seed, and prompt versioning so a separate Google Colab or GPU worker project can consume Cinema output without embedding runtime-specific logic into Cinema itself.

- 🟢 [Done] Design a stable handoff format between Cinema and external inference backends.
  Target JSON + text prompt files + organized image assets, with per-cut and per-scene exports, so model-specific runners such as DiffSynth-Studio notebooks can be iterated independently from the Cinema app.

- 🟢 [Done] Prepare Cinema's metadata model for future film-engine integration without embedding the renderer yet.
  Use the film-engine design notes to shape export schema, shot context, provenance capture, semantic film-look metadata, and reproducibility records while keeping Cinema focused on authoring and handoff.

- 🟢 [Done] Introduce a persistent `SceneState` design centered on Character / Object / Environment / Camera / Lighting / Event / Timeline / Audio.
  Treat these as durable scene-level truth and let each cut describe only local deltas, so Cinema can export continuity-safe bundles for prompting, rendering, and future film-engine integration.

- 🟢 [Done] Add a structured world-state prompting layer on top of `SceneState`.
  Support exportable Initial State / Persistent Rules / Event Sequence / State Transitions / Camera Observation so Cinema can generate stronger continuity-oriented prompts without pretending the model has a full symbolic world model.

- 🟢 [Done] Add an in-app Scene State editor and Scene Bundle validation preview.
  Let users review persistent state, rules, event transitions, referenced assets, and export warnings before handing the bundle to an external runner.

- 🟢 [Done] Define a result bundle and round-trip import path from external runners back into Cinema.
  Preserve the source manifest identity, model revision, effective generation parameters, output media, and runner warnings so generated results can be attached to the correct scene and cut without manual file matching.

- 🔴 [Later] Investigate a companion Rust-based film and color engine as a separate backend project.
  If adopted, keep the engine independent from SwiftUI, codecs, and provider-specific inference services, and connect Cinema through export bundles or a narrow bridge layer rather than direct view-level integration.

- 🔴 [Later] Investigate experimental local generation support for `DiffSynth-Studio/MiniMax-H3-NF4` on Apple Silicon Macs.
  Official ModelScope materials indicate that Apple M-series inference is supported but not recommended, and low-VRAM operation is described around 7GB-class VRAM budgets. Treat this as a research candidate only until a standalone PoC confirms real-world speed, stability, memory pressure, and output quality on a 16GB Apple Silicon Mac.

## Media Browser

- 🟢 [Done] Add Files / Generated Images / Generated Videos tabs to the Browser workspace, with folder tree navigation, adaptive thumbnail grids, search, and file/video opening.
- 🟢 [Done] Persist new image generation history with immutable prompts, context, provider, model, aspect ratio, and timestamps; retain history assets when cuts are deleted and support legacy documents.
- 🟢 [Done] Verify populated Files / Generated Images / Generated Videos and image/video detail previews in Japanese, English and Simplified Chinese, light/dark appearance and 420/780-point windows using local image/video fixtures. Wrap browser controls on narrow windows, retain the compact 180-point tree and allow the thumbnail pane to shrink. Show stored prompt/context in an adaptive image detail sheet, and preview videos inside Cinema with native AVPlayerView controls.
- 🟢 [Done] Extract embedded browser videos off the main actor with cancellation and replacement/close cleanup. Preserve original display filenames, distinguish preparing from missing media, and disable missing-video cards. Verify byte-identical extraction, readable video tracks, safe generated temporary paths, cancellation, empty updates and deallocation cleanup.

## Voice and Performance Continuity

- 🟢 [Done] Add project-wide character IDs, Voice IDs, voice providers/models, speaking styles, and scene-relative dialogue cues linked by stable cut/dialogue IDs. Store timing in 48 kHz integer ticks.
- 🟢 [Done] Add a Japanese / English / Simplified Chinese Voice / Performance editor, production-mode selection, prompt integration, and standalone performance-plan export with dialogue snapshots and validation warnings. Keep Scene Bundle v1 intact.
- 🟢 [Done] Import, inspect, preview and embed locked audio assets in project packages; assign audio and source offsets to dialogue cues with backward-compatible model decoding.
- 🟢 [Done] Store asset-relative phoneme, viseme and performance-event intervals; add manual editing and validated JSON import/export with asset identity, timescale, interval range and duplicate-ID checks.
- 🟢 [Done] Add performance-scoped Scene Bundle v2 / Result Bundle v2 with locked audio assets, alignment, dialogue/cut snapshots, voice settings and runner provenance. Persist export receipts, reject stale or duplicate results, stage imports atomically and preserve original audio takes. Keep reference-image generation on the existing Scene Bundle v1 flow.
- 🟢 [Done] Add URL-based independent audio track composition with overlapping scene-relative cues, audio-only and mixed-video export, explicit native-audio retention, and source/video range validation.
- 🟢 [Done] Add asynchronous, cancellable waveform preview using bounded PCM reads and peak bins.
- 🟢 [Done] Add scene-clock dialogue/music/ambience lane visualization and independent background-audio placement editors in Japanese / English / Simplified Chinese. Persist clips with legacy decoding, mix all lanes on export and include background media and snapshots in Sync Bundle v2.
- 🟢 [Done] Verify speech spanning two locally generated video cuts with overlapping music and ambience; confirm track placement and mixed MP4 duration.
- 🟢 [Done] Add per-placement linear volume (0–100%) and fade-in/out for locked dialogue, music and ambience. Persist optional mix settings with legacy defaults, preserve them through Sync Bundle v2 and reject invalid fade ranges. Apply AVAudioMix ramps to audio/video exports; verify measured AAC amplitude, fades and mute.
- 🟢 [Done] Render populated audio-lane fixtures in Japanese / English / Simplified Chinese, light/dark appearance and 420/660-point widths. Adapt time/fade fields to vertical layouts when horizontal labels do not fit.
- 🟢 [Done] Add AVPlayer-based mixed scene-audio preview using the export composition/mix pipeline, with play/pause/stop, seek slider, completion/error state handling and three-language controls. Invalidate playback after edits, prevent overlapping asset previews, cancel preparation and release temporary sources/observers when closed. Verify preparation, seeking, stop, cancellation and cleanup using local audio fixtures; render localized light/dark preview controls. Audio-only mode excludes native video audio.
- 🟢 [Done] Add scene-local dialogue/music/ambience mute and multiple-solo controls with mute precedence. Preserve silent track durations and validate raw mix settings before muting. Store lane states in projects and Sync Bundle v2 receipts; reject stale results after lane changes. Verify rendered AAC amplitude and all-muted duration.
- 🟢 [Done] Share preview transport position with all lane bars, align their scene clocks and allow bar-click seeking after preview preparation. Distinguish selected controls with checkmarks and colored borders in all three languages.
- 🟢 [Done] Add audio-only / synchronized video-and-audio preview modes using one AVPlayer and an aspect-fit AVPlayerLayer. Resolve the latest scene video from embedded media or the saved project movies directory, copy sources for stable playback, respect native-audio retention and reject placements beyond video duration. Scale the timeline to the full preview duration. Verify video/audio tracks, native audio on/off, external/embedded storage, video-only playback preparation, missing media, seeking and cleanup with local fixtures; render video-mode controls in three languages and both appearances.
- 🟢 [Done] Add scene-video take selection with latest-take default, scene identity validation and preview reset on take changes. Add paused previous/next-frame inspection using lazily indexed compressed sample output timestamps on the playback clock, excluding empty edit-list/control markers. Bound index size, support cancellation, preserve precise seek positions and show millisecond timing. Verify 24/30fps takes, frame boundaries and irregular timestamps; render localized controls.
- 🟢 [Done] Add preview-only start/end range looping, current-position range markers and dialogue selection with 0.2-second handles in three languages. Validate finite, in-duration ranges of at least 0.05 seconds; reset loops after edits or take changes. Verify two actual AVPlayer loop traversals, pause, stop, range removal and cleanup using silent local video; render localized controls at narrow widths in light/dark appearance. Looping uses seeks for inspection and is not a seamless export effect.
- 🟢 [Done] Verify disk package save/reopen through the document reader with nested locked audio and embedded video after removing original sources. Preserve character/voice identity, cue offsets, gain/fades and lane mute state; prepare the reopened mixed AVPlayer and inspect seek/frame/loop/stop interactions. Render enabled preview controls in isolated native windows across three languages and both appearances; initialize range fields correctly when presenting an already prepared preview.
- ⭕️ [Pending] Verify the full preview workflow against real production media and external worker results; local generated fixtures cover storage and transport but cannot establish lip-sync or face/voice continuity quality.
- ⭕️ [Pending] Validate external TTS / lip-sync workers on a two-character, 30-second, 6–10-cut scene. Evaluate voice, lip sync, face identity and temporal continuity independently; requires selected worker runtime and generated media.
- 🔴 [Later] Add beat/bar-aligned MV choreography, singing alignment, and model-specific capability adapters after the locked-audio workflow is verified.
