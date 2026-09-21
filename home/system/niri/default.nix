{
  config,
  pkgs,
  lib,
  ...
}: {
  # We bypass the missing Home Manager module and write the config directly to the XDG path
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us,cz"
            }
        }
        touchpad {
            tap
            natural-scroll
        }
    }

    layout {
        gaps 12
        border {
            width 2
            active-color "#88c0d0"
            inactive-color "#4c566a"
        }
        focus-ring {
            off
        }
    }

    spawn-at-startup "systemctl" "--user" "restart" "clavis-shell.service"
    spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"

    environment {
        DISPLAY ":0"
        NIXOS_OZONE_WL "1"
        QT_QPA_PLATFORM "wayland"
        MOZ_ENABLE_WAYLAND "1"
    }

    binds {
        Mod+Return { spawn "ghostty"; }
        Mod+D { spawn "tofi-drun"; }
        Mod+Q { close-window; }

        Mod+Left { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Up { focus-window-up; }
        Mod+Down { focus-window-down; }

        Mod+Shift+Left { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+Shift+Up { move-window-up-or-to-workspace-up; }
        Mod+Shift+Down { move-window-down-or-to-workspace-down; }

        Mod+Shift+Ctrl+Left { focus-monitor-left; }
        Mod+Shift+Ctrl+Right { focus-monitor-right; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }

        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }

        Print { spawn "sh" "-c" "grim -g \"$(slurp)\""; }
        Mod+Shift+E { quit; }
    }
  '';
}
