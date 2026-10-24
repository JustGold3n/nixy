{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  inkscape,
  xcursorgen,
}:
stdenvNoCC.mkDerivation {
  pname = "arcstarry-cursors-purple";
  version = "0-unstable-2021-12-04";

  src = fetchFromGitHub {
    owner = "yeyushengfan258";
    repo = "ArcStarry-Cursors";
    rev = "3473335fdf2ea45ac57375352e5290ce273cba9c";
    hash = "sha256-nJ4MiharvVRx/4DYbbvBHVVgyqlYrHpVnW3B/UPtJ7E=";
  };

  nativeBuildInputs = [inkscape xcursorgen];

  postPatch = ''
    # Recolor the upstream cyan accent to match the desktop's purple palette.
    substituteInPlace src/svg/*.svg \
      --replace-quiet '#00a0c8' '#c090e8' \
      --replace-quiet '#059bff' '#9e97f8' \
      --replace-quiet '#91fffa' '#d8d5ea'
    substituteInPlace build.sh --replace-fail 'ArcStarry Cursors' 'ArcStarry Purple'
  '';

  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR"
    rm -rf dist/cursors
    bash -e build.sh
    for cursor in src/config/*.cursor; do
      test -s "dist/cursors/$(basename "$cursor" .cursor)"
    done
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/icons/ArcStarry-Purple"
    cp -a dist/. "$out/share/icons/ArcStarry-Purple/"
    runHook postInstall
  '';

  meta = {
    description = "ArcStarry cursors with a purple accent";
    homepage = "https://github.com/yeyushengfan258/ArcStarry-Cursors";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
