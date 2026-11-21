# IPv4 relay, client side (the IPv6-only host). See common.nix.
# Requires a sops secret named wg-relay-key (a `wg genkey` private key) and
# systemd-networkd (networking.useNetworkd).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.yoyozbi.ipv4Relay;
  server = config.networking.yoyozbi.hosts.${cfg.server};
in
{
  imports = [ ./common.nix ];

  # networkd brings the tunnel up itself; `wg show` is for debugging.
  environment.systemPackages = [ pkgs.wireguard-tools ];

  assertions = [
    {
      assertion = config.sops.secrets ? wg-relay-key;
      message = "The ipv4-relay/client role requires a sops secret named `wg-relay-key`.";
    }
    {
      assertion = server.externalIpv6 != null;
      message = "ipv4-relay/client: set externalIpv6 in hosts/${cfg.server}/host.toml [network].";
    }
    {
      assertion = !(lib.hasPrefix "TODO" cfg.serverPublicKey);
      message = "yoyozbi.ipv4Relay.serverPublicKey is not set (see nixos/roles/ipv4-relay/common.nix).";
    }
    {
      assertion = config.systemd.network.enable;
      message = "ipv4-relay/client requires systemd-networkd.";
    }
  ];

  # networkd reads the key itself.
  sops.secrets.wg-relay-key = {
    owner = "systemd-network";
    group = "systemd-network";
    mode = "0400";
    restartUnits = [ "systemd-networkd.service" ];
  };

  systemd.network.netdevs."50-${cfg.interface}" = {
    netdevConfig = {
      Kind = "wireguard";
      Name = cfg.interface;
      MTUBytes = toString cfg.mtu;
    };
    wireguardConfig.PrivateKeyFile = config.sops.secrets.wg-relay-key.path;
    wireguardPeers = [
      {
        PublicKey = cfg.serverPublicKey;
        Endpoint = "[${server.externalIpv6}]:${toString cfg.port}";
        # Cryptokey routing only; the kernel routes come from the network unit
        # below (networkd adds no routes for AllowedIPs by default).
        AllowedIPs = [ "0.0.0.0/0" ];
        # We dial out, so keep the server's stateful firewall (OCI) open.
        PersistentKeepalive = 25;
      }
    ];
  };

  systemd.network.networks."50-${cfg.interface}" = {
    matchConfig.Name = cfg.interface;
    address = [ "${cfg.clientAddr}/${toString cfg.prefixLength}" ];
    networkConfig.LinkLocalAddressing = "no";
    routes = lib.optional cfg.defaultRoute { Destination = "0.0.0.0/0"; };
    # The host must come up (and stay deployable) even if the relay is down.
    linkConfig.RequiredForOnline = "no";
  };
}
