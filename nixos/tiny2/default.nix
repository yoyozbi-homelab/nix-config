{
  lib,
  platform,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    #		inputs.nixos-hardware.nixosModules.common-cpu-amd
    #		inputs.nixos-hardware.common-pc
    #		inputs.nixos-hardware.common-pc-ssd
    (import ./disks.nix { })
    ../_mixins/hardware/grub.nix
    ../_mixins/services/cachix.nix
    ../_mixins/services/openssh.nix
    ../_mixins/services/networkmanager.nix
    ../_mixins/k3s/ocr-cluster.nix
    ../_mixins/k3s/agent.nix
    ../_mixins/services/tmux.nix
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "ata_piix"
        "uhci_hcd"
        "xen_blkfront"
        "vmw_pvscsi"
      ];
      kernelModules = [ "nvme" ];
    };
  };

  zramSwap.enable = true;
  networking = {
    hostName = "tiny2";
    domain = "";

    firewall = {
      enable = lib.mkForce false;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
