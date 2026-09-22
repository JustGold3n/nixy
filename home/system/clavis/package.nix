{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  makeWrapper,
  python3,
  qt6,
  kdePackages,
  quickshell,
  wayland,
  wayland-protocols,
  wayland-scanner,
  libpulseaudio,
  pipewire,
  alsa-lib,
  fftw,
  fftwSinglePrec,
  iniparser,
  libxkbcommon,
  networkmanager,
  bluez,
  udev,
  matugen,
  libcava,
  grim,
  slurp,
  wl-clipboard,
  brightnessctl,
  playerctl,
  wireplumber,
  swww,
  src,
}: let
  pythonEnv = python3.withPackages (ps:
    with ps; [
      requests
    ]);
in
  stdenv.mkDerivation {
    pname = "clavis-shell";
    version = "unstable";

    inherit src;

    nativeBuildInputs = [
      cmake
      ninja
      pkg-config
      makeWrapper
      pythonEnv
      qt6.wrapQtAppsHook
      qt6.qttools
      qt6.qtshadertools
      wayland-scanner
    ];

    buildInputs = [
      # Qt6 Framework
      qt6.qtbase
      qt6.qtdeclarative
      qt6.qtwayland
      qt6.qtpositioning
      qt6.qtshadertools
      qt6.qt5compat
      qt6.qtsvg
      kdePackages.qtkeychain

      # Core Shell & Plugins
      quickshell
      libcava
      iniparser
      libxkbcommon

      # Wayland Protocols
      wayland
      wayland-protocols

      # Hardware & Audio
      libpulseaudio
      pipewire
      alsa-lib
      fftw
      fftwSinglePrec
      networkmanager
      bluez
      udev
    ];

    cmakeFlags = [
      "-DCMAKE_BUILD_TYPE=Release"
      "-DINSTALL_SYSCONFDIR=/etc"
      "-DPython3_EXECUTABLE=${pythonEnv}/bin/python3"
    ];

    dontWrapQtApps = true;

    postInstall = ''
      if [ -d "$out/bin" ]; then
        for bin in "$out/bin"/*; do
          if [ -f "\(bin" ] && [ -x "\)bin" ]; then
            wrapProgram "$bin" \
              --prefix PATH : ${lib.makeBinPath [
        quickshell
        matugen
        libcava
        grim
        slurp
        wl-clipboard
        brightnessctl
        playerctl
        wireplumber
        networkmanager
        bluez
        swww
        pythonEnv
      ]} \
              --prefix QML2_IMPORT_PATH : "\(out/lib/qt6/qml:\)out/lib/qml:\(out/share/quickshell:\){quickshell}/lib/qt6/qml:\({quickshell}/lib/qml:\){qt6.qtdeclarative}/lib/qt6/qml:\({qt6.qtwayland}/lib/qt6/qml:\){qt6.qtpositioning}/lib/qt6/qml:\({qt6.qt5compat}/lib/qt6/qml:\){qt6.qtsvg}/lib/qt6/qml" \
              --prefix QT_PLUGIN_PATH : "\(out/lib/qt6/plugins:\){qt6.qtbase}/lib/qt6/plugins:\({qt6.qtwayland}/lib/qt6/plugins:\){qt6.qtsvg}/lib/qt6/plugins:${kdePackages.qtkeychain}/lib/qt6/plugins" \
              --set QT_QPA_PLATFORM wayland \
              --set QT_WAYLAND_DISABLE_WINDOWDECORATION 1
          fi
        done
      fi
    '';

    meta = with lib; {
      description = "Quickshell desktop shell for Niri built from StatIndet/quickshell";
      homepage = "https://github.com/StatIndet/quickshell";
      license = licenses.gpl3Plus;
      platforms = platforms.linux;
    };
  }
