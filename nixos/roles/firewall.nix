{
  lib,
  hostname,
  ...
}:
let
  wireguard = {
    hosts = [
      "laptop-nix"
    ];

    tcpPortRanges = [
      {
        from = 3000;
        to = 4000;
      }
    ];
  };
  kdeconnect = {
    hosts = [
      "laptop-nix"
    ];

    tcpPortRanges = [
      {
        from = 1716;
        to = 1764;
      }
    ];
    udpPortRanges = [
      {
        from = 1716;
        to = 1764;
      }
    ];
  };
  mqtt = {
    hosts = [
      "laptop-nix"
    ];

    tcpPortRanges = [
      {
        from = 1883;
        to = 1883;
      }
    ];
  };
  lan-mouse = {
    hosts = [
      "laptop-nix"
      "surface-nix"
    ];

    tcpPortRanges = [
      {
        from = 4242;
        to = 4242;
      }
    ];

    udpPortRanges = [
      {
        from = 4242;
        to = 4242;
      }
    ];
  };
in
{
  networking = {
    firewall = {
      enable = true;
      logReversePathDrops = true;
      allowedTCPPortRanges =
        lib.optionals (builtins.elem hostname wireguard.hosts) wireguard.tcpPortRanges
        ++ lib.optionals (builtins.elem hostname kdeconnect.hosts) kdeconnect.tcpPortRanges
        ++ lib.optionals (builtins.elem hostname mqtt.hosts) mqtt.tcpPortRanges
        ++ lib.optionals (builtins.elem hostname lan-mouse.hosts) lan-mouse.tcpPortRanges;
      allowedUDPPortRanges =
        lib.optionals (builtins.elem hostname kdeconnect.hosts) kdeconnect.udpPortRanges
        ++ lib.optionals (builtins.elem hostname lan-mouse.hosts) lan-mouse.udpPortRanges;
    };
  };
}
