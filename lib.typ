#let plugin-wasm = plugin("target/wasm32-unknown-unknown/release/typst_mmdr.wasm")

#let mermaid(
  code,
  base-theme: "modern",
  theme: none,
  layout: none,
) = {
  let svg-bytes = plugin-wasm.mermaid(
    bytes(code),
    bytes(base-theme),
    bytes(
      if theme == none {
        ""
      } else {
        json.encode(theme)
      },
    ),
    bytes(
      if layout == none {
        ""
      } else {
        json.encode(layout)
      },
    ),
  )
  image(svg-bytes)
}
