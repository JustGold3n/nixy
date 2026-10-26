{
  disko.devices = {
    # Use the existing partitions on /dev/nvme0n1.
    disk = {
      boot = {
        type = "disk";
        device = "/dev/disk/by-uuid/1E98-2D28";
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
          mountOptions = ["fmask=0077" "dmask=0077"];
        };
      };

      nixos = {
        type = "disk";
        device = "/dev/disk/by-uuid/a8791708-eebd-4b9b-84e5-ff7a215b217a";
        content = {
          type = "luks";
          name = "luks-a8791708-eebd-4b9b-84e5-ff7a215b217a";
          content = {
            type = "btrfs";
            extraArgs = ["-f"];
            mountpoint = "/";
            # /persist is a directory in the root filesystem, not a subvolume.
            subvolumes = {
              home = {
                mountpoint = "/home";
              };
              nix = {
                mountpoint = "/nix";
              };
            };
          };
        };
      };

      swap = {
        type = "disk";
        device = "/dev/disk/by-uuid/40e784fb-5794-4c09-926a-46dd38aa2b11";
        content = {
          type = "luks";
          name = "luks-40e784fb-5794-4c09-926a-46dd38aa2b11";
          content.type = "swap";
        };
      };
    };
  };

  fileSystems."/home".neededForBoot = true;
}
