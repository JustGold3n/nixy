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
  openKeePassXC = pkgs.writeShellApplication {
    name = "open-keepassxc";
    text = ''
      exec ${pkgs.keepassxc}/bin/keepassxc "$@"
    '';
  };
in {
  home.packages = [pkgs.keepassxc];

  home.persistence."/persist" = lib.mkIf (config.var.impermanenceEnabled or false) {
    directories = [".config/keepassxc"];
  };

  # Reuse the background application when its desktop entry is launched.
  xdg.desktopEntries."org.keepassxc.KeePassXC" = lib.mkIf isNixtop {
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

  systemd.user.services.keepassxc = lib.mkIf isNixtop {
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
}
