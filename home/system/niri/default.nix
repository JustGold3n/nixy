{
  pkgs,
  inputs,
  ...
}: let
  clavisPkg = inputs.clavis.packages.${pkgs.system}.default;
in {
  # 1. Ensure quickshell and clavis assets are available
  home.packages = [
    pkgs.quickshell
    clavisPkg
  ];

  programs.niri.settings = {
    spawn-at-startup = [
      {
        # OPTION A: If the CMake build successfully generated the launcher script
        # Check `ls $(nix build --no-link --print-out-paths github:JustGold3n/clavis-shell)/bin`
        # command = [ "${clavisPkg}/bin/clavis-shell" ];

        # OPTION B: Manual Invocation (Fallback if no bin/ exists)
        # Manually link the Qt plugin path so Quickshell can find the compiled Niri modules
        command = [
          "sh"
          "-c"
          "QML2_IMPORT_PATH=${clavisPkg}/lib/qml:${clavisPkg}/lib/qt-6/qml ${pkgs.quickshell}/bin/quickshell${clavisPkg}/share/clavis-shell/shell.qml"
        ];
      }
    ];
  };
}
