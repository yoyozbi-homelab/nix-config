_: {
  programs = {
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "github.com" = {
          HostName = "github.com";
          IdentityFile = "/home/yohan/.ssh/id_github";
        };

        "codeberg.org" = {
          HostName = "codeberg.org";
          IdentityFile = "/home/yohan/.ssh/id_github";
        };

        rp = {
          HostName = "192.168.1.2";
          User = "nix";
          IdentityFile = "/home/yohan/.ssh/id_github";
        };

        ocr1 = {
          HostName = "144.24.253.246";
          User = "nix";
          IdentityFile = "/home/yohan/.ssh/id_github";
        };

        tiny1 = {
          HostName = "140.238.221.62";
          User = "nix";
          IdentityFile = "/home/yohan/.ssh/id_github";
        };

        tiny2 = {
          HostName = "144.24.239.84";
          User = "nix";
          IdentityFile = "/home/yohan/.ssh/id_github";
        };

        cloudjumper = {
          HostName = "2001:1600:10:101::824";
          User = "nix";
          IdentityFile = "/home/yohan/.ssh/id_github";
        };
      };
    };
  };
}
