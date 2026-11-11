# Feature-rich TUI RSS reader based on the news-flash library
{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: let
  # The Rust build hook requires system libraries, which upstream omits here.
  eilmeldung = pkgs-unstable.eilmeldung.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs-unstable.pkg-config];
    buildInputs = (old.buildInputs or []) ++ [pkgs-unstable.aws-lc pkgs-unstable.sqlite];
  });
in {
  home.packages = [
    eilmeldung
  ];

  home.persistence."/persist" = lib.mkIf (config.var.impermanenceEnabled or false) {
    directories = [".config/eilmeldung"];
  };

  xdg.desktopEntries.eilmeldung = {
    name = "eilmeldung";
    exec = "${pkgs.foot}/bin/foot -e ${eilmeldung}/bin/eilmeldung";
    comment = "Feature-rich TUI RSS reader";
    categories = ["Network" "ConsoleOnly"];
    terminal = false;
    settings.Keywords = "rss;feed;news;reader";
  };
}
