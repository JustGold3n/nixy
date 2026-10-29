# Shared startup dependencies for applications that use the desktop tray.
{
  pkgs,
  osConfig,
}: let
  useNiri = osConfig.programs.niri.enable;
  notificationService =
    if useNiri
    then "suzuha.service"
    else "graphical-session.target";
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
in {
  inherit useNiri notificationService trayStartupTarget waitForTray;
}
