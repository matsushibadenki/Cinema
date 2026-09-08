# Cinema Result Bundle v1

Cinema Result Bundle is the return format for attaching media produced by an external inference runner to the original cuts in Cinema. A result refers to the UUID of the source Scene Bundle manifest and to each cut's persistent UUID; filenames are never used to guess associations.

```text
result_bundle/
├── manifest.json
└── outputs/
    ├── cut-001.png
    └── cut-002.mp4
```

The manifest uses this shape:

```json
{
  "format": "cinema.result-bundle",
  "schemaVersion": "1.0.0",
  "sourceBundleID": "UUID from the source Scene Bundle manifest",
  "sourceProjectTitle": "Project title",
  "sceneTitle": "Scene title at generation time",
  "sceneKey": "Stable scene key from the source bundle",
  "runner": "Runner name and version",
  "modelRevision": "Immutable model revision when available",
  "effectiveParameters": { "seed": "42", "steps": "28" },
  "warnings": [],
  "generatedAt": "2026-09-08T00:00:00Z",
  "outputs": [
    {
      "cutID": "UUID from cuts[].id",
      "mediaType": "image",
      "path": "outputs/cut-001.png",
      "warnings": []
    }
  ]
}
```

Only relative paths contained within the bundle are accepted. Every referenced cut must still exist in the open Cinema document. Image outputs replace the active storyboard image for that cut while remaining embedded in the document. Video outputs are copied to the document's sibling `movies/imports/<sourceBundleID>/` folder and added to the cut's version history.

Cinema records the source bundle UUID, runner, model revision, effective parameters, warnings, and import time in the project document. A bundle containing video requires the document to be saved before import.
