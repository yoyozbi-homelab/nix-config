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

  # This is a 1 OCPU / 1 GB OCI instance. Measured at 70%+ CPU steal with
  # kswapd as the busiest process and zram 100% full, so the memory side is
  # tuned for "swap early and cheaply" rather than "avoid swap".
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    # Default is 50%. zstd is getting ~4:1 on this workload (467 M of data in
    # 114 M of RAM), so a larger zram device buys far more usable memory than
    # the RAM it costs.
    memoryPercent = 100;
  };

  boot.kernel.sysctl = {
    # zram is orders of magnitude cheaper than disk swap, so the kernel should
    # prefer it over evicting page cache and re-reading from the boot volume.
    "vm.swappiness" = 180;
    # Readahead is a disk optimisation; on zram it just decompresses pages
    # nothing asked for. This is what shrinks the si/so churn.
    "vm.page-cluster" = 0;
    # Start reclaiming sooner so kswapd does steady small work instead of
    # stalling allocators in direct reclaim.
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
  };

  nix = {

    # A cachix deploy pulls and GCs the store, which on this box competes
    # directly with the reverse proxy. Keep it single-threaded and let it lose
    # every scheduling contest against live traffic.
    settings = {
      max-jobs = 1;
      cores = 1;
    };

    # nixpkgs already pins the daemon's scheduling, so go through its own
    # options rather than fighting them in serviceConfig.
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "idle";
  };

  systemd.services.cachix-agent.serviceConfig = {
    Nice = 19;
    CPUWeight = 20;
    IOSchedulingClass = "idle";
  };

  systemd.services.nix-daemon.serviceConfig.CPUWeight = 20;

  networking = {
    domain = "";
    firewall.enable = lib.mkForce false;
  };

  sops = {
    defaultSopsFile = ./tiny1-sec.yml;
    secrets = {
      pangolin-server-secret = { };
      crowdsec-bouncer-key = { };
    };
  };
}
