{
  pkgs,
  gitHooksLib,
}: let
  tools = pkgs.callPackage ./nixos/packages/nixy-tools {};
  hooks = gitHooksLib.run {
    src = ./.;
    hooks = {
      alejandra.enable = true;

      inject-exec = {
        enable = true;
        name = "inject-exec";
        entry = "${tools}/bin/inject-exec README.md";
        language = "system";
        files = "(README\\.md)";
        pass_filenames = false;
      };

      doctoc = {
        enable = true;
        name = "doctoc";
        entry = "${pkgs.doctoc}/bin/doctoc --notitle README.md";
        language = "system";
        files = "(README\\.md)";
        pass_filenames = false;
      };
    };
  };
in
  pkgs.mkShell {
    packages = with pkgs;
      [
        doctoc
        cargo
        rustc
        rustfmt
        clippy
        tools
      ]
      ++ hooks.enabledPackages;

    shellHook = hooks.shellHook;
  }
