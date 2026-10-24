# hypridle handles idle management: lock the screen, turn the display off, and
# suspend after periods of inactivity. Keep Awake inhibits idle handling while
# leaving explicit locking and the before-sleep lock handler running.
{
  pkgs,
  scripts,
  ...
}: {
  scripts.caffeine-toggle = pkgs.writeShellScriptBin "caffeine-toggle" ''
    set -eu
    if systemctl --user is-active --quiet caffeine; then
      systemctl --user stop caffeine
      OSD_TEXT="󰾫  Keep Awake Off"
    else
      systemctl --user start caffeine
      OSD_TEXT="󰅶  Keep Awake On"
    fi
    ${scripts.waybar-osd}/bin/waybar-osd "$OSD_TEXT"
  '';

  home.packages = [scripts.caffeine-toggle];

  systemd.user.services.caffeine = {
    Unit = {
      Description = "Keep awake without disabling lock-before-sleep";
      PartOf = ["graphical-session.target"];
      Requires = ["hypridle.service"];
      After = ["hypridle.service"];
    };
    Service = {
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --mode=block --who=KeepAwake --why=KeepAwake ${pkgs.coreutils}/bin/sleep infinity";
      NoNewPrivileges = true;
    };
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Avoid starting multiple hyprlock instances.
        lock_cmd = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        # Wait for the compositor to acknowledge the lock before releasing
        # the sleep delay inhibitor.
        inhibit_sleep = 3;
        after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
      };

      listener = [
        {
          timeout = 300; # 5 min → lock
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 720; # 12 min → screen off
          on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
          on-resume = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
        }
        {
          timeout = 1800; # 30 min → suspend
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  xdg.desktopEntries = {
    caffeine-toggle = {
      name = "Keep Awake";
      exec = "${scripts.caffeine-toggle}/bin/caffeine-toggle";
      icon = "my-caffeine-on-symbolic";
      comment = "Pause idle actions while keeping lock-before-sleep active";
      categories = ["System"];
      terminal = false;
      settings.Keywords = "caffeine;idle;awake;inhibit;suspend;";
    };
  };
}
