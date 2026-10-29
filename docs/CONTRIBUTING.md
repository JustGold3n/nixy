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
