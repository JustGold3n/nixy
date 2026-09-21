{
  config,
  pkgs,
  inputs,
  ...
}: let
  clavis-pkg = pkgs.callPackage ./package.nix {src = inputs.clavis-shell;};
in {
  home.packages = [clavis-pkg];

  # Map the necessary QML modules and assets into the user's configuration directory[cite: 1]
  xdg.configFile."clavis/AppShell.qml".source = "${inputs.clavis-shell}/AppShell.qml";
  xdg.configFile."clavis/Modules".source = "${inputs.clavis-shell}/Modules";
  xdg.configFile."clavis/Components".source = "${inputs.clavis-shell}/Components";

  systemd.user.services.clavis-shell = {
    Unit = {
      Description = "Clavis Shell";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${clavis-pkg}/bin/clavis-shell"; # Adjust binary name to match CMake output
      Restart = "on-failure";

      # Systemd Execution Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
    };
    Install = {
      WantedBy = ["niri.service"]; # Binds to the existing Niri deployment
    };
  };
}
