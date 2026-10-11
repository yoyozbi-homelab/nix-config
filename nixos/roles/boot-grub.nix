_: {
  boot.loader = {
    grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
      configurationLimit = 4;
    };
  };
}
