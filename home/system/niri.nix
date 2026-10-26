{
  config,
  lib,
  pkgs,
  osConfig,
  scripts,
  ...
}: let
  niri = osConfig.programs.niri.package;
  colors = config.lib.stylix.colors;
  amane = "${scripts.suzuha}/bin/amane";
  tools = pkgs.writeShellApplication {
    name = "niri-tools";
    runtimeInputs = [niri pkgs.foot pkgs.python3 pkgs.fzf];
    text = ''
      exec python3 ${./niri/tools.py} "$@"
    '';
  };
  scratch = pkgs.writeShellApplication {
    name = "niri-scratch-toggle";
    runtimeInputs = [niri pkgs.jq];
    text = ''
      if niri msg --json workspaces | jq -e 'any(.[]; .is_focused and .name == "scratch")' >/dev/null; then
        niri msg action focus-workspace-previous
      else
        niri msg action focus-workspace scratch
      fi
    '';
  };
  lock = pkgs.writeShellApplication {
    name = "suzuha-lock";
    runtimeInputs = [pkgs.systemd pkgs.coreutils];
    text = ''
      ${amane} ipc call lock
      # IPC starts an animation asynchronously. Wait for Niri's acknowledgement
      # before swayidle releases its delay inhibitor and lets the laptop sleep.
      for _ in $(seq 1 80); do
        if [[ "$(loginctl show-session "$XDG_SESSION_ID" -p LockedHint --value)" == yes ]]; then
          exit 0
        fi
        sleep 0.05
      done
      echo "Suzuha did not lock the session within four seconds" >&2
      exit 1
    '';
  };
in {
  home.packages = with pkgs; [
    brightnessctl
    playerctl
    papirus-icon-theme
    adw-gtk3
    qt6.qtwayland
    libsForQt5.qt5.qtwayland
  ];
  qt.enable = true;
  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };
  home.sessionVariables = {
    TERMINAL = "foot";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_STYLE_OVERRIDE = lib.mkForce "Fusion";
    XDG_ICON_DIR = "${pkgs.papirus-icon-theme}/share/icons/Papirus";
  };

  services.polkit-gnome.enable = true;
  services.swayidle = {
    enable = true;
    systemdTargets = ["niri.service"];
    events = {
      before-sleep = lib.getExe lock;
      after-resume = "${niri}/bin/niri msg action power-on-monitors";
    };
    timeouts = [
      {
        timeout = 300;
        command = lib.getExe lock;
      }
      {
        timeout = 720;
        command = "${niri}/bin/niri msg action power-off-monitors";
        resumeCommand = "${niri}/bin/niri msg action power-on-monitors";
      }
      {
        timeout = 1800;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
  };
  systemd.user.services.swayidle.Unit.After = ["suzuha.service"];

  xdg.desktopEntries = {
    lock = {
      name = "Lock Screen";
      exec = lib.getExe lock;
      icon = "system-lock-screen";
      categories = ["System"];
    };
    logout = {
      name = "Logout";
      exec = "${niri}/bin/niri msg action quit";
      icon = "system-log-out";
      categories = ["System"];
    };
    suzuha-settings = {
      name = "Desktop Settings";
      exec = "amane ipc call settings";
      icon = "preferences-system";
      categories = ["Settings"];
    };
    amane-clipboard = {
      name = "Amane Clipboard History";
      exec = "${amane} ipc call clipboard";
      icon = "edit-paste-symbolic";
      categories = ["Utility"];
      comment = "Search and restore clipboard history";
    };
  };

  xdg.configFile."niri/config.kdl".text = ''
    cursor {
      xcursor-theme "${config.home.pointerCursor.name}"
      xcursor-size ${toString config.home.pointerCursor.size}
    }
    input {
      keyboard {
        xkb {
          layout "${config.var.keyboardLayout}"
          variant "${config.var.keyboardVariant or ""}"
          options "grp:alt_shift_toggle,caps:escape"
        }
        repeat-delay 300
        repeat-rate 50
        numlock
      }
      touchpad {
        tap
        natural-scroll
        click-method "clickfinger"
      }
      focus-follows-mouse max-scroll-amount="0%"
    }

    output "eDP-1" {
      scale 1
    }
    output "AOC U34G2G1 0x00000E06" {
      mode "3440x1440@99.98"
      scale 1
    }

    layout {
      // Show Suzuha's wallpaper, which is placed in the overview backdrop.
      background-color "transparent"
      gaps ${toString config.theme.gaps-out}
      center-focused-column "on-overflow"
      default-column-width { proportion 0.5; }
      preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
      }
      focus-ring {
        width ${toString config.theme.border-size}
        active-color "#${colors.base0D}"
        inactive-color "#${colors.base03}"
      }
      border { off; }
    }
    prefer-no-csd
    layer-rule {
      match namespace="^wallpaper$"
      place-within-backdrop true
    }
    screenshot-path "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png"
    hotkey-overlay { skip-at-startup; }
    ${lib.concatMapStringsSep "\n" (i: ''workspace "${toString i}"'') (lib.range 1 9)}
    workspace "scratch"
    window-rule {
      geometry-corner-radius ${toString config.theme.rounding}
      clip-to-geometry true
    }
    window-rule {
      match app-id=r#"^(org\.keepassxc\.KeePassXC|keepassxc)$"#
      open-focused false
    }
    window-rule {
      match app-id=r#"^(thunderbird|Thunderbird|org\.mozilla\.Thunderbird)$"#
      open-focused false
    }
    window-rule {
      match app-id=r#"(?i)^(zen|zen-browser|zen-twilight|app\.zen_browser\.zen)$"#
      exclude title="^Picture-in-Picture$"
      open-maximized true
      open-maximized-to-edges false
    }
    window-rule {
      match app-id=r#"(?i)^(steam|com\.valvesoftware\.Steam)$"#
      match app-id=r#"(?i)^(discord|discordcanary|discordptb|legcord|com\.discordapp\.Discord|io\.github\.legcord\.legcord)$"#
      default-column-width { proportion 0.75; }
      open-maximized false
      open-maximized-to-edges false
    }
    window-rule {
      match app-id="^niri-tools$"
      open-floating true
      default-column-width { fixed 1000; }
      default-window-height { fixed 700; }
    }

    binds {
      Mod+F1 repeat=false hotkey-overlay-title="Search all shortcuts" { spawn "${lib.getExe tools}" "shortcuts"; }
      Mod+F2 repeat=false hotkey-overlay-title="Search Niri actions" { spawn "${lib.getExe tools}" "actions"; }
      Mod+Alt+F9 repeat=false hotkey-overlay-title="Stop a screencast" { spawn "${lib.getExe tools}" "actions" "--action" "stop-cast"; }
      Mod+X repeat=false hotkey-overlay-title="Power menu" { spawn "${amane}" "ipc" "call" "power"; }
      Mod+Y repeat=false hotkey-overlay-title="Background apps / system tray" { spawn "${amane}" "ipc" "call" "tray"; }
      Mod+Return { spawn "${pkgs.foot}/bin/foot"; }
      Mod+E { spawn "${pkgs.foot}/bin/foot" "-e" "elio"; }
      Mod+T { spawn "${config.programs.zen-browser.package}/bin/zen-twilight"; }
      Mod+D { spawn "amane" "ipc" "call" "launcher" "toggle"; }
      Mod+Space { spawn "amane" "ipc" "call" "launcher" "toggle"; }
      Mod+N { spawn "amane" "ipc" "call" "utility" "toggle" "notifications"; }
      Mod+C { spawn "amane" "ipc" "call" "control" "toggle"; }
      Mod+Comma { spawn "amane" "ipc" "call" "settings"; }
      Mod+Shift+W { spawn "amane" "ipc" "call" "wallpaper" "toggle"; }
      Mod+Shift+P { spawn "amane" "ipc" "call" "launcher" "showTmux"; }
      Mod+Escape { spawn "${lib.getExe lock}"; }
      Ctrl+B { spawn "${scripts.clipboard-menu}/bin/clipboard-menu"; }
      Ctrl+Shift+F repeat=false hotkey-overlay-title="Amane clipboard history" { spawn "${amane}" "ipc" "call" "clipboard"; }

      Mod+Q { close-window; }
      Mod+F { fullscreen-window; }
      Mod+Shift+F { toggle-window-floating; }
      Mod+Shift+D repeat=false hotkey-overlay-title="Toggle focus mode" { spawn "${amane}" "ipc" "call" "focus"; }
      Mod+S repeat=false hotkey-overlay-title="Toggle scratch workspace" { spawn "${lib.getExe scratch}"; }
      Mod+Shift+S repeat=false hotkey-overlay-title="Send window to scratch" { move-window-to-workspace "scratch" focus=false; }
      Mod+Tab { toggle-overview; }
      Mod+H { focus-column-left; }
      Mod+J { focus-window-down; }
      Mod+K { focus-window-up; }
      Mod+L { focus-column-right; }
      // Hyprland's monitor and master-stack shortcuts, translated to Niri.
      Mod+Shift+H { focus-monitor-previous; }
      Mod+Shift+L { focus-monitor-next; }
      Mod+Shift+J hotkey-overlay-title="Split bottom window into its own column" { expel-window-from-column; }
      Mod+Shift+K hotkey-overlay-title="Add next window to current column" { consume-window-into-column; }
      Mod+Ctrl+Shift+H { move-column-left; }
      Mod+Ctrl+Shift+J { move-window-down; }
      Mod+Ctrl+Shift+K { move-window-up; }
      Mod+Ctrl+Shift+L { move-column-right; }
      Mod+Ctrl+H { focus-monitor-left; }
      Mod+Ctrl+L { focus-monitor-right; }
      Mod+R { switch-preset-column-width; }
      // Niri provides Super+left-drag to move and Super+right-drag to resize.
      Mod+Minus { set-column-width "-10%"; }
      Mod+Equal { set-column-width "+10%"; }
      Mod+Page_Up { focus-workspace-up; }
      Mod+Page_Down { focus-workspace-down; }
      Mod+Shift+Page_Up { move-column-to-workspace-up; }
      Mod+Shift+Page_Down { move-column-to-workspace-down; }
      Mod+Shift+E { quit; }
      Mod+Shift+Slash { show-hotkey-overlay; }
      Print { screenshot; }
      Mod+Print { screenshot-window; }
      Mod+Shift+Print { screenshot-screen; }

      XF86AudioRaiseVolume allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "-l" "1.0" "@DEFAULT_AUDIO_SINK@" "5%+"; }
      XF86AudioLowerVolume allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
      XF86AudioMute allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
      XF86AudioMicMute allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
      XF86AudioPlay allow-when-locked=true { spawn "${pkgs.playerctl}/bin/playerctl" "play-pause"; }
      XF86AudioPause allow-when-locked=true { spawn "${pkgs.playerctl}/bin/playerctl" "play-pause"; }
      XF86AudioNext allow-when-locked=true { spawn "${pkgs.playerctl}/bin/playerctl" "next"; }
      XF86AudioPrev allow-when-locked=true { spawn "${pkgs.playerctl}/bin/playerctl" "previous"; }
      XF86AudioStop allow-when-locked=true { spawn "${pkgs.playerctl}/bin/playerctl" "stop"; }
      XF86MonBrightnessUp allow-when-locked=true { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "+5%"; }
      XF86MonBrightnessDown allow-when-locked=true { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%-"; }
      ${builtins.readFile ./niri/extra-bindings.kdl}
      ${lib.concatMapStringsSep "\n" (i: ''
      Mod+${toString i} { focus-workspace "${toString i}"; }
      Mod+Shift+${toString i} { move-window-to-workspace "${toString i}"; }
      Mod+Ctrl+Shift+${toString i} { move-column-to-workspace "${toString i}"; }
      Mod+Ctrl+${toString i} { move-column-to-workspace "${toString i}"; }
      Mod+Alt+${toString i} { focus-column ${toString i}; }
      Mod+Alt+Shift+${toString i} { focus-window-in-column ${toString i}; }
      Mod+Alt+Ctrl+${toString i} { move-column-to-index ${toString i}; }
      Mod+Alt+Ctrl+Shift+${toString i} { move-workspace-to-index ${toString i}; }
    '') (lib.range 1 9)}
    }
    // Suzuha exports its wallpaper-derived palette; Niri watches for changes.
    include optional=true "${config.home.homeDirectory}/.local/state/amane/niri-colors.kdl"
    include optional=true "${config.home.homeDirectory}/.local/state/amane/niri-focus-mode.kdl"
  '';
}
