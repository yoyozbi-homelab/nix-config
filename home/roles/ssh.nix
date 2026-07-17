_: {
  programs = {
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "gitlab-etu.ing.he-arc.ch" = {
          HostName = "gitlab-etu.ing.he-arc.ch";
          IdentityFile = "/home/yohan/.ssh/id_gitlab-etu";
        };

        "github.com" = {
          HostName = "github.com";
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
          HostName = "152.67.75.190";
          User = "nix";
          IdentityFile = "/home/yohan/.ssh/id_github";
        };

        tiny2 = {
          HostName = "144.24.234.135";
          User = "nix";
          IdentityFile = "/home/yohan/.ssh/id_github";
        };

        cuda = {
          HostName = "157.26.103.173";
          User = "arc22";
          IdentityFile = "/home/yohan/.ssh/id_github";
        };
      };
    };
  };
}
