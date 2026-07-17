{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disks.nix
  ];

  boot.initrd = {
    availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "xen_blkfront"
      "vmw_pvscsi"
    ];
    kernelModules = [ "nvme" ];
  };

  zramSwap.enable = true;

  networking = {
    domain = "";
    firewall.enable = lib.mkForce false;
  };
}
