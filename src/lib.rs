use json_value_merge::Merge;
use mermaid_rs_renderer::{render_with_options, LayoutConfig, RenderOptions, Theme};
use serde::{de::DeserializeOwned, Serialize};
use wasm_minimal_protocol::*;

initiate_protocol!();

#[wasm_func]
pub fn render(
    code: &[u8],
    base_theme: &[u8],
    theme: &[u8],
    layout: &[u8],
) -> Result<Vec<u8>, String> {
    let code_str = bytes_to_str(code)?;
    let base_theme_str = bytes_to_str(base_theme)?;

    let mut options = RenderOptions {
        theme: get_base_theme(base_theme_str),
        layout: LayoutConfig::default(),
    };

    apply_overrides(&mut options.theme, theme)?;
    apply_overrides(&mut options.layout, layout)?;

    render_with_options(code_str, options)
        .map(|svg| svg.into_bytes())
        .map_err(|e| format!("Mermaid rendering error: {:?}", e))
}

/// Helper to convert bytes to UTF-8 string slice
fn bytes_to_str(bytes: &[u8]) -> Result<&str, String> {
    std::str::from_utf8(bytes).map_err(|e| e.to_string())
}

/// Selects the base theme based on the input string
fn get_base_theme(name: &str) -> Theme {
    match name {
        "default" => Theme::mermaid_default(),
        _ => Theme::modern(),
    }
}

/// Merges a JSON byte slice into a target struct
fn apply_overrides<T: Serialize + DeserializeOwned>(
    target: &mut T,
    json: &[u8],
) -> Result<(), String> {
    if json.is_empty() {
        return Ok(());
    }

    // 1. Serialize target to a Value
    let mut target_val = serde_json::to_value(&target).map_err(|e| e.to_string())?;

    // 2. Parse overrides to a Value
    let json_val: serde_json::Value = serde_json::from_slice(json).map_err(|e| e.to_string())?;

    // 3. Merge overrides into target
    target_val.merge(&json_val);

    // 4. Deserialize back to the target struct
    *target = serde_json::from_value(target_val).map_err(|e| e.to_string())?;
    Ok(())
}

/// Dummy implementation of `now` to satisfy the `env::now` import used by `instant` (or `mermaid-rs-renderer`)
#[no_mangle]
pub extern "C" fn now() -> f64 {
    0.0
}
