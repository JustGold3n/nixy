{
  config,
  pkgs,
  ...
}: {
  xdg.configFile."niri/config.kdl".text = ''
    // Environment & daemons
        spawn-at-startup "dbus-update-activation-environment" "--systemd" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP"
        spawn-at-startup "systemctl" "--user" "import-environment" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP"
        spawn-at-startup "systemctl" "--user" "restart" "clavis-shell.service"
        spawn-at-startup "awww-daemon"    binds {
        // Spotlight / App Launcher
        Mod+Space       { spawn "clavis-shell" "ipc" "spotlight" "toggle"; }
        Mod+D           { spawn "clavis-shell" "ipc" "spotlight" "toggle"; }

        // Control Center & Dashboards
        Mod+C           { spawn "clavis-shell" "ipc" "control-center" "toggle"; }
        Mod+N           { spawn "clavis-shell" "ipc" "dashboard" "toggle"; }

        // Session Lock
        Mod+Alt+L       { spawn "clavis-shell" "ipc" "lock"; }

        // Power Menu
        Mod+Escape      { spawn "clavis-shell" "ipc" "power-menu" "toggle"; }

        // Region Selection Screenshot
        Print           { spawn "clavis-shell" "ipc" "region-select"; }
        Mod+Shift+S     { spawn "clavis-shell" "ipc" "region-select"; }

        // Volume
        XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "-l" "1.5" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute        allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86AudioMicMute     allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }

        // Brightness
        XF86MonBrightnessUp   allow-when-locked=true { spawn "brightnessctl" "set" "5%+"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "set" "5%-"; }

        // Media Controls
        XF86AudioPlay  allow-when-locked=true { spawn "playerctl" "play-pause"; }
        XF86AudioNext  allow-when-locked=true { spawn "playerctl" "next"; }
        XF86AudioPrev  allow-when-locked=true { spawn "playerctl" "previous"; }
    }

    window-rule {
        match app-id=r#"^clavis.*"#
        open-floating true
        draw-border-with-background false
    }

    window-rule {
        match app-id="clavis-region-selector"
        open-floating true
        default-floating-position center
        draw-border-with-background false
    }

    layer-rule {
        match namespace="^clavis-.*"
    }
  '';
}
