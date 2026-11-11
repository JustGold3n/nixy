{
  pkgs,
  config,
  lib,
  osConfig,
  ...
}: let
  isNixtop = (config.var.hostname or "") == "nixtop";
  inherit
    (import ../../lib/tray.nix {inherit pkgs osConfig;})
    useNiri
    notificationService
    trayStartupTarget
    waitForTray
    ;
  vesktopSettings = "${config.xdg.configHome}/vesktop/settings.json";
  configureVesktop = pkgs.writeShellScript "vesktop-configure" ''
    set -eu
    umask 077

    settings=${lib.escapeShellArg vesktopSettings}
    if [[ ! -f "$settings" ]]; then
      exit 0
    fi

    temporary="$(${pkgs.coreutils}/bin/mktemp "$settings.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT

    ${lib.getExe pkgs.jq} \
      '.minimizeToTray = true | .tray = true' \
      "$settings" > "$temporary"
    ${pkgs.coreutils}/bin/chmod --reference="$settings" "$temporary"
    ${pkgs.coreutils}/bin/mv "$temporary" "$settings"
    trap - EXIT
  '';
in {
  home.packages = [pkgs.vesktop];

  home.persistence."/persist" = lib.mkIf (config.var.impermanenceEnabled or false) {
    directories = [".config/vesktop"];
  };

  # Reuse the background application when its desktop entry is launched.
  xdg.desktopEntries.vesktop = lib.mkIf isNixtop {
    name = "Discord";
    genericName = "Internet Messenger";
    comment = "Lightweight, alternative desktop client for Discord";
    exec = "${lib.getExe pkgs.vesktop} %U";
    icon = "vesktop";
    terminal = false;
    categories = ["Network" "InstantMessaging" "Chat"];
    mimeType = ["x-scheme-handler/discord"];
    settings = {
      Keywords = "discord;vencord;electron;chat;";
      StartupWMClass = "Vesktop";
    };
  };

  systemd.user.services.vesktop = lib.mkIf isNixtop {
    Unit = {
      Description = "Vesktop background Discord client";
      After = ["graphical-session.target" notificationService];
      Wants = [notificationService];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "exec";
      ExecStartPre = lib.optional useNiri "${waitForTray}" ++ ["${configureVesktop}"];
      ExecStart = "${lib.getExe pkgs.vesktop} --start-minimized";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [trayStartupTarget];
  };
}
