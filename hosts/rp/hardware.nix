{
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./services.nix
  ];

  boot = {
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;
    # Mainline kernel (cached on cache.nixos.org) instead of the
    # nixos-hardware RPi kernel, which has to be built from source.
    initrd.availableKernelModules = [
      "xhci_pci"
      "usbhid"
      "pcie_brcmstb" # PCIe bus behind the VL805 USB controller
    ];
    # The sd-card image profile enables ZFS; not needed here and it would
    # compile the zfs kernel module.
    supportedFilesystems.zfs = lib.mkForce false;
    kernelParams = [
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
    ];
  };

  console.enable = false;

  environment.systemPackages = with pkgs; [
    libraspberrypi
    raspberrypi-eeprom
  ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [ "nofail" ];
    };
    "/mnt" = {
      device = "/dev/sdb1";
      fsType = "ext4";
      options = [
        "noatime"
        "nofail"
      ];
    };
  };

  swapDevices = [ ];

  networking = {
    interfaces.end0.ipv4.addresses = [
      {
        address = "192.168.1.2";
        prefixLength = 24;
      }
    ];
    defaultGateway = {
      address = "192.168.1.1";
      interface = "end0";
    };
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    useDHCP = lib.mkDefault true;
  };
  sops = {
    defaultSopsFile = ./rp-sec.yml;

    secrets = {
      # Bitwarden Secrets Manager machine-account token, used by the
      # bitwarden-secrets role to fetch everything else (see services.nix).
      bws-access-token = { };
      cloudflared-token = { };
    };
  };
}
