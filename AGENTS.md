# Repository Guidelines

## Project Structure & Module Organization

This repository is a Nix flake for NixOS and Home Manager. `flake.nix` declares inputs, development shells, packages, and the `nixtop`, `h-work`, and `jack` host outputs. Keep reusable system modules in `nixos/`, user-level modules in `home/` (`gui/`, `tui/`, `system/`, and `nvf/`), host-specific configuration in `hosts/<hostname>/`, themes in `themes/`, and self-hosted service modules in `server-modules/`. Documentation belongs in `docs/`; README images and maintenance scripts live under `.github/`. Only important host is `nixtop/` ignore the rest of them.

## Build, Test, and Development Commands

- `nix develop` enters the development shell and installs the repository's Git hooks.
- `nix fmt` formats Nix files with Alejandra, the formatter declared by the flake.
- `nix flake check` evaluates flake outputs and catches module or dependency errors.
- `nixy test` builds and activates a host configuration temporarily; replace `nixtop` with the relevant flake output.
- `nixy rebuild` persists a validated configuration.
- `nix flake update` refreshes inputs and `flake.lock`; review lock-file changes before committing.

Run commands from the repository root. Newly created Nix files must be Git-tracked for flake evaluation (`git add <path>`).

## Coding Style & Naming Conventions

Use two-space indentation and let Alejandra determine layout. Prefer small, focused modules with an argument set followed by a single attribute set. Name files and directories in lowercase kebab case (for example, `server-modules/signal-cli-rest-api.nix`); use `default.nix` as a directory entry point. Keep imports grouped logically and use relative paths. Preserve `# CHANGEME` markers where downstream users must customize values.

## Testing Guidelines

There is no standalone unit-test framework or coverage target. Before submitting, run `nix fmt`, `nix flake check`, and a `nixos-rebuild test` for every affected host. For README edits, enter `nix develop` so the `doctoc` and `inject-exec` hooks can regenerate derived content.

## Commit & Pull Request Guidelines

History favors short, imperative subjects such as `make it a service`; make new subjects specific and avoid vague messages like `fix` or `changes`. Keep commits scoped to one concern. Pull requests should target `main`, explain the motivation and affected hosts/modules, list validation commands, and include screenshots for visible Hyprland, Waybar, browser, or theme changes. Link relevant issues when available.

## Security & Local Configuration

Do not commit personal host directories, decrypted secrets, passwords, private keys, or local `.sops.yaml` changes. Store encrypted values through the existing `sops-nix` structure and inspect staged changes with `git diff --cached` before pushing.
