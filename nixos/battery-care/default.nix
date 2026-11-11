{
  config,
  pkgs,
  ...
}: let
  control = pkgs.callPackage ../packages/nixy-tools {};
  firmwareHelper = "${control}/bin/battery-charge-firmware";
in {
  services.upower.enable = true;
  environment.systemPackages = [control];

  # Authorize only this immutable, fixed-purpose helper for the active desktop.
  # Protected firmware writes still require the BIOS password through stdin.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.policykit.exec" &&
          action.lookup("program") == "${firmwareHelper}" &&
          subject.user == ${builtins.toJSON config.var.username} &&
          subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';

  home-manager.users.${config.var.username}.systemd.user.services.battery-care = {
    Unit = {
      Description = "Prompt to restore battery care at login and after unplugging";
      After = ["graphical-session.target" "suzuha.service"];
      PartOf = ["graphical-session.target"];
      ConditionPathExists = "/sys/class/firmware-attributes/dell-wmi-sysman/authentication/Admin/is_enabled";
    };
    Service = {
      ExecStart = "${control}/bin/battery-care-watch";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
