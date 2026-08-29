{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;
    initrd.availableKernelModules = [
      "xhci_pci"
      "usbhid"
    ];
    kernelParams = [
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
    ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
    "/mnt" = {
      device = "/dev/sdb1";
      fsType = "ext4";
      options = [ "noatime " ];
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

  sops.secrets.k3s-server-token.sopsFile = ./rp-sec.yml;
  sops.secrets.cloudflared-token.sopsFile = ./rp-sec.yml;

  # Bitwarden Secrets Manager machine-account token + ArgoCD git repo
  # credentials. Both are turned into k8s Secrets by
  # system.activationScripts.bitwardenSecrets in nixos/roles/k3s-server.nix.
  sops.secrets.bws-access-token.sopsFile = ./rp-sec.yml;
  sops.secrets.argocd-repo-url.sopsFile = ./rp-sec.yml;
  sops.secrets.argocd-repo-username.sopsFile = ./rp-sec.yml;
  sops.secrets.argocd-repo-password.sopsFile = ./rp-sec.yml;
}
