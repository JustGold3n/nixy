<div align="center">
    <img alt="nixy logo" src="./.github/assets/logo.png" width="120px" />
</div>

<br>

# Nixy

<br>
<div align="center">
    <a href="https://github.com/anotherhadi/nixy/stargazers">
        <img src="https://img.shields.io/github/stars/anotherhadi/nixy?color=A89AD1&labelColor=0b0b0b&style=for-the-badge&logo=starship&logoColor=A89AD1">
    </a>
    <a href="https://github.com/anotherhadi/nixy/">
        <img src="https://img.shields.io/github/repo-size/anotherhadi/nixy?color=A89AD1&labelColor=0b0b0b&style=for-the-badge&logo=github&logoColor=A89AD1">
    </a>
    <a href="https://nixos.org">
        <img src="https://img.shields.io/badge/NixOS-unstable-blue.svg?style=for-the-badge&labelColor=0b0b0b&logo=NixOS&logoColor=A89AD1&color=A89AD1">
    </a>
    <a href="https://github.com/anotherhadi/nixy/blob/main/LICENSE">
        <img src="https://img.shields.io/static/v1.svg?style=for-the-badge&label=License&message=MIT&colorA=0b0b0b&colorB=A89AD1&logo=unlicense&logoColor=A89AD1"/>
    </a>
</div>
<br>

**Nixy combines** Niri and the Suzuha desktop shell with a minimalist,
modular & easily customizable setup, heavily focused on TUIs. It provides a
structured way to manage your system configuration and dotfiles with minimal
effort. It includes _home-manager_, _secrets_, and _custom theming_ all in
one place.

**Features:**

- 💻 Niri & TUIs: Preconfigured Niri desktop with the Suzuha shell and terminal apps
- 🎨 Consistent Theming: Base16 & Stylix-powered themes
- ⌨️ Vim-like Everywhere: Unified keybindings (Niri, nvim, vimium, etc.)
- 🔒 Hardened by Default: LUKS encryption, sops-nix secrets, impermanence and more

## Table of Content

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Screenshots](#screenshots)
- [Architecture](#architecture)
  - [🏠 /home (User-level configuration)](#-home-user-level-configuration)
  - [🐧 /nixos](#-nixos)
  - [🎨 /themes](#-themes)
  - [💻 /hosts](#-hosts)
  - [🖥️ /server-modules](#-server-modules)
- [Installation](#installation)
- [Documentation](#documentation)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Screenshots

![Home](.github/assets/screenshots/1.png)
![Neovim and spotify](.github/assets/screenshots/2.png)
![Browser and file explorer](.github/assets/screenshots/3.png)

## Architecture

### 🏠 /home (User-level configuration)

Contains **dotfiles and settings** that apply to your user environment.

**Subfolders:**

- `gui/` contains graphical applications configured with Home Manager.
- `tui/` contains terminal applications, shells, and the `nixy` CLI.
- `system/` contains desktop integration, notifications, and session services.
- `nvf/` contains the standalone Neovim configuration flake.
- `lib/` contains shared helpers and browser start-page definitions.

Application modules use a `default.nix` entry point. The host's `home.nix`
selects modules; `home/lib/utils.nix` provides directory-based imports.
Each configured application keeps its settings, startup services, and persistence
in its own directory; `gui/pkgs/` holds the remaining package list.

### 🐧 /nixos

Those are the system-level configurations. (audio, bluetooth, gpu, bootloader,
...)

Custom package definitions live in `nixos/packages/<package>/default.nix`,
alongside their patches, source files, and package-specific regression tests.
System and Home Manager modules consume these definitions rather than keeping
package overrides inline.

### 🎨 /themes

This folder contains all system themes. Mainly
[stylix](https://stylix.danth.me/) configurations. Check out the available
themes and learn how to create your own in [THEMES.md](docs/THEMES.md)

### 💻 /hosts

This directory contains host-specific configurations. Each host includes:

- `configuration.nix` for system-wide settings
- `home.nix` for user-level configuration
- `variables.nix` for global variables
- `secrets/` for sensitive data

The primary `nixtop` flake output uses `hosts/laptop/`.
Keep personal host configuration and decrypted secrets out of commits.

### 🖥️ /server-modules

This folder contains server-related nixos modules. (gitea, cloudflared, self-hosted apps, ...)

Project documentation belongs in `docs/`; maintenance scripts and README assets
live under `.github/`. `graphify-out/` holds the current knowledge graph.
Its caches and dated backups remain local and are ignored by Git.

## Installation

1. [Fork](https://github.com/anotherhadi/nixy/fork) this repo and clone it to
   your system:

```sh
git clone https://github.com/anotherhadi/nixy ~/.config/nixos
```

2. Copy the `hosts/laptop` folder, rename it to match your system’s hostname,
   and update `variables.nix` with your machine’s settings.
3. Copy your `hardware-configuration.nix` into your new host's folder to ensure
   proper hardware support.
4. Register your new host in `flake.nix` by adding it under nixosConfigurations.

> [!IMPORTANT]
> `# CHANGEME` comments are placed throughout the config to
> indicate necessary modifications. Use the following command to quickly locate
> them:
>
> ```sh
> rg "CHANGEME" ~/.config/nixos
> ```

> [!TIP]
> When you add new files, run `git add <paths>` for the intended files so Nix can
> include them in the flake.

5. Build the system

```sh
sudo nixos-rebuild switch --flake ~/.config/nixos#yourhostname
```

## Documentation

- [SERVER](docs/SERVER.md): Check out the server documentation
- [THEMES](docs/THEMES.md): How themes work and how to create your own
- [WALLPAPERS](https://github.com/anotherhadi/awesome-wallpapers): An awesome
  collection of wallpapers
- [NEOVIM](docs/NEOVIM.md): How to use the Neovim config in your own flake

- [CONTRIBUTING](docs/CONTRIBUTING.md): How to contribute
- [LICENSE](LICENSE): MIT License

---

<div align="center">
  <a href="https://github.com/anotherhadi/nixy">github</a> |
  <a href="https://gitlab.com/anotherhadi_mirror/nixy">gitlab (mirror)</a> |
  <a href="https://git.hadi.icu/anotherhadi/nixy">gitea (mirror)</a>
</div>
