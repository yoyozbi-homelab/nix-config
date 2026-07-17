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
    ../roles/boot-grub.nix
    ../roles/cachix.nix
    ../roles/openssh.nix
    ../roles/networkmanager.nix
    ../roles/ocr-cluster
    ../roles/k3s-agent.nix
    ../roles/tmux.nix
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
