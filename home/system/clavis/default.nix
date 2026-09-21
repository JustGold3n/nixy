{
  pkgs,
  inputs,
  ...
}: let
  # 1. Fetch the raw package and STRIP the broken systemd service so it doesn't conflict
  clavisPkg = inputs.clavis.packages.${pkgs.system}.default.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        rm -rf $out/share/systemd
      '';
  });

  # 2. Create the missing executable wrapper
  clavisLauncher = pkgs.writeShellScriptBin "clavis-shell" ''
    #!/bin/sh
    export MALLOC_CONF="thp:never,narenas:4,dirty_decay_ms:3000"
    export QML2_IMPORT_PATH="${clavisPkg}/lib/qml:${clavisPkg}/lib/qt-6/qml:$QML2_IMPORT_PATH"

    exec ${pkgs.quickshell}/bin/quickshell "${clavisPkg}/share/clavis-shell/shell.qml" "$@"
  '';
in {
  # Add the sanitized package and your new launcher
  home.packages = [
    clavisPkg
    clavisLauncher
  ];

  # 3. Define the systemd user service declaratively
  systemd.user.services.clavis-shell = {
    Unit = {
      Description = "Clavis Shell";
      Documentation = "https://github.com/StatIndet/quickshell";
      Requisite = "niri.service";
      PartOf = "niri.service";
      After = "niri.service";
    };

    Service = {
      Type = "simple";
      ExecStart = "${clavisLauncher}/bin/clavis-shell";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 10;
    };

    Install = {
      WantedBy = ["niri.service"];
    };
  };
}
