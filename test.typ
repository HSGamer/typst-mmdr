#import "lib.typ": mermaid

#set page(width: auto, height: auto, margin: 1cm)

#mermaid(
  "
  graph TD;
  A-->B;
  ",
  layout: (
    node_spacing: 500,
    rank_spacing: 20,
  ),
  theme: (
    background: "cyan",
  ),
)
