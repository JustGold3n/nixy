# Neovim

The Neovim configuration is built with [nvf](https://github.com/notashelf/nvf) and exposed as a standalone flake output.
It can be used in three ways: run it directly, import it into another flake's home-manager setup, or use it as part of this config.

## Run directly

No installation needed:

```sh
nix run github:anotherhadi/nixy#nvim
```

## Use in another flake

Add this repo as an input:

```nix
inputs.nixy.url = "github:anotherhadi/nixy";
```

Then import the home-manager module in your home configuration:

```nix
{ inputs, ... }: {
  imports = [ inputs.nixy.homeManagerModules.nvim ];
}
```

## What's included

| File            | Description                                                            |
| --------------- | ---------------------------------------------------------------------- |
| `options.nix`   | Core settings: theme (catppuccin mocha), clipboard, indentation, folds |
| `languages.nix` | LSP, treesitter, formatters, diagnostics, and per-language config      |
| `keymaps.nix`   | All key mappings (leader: `space`)                                     |
| `picker.nix`    | Snacks picker + oil.nvim                                               |
| `snacks.nix`    | Snacks extras: image preview, zen mode, git signs, statuscolumn        |
| `utils.nix`     | Bufferline, lualine, copilot, lazygit, toggleterm, autocomplete        |
| `mini.nix`      | Mini.nvim suite: ai, clue, comment, diff, git, icons, indentscope, jump2d, pairs, starter, statusline, surround |

## Astro development

The development packages include Bun for package management and Node.js for tooling.
Create a project with:

```sh
bun create astro my-site
cd my-site
bun run dev
```

Keep Astro and its dependencies in the project. For command-line type checking:

```sh
bun add -D @astrojs/check typescript@6
bun run astro check
bun run build
```

`astro check` currently requires TypeScript 5 or 6; TypeScript 7 does not provide
the JavaScript API used by Astro's language tools.

Open `.astro` files with `vim` or `nvim`. Astro's language server provides completion,
diagnostics, hover information, and navigation. It uses the project's TypeScript SDK
when compatible and falls back to the Nix-provided SDK otherwise. Treesitter supplies
syntax highlighting, and Prettier includes the Astro plugin. Formatting runs on save;
press `<Space>lf` to format manually. TypeScript, HTML, CSS, and Tailwind CSS support
are also enabled.
