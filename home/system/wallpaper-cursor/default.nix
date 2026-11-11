{
  config,
  lib,
  pkgs,
  ...
}: let
  cursor = config.home.pointerCursor;
  state = "${config.home.homeDirectory}/.local/state/amane";
  command = lib.escapeShellArgs [
    "${pkgs.callPackage ../../../nixos/packages/nixy-tools {}}/bin/wallpaper-cursor"
    "--source"
    "${cursor.package}/share/icons/${cursor.name}"
    "--state"
    state
    "--icons"
    "${config.xdg.dataHome}/icons"
    "--size"
    (toString cursor.size)
    "--dconf"
    "${pkgs.dconf}/bin/dconf"
    "--systemctl"
    "${pkgs.systemd}/bin/systemctl"
  ];
in {
  home.sessionSearchVariables.XCURSOR_PATH = ["${config.xdg.dataHome}/icons"];
  # Desktop settings supply the live theme. Fixed GTK/dconf values would reset
  # it at activation or make new GTK apps pick the old purple pointer.
  gtk.cursorTheme = lib.mkForce null;
  systemd.user.services.wallpaper-cursor = {
    Unit = {
      Description = "Match the mouse pointer to Suzuha's wallpaper palette";
      PartOf = ["niri.service"];
      After = ["suzuha.service"];
      ConditionEnvironment = "NIRI_SOCKET";
    };
    Service = {
      ExecStart = command;
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = ["niri.service"];
  };
}
