# Contributing to Nixy

Everybody is invited and welcome to contribute to Nixy. There is a lot to do... Check the issues!

The process is straight-forward.

- Read [How to get faster PR reviews](https://github.com/kubernetes/community/blob/master/contributors/guide/pull-requests.md#best-practices-for-faster-reviews) by Kubernetes (but skip step 0 and 1)
- Fork Nixy [git repository](https://github.com/anotherhadi/nixy).
- Write your changes (new theme, bug fixes, issues fix, ...).
- Create a Pull Request against the main branch of Nixy.

> [!IMPORTANT]
> Don't push your host's folder

## Keep the layout consistent

- Put reusable NixOS modules in `nixos/` and user configuration in the appropriate
  `home/gui/`, `home/tui/`, `home/system/`, or `home/nvf/` directory.
- Keep application settings, desktop entries, startup services, and persistence
  together in `home/gui/<application>/default.nix`. Keep the remaining package
  list in `home/gui/pkgs/` and shared helpers in `home/lib/`.
- Keep each custom package in `nixos/packages/<package>/`, with `default.nix`,
  patches, supporting sources, and regression tests together. Import it from the
  modules that need it.
- Keep host settings in `hosts/`, themes in `themes/`, and self-hosted services in
  `server-modules/`. The `nixtop` output maps to `hosts/laptop/`.
- Put documentation in `docs/`, maintenance scripts in `.github/scripts/`, and
  README images in `.github/assets/`.
- Use lowercase kebab-case names for new modules. Preserve `# CHANGEME` markers.

`home/lib/utils.nix` automatically imports immediate subdirectories containing
`default.nix`. Adding an entry point there enables the module for every host
using that directory, so check the importing hosts before moving a module.

Keep build outputs, editor logs, Python bytecode, and Graphify caches or dated
backups out of Git. Retain the current graph and report in `graphify-out/`; run
`graphify update .` after code changes.

## Validate changes

Run commands from the repository root. Add new Nix files and their supporting
assets with `git add <paths>` so Git-backed flake evaluation can see them.
Stage paths selectively to avoid including personal host settings or secrets.

```sh
nix fmt .
nix flake check
sudo nixos-rebuild test --flake .#nixtop
```

Enter `nix develop` to install the Git hooks, including Alejandra for Nix files.
For README changes, run `pre-commit run --files README.md` in that shell to refresh
the generated table of contents and command output. Review the diff before
committing.

## Rust tools

Local desktop services, battery controls, and the `inject-exec` README hook are
compiled together as `nixy-tools`. Their sources stay beside the modules that
use them; the root `Cargo.toml` declares the binaries. Nix builds them with the
committed `Cargo.lock` and runs their unit tests. Systemd services, Home Manager
activation, and the README hook use the compiled binaries directly.

```sh
nix build .#nixy-tools
./result/bin/niri-tools shortcuts --list
./result/bin/niri-tools actions --list
./result/bin/battery-charge care
./result/bin/battery-charge full
```

`battery-charge` opens a local BIOS password dialog when needed. Full charging
requires the charger to be connected. The firmware helper accepts the password
only on standard input; use `battery-charge` for interactive changes.

Inside `nix develop`, run the Rust checks with:

```sh
cargo fmt --all --check
cargo clippy --locked --all-targets -- -D warnings
cargo test --locked
```

`nix flake check` also runs the standalone Nixy argument tests, the offscreen Loaf
chooser tests, and the portal tests in an isolated D-Bus session. To run those
against individual binaries during development:

```sh
cargo run --locked --bin test-nixy -- /path/to/nixy
cargo run --locked --bin test-loaf-chooser -- /path/to/loaf
dbus-run-session -- cargo run --locked --bin test-termfilechooser -- \
  --backend /path/to/xdg-desktop-portal-termfilechooser
```
