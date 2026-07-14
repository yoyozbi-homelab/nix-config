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
    kernelParams = [ "video=Virtual-1:1920x1080@60" ];
  };

  services.xserver.xkb = {
    layout = "ch";
    variant = "fr";
  };

  # Guest-side OpenGL: provides Mesa's virgl (virtio-gpu) userspace driver so
  # the compositor renders through the host GPU instead of llvmpipe software GL.
  hardware.graphics.enable = true;

  # `nixos-rebuild build-vm` reads these `vmVariant` options to build the QEMU
  # run script. Defaults (1 vCPU / 1 GiB / no GPU) make Hyprland software-render
  # and thrash — the settings below give it real resources and 3D acceleration.
  # spice-vdagentd bridges the SPICE clipboard channel to the Wayland clipboard
  # inside the guest, enabling copy-paste between VM and host.
  services.spice-vdagentd.enable = true;

  virtualisation.vmVariant.virtualisation = {
    memorySize = 4096; # MiB
    cores = 4;
    qemu.options = [
      # virtio-vga-gl with spice-app gives 3D acceleration AND clipboard sharing.
      # spice-app launches remote-viewer on the host automatically.
      "-vga none"
      "-device virtio-vga-gl"
      "-display spice-app,gl=on"
      # SPICE vdagent channel — required for clipboard and guest<->host copy-paste
      "-device virtio-serial"
      "-chardev spicevmc,id=vdagent,name=vdagent"
      "-device virtserialport,chardev=vdagent,name=com.redhat.spice.0"
    ];
  };
}
