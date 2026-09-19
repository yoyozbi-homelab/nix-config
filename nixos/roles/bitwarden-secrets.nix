# Pulls secrets out of Bitwarden Secrets Manager at boot, sops-nix style.
#
# Declare secrets by their Bitwarden UUID and they land as root-only files
# under /run/bitwarden-secrets. `templates` render a file with
# `config.yoyozbi.bitwardenSecrets.placeholder.<name>` substituted, for
# consumers that want one config file rather than a file per value. Like
# sops-nix templates, values are substituted verbatim, without escaping.
#
# Files are root:root 0600, so a container must read them before dropping
# privileges (as newt and paperless' s6 init do).
#
# Units consuming these files should `requires` + `after`
# bitwarden-secrets.service: a restart of the fetcher then restarts them too.
#
# This requires a sops secret named bws-access-token (a machine-account token)!
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.yoyozbi.bitwardenSecrets;
  secretsDir = "/run/bitwarden-secrets";

  mkPlaceholder = name: "<BWS:${name}>";

  secretNames = lib.attrNames cfg.secrets;

  # jq's single-argument split() is a literal (non-regex) split, so values and
  # placeholders need no escaping.
  jqArgs = lib.concatImapStringsSep " " (
    i: name: "--rawfile s${toString i} ${lib.escapeShellArg cfg.secrets.${name}.path}"
  ) secretNames;
  jqFilter =
    if secretNames == [ ] then
      "."
    else
      lib.concatImapStringsSep " | " (
        i: name: "split(${builtins.toJSON (mkPlaceholder name)}) | join($s${toString i})"
      ) secretNames;

  fetchSecret = name: secret: ''
    bws secret get ${lib.escapeShellArg secret.id} --output json \
      | jq -j .value > ${secretsDir}/.${name}.tmp
    mv ${secretsDir}/.${name}.tmp ${lib.escapeShellArg secret.path}
  '';

  renderTemplate = name: template: ''
    jq -Rsj ${jqArgs} \
      ${lib.escapeShellArg jqFilter} \
      < ${pkgs.writeText "bws-template-${name}" template.content} \
      > ${secretsDir}/.${name}.tmp
    mv ${secretsDir}/.${name}.tmp ${lib.escapeShellArg template.path}
  '';

  # A standalone script rather than a function: errexit is suppressed inside a
  # function called from an `if`, which would let a failed fetch pass.
  fetchAll = pkgs.writeShellApplication {
    name = "bitwarden-secrets-fetch";
    runtimeInputs = with pkgs; [
      bws
      jq
      coreutils
    ];
    text = ''
      mkdir -p ${secretsDir}/templates
      ${lib.concatStrings (lib.mapAttrsToList fetchSecret cfg.secrets)}
      ${lib.concatStrings (lib.mapAttrsToList renderTemplate cfg.templates)}
    '';
  };
in
{
  options.yoyozbi.bitwardenSecrets = with lib; {
    serverUrl = mkOption {
      type = types.str;
      default = "https://vault.bitwarden.com";
      description = "Bitwarden server the access token belongs to.";
    };

    secrets = mkOption {
      default = { };
      description = "Secrets to fetch, keyed by the file name they are written to.";
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              id = mkOption {
                type = types.str;
                description = "Bitwarden secret UUID.";
              };
              path = mkOption {
                type = types.str;
                readOnly = true;
                default = "${secretsDir}/${name}";
              };
            };
          }
        )
      );
    };

    templates = mkOption {
      default = { };
      description = "Files rendered from the fetched secrets via `placeholder`.";
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              content = mkOption { type = types.lines; };
              path = mkOption {
                type = types.str;
                readOnly = true;
                default = "${secretsDir}/templates/${name}";
              };
            };
          }
        )
      );
    };

    placeholder = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      default = lib.mapAttrs (name: _: mkPlaceholder name) cfg.secrets;
    };
  };

  config = {
    assertions = [
      {
        assertion = config.sops.secrets ? bws-access-token;
        message = ''
          The bitwarden-secrets role requires a SOPS secret named `bws-access-token`.
          Declare it on the host, e.g. in hosts/<host>/hardware.nix:
            sops.secrets.bws-access-token = { };
        '';
      }
    ];

    systemd.services.bitwarden-secrets = {
      description = "Fetch secrets from Bitwarden Secrets Manager";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        BWS_SERVER_URL = cfg.serverUrl;
        # bws keeps its login state under $HOME/.config/bws.
        HOME = "/var/lib/bitwarden-secrets";
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "bitwarden-secrets";
        StateDirectoryMode = "0700";
        UMask = "0077";
        # Covers the retry loop below on a slow boot network.
        TimeoutStartSec = "15min";
      };

      script = ''
        set -euo pipefail
        BWS_ACCESS_TOKEN="$(< ${config.sops.secrets.bws-access-token.path})"
        export BWS_ACCESS_TOKEN

        # network-online does not mean Bitwarden is reachable yet.
        for attempt in $(seq 1 30); do
          if ${lib.getExe fetchAll}; then
            exit 0
          fi
          echo "Fetching from Bitwarden failed (attempt $attempt/30), retrying in 20s" >&2
          sleep 20
        done
        exit 1
      '';
    };
  };
}
