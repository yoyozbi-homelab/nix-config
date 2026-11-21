# Partitioned by nixos-anywhere (disko) at install. Infomaniak attaches the
# flavor disk over virtio-scsi (q35), so it is /dev/sda, not /dev/vda; the
# by-id path is stable across kernels and boot order. BIOS boot partition +
# ESP so grub boots whether the instance uses SeaBIOS or UEFI; disko sets
# boot.loader.grub.devices from the EF02 partition.
_: {
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0-0-0-0";
    content = {
      type = "gpt";
      partitions = {
        bios = {
          size = "1M";
          type = "EF02";
          priority = 1;
        };
        ESP = {
          size = "512M";
          type = "EF00";
          priority = 2;
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
