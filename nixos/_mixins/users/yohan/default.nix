{
  config,
  desktop,
  hostname,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  ifExists = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
  stable-packages =
    with pkgs;
    [
      kubectl
      kubectx
      envsubst
      kubernetes-helm
      talosctl
      cifs-utils
      git
      vim
      comma
    ]
    ++ lib.optionals (desktop != null) [
      appimage-run
      libreoffice

      #troubleshooting disks
      gparted
      ntfs3g
      btrfs-progs
      samba

      # Other
      unstable.obsidian
      unstable.ungoogled-chromium
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ]
    ++ lib.optionals (desktop != null && hostname == "laptop-nix") [
      # Productivity
      superProductivity
      gnome-network-displays
      claude-code

      # Dotnet
      dotnet-sdk_9

      # Rust
      rustup
      rustPackages.clippy
      rustfmt
      openssl.dev
      jetbrains.rust-rover

      # Java
      jdk24
#      unstable.jetbrains.idea-ultimate
#      unstable.android-studio
      gradle
      imagej
      turbovnc

      # Go
      go
      gopls

      # C/C++
#      jetbrains.clion
      mesa # Opengl
      autoconf # vcpkg
      pkgconf
      automake
      gcc
      clang-tools
      cmake
      ninja
      gnumake
      unzip
      zip
      wget
      icu63

#      godot
#      pixelorama

      # Dev
      bruno
      beekeeper-studio
      unstable.zed-editor
      python313

      # Other
      vlc

      # Photos
#      unstable.darktable
#      hugin
#      digikam
      exiftool
#      gimp

#      kdePackages.kdenlive
      ffmpeg
      SDL
      xml2
      handbrake
      #kDrive

      android-tools

      #Music/Video
      spotify
      jellyfin-media-player
      deluge
      obs-studio
      blender

      unstable.argocd
#      cloudflared
      zotero

      # Games and co
#      discord
#      steam
#      heroic
    ]
    ++ lib.optionals (desktop != null && hostname == "surface-nix") [
    ];

in
{
  imports = lib.optionals (desktop != null) [
    ../../services/appimage.nix
  ];

  environment.localBinInPath = true;
  environment.systemPackages = stable-packages;


  programs.zsh.enable = true;
  programs.nix-ld.enable = true;

  # Configure keymap in X11
  services = {
    xserver = {
      xkb = {
        layout = "ch";
        variant = "fr";
      };

    };
  };

  # Configure console keymap
  console.keyMap = "fr_CH";

  users.groups.yohan = { };
  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  users.users.yohan = {
    description = "Yohan Zbinden";
    isNormalUser = true;
    group = "yohan";
    extraGroups = [
      "audio"
      "input"
      "networkmanager"
      "kvm"
      "libvirtd"
      "users"
      "video"
      "wheel"
    ]
    ++ ifExists [
      "docker"
      "lxd"
      "podman"
      "vboxusers"
    ];
    # mkpasswd -m sha-512
    hashedPassword = "$6$a.nRdlFB3YPvVgjX$iWBzmkH0zK/3n/yyEl2Fuwp1G4ayzr5zG0Un7z4hCvWoKctMZirMKWMcwPBgqRylhgnI.gKLhg5xvwqRuipqZ.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0wY1HBFWJGgaoT0L23bQg3icnmyDBds12gc0iOzuDV yohan@laptop-nix"
    ];

    packages = [ pkgs.home-manager ];
    shell = pkgs.zsh;
  };
}
