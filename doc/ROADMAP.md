# Cinema Roadmap

## AI / Local Generation

- [Next] Strengthen Cinema as an export-first authoring tool for external open-weight inference projects.
  Prioritize structured export bundles for prompts, cut metadata, scene metadata, reference images, aspect ratio, duration, continuity hints, seed, and prompt versioning so a separate Google Colab or GPU worker project can consume Cinema output without embedding runtime-specific logic into Cinema itself.

- [Next] Design a stable handoff format between Cinema and external inference backends.
  Target JSON + text prompt files + organized image assets, with per-cut and per-scene exports, so model-specific runners such as DiffSynth-Studio notebooks can be iterated independently from the Cinema app.

- [Next] Prepare Cinema's metadata model for future film-engine integration without embedding the renderer yet.
  Use the film-engine design notes to shape export schema, shot context, provenance capture, semantic film-look metadata, and reproducibility records while keeping Cinema focused on authoring and handoff.

- [Next] Introduce a persistent `SceneState` design centered on Character / Object / Environment / Camera / Lighting / Event / Timeline / Audio.
  Treat these as durable scene-level truth and let each cut describe only local deltas, so Cinema can export continuity-safe bundles for prompting, rendering, and future film-engine integration.

- [Next] Add a structured world-state prompting layer on top of `SceneState`.
  Support exportable Initial State / Persistent Rules / Event Sequence / State Transitions / Camera Observation so Cinema can generate stronger continuity-oriented prompts without pretending the model has a full symbolic world model.

- [Later] Investigate a companion Rust-based film and color engine as a separate backend project.
  If adopted, keep the engine independent from SwiftUI, codecs, and provider-specific inference services, and connect Cinema through export bundles or a narrow bridge layer rather than direct view-level integration.

- [Later] Investigate experimental local generation support for `DiffSynth-Studio/MiniMax-H3-NF4` on Apple Silicon Macs.
  Official ModelScope materials indicate that Apple M-series inference is supported but not recommended, and low-VRAM operation is described around 7GB-class VRAM budgets. Treat this as a research candidate only until a standalone PoC confirms real-world speed, stability, memory pressure, and output quality on a 16GB Apple Silicon Mac.
