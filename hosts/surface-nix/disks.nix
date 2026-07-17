{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings.crypttabExtraOpts = [ "tpm2-device=auto" "tpm2-pcrs=7" "token-timeout=10" ];
                content = {
                  type = "btrfs";
                  extraArgs = [ "-L" "nixos" "-f" ];
                  subvolumes = {
                    "/root" = { mountpoint = "/"; mountOptions = [ "compress=zstd" "noatime" ]; };
                    "/home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" ]; };
                    "/nix"  = { mountpoint = "/nix";  mountOptions = [ "compress=zstd" "noatime" ]; };
                    "/swap" = { mountpoint = "/.swapvol"; swap.swapfile.size = "10G"; };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
