{
  inputs,
  pkgs,
}: let
  upstream = inputs.loaf.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
  upstream.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./loaf-chooser.patch];
    meta = (old.meta or {}) // {mainProgram = "loaf";};
  })
