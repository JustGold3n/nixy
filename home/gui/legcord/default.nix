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
  legcordSettings = "${config.xdg.configHome}/legcord/storage/settings.json";
  configureLegcord = pkgs.writeShellScript "legcord-configure" ''
    set -eu
    umask 077

    settings=${lib.escapeShellArg legcordSettings}
    if [[ ! -f "$settings" ]]; then
      exit 0
    fi

    temporary="$(${pkgs.coreutils}/bin/mktemp "$settings.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT

    ${lib.getExe pkgs.jq} \
      '.startMinimized = true | .minimizeToTray = true | if .tray == "disabled" then .tray = "dynamic" else . end' \
      "$settings" > "$temporary"
    ${pkgs.coreutils}/bin/chmod --reference="$settings" "$temporary"
    ${pkgs.coreutils}/bin/mv "$temporary" "$settings"
    trap - EXIT
  '';
in {
  home.packages = [pkgs.legcord];

  home.persistence."/persist" = lib.mkIf (config.var.impermanenceEnabled or false) {
    directories = [".config/legcord"];
  };

  # Reuse the background application when its desktop entry is launched.
  xdg.desktopEntries.legcord = lib.mkIf isNixtop {
    name = "Discord";
    genericName = "Internet Messenger";
    comment = "Lightweight, alternative desktop client for Discord";
    exec = "${lib.getExe pkgs.legcord} %U";
    icon = "legcord";
    terminal = false;
    categories = ["Network" "InstantMessaging" "Chat"];
    settings = {
      Keywords = "discord;vencord;electron;chat;";
      StartupWMClass = "Legcord";
    };
  };

  systemd.user.services.legcord = lib.mkIf isNixtop {
    Unit = {
      Description = "Legcord background Discord client";
      After = ["graphical-session.target" notificationService];
      Wants = [notificationService];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "exec";
      ExecStartPre = lib.optional useNiri "${waitForTray}" ++ ["${configureLegcord}"];
      ExecStart = "${lib.getExe pkgs.legcord}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [trayStartupTarget];
  };
}
