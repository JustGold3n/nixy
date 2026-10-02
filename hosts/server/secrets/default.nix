{pkgs, ...}: {
  sops = {
    age.keyFile = "/home/hadi/.config/sops/age/keys.txt";
    defaultSopsFile = ./secrets.yaml;
    secrets = {
    };
  };

  environment.systemPackages = with pkgs; [
    sops
    age
  ];
}
