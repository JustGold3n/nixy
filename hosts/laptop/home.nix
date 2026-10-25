{
  config,
  inputs,
  lib,
  ...
}: let
  utils = import ../../home/lib/utils.nix {inherit lib;};
in {
  imports =
    utils.importAll ../../home/tui
    ++ utils.importAll ../../home/gui
    ++ (builtins.filter
      (path: !(builtins.elem (baseNameOf path) ["hyprland" "hypridle" "hyprlock" "waybar" "swaync" "power"]))
      (utils.importAll ../../home/system))
    ++ [
      ../../home/system/niri.nix
      ../../home/system/suzuha.nix
      inputs.nvf-config.homeManagerModules.default # My vim config
      #../../home/tui/git/signing.nix # CHANGEME: Change the key or remove this file
      ./variables.nix # Mostly user-specific configuration
    ];

  home = {
    inherit (config.var) username;
    homeDirectory = "/home/" + config.var.username;

    persistence."/persist" = lib.mkIf (config.var.impermanenceEnabled or false) {
      directories = [
        ".config/nixos" # this repo itself (nixy manages it here)
        ".local/share"
        ".local/state"
        ".cache"
        ".steam"
        "Notes"
        "Music"
        "Projects"
        "Documents"
        "Downloads"
        "Pictures"
        "Videos"
      ];

      files = [
        ".ssh/known_hosts"
        ".config/sops/age/keys.txt"
      ];
    };

    # Don't touch this
    stateVersion = "26.05";
  };

  disabledModules = [../../home/system/tofi/desktop-actions.nix];

  programs = {
    home-manager.enable = true;
    nixy = {
      enable = true;
      configDirectory = config.var.configDirectory;
    };
  };
}
