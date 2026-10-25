{
  pkgs,
  config,
  lib,
  osConfig,
  ...
}: let
  isNixtop = (config.var.hostname or "") == "nixtop";
  useNiri = osConfig.programs.niri.enable;
  notificationService =
    if useNiri
    then "suzuha.service"
    else "swaync.service";
  keepassDatabase = "${config.home.homeDirectory}/.local/share/database_pc.kdbx";
  keepassPasswordFile = osConfig.sops.secrets.keepass.path;
  keepassConfig = "${config.xdg.configHome}/keepassxc/keepassxc.ini";
  configureKeePassXC = pkgs.writeShellScript "keepassxc-configure" ''
    set -eu
    umask 077

    ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg (dirOf keepassConfig)}
    ${pkgs.coreutils}/bin/touch ${lib.escapeShellArg keepassConfig}
    ${pkgs.coreutils}/bin/chmod 600 ${lib.escapeShellArg keepassConfig}

    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} General ConfigVersion 2
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} General MinimizeAfterUnlock true
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} GUI ApplicationTheme dark
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} GUI ShowTrayIcon true
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} GUI MinimizeToTray true
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} GUI MinimizeOnStartup true
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} GUI MinimizeOnClose true
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} Browser Enabled true
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} Browser UpdateBinaryPath false
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} Security LockDatabaseScreenLock true
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} Security LockDatabaseIdle true
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} Security LockDatabaseIdleSeconds 300
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} Security ClearClipboard true
    ${pkgs.crudini}/bin/crudini --set ${lib.escapeShellArg keepassConfig} Security ClearClipboardTimeout 20
  '';
  startKeePassXC = pkgs.writeShellScript "keepassxc-autostart" ''
    set -eu

    if [[ ! -r ${lib.escapeShellArg keepassPasswordFile} ]]; then
      echo "KeePassXC password file is not readable" >&2
      exit 1
    fi

    if [[ ! -f ${lib.escapeShellArg keepassDatabase} ]]; then
      echo "KeePassXC database does not exist: ${keepassDatabase}" >&2
      exit 1
    fi

    exec ${pkgs.keepassxc}/bin/keepassxc \
      --minimized \
      --pw-stdin \
      ${lib.escapeShellArg keepassDatabase} \
      < ${lib.escapeShellArg keepassPasswordFile}
  '';
  legcordSettings = "${config.xdg.configHome}/legcord/storage/settings.json";
  configureLegcord = pkgs.writeShellScript "legcord-configure" ''
    set -eu
    umask 077

    settings=${lib.escapeShellArg legcordSettings}
    if [[ ! -f "$settings" ]]; then
      exit 0
    fi

    temporary="$(${pkgs.coreutils}/bin/mktemp "$settings.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT

    ${lib.getExe pkgs.jq} \
      '.startMinimized = true | .minimizeToTray = true | if .tray == "disabled" then .tray = "dynamic" else . end' \
      "$settings" > "$temporary"
    ${pkgs.coreutils}/bin/chmod --reference="$settings" "$temporary"
    ${pkgs.coreutils}/bin/mv "$temporary" "$settings"
    trap - EXIT
  '';
  # Niri has no minimize action. Keep Thunderbird's main window unmapped via
  # Xwayland so mail checking continues without occupying a workspace.
  thunderbirdWindow = pkgs.writeShellApplication {
    name = "thunderbird-window";
    runtimeInputs = [pkgs.coreutils pkgs.systemd pkgs.xdotool];
    text = ''
      visibility=()
      case "''${1:-}" in
        hide) action=windowunmap; visibility=(--onlyvisible) ;;
        show) action=windowmap ;;
        *) echo "Usage: thunderbird-window hide|show" >&2; exit 2 ;;
      esac
      for _ in $(seq 1 200); do
        main_pid="$(systemctl --user show thunderbird.service -p MainPID --value)"
        if [[ "$main_pid" != 0 ]]; then
          # The X11 window exists before Thunderbird maps it during startup.
          # Wait for that first map before hiding, otherwise it reappears.
          window="$(xdotool search --all --limit 1 "''${visibility[@]}" --pid "$main_pid" --role '^3pane$' || true)"
          if [[ -n "$window" ]]; then
            if [[ "$action" == windowunmap ]]; then
              # Thunderbird maps the main window again while restoring tabs.
              # Keep it hidden through startup; the launcher waits for this
              # ExecStartPost to finish before deliberately showing it.
              for _ in $(seq 1 25); do
                timeout 5 xdotool windowunmap --sync "$window"
                sleep 0.2
              done
              exit 0
            fi
            exec timeout 5 xdotool "$action" --sync "$window"
          fi
        fi
        sleep 0.1
      done
      echo "Thunderbird's main window did not appear" >&2
      exit 1
    '';
  };
  mkSpecialWorkspaceLauncher = {
    name,
    service,
    workspace,
    windowClass,
    executable,
    revealCommand ? "",
  }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        (
          if useNiri
          then osConfig.programs.niri.package
          else pkgs.hyprland
        )
        pkgs.jq
        pkgs.systemd
      ];
      text =
        ''
          systemctl --user start ${service}.service
          ${revealCommand}
        ''
        + (
          if useNiri
          then ''
            find_client() {
              ${osConfig.programs.niri.package}/bin/niri msg --json windows \
                | ${lib.getExe pkgs.jq} -r --arg class ${lib.escapeShellArg windowClass} \
                  'first(.[] | select((.app_id // "" | ascii_downcase) == ($class | ascii_downcase)) | .id) // empty'
            }
            client_id="$(find_client)"
            if (( $# > 0 )) || [[ -z "$client_id" ]]; then
              ${executable} "$@" >/dev/null 2>&1 &
            fi
            for _ in $(seq 1 50); do
              client_id="$(find_client)"
              if [[ -n "$client_id" ]]; then
                exec ${osConfig.programs.niri.package}/bin/niri msg action focus-window --id "$client_id"
              fi
              sleep 0.1
            done
            echo "${service} started, but its window did not appear" >&2
            exit 1
          ''
          else ''
            find_client() {
              ${pkgs.hyprland}/bin/hyprctl -j clients \
                | ${lib.getExe pkgs.jq} -r --arg class ${lib.escapeShellArg windowClass} \
                  'first(.[] | select(.class == $class) | .address) // empty'
            }

            client_address="$(find_client)"

            # Both applications are single-instance. Ask the service-owned process
            # to map a minimized window, or forward a URI/file argument. Do this in
            # the background so a failed single-instance handoff cannot block the
            # launcher before it reveals the special workspace.
            if (( $# > 0 )) || [[ -z "$client_address" ]]; then
              ${executable} "$@" >/dev/null 2>&1 &
            fi

            for _ in $(seq 1 50); do
              client_address="$(find_client)"
              if [[ -n "$client_address" ]]; then
                break
              fi
              sleep 0.1
            done

            if [[ -z "$client_address" ]]; then
              echo "${service} started, but its window did not appear" >&2
              exit 1
            fi

            if ! ${pkgs.hyprland}/bin/hyprctl -j monitors \
              | ${lib.getExe pkgs.jq} -e --arg workspace ${lib.escapeShellArg "special:${workspace}"} \
                'any(.[]; .specialWorkspace.name == $workspace)' >/dev/null; then
              ${pkgs.hyprland}/bin/hyprctl dispatch togglespecialworkspace ${lib.escapeShellArg workspace} >/dev/null
            fi

            ${pkgs.hyprland}/bin/hyprctl dispatch focuswindow "address:$client_address" >/dev/null
          ''
        );
    };
  openKeePassXC = mkSpecialWorkspaceLauncher {
    name = "open-keepassxc";
    service = "keepassxc";
    workspace = "keepass";
    windowClass = "org.keepassxc.KeePassXC";
    executable = "${pkgs.keepassxc}/bin/keepassxc";
  };
  openThunderbird = mkSpecialWorkspaceLauncher {
    name = "open-thunderbird";
    service = "thunderbird";
    workspace = "mail";
    windowClass = "thunderbird";
    executable = "${config.programs.thunderbird.finalPackage}/bin/thunderbird";
    revealCommand = lib.optionalString useNiri "${lib.getExe thunderbirdWindow} show";
  };
in {
  home.packages =
    (with pkgs; [
      vlc # Video player
      obsidian # Note taking app
      pinta # Image editor
      onlyoffice-desktopeditors # Office suite
      blanket # Listen to different sounds
      signal-desktop # Messaging app
      ticktick # Todo app
      keepassxc
      legcord
      telegram-desktop

      # Backup
      thunar
      gnome-text-editor
    ])
    ++ lib.optional (!isNixtop) pkgs.thunderbird;

  home.persistence."/persist" = lib.mkIf (config.var.impermanenceEnabled or false) {
    directories = [
      ".config/ticktick"
      ".config/keepassxc"
      ".config/legcord"
      ".config/Signal"
      ".config/obsidian"
      ".thunderbird"
    ];
  };

  # Keep GUI-backed background services on unbound special workspaces. The
  # silent rules are a fallback for startup or error dialogs: neither service
  # can steal focus, switch the active workspace, or animate onto the screen.
  wayland.windowManager.hyprland.settings.windowrule = lib.mkIf (isNixtop && !useNiri) [
    "match:class ^(org\\.keepassxc\\.KeePassXC|keepassxc)$, workspace special:keepass silent, no_anim on, suppress_event activate activatefocus"
    "match:class ^(thunderbird|Thunderbird|org\\.mozilla\\.Thunderbird)$, workspace special:mail silent, no_anim on, suppress_event activate activatefocus"
  ];

  programs.thunderbird = lib.mkIf isNixtop {
    enable = true;
    package = pkgs.thunderbird;
    policies.Preferences = {
      "ui.systemUsesDarkTheme" = {
        Value = 1;
        Status = "locked";
      };
      "browser.theme.content-theme" = {
        Value = 0;
        Status = "locked";
      };
      "browser.theme.toolbar-theme" = {
        Value = 0;
        Status = "locked";
      };
      "mail.biff.show_alert" = {
        Value = true;
        Status = "locked";
      };
      "mail.biff.use_system_alert" = {
        Value = true;
        Status = "locked";
      };
    };
  };

  # Reveal the service-owned window on its compositor workspace when launched
  # again, including when the single-instance application is already running.
  xdg.desktopEntries = lib.mkIf isNixtop {
    legcord = {
      name = "Discord";
      genericName = "Internet Messenger";
      comment = "Lightweight, alternative desktop client for Discord";
      exec = "${lib.getExe pkgs.legcord} %U";
      icon = "legcord";
      terminal = false;
      categories = ["Network" "InstantMessaging" "Chat"];
      settings = {
        Keywords = "discord;vencord;electron;chat;";
        StartupWMClass = "Legcord";
      };
    };

    "org.keepassxc.KeePassXC" = {
      name = "KeePassXC";
      genericName = "Password Manager";
      comment = "Manage passwords";
      exec = "${lib.getExe openKeePassXC} %f";
      icon = "keepassxc";
      terminal = false;
      categories = ["Utility" "Security"];
      mimeType = ["application/x-keepass2"];
      settings = {
        Keywords = "security;privacy;password-manager;yubikey;password;keepass;";
        SingleMainWindow = "true";
        StartupNotify = "false";
        StartupWMClass = "keepassxc";
      };
    };

    thunderbird = {
      name = "Thunderbird";
      genericName = "Email Client";
      comment = "Read and write email or RSS feeds, or manage calendars";
      exec = "${lib.getExe openThunderbird} %U";
      icon = "thunderbird";
      terminal = false;
      categories = ["Network" "Chat" "Email" "Feed" "GTK" "News"];
      mimeType = [
        "message/rfc822"
        "x-scheme-handler/mailto"
        "text/calendar"
        "text/x-vcard"
      ];
      settings = {
        Keywords = "mail;email;e-mail;messages;rss;calendar;address book;addressbook;chat;";
        StartupNotify = "false";
        StartupWMClass = "thunderbird";
      };
    };
  };

  systemd.user.services = lib.mkIf isNixtop {
    keepassxc = {
      Unit = {
        Description = "KeePassXC unlocked from the age-encrypted SOPS secret";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "exec";
        ExecStartPre = "${configureKeePassXC}";
        ExecStart = "${startKeePassXC}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["graphical-session.target"];
    };

    thunderbird = {
      Unit = {
        Description = "Thunderbird background mail client";
        After = ["graphical-session.target" notificationService];
        Wants = [notificationService];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "exec";
        ExecStart = "${config.programs.thunderbird.finalPackage}/bin/thunderbird -mail";
        Environment = lib.optionals useNiri ["MOZ_ENABLE_WAYLAND=0" "GDK_BACKEND=x11"];
        ExecStartPost = lib.optionalString useNiri "${lib.getExe thunderbirdWindow} hide";
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = ["graphical-session.target"];
    };

    legcord = {
      Unit = {
        Description = "Legcord background Discord client";
        After = ["graphical-session.target" notificationService];
        Wants = [notificationService];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "exec";
        ExecStartPre = "${configureLegcord}";
        ExecStart = "${lib.getExe pkgs.legcord}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
