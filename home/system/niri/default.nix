{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.niri = {
    enable = true;

    settings = {
      input = {
        keyboard = {
          xkb = {
            layout = "us,cz";
          };
        };
        touchpad = {
          tap = true;
          natural-scroll = true;
        };
      };

      layout = {
        gaps = 12;
        border = {
          enable = true;
          width = 2;
          active.color = "#88c0d0";
          inactive.color = "#4c566a";
        };
        focus-ring = {
          enable = false;
        };
      };

      spawn-at-startup = [
        # Restarts the systemd user service created previously to guarantee
        # it hooks correctly into the active Wayland display session.
        {command = ["systemctl" "--user" "restart" "clavis-shell.service"];}
        # Polkit authentication agent (required for GUI privilege escalation)
        {command = ["${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"];}
      ];

      # Environment variables for Wayland
      environment = {
        DISPLAY = ":0";
        NIXOS_OZONE_WL = "1";
        QT_QPA_PLATFORM = "wayland";
        MOZ_ENABLE_WAYLAND = "1";
      };

      binds = {
        # Core Applications
        "Mod+Return".action.spawn = ["ghostty"];
        "Mod+D".action.spawn = ["tofi-drun"];
        "Mod+Q".action.close-window = {};

        # Window Navigation
        "Mod+Left".action.focus-column-left = {};
        "Mod+Right".action.focus-column-right = {};
        "Mod+Up".action.focus-window-up = {};
        "Mod+Down".action.focus-window-down = {};

        # Window Movement
        "Mod+Shift+Left".action.move-column-left = {};
        "Mod+Shift+Right".action.move-column-right = {};
        "Mod+Shift+Up".action.move-window-up-or-to-workspace-up = {};
        "Mod+Shift+Down".action.move-window-down-or-to-workspace-down = {};

        # Monitor Focus
        "Mod+Shift+Ctrl+Left".action.focus-monitor-left = {};
        "Mod+Shift+Ctrl+Right".action.focus-monitor-right = {};

        # Workspace Navigation
        "Mod+1".action.focus-workspace = 1;
        "Mod+2".action.focus-workspace = 2;
        "Mod+3".action.focus-workspace = 3;
        "Mod+4".action.focus-workspace = 4;
        "Mod+5".action.focus-workspace = 5;

        # Move Window to Workspace
        "Mod+Shift+1".action.move-column-to-workspace = 1;
        "Mod+Shift+2".action.move-column-to-workspace = 2;
        "Mod+Shift+3".action.move-column-to-workspace = 3;
        "Mod+Shift+4".action.move-column-to-workspace = 4;
        "Mod+Shift+5".action.move-column-to-workspace = 5;

        # System Controls
        "Print".action.spawn = ["grim" "-g" ''"$(slurp)"''];
        "Mod+Shift+E".action.quit = {};
      };
    };
  };
}
