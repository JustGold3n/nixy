# Graph Report - nixos  (2026-10-08)

## Corpus Check
- 25 files · ~187,215 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 150 file(s) not represented in the graph (top: .nix 145, (none) 2, .lock 2)

## Summary
- 95 nodes · 104 edges · 12 communities (9 shown, 3 thin omitted)
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 15 edges (avg confidence: 0.9)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Graphify Extraction and Integration
- Graphify Query and Updates
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
1. `Graphify Skill` - 13 edges
2. `Glance dashboard` - 7 edges
3. `Customized NixOS desktop screenshot` - 6 edges
4. `Query Path and Explain Reference` - 5 edges
5. `Nixy README` - 5 edges
6. `Tiled terminal desktop screenshot` - 5 edges
7. `Tiled NixOS desktop screenshot` - 5 edges
8. `Nixy banner image` - 4 edges
9. `Minimal dark NixOS desktop environment` - 4 edges
10. `Three-pane terminal file manager` - 4 edges

## Surprising Connections (you probably didn't know these)
- `Graphify-First Codebase Workflow` --references--> `Graphify Skill`  [EXTRACTED]
  AGENTS.md → .codex/skills/graphify/SKILL.md
- `nvf Standalone Neovim Output` --conceptually_related_to--> `NixOS and Home Manager Flake`  [INFERRED]
  docs/NEOVIM.md → AGENTS.md
- `Nixy README` --references--> `Contributing to Nixy`  [EXTRACTED]
  README.md → docs/CONTRIBUTING.md
- `Nixy README` --references--> `Neovim Configuration Guide`  [EXTRACTED]
  README.md → docs/NEOVIM.md
- `Nixy README` --references--> `Self-Hosted Server Guide`  [EXTRACTED]
  README.md → docs/SERVER.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Extraction Pipeline** — _codex_skills_graphify_skill_structural_extraction, _codex_skills_graphify_skill_semantic_extraction, _codex_skills_graphify_skill_community_detection [EXTRACTED 1.00]
- **Nixy Declarative Configuration** — agents_nix_flake_repository, readme_nixy_configuration_system, docs_neovim_nvf_standalone_output, docs_server_cloudflare_nixos_server, docs_themes_theme_definition_system [INFERRED 0.85]

## Communities (12 total, 3 thin omitted)

### Community 0 - "Graphify Extraction and Integration"
Cohesion: 0.14
Nodes (16): Extra Exports Reference, Graphify MCP Server, Edge Confidence Model, Deterministic Node IDs, Semantic Extraction Specification, Cross-Repository Graph Merge, GitHub Clone and Merge Reference, Commit Hook and Claude Integration Reference (+8 more)

### Community 1 - "Graphify Query and Updates"
Cohesion: 0.17
Nodes (12): Add URL and Watch Reference, Folder Watcher, URL Ingestion, Constrained Query Expansion, BFS and DFS Graph Traversal, Query Path and Explain Reference, Graph Work Memory, Incremental Graph Merge (+4 more)

### Community 2 - "Nixy Configuration Documentation"
Cohesion: 0.20
Nodes (12): NixOS and Home Manager Flake, Contributing to Nixy, Nixy Contribution Workflow, Neovim Configuration Guide, nvf Standalone Neovim Output, Cloudflare-Fronted NixOS Server, Self-Hosted Server Guide, Theme Definition System (+4 more)

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
- **28 isolated node(s):** `Persistent Knowledge Graph`, `Community Detection`, `Folder Watcher`, `Graphify MCP Server`, `Edge Confidence Model` (+23 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 34 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Graphify Skill` connect `Graphify Extraction and Integration` to `Graphify Query and Updates`?**
  _High betweenness centrality (0.123) - this node is a cross-community bridge._
- **Why does `Repository Guidelines` connect `Graphify Query and Updates` to `Nixy Configuration Documentation`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._
- **Why does `Graphify-First Codebase Workflow` connect `Graphify Query and Updates` to `Graphify Extraction and Integration`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._
- **What connects `Persistent Knowledge Graph`, `Community Detection`, `Folder Watcher` to the rest of the system?**
  _28 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Graphify Extraction and Integration` be split into smaller, more focused modules?**
  _Cohesion score 0.14166666666666666 - nodes in this community are weakly interconnected._