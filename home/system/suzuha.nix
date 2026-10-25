{
  config,
  lib,
  inputs,
  pkgs-unstable,
  ...
}: let
  suzuha = pkgs-unstable.callPackage ../../nixos/packages/suzuha.nix {inherit inputs;};
in {
  scripts.suzuha = suzuha;
  home.packages = [suzuha];
  home.file."Pictures/Wallpapers/nixy.png".source = config.stylix.image;
  # Seed a wallpaper once; later changes in Suzuha's settings remain writable.
  home.activation.suzuhaWallpaper = lib.hm.dag.entryAfter ["writeBoundary"] ''
    state="${config.xdg.stateHome}/amane"
    run mkdir -p "$state"
    if [ ! -e "$state/wallpaper-selection" ]; then
      run sh -c 'printf "%s\\n" "$1" > "$2"' sh \
        "${config.home.homeDirectory}/Pictures/Wallpapers/nixy.png" "$state/wallpaper-selection"
    fi
  '';
  xdg.configFile = {
    "amane/shaders".source = "${inputs.suzuha}/shaders";
    "amane/cava.conf".source = "${inputs.suzuha}/cava.conf";
  };

  systemd.user.services.suzuha = {
    Unit = {
      Description = "Suzuha desktop shell";
      PartOf = ["niri.service"];
      After = ["graphical-session.target"];
      ConditionEnvironment = "NIRI_SOCKET";
    };
    Service = {
      ExecStart = "${suzuha}/bin/suzuha";
      # Applications launched by the shell must survive shell updates/restarts.
      KillMode = "process";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = ["niri.service"];
  };
}
