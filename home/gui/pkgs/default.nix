{
  pkgs,
  config,
  lib,
  ...
}: let
  isNixtop = (config.var.hostname or "") == "nixtop";
in {
  home.packages =
    (with pkgs; [
      vlc # Video player
      obsidian # Note taking app
      pinta # Image editor
      onlyoffice-desktopeditors # Office suite
      blanket # Listen to different sounds
      signal-desktop # Messaging app
      ticktick # Todo app
      telegram-desktop

      # Backup
      gnome-text-editor
    ])
    ++ lib.optional (!isNixtop) pkgs.thunar;

  home.persistence."/persist" = lib.mkIf (config.var.impermanenceEnabled or false) {
    directories = [
      ".config/ticktick"
      ".config/Signal"
      ".config/obsidian"
    ];
  };
}
