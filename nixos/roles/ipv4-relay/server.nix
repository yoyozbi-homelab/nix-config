# IPv4 relay, server side (the host that owns the public IPv4). See common.nix.
# Requires a sops secret named wg-relay-key (a `wg genkey` private key).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.yoyozbi.ipv4Relay;
  inherit (config.networking.yoyozbi) currentHost;

  # On OCI the public IPv4 is 1:1 NAT'd to the VNIC's private address, so that
  # is the destination packets arrive with. Matching on it (rather than an
  # interface) leaves the host's own traffic and ssh untouched.
  publicAddr = currentHost.internalIp;

  ports = lib.concatMapStringsSep ", " toString;

  # Own table, loaded on its own: no `networking.nftables.enable`, whose
  # `flush ruleset` would wipe Docker's rules on a host that still runs Docker.
  # The empty-table + delete idiom makes reloading idempotent.
  ruleset = pkgs.writeText "ipv4-relay.nft" ''
    table ip ipv4relay {}
    delete table ip ipv4relay

    table ip ipv4relay {
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        ip daddr ${publicAddr} tcp dport { ${ports cfg.forwardTcp} } dnat to ${cfg.clientAddr}
        ip daddr ${publicAddr} udp dport { ${ports cfg.forwardUdp} } dnat to ${cfg.clientAddr}
      }

      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        # The client's own IPv4 egress. Replies to DNAT'd flows are not
        # touched: NAT rules only see the first packet of a connection.
        ip saddr ${cfg.clientAddr} oifname != "${cfg.interface}" masquerade
      }

      chain forward {
        type filter hook forward priority mangle; policy accept;
        # Fit TCP into the tunnel MTU in both directions (SYN and SYN-ACK
        # entering the tunnel carry the clamped MSS).
        oifname "${cfg.interface}" tcp flags syn tcp option maxseg size set rt mtu
      }
    }
  '';
in
{
  imports = [ ./common.nix ];

  assertions = [
    {
      assertion = config.sops.secrets ? wg-relay-key;
      message = "The ipv4-relay/server role requires a sops secret named `wg-relay-key`.";
    }
    {
      assertion = !(lib.hasPrefix "TODO" cfg.clientPublicKey);
      message = "yoyozbi.ipv4Relay.clientPublicKey is not set (see nixos/roles/ipv4-relay/common.nix).";
    }
  ];

  sops.secrets.wg-relay-key = {
    restartUnits = [ "wireguard-${cfg.interface}.service" ];
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.wireguard.interfaces.${cfg.interface} = {
    ips = [ "${cfg.serverAddr}/${toString cfg.prefixLength}" ];
    listenPort = cfg.port;
    inherit (cfg) mtu;
    privateKeyFile = config.sops.secrets.wg-relay-key.path;
    peers = [
      {
        # The client dials in (it knows the server's IPv6); no endpoint here.
        publicKey = cfg.clientPublicKey;
        allowedIPs = [ "${cfg.clientAddr}/32" ];
      }
    ];
  };

  networking.networkmanager.unmanaged = lib.mkIf config.networking.networkmanager.enable [
    "interface-name:${cfg.interface}"
  ];

  systemd.services.ipv4-relay-nat = lib.mkIf cfg.forward.enable {
    description = "IPv4 relay: DNAT to ${cfg.client} and masquerade its egress";
    wantedBy = [ "multi-user.target" ];
    before = [ "network-pre.target" ];
    wants = [ "network-pre.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.nftables}/bin/nft -f ${ruleset}";
      ExecStop = "${pkgs.nftables}/bin/nft delete table ip ipv4relay";
    };
  };
}
