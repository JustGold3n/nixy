{
  pkgs,
  config,
  lib,
  osConfig,
  ...
}: let
  isNixtop = (config.var.hostname or "") == "nixtop";
  inherit
    (import ../../lib/tray.nix {inherit pkgs osConfig;})
    useNiri
    notificationService
    trayStartupTarget
    waitForTray
    ;
  birdtraySettings = "${config.xdg.configHome}/birdtray-config.json";
  birdtray = pkgs.callPackage ../../../nixos/packages/birdtray {};
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
  openThunderbird = pkgs.writeShellApplication {
    name = "open-thunderbird";
    runtimeInputs = [pkgs.systemd];
    text =
      if useNiri
      then ''
        systemctl --user start thunderbird.service
        export MOZ_ENABLE_WAYLAND=0 GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb
        if (( $# > 0 )); then
          ${config.programs.thunderbird.finalPackage}/bin/thunderbird "$@" &
        fi
        exec ${birdtray}/bin/birdtray --show-tb
      ''
      else ''
        exec ${config.programs.thunderbird.finalPackage}/bin/thunderbird "$@"
      '';
  };
in {
  home.packages =
    lib.optional (!isNixtop) pkgs.thunderbird
    ++ lib.optional (isNixtop && useNiri) birdtray;

  home.persistence."/persist" = lib.mkIf (config.var.impermanenceEnabled or false) {
    directories = [".thunderbird"];
  };

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

  # Reuse the background application when its desktop entry is launched.
  xdg.desktopEntries.thunderbird = lib.mkIf isNixtop {
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

  systemd.user.services.thunderbird = lib.mkIf isNixtop {
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
}
