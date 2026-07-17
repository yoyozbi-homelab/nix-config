{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")

    (import ./disks.nix { })
    ../roles/boot-grub.nix
    ../roles/cachix.nix
    ../roles/openssh.nix
    ../roles/networkmanager.nix
    ../roles/netdata.nix
    ../roles/ocr-cluster
    ../roles/k3s-server.nix
    ../roles/tmux.nix
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "virtio_scsi"
  ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  networking.hostName = "ocr1";

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  #networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s6.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
