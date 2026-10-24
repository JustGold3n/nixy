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
    # User password secrets must be available before activation restores
    # per-user bind mounts. Read the persistent backing file directly.
    age.keyFile =
      if config.var.impermanenceEnabled
      then "/persist${home}/.config/sops/age/keys.txt"
      else "${home}/.config/sops/age/keys.txt";
    defaultSopsFile = ./secrets.yaml;
    secrets = {
      login-password-hash = {
        neededForUsers = true;
      };
      ssh-config = {
        owner = username;
        mode = "0600";
        path = "${home}/.ssh/config";
      };
      ssh-github-key = {
        owner = username;
        mode = "0600";
        path = "${home}/.ssh/github";
      };
      keepass = {
        owner = username;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    sops
    age
  ];
}
