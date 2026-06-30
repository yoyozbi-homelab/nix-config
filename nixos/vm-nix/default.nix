{ lib, platform, ... }:
{
  networking.hostName = "vm-nix";
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
  time.timeZone = "Europe/Zurich";

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd.availableKernelModules = [
      "xhci_pci"
      "virtio_pci"
      "virtio_scsi"
      "virtio_blk"
    ];
    kernelModules = [ "kvm-intel" ];
  };

  services.xserver.xkb = {
    layout = "ch";
    variant = "fr";
  };
}
