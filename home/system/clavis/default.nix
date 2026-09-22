{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  clavisShellPkg =
    pkgs.clavis-shell or (pkgs.callPackage ./package.nix {
      src = inputs.clavis;
      quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
    });

  runtimeDeps = with pkgs; [
    matugen
    cava
    playerctl
    brightnessctl
    wireplumber
    grim
    slurp
    wl-clipboard
    libnotify
    networkmanager
    bluez
    socat
    jq
    swww
  ];
in {
  # 1. Disable conflicting bars and notification daemons
  services.mako.enable = lib.mkForce false;
  services.dunst.enable = lib.mkForce false;
  programs.waybar.enable = lib.mkForce false;

  # 2. Add shell binary and runtime dependencies
  home.packages = [clavisShellPkg] ++ runtimeDeps;

  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_DESKTOP = "niri";
  };

  # 3. Matugen templates and configuration
  xdg.configFile."clavis/matugen/config.toml".text = ''
    [config]
    reload_apps = true

    [templates.btop]
    input_path = "~/.config/clavis/matugen/templates/btop.theme"
    output_path = "~/.config/btop/themes/clavis.theme"

    [templates.quickshell]
    input_path = "~/.config/clavis/matugen/templates/quickshell-colors.json"
    output_path = "~/.config/clavis/colors.json"

    [templates.cava]
    input_path = "~/.config/clavis/matugen/templates/cava-colors.ini"
    output_path = "~/.config/cava/config"
  '';

  xdg.configFile."clavis/matugen/templates/quickshell-colors.json".text = ''
    {
      "primary": "{{colors.primary.default.hex}}",
      "on_primary": "{{colors.on_primary.default.hex}}",
      "primary_container": "{{colors.primary_container.default.hex}}",
      "on_primary_container": "{{colors.on_primary_container.default.hex}}",
      "surface": "{{colors.surface.default.hex}}",
      "on_surface": "{{colors.on_surface.default.hex}}",
      "surface_variant": "{{colors.surface_variant.default.hex}}",
      "on_surface_variant": "{{colors.on_surface_variant.default.hex}}",
      "background": "{{colors.background.default.hex}}",
      "on_background": "{{colors.on_background.default.hex}}",
      "outline": "{{colors.outline.default.hex}}"
    }
  '';

  # 4. Systemd user service
  systemd.user.services.clavis-shell = {
    Unit = {
      Description = "Clavis Shell - Desktop Shell for Niri";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${clavisShellPkg}/bin/clavis-shell";
      Restart = "on-failure";
      RestartSec = "2s";
      Environment = [
        "PATH=${lib.makeBinPath runtimeDeps}:/run/current-system/sw/bin"
        "QT_QPA_PLATFORM=wayland"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION=1"
      ];
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
