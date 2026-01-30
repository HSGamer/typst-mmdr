use wasm_minimal_protocol::*;
use mermaid_rs_renderer::{render_with_options, RenderOptions, Theme, LayoutConfig};
use serde::{de::DeserializeOwned, Serialize};

initiate_protocol!();

#[wasm_func]
pub fn mermaid(
    code: &[u8],
    base_theme: &[u8],
    theme: &[u8],
    layout: &[u8]
) -> Result<Vec<u8>, String> {
    let code_str = std::str::from_utf8(code).map_err(|e| e.to_string())?;
    let base_theme_str = std::str::from_utf8(base_theme).map_err(|e| e.to_string())?;
    
    let mut options = RenderOptions {
        theme: match base_theme_str {
            "default" => Theme::mermaid_default(),
            _ => Theme::modern(),
        },
        layout: LayoutConfig::default(),
    };

    merge_json(&mut options.theme, theme)?;
    merge_json(&mut options.layout, layout)?;

    match render_with_options(code_str, options) {
        Ok(svg) => Ok(svg.into_bytes()),
        Err(e) => Err(format!("Mermaid rendering error: {:?}", e)),
    }
}

fn merge_json<T: Serialize + DeserializeOwned>(target: &mut T, json: &[u8]) -> Result<(), String> {
    if json.is_empty() {
        return Ok(());
    }
    let mut target_val = serde_json::to_value(&target).map_err(|e| e.to_string())?;
    let json_val: serde_json::Value = serde_json::from_slice(json).map_err(|e| e.to_string())?;

    merge(&mut target_val, json_val);
    
    *target = serde_json::from_value(target_val).map_err(|e| e.to_string())?;
    Ok(())
}

fn merge(a: &mut serde_json::Value, b: serde_json::Value) {
    match (a, b) {
        (serde_json::Value::Object(a), serde_json::Value::Object(b)) => {
            for (k, v) in b {
                merge(a.entry(k).or_insert(serde_json::Value::Null), v);
            }
        }
        (a, b) => *a = b,
    }
}
