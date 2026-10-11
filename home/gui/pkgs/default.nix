{
  pkgs,
  config,
  lib,
  osConfig,
  ...
}: let
  isNixtop = (config.var.hostname or "") == "nixtop";
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
      ".config/Signal"
      ".config/obsidian"
      ".thunderbird"
    ];
  };

  # Keep GUI-backed background services on unbound special workspaces. The
  # silent rules are a fallback for startup or error dialogs: neither service
  # can steal focus, switch the active workspace, or animate onto the screen.
  wayland.windowManager.hyprland.settings.windowrule = lib.mkIf isNixtop [
    "match:class ^(org\\.keepassxc\\.KeePassXC|keepassxc)$, workspace special:keepass silent, no_initial_focus on, focus_on_activate off, no_focus on, no_anim on, suppress_event activate activatefocus"
    "match:class ^(thunderbird|Thunderbird|org\\.mozilla\\.Thunderbird)$, workspace special:mail silent, no_initial_focus on, focus_on_activate off, no_focus on, no_anim on, suppress_event activate activatefocus"
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
        After = ["graphical-session.target" "swaync.service"];
        Wants = ["swaync.service"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "exec";
        ExecStart = "${config.programs.thunderbird.finalPackage}/bin/thunderbird -mail";
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
