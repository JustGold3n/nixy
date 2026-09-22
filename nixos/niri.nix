{
  config,
  pkgs,
  ...
}: {
  # 1. Enable Niri compositor on system level
  programs.niri.enable = true;

  # 2. Critical PAM profile for Clavis Lockscreen
  security.pam.services.clavis = {};

  # 3. Enable polkit for authorization dialogs
  security.polkit.enable = true;

  # 4. XDG Desktop Portals configuration for Niri
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config = {
      niri = {
        default = ["gnome" "gtk"];
        "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
      };
    };
  };

  # 5. UDev rules for backlight & input permissions
  services.udev.packages = [pkgs.brightnessctl];
}
