{
  inputs,
  lib,
  config,
  platform,
  pkgs,
  ...
}:
{
  imports = [
    ./disks.nix
    #./hardware-configuration.nix
    ../roles/boot-lanzaboote.nix
    inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel
    ../roles/cachix.nix
    ../roles/bluetooth.nix
    ../roles/firewall.nix
    ../roles/fwupd.nix
    ../roles/tpm.nix
    ../roles/touchpad.nix
    ../roles/openssh.nix
  ];

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
    extraModulePackages = [ ];
  };

  time.timeZone = "Europe/Zurich";

  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp4s0u2u4.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp0s20f3.useDHCP = lib.mkDefault true;
  hardware.enableAllFirmware = false;
  environment.systemPackages = with pkgs; [
    sbctl
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

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
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  networking.hostName = "surface-nix"; # Define your hostname.
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
