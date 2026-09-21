{
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.clavis-shell];

  systemd.user.services.clavis-shell = {
    Unit = {
      Description = "Clavis Shell";
      Documentation = "https://github.com/StatIndet/quickshell";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };
    Service = {
      # lib.getExe automatically resolves the absolute /nix/store path
      ExecStart = "${lib.getExe pkgs.clavis-shell} --foreground --no-duplicate";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
