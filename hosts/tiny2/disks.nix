_: {
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/UEFI";
    fsType = "vfat";
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/cloudimg-rootfs";
    fsType = "ext4";
  };
}
