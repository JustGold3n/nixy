# Graph Report - nixos  (2026-10-25)

## Corpus Check
- 14 files · ~181,293 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 162 file(s) not represented in the graph (top: .nix 153, .patch 4, .lock 2)

## Summary
- 230 nodes · 387 edges · 15 communities (12 shown, 3 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.9)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `440e71b4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- suzuha-niri-colors.rs
- suzuha-focus.rs
- Nixy Configuration Documentation
- Browser and File Desktop
- Self-Hosted Server Dashboard
- Nixy System Desktop
- Development and Media Desktop
- tools.py
- Nixy Banner Identity
- Nixy Logo Design
- Project Funding
- suzuha-clipboard.rs
- suzuha-tray.rs
- amane-tray.rs
- WATCHER

## God Nodes (most connected - your core abstractions)
1. `Popup` - 14 edges
2. `main()` - 10 edges
3. `WATCHER` - 10 edges
4. `call()` - 10 edges
5. `Item` - 9 edges
6. `icon()` - 8 edges
7. `click()` - 7 edges
8. `icons()` - 7 edges
9. `Glance dashboard` - 7 edges
10. `read()` - 6 edges

## Surprising Connections (you probably didn't know these)
- `nvf Standalone Neovim Output` --conceptually_related_to--> `NixOS and Home Manager Flake`  [INFERRED]
  docs/NEOVIM.md → AGENTS.md
- `Nixy README` --references--> `Contributing to Nixy`  [EXTRACTED]
  README.md → docs/CONTRIBUTING.md
- `Nixy README` --references--> `Neovim Configuration Guide`  [EXTRACTED]
  README.md → docs/NEOVIM.md
- `Nixy README` --references--> `Self-Hosted Server Guide`  [EXTRACTED]
  README.md → docs/SERVER.md
- `Nixy README` --references--> `Themes Guide`  [EXTRACTED]
  README.md → docs/THEMES.md

## Import Cycles
- 2-file cycle: `nixos/packages/amane-tray.rs -> nixos/packages/suzuha-tray.rs -> nixos/packages/amane-tray.rs`

## Hyperedges (group relationships)
- **Nixy Declarative Configuration** — agents_nix_flake_repository, readme_nixy_configuration_system, docs_neovim_nvf_standalone_output, docs_server_cloudflare_nixos_server, docs_themes_theme_definition_system [INFERRED 0.85]

## Communities (15 total, 3 thin omitted)

### Community 1 - "suzuha-focus.rs"
Cohesion: 0.36
Nodes (3): Focus, ipc(), path()

### Community 2 - "Nixy Configuration Documentation"
Cohesion: 0.15
Nodes (15): Graphify-First Codebase Workflow, NixOS and Home Manager Flake, Repository Guidelines, Validation and Security Workflow, Contributing to Nixy, Nixy Contribution Workflow, Neovim Configuration Guide, nvf Standalone Neovim Output (+7 more)

### Community 3 - "Browser and File Desktop"
Cohesion: 0.31
Nodes (9): Cyber directory containing tmp and wordlists, Tiled NixOS desktop screenshot, Grouped bookmarks for tools, entertainment, social media, information security, documentation, and personal services, Home directory containing Cyber, Desktop, dev, Documents, Downloads, Projects, and other folders, Dark browser start page dashboard, Colored terminal ASCII art, Three-pane terminal file manager, Dark themed tiled desktop layout (+1 more)

### Community 4 - "Self-Hosted Server Dashboard"
Cohesion: 0.28
Nodes (9): Core self-hosted services status, Dark minimal dashboard theme, Self-hosted server dashboard screenshot, DNS statistics forbidden error state, Glance dashboard, Clock weather markets and news widgets, Media and download automation stack, anotherhadi/nixy repository widget (+1 more)

### Community 5 - "Nixy System Desktop"
Cohesion: 0.36
Nodes (8): Large desktop clock widget, Minimal dark NixOS desktop environment, Customized NixOS desktop screenshot, Monochrome misty mountain wallpaper, NixOS system information terminal, Nixy command menu, Nixy rebuild, test, update, garbage collection, boot cleanup, and generation listing actions, Top workspace and system status bar

### Community 6 - "Development and Media Desktop"
Cohesion: 0.29
Nodes (8): Dark purple desktop theme, Tiled terminal desktop screenshot, Terminal music player interface, Nix flake code editor, Recently played tracks library, NixOS repository file explorer, Two-column tiling window layout, Centered workspace and system status bar

### Community 7 - "tools.py"
Cohesion: 0.20
Nodes (15): process(), replace(), action_args(), ask(), catalog(), choose(), clean(), data() (+7 more)

### Community 8 - "Nixy Banner Identity"
Cohesion: 0.60
Nodes (5): Nixy banner image, Nix snowflake symbol, Nixy visual identity, nixy wordmark, Pastel pink and blue cloud background

### Community 9 - "Nixy Logo Design"
Cohesion: 0.40
Nodes (5): Angular interlocking geometric arms, Repository logo image, Stylized Nix snowflake symbol, Pink and purple gradient palette, Rounded black square background

### Community 11 - "suzuha-clipboard.rs"
Cohesion: 0.11
Nodes (13): CLIPHIST, copy(), Database, decode(), duplicate_previews_keep_distinct_ids_and_exact_content(), empty_history_and_missing_entry_are_handled(), find(), History (+5 more)

### Community 12 - "suzuha-tray.rs"
Cohesion: 0.08
Nodes (14): Item, click(), close(), dismiss(), hover(), icon(), icons(), image() (+6 more)

### Community 13 - "amane-tray.rs"
Cohesion: 0.10
Nodes (21): activate(), alive(), call(), CONNECTION, endpoint(), entries(), find_icon(), icon_folder() (+13 more)

## Knowledge Gaps
- **20 isolated node(s):** `Hadi Donation Page`, `Funding Configuration`, `Graphify-First Codebase Workflow`, `Validation and Security Workflow`, `Nixy Contribution Workflow` (+15 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 75 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Item` connect `suzuha-tray.rs` to `suzuha-clipboard.rs`?**
  _High betweenness centrality (0.065) - this node is a cross-community bridge._
- **What connects `Hadi Donation Page`, `Funding Configuration`, `Graphify-First Codebase Workflow` to the rest of the system?**
  _20 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `suzuha-clipboard.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.1103448275862069 - nodes in this community are weakly interconnected._
- **Why does `MenuEntry` connect `amane-tray.rs` to `suzuha-tray.rs`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Should `suzuha-tray.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.07770582793709528 - nodes in this community are weakly interconnected._
- **Why does `icons()` connect `suzuha-tray.rs` to `amane-tray.rs`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **Should `amane-tray.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.1039136302294197 - nodes in this community are weakly interconnected._