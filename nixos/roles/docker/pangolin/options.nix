{ lib, ... }:
{
  options.yoyozbi.pangolin.ipv6Subnet = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "fd31:7a6e:9f00::/64";
    description = ''
      ULA subnet for the `pangolin` compose network. Set it on hosts with
      public IPv6, together with Docker's `userland-proxy = false` and
      `ip6tables = true`: Docker then NATs IPv6 to the published ports in the
      kernel and keeps the client's source address. Without it, IPv6 clients
      go through docker-proxy and all appear as the bridge gateway, so
      crowdsec would see (and could ban) a single address for all of them.
    '';
  };
}
