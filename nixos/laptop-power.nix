{
  lib,
  pkgs,
  ...
}: {
  # Let Intel HWP boost on demand; PPD owns the energy/platform preferences.
  # A second CPU policy daemon would fight the desktop's profile controls.
  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;

  systemd.services =
    {
      laptop-power-profile = {
        description = "Start the laptop with the balanced power profile";
        wantedBy = ["multi-user.target"];
        after = ["power-profiles-daemon.service"];
        requires = ["power-profiles-daemon.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.systemd}/bin/busctl set-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile s balanced";
        };
      };
    }
    // lib.genAttrs ["nix-gc" "nix-optimise" "fstrim"] (_: {
      unitConfig.ConditionACPower = true;
      serviceConfig = {
        Nice = 19;
        IOSchedulingClass = "idle";
        CPUWeight = 10;
        IOWeight = 10;
      };
    });

  # Deduplication belongs in scheduled maintenance, not every store write.
  nix.settings.auto-optimise-store = lib.mkForce false;
  nix.optimise = {
    automatic = true;
    dates = ["weekly"];
  };
}
