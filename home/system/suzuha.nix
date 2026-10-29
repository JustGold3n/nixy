{
  config,
  lib,
  inputs,
  pkgs,
  pkgs-unstable,
  ...
}: let
  suzuha = pkgs-unstable.callPackage ../../nixos/packages/suzuha {inherit inputs;};
  # Suzuha currently uses this path directly, rather than XDG_STATE_HOME.
  stateHome = "${config.home.homeDirectory}/.local/state/amane";
  enableIntegrations = pkgs.writeText "suzuha-enable-integrations.py" ''
    from pathlib import Path
    import sys

    state = Path(sys.argv[1])
    config_home = Path(sys.argv[2])
    state.mkdir(parents=True, exist_ok=True)

    # Enable once, preserving other settings and subsequent UI changes.
    marker = state / "theme-integrations-enabled"
    if not marker.exists():
        keys = {
            f"integration_{name}"
            for name in ("gtk", "terminal", "tmux", "vesktop", "spotify", "btop", "cava")
        }
        settings = state / "settings"
        lines = settings.read_text().splitlines() if settings.exists() else []
        lines = [line for line in lines if line.partition("=")[0] not in keys]
        lines.extend(f"{key}=true" for key in sorted(keys))
        pending = settings.with_suffix(".partial")
        pending.write_text("\n".join(lines) + "\n")
        pending.replace(settings)
        marker.touch()

    # Foot requires its include to exist before the shell exports its palette.
    palette = state / "terminal-colors-foot.ini"
    if not palette.exists():
        palette.write_text("# Populated by Suzuha at startup.\n")
    # The upstream Vesktop exporter expects this directory to exist already.
    (config_home / "vesktop/settings").mkdir(parents=True, exist_ok=True)
  '';
in {
  scripts.suzuha = suzuha;
  home.packages = [suzuha];
  home.file."Pictures/Wallpapers/nixy.png".source = config.stylix.image;
  home.activation.suzuhaThemeIntegrations = lib.hm.dag.entryBetween ["reloadSystemd"] ["writeBoundary"] ''
    run ${pkgs.python3}/bin/python3 ${enableIntegrations} \
      ${lib.escapeShellArg stateHome} ${lib.escapeShellArg config.xdg.configHome}
  '';

  # Keep Stylix fonts, but let Suzuha own the generated application palettes.
  stylix.targets = {
    gtk.colors.enable = false;
    foot.colors.enable = false;
    btop.colors.enable = false;
    cava.enable = false;
  };
  programs.foot.settings.main.include = ["${stateHome}/terminal-colors-foot.ini"];
  programs.btop.settings.color_theme = "amane";
  programs.cava.settings.color.theme = "amane";

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
    "tmux/tmux.conf".text = ''
      source-file -q ${lib.escapeShellArg "${stateHome}/tmux-colors.conf"}
    '';
  };

  systemd.user.services.suzuha = {
    Unit = {
      Description = "Suzuha desktop shell";
      PartOf = ["niri.service"];
      After = ["graphical-session.target"];
      ConditionEnvironment = "NIRI_SOCKET";
      X-Restart-Triggers = ["${enableIntegrations}"];
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

  systemd.user.targets.amane-tray = {
    Unit = {
      Description = "Applications in the Amane system tray";
      Wants = ["suzuha.service"];
      After = ["suzuha.service"];
      PartOf = ["graphical-session.target"];
    };
    Install.WantedBy = ["niri.service"];
  };
}
