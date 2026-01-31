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

#show raw.where(lang: "mermaid"): it => mermaid(it.text)

```mermaid
flowchart TB
    subgraph mmdr["mmdr (Rust) ~ 3ms total"]
        direction LR
        I1[/".mmd file"/] --> P1["Parse"]
        P1 --> IR1[("Graph IR")]
        IR1 --> L1["Layout"]
        L1 --> R1["Render"]
        R1 --> O1[/"SVG"/]
        O1 -.-> RS["resvg"]
        RS -.-> O2[/"PNG"/]
    end

    style mmdr fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
```

```mermaid
sequenceDiagram
    participant Client
    participant Server
    participant Database
    Client->>Server: Request
    Server->>Database: Query
    Database-->>Server: Results
    Server-->>Client: Response
    Client->>Server: Update
    Server->>Database: Write
    Database-->>Server: Confirm
    Server-->>Client: Success
```
