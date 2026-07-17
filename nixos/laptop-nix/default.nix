{
  inputs,
  lib,
  config,
  platform,
  pkgs,
  ...
}:
let
  pkgs-unstable = inputs.hyprland.inputs.nixpkgs.legacyPackages.${platform};
in
{
  imports = [
    #./hardware-configuration.nix
    ../roles/boot-systemd.nix
    inputs.nixos-hardware.nixosModules.dell-xps-15-9520-nvidia
    ../roles/bluetooth.nix
    ../roles/firewall.nix
    ../roles/fwupd.nix
    ../roles/docker.nix
    ../roles/thunderbolt.nix
    ../roles/boxes.nix
    ../roles/virtualbox.nix
    ../roles/focusrite.nix
    ../roles/desktop/hyprland.nix
  ];

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
  swapDevices = [
    {
      device = "/dev/disk/by-uuid/3c0e4bf1-cf21-42b7-820c-e81c85a8d6fb";
    }
  ];

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
      kernelModules = [ ];

      luks = {
        devices = {
          "enc" = {
            device = "/dev/disk/by-uuid/aebd5b7d-2d4e-481c-aa66-ed3a95f3f18f";
            #keyFile = "/crypto_keyfile.bin";
          };

          "swap" = {
            device = "/dev/disk/by-uuid/11ddffc2-ca30-424e-895e-cca0b096f585";
            #keyFile = "/crypto_keyfile.bin";
          };
        };
      };
    };

    kernelParams = [ "net.ipv4.ip_forward=1" ];
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
    supportedFilesystems = [ "btrfs" ];

    resumeDevice = "/dev/disk/by-uuid/3c0e4bf1-cf21-42b7-820c-e81c85a8d6fb";

    binfmt = {
      emulatedSystems = [ "aarch64-linux" ];
    };
  };

  time.timeZone = "Europe/Zurich";

  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp4s0u2u4.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp0s20f3.useDHCP = lib.mkDefault true;
  hardware.enableAllFirmware = true;

  #enable Zen kernel
  #boot.kernelPackages = pkgs.linuxPackages_zen;

  hardware.graphics = {
    #package = pkgs-unstable.mesa.drivers;
    enable = true;
    enable32Bit = true;
    #package32 = pkgs-unstable.pkgsi686Linux.mesa.drivers;
  };

  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
    xkb = {
      layout = "ch";
      variant = "fr";
    };
  };

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = true;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = true;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
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

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  networking.hostName = "laptop-nix"; # Define your hostname.
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
