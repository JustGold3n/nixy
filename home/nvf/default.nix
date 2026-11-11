{...}: {
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Suzuha supplies the live palette; keep fixed Stylix colors out of Neovim.
  stylix.targets.nvf.enable = false;

  programs.nvf = {
    enable = true;
    settings = {
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
