{
  config,
  lib,
  pkgs,
  ...
}: {
  # ==========================================
  # 1. SYSTEM CONFIGURATION
  # ==========================================

  services.pcscd.enable = true;

  services.udev.packages = with pkgs; [
    yubikey-personalization
    libfido2
  ];

  # Device authorization belongs in the host's USBGuard policy. A vendor-only
  # allow rule would bypass its device, interface, and port restrictions.

  # Enable GPG Agent and tell it to act as the SSH agent
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # The user's SSH config is managed by SOPS. Add key selection in the system
  # config so its per-host usernames, ports, and forwarding settings still apply.
  programs.ssh.extraConfig = ''
    Match host vshosting.cz,*.vshosting.cz localuser ${config.var.username}
      IdentityAgent /run/user/%i/gnupg/S.gpg-agent.ssh
      IdentityFile ${./yubikey/vshosting.pub}
      IdentitiesOnly yes
    Host *
  '';

  # ==========================================
  # 2. USER CONFIGURATION (Home Manager)
  # ==========================================

  home-manager.users.${config.var.username} = {
    # pcscd owns the reader. GnuPG must use PC/SC instead of opening the same
    # device through its built-in CCID driver.
    programs.gpg = {
      enable = true;
      scdaemonSettings.disable-ccid = true;
    };

    # Use a standalone PIN dialog on Niri; the GNOME prompt service can time
    # out without displaying a window in this session.
    home.file.".gnupg/gpg-agent.conf".text = ''
      pinentry-program ${lib.getExe pkgs.pinentry-qt}
    '';

    home.packages = with pkgs; [
      yubikey-manager
      yubikey-personalization
      gnupg # Ensure GPG is installed
    ];
  };
}
