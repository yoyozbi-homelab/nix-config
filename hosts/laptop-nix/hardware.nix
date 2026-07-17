{ config, lib, ... }:
{
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "vmd"
        "nvme"
        "usb_storage"
        "sd_mod"
        "rtsx_pci_sdmmc"
      ];
      luks.devices = {
        "enc" = {
          device = "/dev/disk/by-uuid/aebd5b7d-2d4e-481c-aa66-ed3a95f3f18f";
        };
        "swap" = {
          device = "/dev/disk/by-uuid/11ddffc2-ca30-424e-895e-cca0b096f585";
        };
      };
    };
    kernelParams = [ "net.ipv4.ip_forward=1" ];
    kernelModules = [ "kvm-intel" ];
    supportedFilesystems = [ "btrfs" ];
    resumeDevice = "/dev/disk/by-uuid/3c0e4bf1-cf21-42b7-820c-e81c85a8d6fb";
    binfmt.emulatedSystems = [ "aarch64-linux" ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/8be38d0e-8c11-4139-bb55-3b7146176003";
      fsType = "btrfs";
      options = [
        "subvol=root"
        "compress=zstd"
        "noatime"
      ];
    };
    "/home" = {
      device = "/dev/disk/by-uuid/8be38d0e-8c11-4139-bb55-3b7146176003";
      fsType = "btrfs";
      options = [
        "subvol=home"
        "compress=zstd"
        "noatime"
      ];
    };
    "/nix" = {
      device = "/dev/disk/by-uuid/8be38d0e-8c11-4139-bb55-3b7146176003";
      fsType = "btrfs";
      options = [
        "subvol=nix"
        "compress=zstd"
        "noatime"
      ];
    };
    "/persist" = {
      device = "/dev/disk/by-uuid/8be38d0e-8c11-4139-bb55-3b7146176003";
      fsType = "btrfs";
      options = [
        "subvol=persist"
        "compress=zstd"
        "noatime"
      ];
    };
    "/var/log" = {
      device = "/dev/disk/by-uuid/8be38d0e-8c11-4139-bb55-3b7146176003";
      fsType = "btrfs";
      options = [
        "subvol=log"
        "compress=zstd"
        "noatime"
      ];
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/B620-59D1";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/3c0e4bf1-cf21-42b7-820c-e81c85a8d6fb"; } ];

  time.timeZone = "Europe/Zurich";

  networking.useDHCP = lib.mkDefault true;

  hardware = {
    enableAllFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };

  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
    xkb = {
      layout = "ch";
      variant = "fr";
    };
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
