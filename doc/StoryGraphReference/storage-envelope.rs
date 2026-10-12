#[derive(Serialize)]
struct SavedWorkspace {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    generation: Option<String>,
    format: String,
    version: u32,
    document: Document,
}
impl<'de> Deserialize<'de> for SavedWorkspace {
    fn deserialize<D: serde::Deserializer<'de>>(
        deserializer: D,
    ) -> std::result::Result<Self, D::Error> {
        #[derive(Deserialize)]
        #[serde(deny_unknown_fields)]
        struct Envelope {
            #[serde(default)]
            generation: Option<String>,
            format: String,
            version: u32,
            #[serde(default)]
            document: Option<Document>,
            #[serde(default)]
            workspace: Option<Value>,
        }
        let envelope = Envelope::deserialize(deserializer)?;
        let document = match (envelope.version, envelope.document, envelope.workspace) {
            (1 | 2, Some(document), None) => document,
            (3, None, Some(workspace)) => {
                shared_workspace::decode(workspace).map_err(serde::de::Error::custom)?
            }
            _ => return Err(serde::de::Error::custom("unsupported_workspace")),
        };
        Ok(Self {
            generation: envelope.generation,
            format: envelope.format,
            version: envelope.version,
            document,
        })
    }
}
fn workspace_version(document: &Document) -> u32 {
    if document.extensions.is_empty() { 1 } else { 2 }
}
fn save(path: &std::path::Path, document: &Document) -> std::result::Result<(), String> {
    journal::save_workspace(path, document)
}

fn load(path: &std::path::Path) -> std::result::Result<Document, String> {
    if std::fs::metadata(path).map_err(|e| e.to_string())?.len() > 128 * 1024 * 1024 {
        return Err("limit_exceeded".into());
    }
    let saved: SavedWorkspace =
        serde_json::from_slice(&journal::read_workspace(path)?).map_err(|e| e.to_string())?;
    if saved.format != "komyaku-story-workspace" || ![1, 2, 3].contains(&saved.version) {
        return Err("unsupported_workspace".into());
    }
    saved.document.validate().map_err(|e| e.to_string())?;
    Ok(saved.document)
}
fn labels(registry: &unge_executor::Registry) -> LabelCatalog {
    registry
        .definitions()
