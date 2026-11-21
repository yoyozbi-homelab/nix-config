{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disks.nix
  ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
  ];

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    configurationLimit = 4;
    # devices: set by disko from the EF02 partition in disks.nix
  };

  zramSwap.enable = true;

  # ext-v6only1 is IPv6-only with dhcpv6-stateful addressing (no SLAAC): the
  # router advertisement carries the M flag and the address comes from DHCPv6.
  networking = {
    useDHCP = false;
    useNetworkd = true;
    domain = "";
    # The OpenStack security group is the firewall, as on the OCI hosts.
    firewall.enable = lib.mkForce false;
    # Infomaniak resolvers, in case DHCPv6 does not hand them out.
    nameservers = [
      "2001:1600:0:aaaa::53:5"
      "2001:1600:0:aaaa::53:6"
    ];
  };

  systemd.network = {
    enable = true;
    networks."10-uplink" = {
      matchConfig.Name = "en* eth*";
      networkConfig = {
        DHCP = "ipv6";
        IPv6AcceptRA = true;
        LinkLocalAddressing = "ipv6";
      };
      # Don't wait for the RA's M flag to decide; the subnet is stateful.
      dhcpV6Config.WithoutRA = "solicit";
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # Secrets: add hosts/cloudjumper/cloudjumper-sec.yml once the host key's age
  # recipient is in .sops.yaml (infra: `tofu output -raw ssh_host_public_key | ssh-to-age`):
  sops.defaultSopsFile = ./cloudjumper-sec.yml;
}
