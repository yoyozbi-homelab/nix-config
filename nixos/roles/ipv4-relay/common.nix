# Shared settings of the IPv4 relay between an IPv4-capable host (server,
# tiny1) and an IPv6-only host (client, cloudjumper). Imported by the
# `ipv4-relay/server` and `ipv4-relay/client` roles; not a role by itself.
#
#   IPv4 client -> server public IPv4 -> nft DNAT (no SNAT) -> WireGuard over
#   IPv6 -> client. The client's IPv4 default route points into the tunnel, so
#   replies return the same way and the server's conntrack reverses the DNAT:
#   the client sees real source IPs (crowdsec bans by IP). The server also
#   masquerades the client's own IPv4 egress (GitHub has no IPv6).
#
# Design and cutover runbook: https://github.com/yoyozbi-homelab/infra (PLAN.md)
{ lib, ... }:
{
  options.yoyozbi.ipv4Relay = with lib; {
    server = mkOption {
      type = types.str;
      default = "tiny1";
      description = "Host with public IPv4 that forwards to the client.";
    };
    client = mkOption {
      type = types.str;
      default = "cloudjumper";
      description = "IPv6-only host that receives the forwarded IPv4 traffic.";
    };

    interface = mkOption {
      type = types.str;
      default = "wg-relay";
    };
    port = mkOption {
      type = types.port;
      default = 51830;
      description = "WireGuard listen port on the server (reached over IPv6).";
    };
    # WireGuard over IPv6 costs 80 bytes: 1500 - 80.
    mtu = mkOption {
      type = types.int;
      default = 1420;
    };

    serverAddr = mkOption {
      type = types.str;
      default = "10.200.0.1";
    };
    clientAddr = mkOption {
      type = types.str;
      default = "10.200.0.2";
    };
    prefixLength = mkOption {
      type = types.int;
      default = 30;
    };

    # Public halves of the `wg-relay-key` sops secrets of each host:
    #   sops decrypt --extract '["wg-relay-key"]' hosts/<host>/<host>-sec.yml | wg pubkey
    serverPublicKey = mkOption {
      type = types.str;
      default = "cciUnhtvED+jFEXg0pb9YfkgosSYjsFJBSkSNeXgqGA=";
    };
    clientPublicKey = mkOption {
      type = types.str;
      default = "QJMMdJ8JEkQgmalnxs1ZE+ZVd7RpJ/xGfwNaLdQcSyg=";
    };

    forwardTcp = mkOption {
      type = types.listOf types.port;
      default = [
        80
        443
      ];
      description = "TCP ports DNAT'd from the server's public IPv4 to the client.";
    };
    forwardUdp = mkOption {
      type = types.listOf types.port;
      default = [
        443 # HTTP/3
        51820 # gerbil WireGuard (newt sites)
        21820 # gerbil WireGuard (clients)
      ];
      description = "UDP ports DNAT'd from the server's public IPv4 to the client.";
    };

    forward.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Server: install the DNAT/masquerade rules. Off while the server still
        serves these ports itself (before the Pangolin cutover).
      '';
    };
    defaultRoute = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Client: route all IPv4 through the tunnel. Turn on together with the
        server's forward.enable; before that the server drops forwarded traffic.
      '';
    };
  };
}
