{
  inputs,
  pkgs,
  ...
}: {
  home.packages = [
    inputs.clavis-shell.packages.${pkgs.system}.default
  ];
}
