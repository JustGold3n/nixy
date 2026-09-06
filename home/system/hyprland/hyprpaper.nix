# Hyprpaper is used to set the wallpaper on the system
{lib, ...}: {
  # The wallpaper is set by stylix
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [",/home/gold3n/.config/nixos/hosts/laptop/wallpaper1.jpg"];
      wallpaper = [",/home/gold3n/.config/nixos/hosts/laptop/wallpaper1.jpg"];
      # ipc = "on";
      # splash = false;
    };
  };
  systemd.user.services.hyprpaper.Unit.After = lib.mkForce "graphical-session.target";

  wayland.windowManager.hyprland.settings.exec-once = [
    "systemctl --user enable --now hyprpaper.service"
  ];
}
