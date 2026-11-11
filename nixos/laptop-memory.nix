{
  lib,
  pkgs,
  ...
}: {
  # Bound compilation on this 16 GiB laptop while allowing small builds
  # to run together. Command-line --max-jobs and --cores can still override.
  nix.settings = {
    max-jobs = 2;
    cores = 2;
    download-buffer-size = lib.mkForce (32 * 1024 * 1024);
  };

  # Prefer compressed RAM; use disk only when more headroom is needed.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };
  # Restore the pre-tuning reclaim values explicitly so activation resets
  # the running kernel too, without requiring a reboot.
  boot.kernel.sysctl = {
    "vm.swappiness" = 60;
    "vm.page-cluster" = 3;
  };

  # /persist lives on the existing LUKS-encrypted Btrfs filesystem.
  swapDevices = [
    {
      device = "/persist/swap/swapfile";
      size = 16 * 1024;
      priority = 10;
    }
  ];
  systemd.services.mkswap-persist-swap-swapfile.preStart = ''
    # A separate subvolume keeps the active swapfile out of parent snapshots.
    if [ ! -d /persist/swap ]; then
      mkdir -p /persist
      ${pkgs.btrfs-progs}/bin/btrfs subvolume create /persist/swap
    fi
    chmod 0700 /persist/swap
  '';

  # These settings also apply to builds requested by nixy through the daemon.
  # They lower contention with the desktop without limiting idle CPU capacity.
  systemd.services.nix-daemon.serviceConfig = {
    Nice = 5;
    CPUWeight = 50;
    IOWeight = 50;
  };
}
