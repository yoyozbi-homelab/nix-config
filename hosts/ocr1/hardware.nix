{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disks.nix
  ];

  boot.initrd = {
    availableKernelModules = [ "xhci_pci" "virtio_scsi" ];
    kernelModules = [ "dm-snapshot" ];
  };
}
