{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  loaf = import ../../../nixos/packages/loaf {inherit inputs pkgs;};
  chooser = pkgs.writeShellApplication {
    name = "loaf-filechooser";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      # xdg-desktop-portal-termfilechooser protocol: multiple directory save path output debug.
      export LOAF_CHOOSER_MULTIPLE="$1"
      export LOAF_CHOOSER_DIRECTORY="$2"
      export LOAF_CHOOSER_SAVE="$3"
      export LOAF_CHOOSER_OUTPUT="$5"
      export LOAF_CHOOSER_NAME=""
      path="$4"
      # An empty result means cancellation; never reuse a previous selection.
      : > "$LOAF_CHOOSER_OUTPUT"
      if [[ "$LOAF_CHOOSER_SAVE" == 1 ]]; then
        LOAF_CHOOSER_NAME="$(basename -- "$path")"
        path="$(dirname -- "$path")"
      fi
      if [[ ! -e "$path" ]]; then
        path="$HOME"
      fi
      exec ${lib.getExe loaf} --new-window -- "$path"
    '';
  };
in {
  home.packages = [
    loaf
    pkgs.ffmpegthumbnailer
    pkgs.poppler-utils
  ];

  # Activate Loaf for browser "Show in folder" even when no window is open.
  xdg.dataFile."dbus-1/services/org.freedesktop.FileManager1.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.FileManager1
    Exec=${lib.getExe loaf}
  '';

  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${lib.getExe chooser}
    default_dir=${config.home.homeDirectory}
    open_mode=suggested
    save_mode=suggested
    create_help_file=0
  '';

  home.sessionVariables = {
    GTK_USE_PORTAL = "1";
    QT_QPA_PLATFORMTHEME = lib.mkForce "xdgdesktopportal";
  };

  services.udiskie.settings.program_options.file_manager = lib.getExe loaf;
}
