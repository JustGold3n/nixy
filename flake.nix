{
  # https://github.com/anotherhadi/nixy
  description = ''
    Nixy simplifies and unifies the Hyprland ecosystem with a modular, easily customizable setup.
    It provides a structured way to manage your system configuration and dotfiles with minimal effort.
  '';

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nvf.url = "github:notashelf/nvf";
    nvf-config = {
      url = "path:./home/programs/tui/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nvf.follows = "nvf";
    };
    nur = {
      url = "github:nix-community/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium-browser = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    default-creds = {
      url = "github:anotherhadi/default-creds";
      flake = false;
    };

    # Quickshell runtime toolkit needed to compile and run Clavis plugins
    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Non-flake source repository for the shell
    clavis = {
      url = "github:StatIndet/quickshell";
      flake = false;
    };

    # Server
    nixarr.url = "github:nix-media-server/nixarr";
    default-creds-web.url = "github:anotherhadi/default-creds-web";
  };

  outputs = inputs @ {
    nixpkgs,
    nixpkgs-unstable,
    git-hooks,
    ...
  }: let
    system = "x86_64-linux";

    # Overlay that builds clavis-shell from the raw source tree using Quickshell
    clavisOverlay = final: prev: {
      clavis-shell = final.callPackage ./home/system/clavis/package.nix {
        src = inputs.clavis;
        quickshell = inputs.quickshell.packages.${final.stdenv.hostPlatform.system}.default;
      };
    };

    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [clavisOverlay];
    };

    args = {
      inherit
        inputs
        nixpkgs
        system
        pkgs-unstable
        pkgs
        clavisOverlay
        ;
    };

    merge = nixpkgs.lib.foldl nixpkgs.lib.recursiveUpdate {};
    supportedSystems = ["x86_64-linux" "aarch64-linux"];

    forAllSystems = f:
      nixpkgs.lib.genAttrs supportedSystems
      (sys:
        f sys (import nixpkgs {
          system = sys;
          config.allowUnfree = true;
          overlays = [clavisOverlay];
        }));
  in
    merge [
      (import ./home/programs/tui/nixy/flake.nix args)
      {
        formatter.${system} = pkgs.alejandra;

        # Grouped dynamic attribute to prevent evaluation collisions
        packages.${system} = {
          nvim = inputs.nvf-config.packages.${system}.nvim;
          clavis-shell = pkgs.clavis-shell;
        };

        apps.${system}.nvim = inputs.nvf-config.apps.${system}.nvim;

        nixosConfigurations = {
          nixtop = import ./hosts/laptop/flake.nix args;
          g-work = import ./hosts/work/flake.nix args;
          rack = import ./hosts/server/flake.nix args;
        };

        devShells = forAllSystems (sys: p: {
          default = import ./shell.nix {
            pkgs = p;
            gitHooksLib = git-hooks.lib.${sys};
          };
        });
      }
    ];
}
