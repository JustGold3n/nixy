# Desktop hardening for nixtop. Keep user namespaces available for browser
# sandboxes, Steam and Nix builds.
{config, ...}: {
  boot.loader.systemd-boot.editor = false;
  boot.initrd.systemd = {
    enable = true;
    emergencyAccess = false;
  };

  boot.kernel.sysctl = {
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "fs.suid_dumpable" = 0;
    "kernel.randomize_va_space" = 2;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;
  };

  networking.firewall = {
    enable = true;
    allowPing = false;
  };

  # Keep remote login disabled; require keys if deliberately enabled later.
  services.openssh = {
    enable = false;
    openFirewall = false;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
    };
  };

  nix.settings = {
    sandbox = true;
    require-sigs = true;
    trusted-users = ["root"];
  };

  security.sudo = {
    execWheelOnly = true;
    wheelNeedsPassword = true;
    extraConfig = ''
      Defaults use_pty
      Defaults timestamp_timeout=5
    '';
  };

  # Crash dumps can contain decrypted mail, passwords and browser session data.
  systemd.coredump.settings.Coredump = {
    Storage = "none";
    ProcessSizeMax = 0;
  };

  systemd.tmpfiles.rules = [
    "d /home/${config.var.username}/.ssh 0700 ${config.var.username} users -"
    "d /home/${config.var.username}/.config/sops 0700 ${config.var.username} users -"
    "d /home/${config.var.username}/.config/sops/age 0700 ${config.var.username} users -"
  ];
}
