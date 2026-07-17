{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./disks.nix ];

  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "nvme"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [ "tpm_tis" ];
    };
    kernelParams = [ "net.ipv4.ip_forward=0" ];
    kernelModules = [ "kvm-intel" ];
  };

  time.timeZone = "Europe/Zurich";

  networking.useDHCP = lib.mkDefault true;

  hardware = {
    enableAllFirmware = false;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  environment.systemPackages = [ pkgs.sbctl ];

  services.xserver = {
    enable = true;
    xkb = {
      layout = "ch";
      variant = "fr";
    };
  };

  services.iptsd.config = {
    Touchscreen = {
      DisableOnPalm = true;
      DisableOnStylus = true;
    };
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
