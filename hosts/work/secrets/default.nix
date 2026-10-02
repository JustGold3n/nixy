# Those are my secrets, encrypted with sops
# You shouldn't import this file, unless you edit it
{
  pkgs,
  config,
  ...
}: let
  username = config.var.username;
  home = "/home/${username}";
in {
  sops = {
    age.keyFile = "${home}/.config/sops/age/keys.txt";
    defaultSopsFile = ./secrets.yaml;
    secrets = {
    };
  };

  environment.systemPackages = with pkgs; [
    sops
    age
  ];
}
