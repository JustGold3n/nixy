{
  # https://github.com/anotherhadi/nixy
  description = ''
    Nixy provides a customizable NixOS setup with Niri, the Suzuha desktop shell, and TUIs.
  '';

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    amane = {
      url = "github:MystiaFin/amane";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    suzuha = {
      url = "github:MystiaFin/suzuha";
      flake = false;
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nvf.url = "github:notashelf/nvf";
    nvf-config = {
      url = "path:./home/nvf";
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
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium-browser = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    loaf = {
      url = "github:m-uvex/loaf-fm/dev";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    default-creds = {
      url = "github:anotherhadi/default-creds";
      flake = false;
    };
    tldr-pages-src = {
      url = "github:tldr-pages/tldr";
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
    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
    pkgs = nixpkgs.legacyPackages.${system};
    args = {
      inherit
        inputs
        nixpkgs
        system
        pkgs-unstable
        pkgs
        ;
    };
    merge = nixpkgs.lib.foldl nixpkgs.lib.recursiveUpdate {};
    supportedSystems = ["x86_64-linux" "aarch64-linux"];

    forAllSystems = f:
      nixpkgs.lib.genAttrs supportedSystems
      (system: f system (import nixpkgs {inherit system;}));
  in
    merge [
      (import ./home/tui/nixy/flake.nix args)
      {
        formatter.${system} = pkgs.alejandra;
        packages.${system} = {
          nvim = inputs.nvf-config.packages.${system}.nvim;
          suzuha = pkgs-unstable.callPackage ./nixos/packages/suzuha {inherit inputs;};
        };
        apps.${system}.nvim = inputs.nvf-config.apps.${system}.nvim;
        nixosConfigurations = {
          nixtop = import ./hosts/laptop/flake.nix args;
          h-work = import ./hosts/work/flake.nix args;
          jack = import ./hosts/server/flake.nix args;
        };
        devShells = forAllSystems (system: pkgs: {
          default = import ./shell.nix {
            inherit pkgs;
            gitHooksLib = git-hooks.lib.${system};
          };
        });
      }
    ];
}
