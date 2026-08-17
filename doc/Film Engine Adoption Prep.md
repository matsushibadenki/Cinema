# Film Engine Adoption Prep for Cinema

## Purpose

This note prepares Cinema to adopt ideas from [Universal Film & Color Imaging Engine](/Users/Shared/Program/Xcode/Cinema/doc/Universal%20Film%20%26%20Color%20Imaging%20Engine.md) without starting implementation yet.

The goal is to preserve the document's strongest architectural decisions while fitting them into Cinema's current role as an authoring, context, and export tool for AI-assisted image and video generation.

## Confirmed Fit With Cinema

The source document aligns well with Cinema in four areas:

1. Keep the film engine separate from app UI, camera APIs, codec handling, and model-specific inference logic.
2. Treat film look as structured project context, not as a loose prompt phrase.
3. Preserve reproducibility metadata such as model, prompt, seed, profile version, and recipe.
4. Prefer an export-first boundary so Cinema can hand off stable metadata to an external renderer or inference worker.

These ideas match Cinema's current direction better than embedding heavy rendering logic directly into the SwiftUI app.

## Core Scene-State Direction

Cinema should manage the following as persistent `SceneState`, not as prompt-only text:

- Character
- Object
- Environment
- Camera
- Lighting
- Event
- Timeline
- Audio

This should become a core design rule:

```text
Project Context
    ↓
Persistent Scene State
    ↓
Per-Cut Shot Delta
    ↓
Prompt / Export Bundle / External Renderer
```

In other words, each cut should not fully redefine the world from scratch.
Each cut should inherit a durable scene state and then describe only its local change, emphasis, or transition.

## World-State Prompting Direction

The external AI idea is worth adopting in Cinema with one important interpretation:

- Cinema should not assume that a model gains a true internal world simulator from prompting alone.
- Cinema should assume that better-structured prompts can more strongly elicit continuity, persistence, causality, and object permanence that the model already partially supports.

This means Cinema should support a prompt architecture based on:

1. `Initial State`
2. `Persistent Rules`
3. `Event Sequence`
4. `State Transitions`
5. `Camera Observation`

This is a strong fit for video generation and should be preferred over a flat prose-only prompt when continuity matters.

## Persistent Scene State Model

The long-term structure should be split into three levels:

1. `ProjectContext`
2. `SceneState`
3. `ShotDelta`

Suggested responsibilities:

### `ProjectContext`

Shared across the whole work:

- story-wide themes
- global visual bible
- reusable character and asset identities
- high-level film / color intent
- reproducibility defaults

### `SceneState`

Persistent within a scene:

- `characterState`
- `objectState`
- `environmentState`
- `cameraState`
- `lightingState`
- `eventState`
- `timelineState`
- `audioState`

### `ShotDelta`

Only what changes at a given cut:

- character pose or gaze change
- object movement or interaction
- environment change
- reframing or lens change
- lighting cue change
- event progression
- timeline progression
- dialogue / sound cue change

This prevents the export layer from restating stable information in every prompt while preserving continuity.

## Observation Model

Cinema should explicitly separate:

- `WorldState`
- `CameraObservation`

Conceptually:

```text
WorldState_t
    ↓ observed by
Camera_t
    ↓ produces
Frame_t
```

This distinction is especially useful because many video models behave as if:

```text
World ≈ Visible Frame
```

Cinema should instead author toward:

```text
World != Camera
```

Meaning:

- offscreen objects still exist
- occluded objects still exist
- camera movement does not rewrite the world
- framing changes observation, not underlying state

This should become a first-class export concept.

## Best Adoption Points In The Current Codebase

### 1. Drawing Presets -> Creative Presets

Current closest model:

- `DrawingSettings`
- `DrawingPreset`
- `DrawingSettingsSection`
- `DrawingSettingsField`

Preparation decision:

- Keep `DrawingPreset` as the current authoring-layer concept.
- Later, allow a preset to optionally reference:
  - film profile
  - film recipe
  - creative preset
  - output color intent

Reason:

Cinema already stores high-level style direction here, so this is the least disruptive place to add film-context fields later.

### 2. Cut Data -> Shot Context

Current closest model:

- `StoryboardCut`
- `AIShotSettings`
- `ReferenceImage`

Preparation decision:

- Treat each `StoryboardCut` as the future host for a lightweight `ShotDelta`, not the full scene state.
- Add a scene-level persistent state model above cuts.
- Do not add low-level physical imaging parameters yet.
- Reserve future scene-state and shot-delta expansion for:
  - Character
  - Object
  - Environment
  - Camera
  - Lighting
  - Event
  - Timeline
  - Audio
- Then allow cut-level overrides or deltas for:
  - camera framing
  - lens / focal change
  - lighting cue changes
  - character movement
  - object interaction
  - timeline progression
  - event progression
  - dialogue / sound actions
  - film profile
  - print profile
  - grade
  - references
- Reserve future event/state expansion for:
  - initial state snapshot
  - event list
  - state transition list
  - continuity assertions
  - conservation rules
  - camera observation rules

Reason:

This follows the source document closely while improving continuity management. Cinema already groups shot-specific prompt and continuity data per cut, but the durable state should live one level above the cut.

### 3. Reference Sidebar -> Provenance Capture

Current closest model:

- `ReferenceImage`
- `ReferenceSidebarView`

Preparation decision:

- Reuse the existing `details` structure on reference images to hold source provenance before introducing a dedicated schema.
- Favor future fields such as:
  - source
  - source type
  - source URL
  - creator / manufacturer
  - document name
  - confidence
  - measurement quality

Reason:

Cinema already has a user-editable metadata surface for references, so provenance can be staged there before a more formal film-profile database exists.

### 4. Prompt Builder -> Structured Export Boundary

Current closest model:

- `AIPromptBuilder`
- scene prompt export flow

Preparation decision:

- Keep prompts as only one export artifact.
- Prepare future export bundles to include structured film metadata beside prompts, not merged into prompts.
- Build prompt text from `SceneState + ShotDelta`, rather than from raw freeform fields alone.
- Add a world-state prompt mode that serializes:
  - initial state
  - persistent rules
  - event sequence
  - state transitions
  - camera observation
  - continuity requirements

Reason:

The source document explicitly separates semantic metadata from physical or measured data. Cinema should preserve that separation in exports.

### 4a. Prompt Format Strategy

Cinema should support at least two prompt surfaces in the future:

1. `Human Creative Prompt`
2. `Structured World-State Prompt`

The first is useful for creative nuance and fast authoring.
The second is useful for continuity, persistence, causality, and multi-step action.

The preferred generation payload is:

```text
Human Creative Prompt
+ 
Structured World-State Prompt
+ 
Reference Images / First Frame / Last Frame / Scene Assets
```

This provides a better balance than replacing all natural language with rigid state notation.

### 5. Project File -> Reproducibility Metadata

Current closest model:

- `StoryboardProject`
- generated image / video records
- provider settings and model selections

Preparation decision:

- Prepare for project-level storage of:
  - AI provider
  - AI model
  - AI model version if available
  - seed
  - film profile
  - film profile version
  - film recipe
  - creative preset
  - engine version

Reason:

This is one of the strongest ideas in the source document and is highly compatible with Cinema's role as a context-management tool.

## Recommended Adoption Order For Cinema

### Step 1. Export schema first

Define a Cinema-side export schema that can carry:

- project context
- persistent scene state
- per-cut shot delta
- event graph
- state transitions
- conservation rules
- camera observation rules
- reference metadata
- drawing preset
- future film profile identifiers
- future film recipe identifiers

This should happen before any renderer integration.

### Step 2. Persistent scene-state schema second

Define durable scene-state categories for:

- Character
- Object
- Environment
- Camera
- Lighting
- Event
- Timeline
- Audio

These should be editable and exportable even before a film engine exists.

### Step 3. Event and transition model third

Define a structured event layer that can express:

- ordered events
- preconditions
- postconditions
- persistent consequences
- object permanence
- conservation constraints
- offscreen persistence
- camera/world separation

This is the main adoption point for the world-state prompting idea.

### Step 4. Semantic film metadata fourth

Add semantic film-look fields that are useful even without a rendering engine:

- contrast
- saturation
- grain intent
- highlight rolloff
- temperature
- print intent

These can improve prompting and external handoff immediately.

### Step 5. Reproducibility records fifth

Persist model and render metadata so that exported work can be re-run later.

### Step 6. External engine bridge later

If a Rust-based engine is pursued, integrate it as a separate backend or companion project rather than mixing it directly into SwiftUI view logic.

## What Should Not Be Done Yet

- Do not add `wgpu`, Rust FFI, or GPU rendering glue into Cinema now.
- Do not force ACES or OCIO implementation into the app before the export schema is stable.
- Do not overload prompt text with film-profile internals.
- Do not treat AI prompt phrases like "Kodak look" as a replacement for structured metadata.

## Suggested Future Data Layers

When Cinema is ready, the layering should look like this:

1. `DrawingPreset`
2. `ProjectContext`
3. `SceneState`
4. `ShotDelta`
5. `EventGraph`
6. `StateTransitionSet`
7. `CameraObservation`
8. `FilmProfileRef`
9. `FilmRecipe`
10. `CreativePreset`
11. `ExportBundle`

This keeps the current authoring UX intact while allowing the imaging system to grow without rewriting the app model.

## Scene-State Category Guidance

To keep the model stable, each persistent scene-state category should answer a different question:

### Character

Who is present, how they look, what they wear, their emotional state, pose baseline, and identity continuity rules.

### Object

What props or vehicles exist, their condition, ownership, placement, and continuity-critical attributes.

### Environment

Location identity, set dressing, weather, time-of-day, atmosphere, architecture, and spatial layout.

### Camera

Default capture logic for the scene such as camera system, lens family, movement language, aspect intent, and continuity constraints.

### Lighting

Motivated sources, color temperature intent, contrast style, practical lights, time-based lighting consistency, and cue rules.

### Event

What is happening in the scene at a narrative level, including goals, conflict, and continuity-sensitive beats.

### Timeline

Where the scene sits in story time, elapsed time within the scene, ordering constraints, and before/after relationships between cuts.

### Audio

Dialogue continuity, ambience bed, key sound events, offscreen sound, music intent, and sound carry-over between cuts.

## World-State Rule Categories

Cinema should be able to persist rule-like continuity constraints, not just descriptive metadata.

Examples:

### Persistence Rules

- objects continue to exist when offscreen
- occlusion does not remove objects
- character identity persists across cuts
- previous actions remain effective until changed

### Conservation Rules

- object count is conserved unless an explicit event changes it
- objects do not teleport
- objects do not duplicate
- solid objects do not pass through one another unless intentionally surreal

### Causality Rules

- state changes must follow explicit events
- object locations change only through plausible actions
- camera motion cannot create or delete world state

These rules should live beside the scene state and event graph, not be buried inside one freeform prompt paragraph.

## Event Graph Direction

For continuity-heavy sequences, Cinema should eventually support a state-machine-like representation:

```text
State S0
    ↓ Event E1
State S1
    ↓ Event E2
State S2
    ↓ Event E3
State S3
```

This does not require fully symbolic reasoning from the model.
It simply gives the exporter a better structure for prompting and for future validation.

## Practical Adoption Boundary

Cinema should adopt this idea as:

- authoring structure
- export structure
- prompt serialization strategy

Cinema should not adopt it as a claim that current video models have a true internal physics engine or fully reliable symbolic memory.

The intended value is:

```text
flat prose prompt
    <
world-state prompt
    <
true world model
```

That is still a worthwhile upgrade for preview generation and continuity control.

## Immediate Modeling Rule

For future implementation, use this rule:

- `SceneState` stores the persistent truth of the scene.
- `StoryboardCut` stores the local visible or temporal change from that truth.
- Exporters reconstruct each shot by combining inherited scene state with cut-specific delta.

This is the preferred architecture for continuity, reproducibility, and future external rendering support.

## Immediate Outcome Of This Prep

After this preparation step, the source document can be used as a design reference for:

- export bundle design
- future cut-level metadata extensions
- future reference provenance capture
- future reproducibility support

No rendering implementation is started by this document.
