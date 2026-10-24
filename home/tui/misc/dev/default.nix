{
  pkgs,
  pkgs-unstable,
  config,
  lib,
  ...
}: {
  home = {
    packages = with pkgs-unstable;
      [
        go
        claude-code
        bun
      ]
      ++ (with pkgs; [
        nodejs
        air
        duckdb
        python3
        rustc
        cargo
        rustfmt
        clippy
        rust-analyzer
        jq
        nix-prefetch-github
        rsync
      ]);

    persistence."/persist" = lib.mkIf (config.var.impermanenceEnabled or false) {
      directories = [
        ".claude"
      ];
      files = [".claude.json"];
    };

    sessionPath = ["$HOME/.local/share/go/bin"];
    sessionVariables.GOPATH = "$HOME/.local/share/go";
  };
}
