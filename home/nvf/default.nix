{
  config,
  lib,
  ...
}: {
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Stylix's nvf target still sets the deprecated lualine.theme option.
  # Apply its theme locally until the target supports the current nvf API.
  stylix.targets.nvf.enable = false;

  programs.nvf = {
    enable = true;
    settings = {
      vim.theme = lib.mkIf (config ? stylix && config.stylix.enable) {
        enable = true;
        name = config.stylix.targets.nvf.plugin;
        base16-colors = lib.filterAttrs (name: _: builtins.match "base0[0-9A-F]" name != null) config.lib.stylix.colors.withHashtag;
        transparent = config.stylix.targets.nvf.transparentBackground;
      };
      vim.statusline.lualine.setupOpts.options.theme = lib.mkIf (
        config ? stylix && config.stylix.enable && config.stylix.targets.nvf.plugin == "base16"
      ) "base16";
      vim.luaConfigRC = lib.mkIf (config ? stylix && config.stylix.enable) {
        hl-overrides = let
          c = config.lib.stylix.colors;
        in ''
          local function apply_hl()
            vim.api.nvim_set_hl(0, "MiniStarterHeader",   { fg = "#${c.base0D}", bold = true })
            vim.api.nvim_set_hl(0, "SnacksPickerBorder",  { fg = "#${c.base0D}" })
            vim.api.nvim_set_hl(0, "SnacksPickerTitle",   { fg = "#${c.base0D}", bold = true })
          end
          apply_hl()
          vim.api.nvim_create_autocmd("ColorScheme", { pattern = "*", callback = apply_hl })
        '';
      };
      imports = [
        ./options.nix
        ./languages.nix
        ./picker.nix
        ./snacks.nix
        ./keymaps.nix
        ./utils.nix
        ./mini.nix
      ];
    };
  };
}
