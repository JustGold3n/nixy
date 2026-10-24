# Myx is a lean terminal Spotify player written in Rust, with album-art-reactive
# theming, a live visualizer and synced lyrics.
{
  config,
  pkgs-unstable,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs-unstable.myx];

  home.persistence."/persist" = lib.mkIf (config.var.impermanenceEnabled or false) {
    directories = [".config/myx"];
  };

  xdg.desktopEntries.myx = {
    name = "Spotify";
    exec = "${pkgs.foot}/bin/foot --override=pad=0x0 -e ${pkgs-unstable.myx}/bin/myx";
    icon = "spotify";
    comment = "Control Spotify from the terminal";
    categories = ["Audio" "Music"];
    terminal = false;
    settings.Keywords = "spotify;myx;music;";
  };
}
