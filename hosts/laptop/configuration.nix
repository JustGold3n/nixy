{
  config,
  lib,
  ...
}: {
  imports = [
    #../../nixos/nvidia.nix # CHANGEME: Remove this line if you don't have an Nvidia GPU
    ../../nixos/audio.nix
    ../../nixos/bluetooth.nix
    ../../nixos/fonts.nix
    ../../nixos/fingerprint.nix
    ../../nixos/home-manager.nix
    ../../nixos/nix.nix
    #../../nixos/lanzaboot.nix # CHANGEME: Remove this line and uncomment the next one if you don't want to setup secure boot
    ../../nixos/systemd-boot.nix
    ../../nixos/tuigreet.nix
    ../../nixos/autologin.nix # Skip first TUIGreet login, use LUKS password to unlock the keyring
    ../../nixos/users.nix
    ../../nixos/utils.nix
    ../../nixos/hyprland.nix
    ../../nixos/steam.nix
    ../../nixos/kernel-hardening.nix
    ../../home/gui/helium/system.nix # I hate browser's configuration..

    # CHANGEME: You should probably remove those things:
    #./wireguard.nix
    ./secrets

    # You should let those lines as is
    ./hardware-configuration.nix
    ./variables.nix
  ];

  home-manager.users."${config.var.username}" = import ./home.nix;

  # User password
  users.users.${config.var.username}.hashedPassword = "$y$j9T$A7gH534UczuBxulj9IfEu1$ImRy3lpYpemRWNVIkA7efKPWXneFiqhZnEF1aMkWcD8";

  # Impermanence: declares what should survive a wipe of "/".
  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      "/etc/NetworkManager/system-connections" # Wifi connections, VPN
      "/var/lib/bluetooth" # Bluetooth connections
      "/var/lib/nixos" # keeps uid/gid stable across boots
      "/var/lib/systemd" # random seed and other systemd state
      "/var/lib/upower" # battery calibration state
      "/var/log"
      "/var/db/sudo/lectured" # remembers that the sudo lecture was already shown
    ];

    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  # USBGuard:
  # The following line allow all USB devices until a proper policy is configured.
  # Run `sudo usbguard generate-policy` with your devices plugged in,
  # then set rules = "<output>" and switch implicitPolicyTarget to "block".
  # services.usbguard.implicitPolicyTarget = lib.mkForce "allow";
  services.usbguard = {
    enable = true;
    implicitPolicyTarget = "block";
    IPCAllowedUsers = [
      "root"
    ];
    rules = ''
      allow id 1d6b:0002 serial "0000:00:0d.0" name "xHCI Host Controller" hash "d3YN7OD60Ggqc9hClW0/al6tlFEshidDnQKzZRRk410=" parent-hash "Y1kBdG1uWQr5CjULQs7uh2F6pHgFb6VDHcWLk83v+tE=" with-interface 09:00:00 with-connect-type ""
      allow id 1d6b:0003 serial "0000:00:0d.0" name "xHCI Host Controller" hash "G+G3Mro8zBWJavFOAQUtoNiOsZSfBCt2XqHfOufYFis=" parent-hash "Y1kBdG1uWQr5CjULQs7uh2F6pHgFb6VDHcWLk83v+tE=" with-interface 09:00:00 with-connect-type ""
      allow id 1d6b:0002 serial "0000:00:14.0" name "xHCI Host Controller" hash "jEP/6WzviqdJ5VSeTUY8PatCNBKeaREvo2OqdplND/o=" parent-hash "rV9bfLq7c2eA4tYjVjwO4bxhm+y6GgZpl9J60L0fBkY=" with-interface 09:00:00 with-connect-type ""
      allow id 1d6b:0003 serial "0000:00:14.0" name "xHCI Host Controller" hash "E8Zs26CP5+JQoiPVmDSuTb4j11VatW+WHlWxiX8+qJc=" parent-hash "rV9bfLq7c2eA4tYjVjwO4bxhm+y6GgZpl9J60L0fBkY=" with-interface 09:00:00 with-connect-type ""
      allow id 1050:0407 serial "" name "YubiKey OTP+FIDO+CCID" hash "+yHSjnnIMzjrazEwqcEGVKmguy5xWgoVqqAQUnLyL5E=" parent-hash "jEP/6WzviqdJ5VSeTUY8PatCNBKeaREvo2OqdplND/o=" via-port "3-3" with-interface { 03:01:01 03:00:00 0b:00:00 } with-connect-type "hotplug"
      allow id 8086:0b63 serial "" name "USB Bridge" hash "gSptQpfBIAzo6PN8OUUrc+V95M7pPFW7XmI7Ge62Kgs=" parent-hash "jEP/6WzviqdJ5VSeTUY8PatCNBKeaREvo2OqdplND/o=" via-port "3-8" with-interface ff:ff:ff with-connect-type "not used"
      allow id 27c6:63bc serial "UIDE0267113_XXXX_MOC_B0" name "Goodix Fingerprint USB Device" hash "csvc9k4c736r5K9unXu6A4Q6RlSknGggTVyGGHGEq7U=" parent-hash "jEP/6WzviqdJ5VSeTUY8PatCNBKeaREvo2OqdplND/o=" with-interface ff:00:00 with-connect-type "not used"
      allow id 8087:0033 serial "" name "" hash "ciwwGozaSw4maEXfs4NdvETeMt6bnFEK6f4vmCqfud0=" parent-hash "jEP/6WzviqdJ5VSeTUY8PatCNBKeaREvo2OqdplND/o=" via-port "3-10" with-interface { e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 } with-connect-type "not used"
    '';
  };

  # Don't touch this
  system.stateVersion = "26.05";
}
