{ ... }:
{
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

  hardware.graphics.enable = true;

  services.spice-vdagentd.enable = true;

  virtualisation.vmVariant.virtualisation = {
    memorySize = 4096;
    cores = 4;
    qemu.options = [
      "-vga none"
      "-device virtio-vga-gl"
      "-display spice-app,gl=on"
      "-device virtio-serial"
      "-chardev spicevmc,id=vdagent,name=vdagent"
      "-device virtserialport,chardev=vdagent,name=com.redhat.spice.0"
    ];
  };
}
