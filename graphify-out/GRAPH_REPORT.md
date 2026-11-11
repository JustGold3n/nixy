# Graph Report - nixos  (2026-11-11)

## Corpus Check
- 37 files · ~194,438 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 170 file(s) not represented in the graph (top: .nix 143, .patch 19, (none) 2)

## Summary
- 546 nodes · 1014 edges · 32 communities (27 shown, 5 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 30 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `44478872`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- suzuha-glass-region.rs
- suzuha-private-dir.rs
- Nixy Configuration Documentation
- Browser and File Desktop
- Self-Hosted Server Dashboard
- Nixy System Desktop
- Development and Media Desktop
- tools.rs
- Nixy Banner Identity
- Nixy Logo Design
- Project Funding
- suzuha-clipboard.rs
- amane-tray.rs
- cursor.rs
- system-notifications/watch.rs
- suzuha-fingerprint.rs
- suzuha-status.rs
- suzuha-battery-care.rs
- amane-background-effect.rs
- ui.rs
- policy.rs
- wallpaper.lua
- Popup
- test-termfilechooser.rs
- path
- firmware.rs
- battery-care/watch.rs
- result
- mode_button
- Item
- nixy-tools

## God Nodes (most connected - your core abstractions)
1. `Popup` - 14 edges
2. `WATCHER` - 11 edges
3. `run()` - 10 edges
4. `call()` - 10 edges
5. `Snapshot` - 10 edges
6. `Item` - 10 edges
7. `action_args()` - 8 edges
8. `network_state()` - 8 edges
9. `run()` - 8 edges
10. `set_policy_with()` - 8 edges

## Surprising Connections (you probably didn't know these)
- `inject()` --calls--> `execute()`  [INFERRED]
  .github/scripts/inject-exec.rs → nixos/battery-care/ui.rs
- `read()` --calls--> `checked()`  [INFERRED]
  home/system/niri/tools.rs → rust/lib.rs
- `execute_action()` --calls--> `checked()`  [INFERRED]
  home/system/niri/tools.rs → rust/lib.rs
- `enable()` --calls--> `atomic_write()`  [INFERRED]
  home/system/suzuha-enable-integrations.rs → rust/lib.rs
- `run()` --calls--> `checked()`  [INFERRED]
  home/tui/nixy/test-nixy.rs → rust/lib.rs

## Import Cycles
- 1-file cycle: `nixos/packages/suzuha/amane-background-effect.rs -> nixos/packages/suzuha/amane-background-effect.rs`
- 1-file cycle: `nixos/packages/suzuha/amane-tray.rs -> nixos/packages/suzuha/amane-tray.rs`
- 1-file cycle: `nixos/packages/suzuha/suzuha-fingerprint.rs -> nixos/packages/suzuha/suzuha-fingerprint.rs`
- 2-file cycle: `nixos/packages/suzuha/amane-tray.rs -> nixos/packages/suzuha/suzuha-tray.rs -> nixos/packages/suzuha/amane-tray.rs`

## Hyperedges (group relationships)
- **Nixy Declarative Configuration** — agents_nix_flake_repository, readme_nixy_configuration_system, docs_neovim_nvf_standalone_output, docs_server_cloudflare_nixos_server, docs_themes_theme_definition_system [INFERRED 0.85]

## Communities (32 total, 5 thin omitted)

### Community 0 - "suzuha-glass-region.rs"
Cohesion: 0.40
Nodes (5): blur_region(), covered(), distance(), marching_matches_every_pixel_through_merging_and_moving_panels(), separated_panels_leave_gap_and_rounded_corners_clear()

### Community 1 - "suzuha-private-dir.rs"
Cohesion: 0.09
Nodes (9): Focus, ipc(), path(), MKTEMP, preexisting_profiles_and_symlinks_are_not_reused_or_deleted(), PrivateDir, workspaces_are_private_unique_and_removed_on_drop(), FileWatch (+1 more)

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

### Community 7 - "tools.rs"
Cohesion: 0.15
Nodes (23): inject(), main(), replaces_multiple_blocks_and_strips_nested_markers(), run(), action_args(), array(), ask(), catalog() (+15 more)

### Community 8 - "Nixy Banner Identity"
Cohesion: 0.60
Nodes (5): Nixy banner image, Nix snowflake symbol, Nixy visual identity, nixy wordmark, Pastel pink and blue cloud background

### Community 9 - "Nixy Logo Design"
Cohesion: 0.40
Nodes (5): Angular interlocking geometric arms, Repository logo image, Stylized Nix snowflake symbol, Pink and purple gradient palette, Rounded black square background

### Community 11 - "suzuha-clipboard.rs"
Cohesion: 0.10
Nodes (15): CLIPHIST, copy(), Database, decode(), duplicate_previews_keep_distinct_ids_and_exact_content(), empty_history_and_missing_entry_are_handled(), find(), History (+7 more)

### Community 13 - "amane-tray.rs"
Cohesion: 0.07
Nodes (22): activate(), alive(), call(), CONNECTION, endpoint(), entries(), find_icon(), icon_folder() (+14 more)

### Community 14 - "cursor.rs"
Cohesion: 0.13
Nodes (19): accent(), cache_is_complete_bounded_and_preserves_user_themes_and_aliases(), fixture(), generate(), hls(), IMAGE, MAGIC, main() (+11 more)

### Community 15 - "system-notifications/watch.rs"
Cohesion: 0.09
Nodes (31): ACTIVE, ADAPTER, bluetooth_state(), BLUEZ, changes(), charger_only_notifies_on_external_power_changes(), daemon_restart_rebaselines_and_bursts_debounce(), DEVICE (+23 more)

### Community 16 - "suzuha-fingerprint.rs"
Cohesion: 0.15
Nodes (15): cancellation_interrupts_a_blocked_helper(), failed_scan_is_retried_without_keyboard_interaction(), fingerprint_can_win_while_password_is_pending(), Lock, PAMTESTER, password_failure_keeps_scanner_available(), password_retry_interrupts_a_stuck_scan_and_allows_a_fresh_scan(), password_success_cancels_fingerprint_and_old_scans_cannot_unlock_again() (+7 more)

### Community 17 - "suzuha-status.rs"
Cohesion: 0.12
Nodes (9): card(), edge(), fill(), tint(), SIZE, START, SWEEP, THICKNESS (+1 more)

### Community 18 - "suzuha-battery-care.rs"
Cohesion: 0.09
Nodes (7): BATTERY, CONTROL, detail(), level_icon(), number(), tab_icon(), view()

### Community 19 - "amane-background-effect.rs"
Cohesion: 0.15
Nodes (3): Effect, OpenWindow, WaylandState

### Community 20 - "ui.rs"
Cohesion: 0.21
Nodes (7): Secret, dialog(), execute(), main(), output(), run(), secret_goes_only_to_helper_stdin()

### Community 21 - "policy.rs"
Cohesion: 0.11
Nodes (17): AC, applies_custom_before_thresholds_and_clears_auth(), BATTERY, FIRMWARE, fixture(), invalid_inputs_and_unplugged_full_charge_cannot_write(), is_care(), prompt_lifecycle_remembers_brief_unplug_and_busy_lock() (+9 more)

### Community 22 - "wallpaper.lua"
Cohesion: 0.83
Nodes (3): accents(), apply(), color()

### Community 23 - "Popup"
Cohesion: 0.22
Nodes (8): click(), close(), dismiss(), ipc(), Popup, show_apps(), show_menu(), shown()

### Community 24 - "test-termfilechooser.rs"
Cohesion: 0.18
Nodes (7): Backend, DESTINATION, Fixture, main(), OBJECT, picker(), run()

### Community 25 - "path"
Cohesion: 0.24
Nodes (6): main(), run(), check(), main(), Options, run()

### Community 28 - "result"
Cohesion: 0.43
Nodes (4): enable(), main(), migration_preserves_other_settings_and_subsequent_changes(), run()

### Community 29 - "mode_button"
Cohesion: 0.25
Nodes (4): Charge, mode_button(), toggle(), hover()

### Community 30 - "Item"
Cohesion: 0.39
Nodes (4): icon(), icons(), image(), text_row()

## Knowledge Gaps
- **21 isolated node(s):** `nixy-tools`, `Hadi Donation Page`, `Funding Configuration`, `Graphify-First Codebase Workflow`, `Validation and Security Workflow` (+16 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 158 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Item` connect `suzuha-clipboard.rs` to `suzuha-tray.rs`, `Popup`, `Item`, `system-notifications/watch.rs`?**
  _High betweenness centrality (0.032) - this node is a cross-community bridge._
- **What connects `nixy-tools`, `Hadi Donation Page`, `Funding Configuration` to the rest of the system?**
  _21 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `suzuha-private-dir.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.0907258064516129 - nodes in this community are weakly interconnected._
- **Why does `icons()` connect `Item` to `suzuha-tray.rs`, `amane-tray.rs`, `Popup`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Should `tools.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.14838709677419354 - nodes in this community are weakly interconnected._
- **Should `suzuha-clipboard.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.10227272727272728 - nodes in this community are weakly interconnected._
- **Should `suzuha-tray.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.11764705882352941 - nodes in this community are weakly interconnected._