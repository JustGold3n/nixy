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
  trayStartupTarget =
    if useNiri
    then "amane-tray.target"
    else "graphical-session.target";
  waitForTray = pkgs.writeShellScript "wait-for-amane-tray" ''
    for ((attempt = 0; attempt < 150; attempt++)); do
      if [[ "$(${pkgs.systemd}/bin/busctl --user --timeout=1 get-property \
          org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
          org.kde.StatusNotifierWatcher IsStatusNotifierHostRegistered 2>/dev/null)" == "b true" ]]; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 0.2
    done
    echo "Amane's system tray did not become ready" >&2
    exit 1
  '';
  birdtraySettings = "${config.xdg.configHome}/birdtray-config.json";
  birdtray = pkgs.birdtray.overrideAttrs (old: {
    patches = (old.patches or []) ++ [../../../nixos/packages/birdtray-xwayland.patch];
  });
  birdtrayDefaults = pkgs.writeText "birdtray-startup.json" (builtins.toJSON {
    "common/showhidethunderbird" = true;
    "common/launchthunderbird" = true;
    "common/hidewhenminimized" = true;
    "common/exitthunderbirdonquit" = true;
    "common/monitorthunderbirdwindow" = true;
    "common/restartthunderbird" = false;
    "common/hidewhenstarted" = true;
    "common/hidewhenrestarted" = true;
    "common/startClosedThunderbird" = true;
    "common/hideWhenStartedManually" = false;
    "common/showDialogIfNoAccountsConfigured" = false;
    "common/showunreademailcount" = false;
    "advanced/tbcmdline" = ["${config.programs.thunderbird.finalPackage}/bin/thunderbird" "-mail"];
    "advanced/tbwindowmatch" = "Mozilla Thunderbird";
    "advanced/tbprocessname" = "thunderbird";
    "advanced/updateOnStartup" = false;
    "advanced/onlyShowIconOnUnreadMessages" = false;
    "advanced/notificationfontminsize" = 4;
    "advanced/notificationfontmaxsize" = 512;
    "advanced/watchfiletimeout" = 150;
    "advanced/unreadopacitylevel" = 0.75;
  });
  configureBirdtray = pkgs.writeShellScript "birdtray-configure" ''
    set -eu
    umask 077
    settings=${lib.escapeShellArg birdtraySettings}
    ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$settings")"
    if [[ ! -e "$settings" ]]; then
      printf '{}\n' > "$settings"
    fi
    temporary="$(${pkgs.coreutils}/bin/mktemp "$settings.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT
    ${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$settings" ${birdtrayDefaults} > "$temporary"
    ${pkgs.coreutils}/bin/mv "$temporary" "$settings"
    trap - EXIT
  '';
  mkSpecialWorkspaceLauncher = {
    name,
    service,
    workspace,
    windowClass,
    executable,
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
        ''
        + ''
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
        '';
    };
  openKeePassXC =
    if useNiri
    then
      pkgs.writeShellApplication {
        name = "open-keepassxc";
        text = ''
          exec ${pkgs.keepassxc}/bin/keepassxc "$@"
        '';
      }
    else
      mkSpecialWorkspaceLauncher {
        name = "open-keepassxc";
        service = "keepassxc";
        workspace = "keepass";
        windowClass = "org.keepassxc.KeePassXC";
        executable = "${pkgs.keepassxc}/bin/keepassxc";
      };
  openThunderbird =
    if useNiri
    then
      pkgs.writeShellApplication {
        name = "open-thunderbird";
        runtimeInputs = [pkgs.systemd];
        text = ''
          systemctl --user start thunderbird.service
          export MOZ_ENABLE_WAYLAND=0 GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb
          if (( $# > 0 )); then
            ${config.programs.thunderbird.finalPackage}/bin/thunderbird "$@" &
          fi
          exec ${birdtray}/bin/birdtray --show-tb
        '';
      }
    else
      mkSpecialWorkspaceLauncher {
        name = "open-thunderbird";
        service = "thunderbird";
        workspace = "mail";
        windowClass = "thunderbird";
        executable = "${config.programs.thunderbird.finalPackage}/bin/thunderbird";
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
    ++ lib.optional (!isNixtop) pkgs.thunderbird
    ++ lib.optional (isNixtop && useNiri) birdtray;

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
        After = ["graphical-session.target" notificationService];
        Wants = [notificationService];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "exec";
        ExecStartPre = lib.optional useNiri "${waitForTray}" ++ ["${configureKeePassXC}"];
        ExecStart = "${startKeePassXC}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [trayStartupTarget];
    };

    thunderbird = {
      Unit = {
        Description = "Thunderbird background mail client with tray controls";
        After = ["graphical-session.target" notificationService];
        Wants = [notificationService];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "exec";
        ExecStartPre = lib.optionals useNiri ["${waitForTray}" "${configureBirdtray}"];
        ExecStart =
          if useNiri
          then "${birdtray}/bin/birdtray"
          else "${config.programs.thunderbird.finalPackage}/bin/thunderbird -mail";
        # Birdtray controls Thunderbird's Xwayland window through X11.
        Environment = lib.optionals useNiri ["MOZ_ENABLE_WAYLAND=0" "GDK_BACKEND=x11" "QT_QPA_PLATFORM=xcb"];
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [trayStartupTarget];
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
        ExecStartPre = lib.optional useNiri "${waitForTray}" ++ ["${configureLegcord}"];
        ExecStart = "${lib.getExe pkgs.legcord}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [trayStartupTarget];
    };
  };
}
