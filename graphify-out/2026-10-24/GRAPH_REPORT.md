# Graph Report - nixos  (2026-10-24)

## Corpus Check
- 8 files · ~176,745 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 157 file(s) not represented in the graph (top: .nix 153, .lock 2, (none) 1)

## Summary
- 68 nodes · 76 edges · 9 communities (7 shown, 2 thin omitted)
- Extraction: 80% EXTRACTED · 20% INFERRED · 0% AMBIGUOUS · INFERRED: 15 edges (avg confidence: 0.9)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `440e71b4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Nixy Configuration Documentation
- Browser and File Desktop
- Self-Hosted Server Dashboard
- Nixy System Desktop
- Development and Media Desktop
- Inject Exec Script
- Nixy Banner Identity
- Nixy Logo Design
- Project Funding

## God Nodes (most connected - your core abstractions)
1. `Glance dashboard` - 7 edges
2. `Customized NixOS desktop screenshot` - 6 edges
3. `replace()` - 5 edges
4. `Nixy README` - 5 edges
5. `Tiled NixOS desktop screenshot` - 5 edges
6. `Tiled terminal desktop screenshot` - 5 edges
7. `Three-pane terminal file manager` - 4 edges
8. `Minimal dark NixOS desktop environment` - 4 edges
9. `Nixy banner image` - 4 edges
10. `Repository Guidelines` - 3 edges

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
- None detected.

## Hyperedges (group relationships)
- **Nixy Declarative Configuration** — agents_nix_flake_repository, readme_nixy_configuration_system, docs_neovim_nvf_standalone_output, docs_server_cloudflare_nixos_server, docs_themes_theme_definition_system [INFERRED 0.85]

## Communities (9 total, 2 thin omitted)

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

### Community 8 - "Nixy Banner Identity"
Cohesion: 0.60
Nodes (5): Nixy banner image, Nix snowflake symbol, Nixy visual identity, nixy wordmark, Pastel pink and blue cloud background

### Community 9 - "Nixy Logo Design"
Cohesion: 0.40
Nodes (5): Angular interlocking geometric arms, Repository logo image, Stylized Nix snowflake symbol, Pink and purple gradient palette, Rounded black square background

## Knowledge Gaps
- **20 isolated node(s):** `Graphify-First Codebase Workflow`, `Validation and Security Workflow`, `Hadi Donation Page`, `Funding Configuration`, `Nixy Contribution Workflow` (+15 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 21 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `Graphify-First Codebase Workflow`, `Validation and Security Workflow`, `Hadi Donation Page` to the rest of the system?**
  _20 weakly-connected nodes found - possible documentation gaps or missing edges._