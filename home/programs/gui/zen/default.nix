{
  config,
  pkgs,
  lib,
  ...
}: let
  # Aggregate all modularized bookmarks into a single list
  bookmarks = import ./bookmarks {inherit pkgs lib;};
in {
  # imports = [
  #   ./system.nix
  # ];

  home.packages = [
    pkgs.zen-browser
  ];

  # Core browser configuration mapping directly to Zen's profile
  home.file.".zen/default/user.js".text = ''
    user_pref("browser.tabs.inTitlebar", 0);
    user_pref("toolkit.telemetry.enabled", false);
    user_pref("browser.send_pings", false);
    user_pref("network.http.referer.XOriginPolicy", 2);
    user_pref("privacy.donottrackheader.enabled", true);
  '';

  # Enterprise policies for native bookmark and feature integration
  home.file.".zen/distribution/policies.json".text = builtins.toJSON {
    policies = {
      DisableTelemetry = true;
      DisableFirefoxAccounts = true;
      DisablePocket = true;
      Bookmarks = bookmarks;
    };
  };
}
