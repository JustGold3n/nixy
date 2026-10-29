{
  config,
  lib,
  pkgs,
  ...
}: let
  python = pkgs.python3.withPackages (ps: [ps.dbus-python ps.pygobject3]);
in {
  config = lib.mkIf ((config.var.hostname or "") == "nixtop") {
    services.poweralertd.enable = true;
    systemd.user.services.poweralertd.Unit.After = ["suzuha.service"];

    systemd.user.services.system-notifications = {
      Unit = {
        Description = "Network and Bluetooth event notifications";
        After = ["graphical-session.target" "suzuha.service"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${python}/bin/python ${./watch.py}";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
