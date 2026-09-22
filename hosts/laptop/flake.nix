args @ {
  inputs,
  nixpkgs,
  system,
  clavisOverlay,
  ...
}:
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = {inherit inputs;};
  modules = [
    {
      nixpkgs.overlays = [clavisOverlay];
    }
    ./configuration.nix
    ../../nixos/niri.nix
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = {inherit inputs;};
      home-manager.users.marek = import ./home.nix;
    }
  ];
}
