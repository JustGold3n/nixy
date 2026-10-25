{
  pkgs,
  lib,
  ...
}: {
  programs.niri = {
    enable = true;
    useNautilus = false;
  };
  environment.systemPackages = [pkgs.xwayland-satellite];
  environment.variables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # Each unlock attempt uses exactly one method. A password must not wait for
  # the fingerprint module, and fingerprint verification must not ask for a password.
  security.pam.services = {
    amane.fprintAuth = false;
    amane-fingerprint = {
      unixAuth = false;
      fprintAuth = true;
      rules.auth.fprintd.settings = {
        max-tries = 3;
        timeout = 10;
      };
    };
  };
  services.upower.enable = true;
  xdg.portal.config.niri."org.freedesktop.impl.portal.FileChooser" = lib.mkForce ["termfilechooser"];

  fonts.packages = with pkgs; [
    poppins
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    material-design-icons
  ];
}
