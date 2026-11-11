{
  config,
  lib,
  pkgs,
  ...
}: let
  tools = pkgs.callPackage ../../../nixos/packages/nixy-tools {};
in {
  config = lib.mkIf ((config.var.hostname or "") == "nixtop") {
    # Report charger connections below; battery charge-cycle states stay quiet.
    services.poweralertd.enable = false;

    services.udiskie.package = pkgs.udiskie.overrideAttrs (old: {
      patches = (old.patches or []) ++ [./udiskie-notifications.patch];
    });

    systemd.user.services.system-notifications = {
      Unit = {
        Description = "Network, Bluetooth and charger connection notifications";
        After = ["graphical-session.target" "suzuha.service"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${tools}/bin/system-notifications";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
