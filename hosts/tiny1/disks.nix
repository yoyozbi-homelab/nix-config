_: {
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/9947-500A";
    fsType = "vfat";
  };
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };
}
