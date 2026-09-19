# Encrypted duplicity backups of a list of paths to a remote target (WebDAV,
# S3, SFTP, ...), with an optional ntfy notification for every run.
#
# Every run is incremental until the last full backup is older than
# `fullIfOlderThan`, and the `keepFull` most recent full chains are kept.
#
# The target and credentials come from `environmentFile` (systemd
# EnvironmentFile syntax), so none of them land in the Nix store:
#   BACKUP_TARGET_URL  e.g. webdavs://user@dav.example.com/backups/host
#   PASSPHRASE         GPG passphrase for the archives. Without it the backups
#                      cannot be restored, so keep it somewhere other than this host
#   BACKEND_PASSWORD   the target's password (read by every duplicity backend,
#                      unless the URL already carries one)
#   NTFY_URL           optional, e.g. https://ntfy.sh/<topic>
#   NTFY_TOKEN         optional, for protected topics
#
# Restoring rp's paperless is documented in hosts/rp/README.md.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.yoyozbi.backup;
  hostName = config.networking.hostName;
  archiveDir = "/var/lib/duplicity";

  # Sends to NTFY_URL if it is set, a no-op otherwise.
  notify = pkgs.writeShellApplication {
    name = "backup-notify";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      # usage: backup-notify <title> <priority> <tags> <message>
      if [ -z "''${NTFY_URL:-}" ]; then
        exit 0
      fi
      auth=()
      if [ -n "''${NTFY_TOKEN:-}" ]; then
        auth=(-H "Authorization: Bearer $NTFY_TOKEN")
      fi
      curl -fsS --retry 3 -o /dev/null \
        -H "Title: $1" -H "Priority: $2" -H "Tags: $3" "''${auth[@]}" \
        --data-binary "$4" "$NTFY_URL"
    '';
  };

  # Excludes go first: duplicity applies the first selection rule that matches.
  selection = lib.escapeShellArgs (
    lib.concatMap (p: [
      "--exclude"
      p
    ]) cfg.exclude
    ++ lib.concatMap (p: [
      "--include"
      p
    ]) cfg.paths
    ++ [
      "--exclude"
      "**"
    ]
  );

  commonFlags = lib.escapeShellArgs [
    "--archive-dir"
    archiveDir
    "--verbosity"
    "notice"
  ];

  backup = pkgs.writeShellApplication {
    name = "duplicity-backup";
    runtimeInputs = [
      pkgs.duplicity
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      notify
    ];
    text = ''
      : "''${BACKUP_TARGET_URL:?must be set in the environment file}"
      : "''${PASSPHRASE:?must be set in the environment file}"

      ${cfg.preBackup}

      log="$(mktemp)"
      trap 'rm -f "$log"' EXIT

      # Remove leftovers from an interrupted run before starting a new one.
      duplicity cleanup --force "$BACKUP_TARGET_URL" ${commonFlags}

      duplicity incr / "$BACKUP_TARGET_URL" \
        --full-if-older-than ${lib.escapeShellArg cfg.fullIfOlderThan} \
        ${selection} ${commonFlags} 2>&1 | tee "$log"

      duplicity remove-all-but-n-full ${toString cfg.keepFull} --force \
        "$BACKUP_TARGET_URL" ${commonFlags}

      kind="Incremental"
      if grep -Eq 'forcing full backup|switching to full backup' "$log"; then
        kind="Full"
      fi
      stats="$(awk '$1 ~ /^(ElapsedTime|SourceFileSize|TotalDestinationSizeChange|Errors)$/' "$log")"

      # The data is already safe, so a failed notification must not fail the unit
      # (which would send a misleading failure notification instead).
      backup-notify "${hostName}: $kind backup done" default floppy_disk "$stats" \
        || echo "Sending the ntfy notification failed" >&2
    '';
  };

  failureNotify = pkgs.writeShellApplication {
    name = "duplicity-backup-failure-notify";
    runtimeInputs = [
      pkgs.systemd
      notify
    ];
    text = ''
      # systemd sets MONITOR_INVOCATION_ID for OnFailure= units, which scopes
      # the log excerpt to the run that failed.
      if [ -n "''${MONITOR_INVOCATION_ID:-}" ]; then
        logs="$(journalctl _SYSTEMD_INVOCATION_ID="$MONITOR_INVOCATION_ID" -n 15 -o cat --no-pager)"
      else
        logs="$(journalctl -u duplicity-backup.service -n 15 -o cat --no-pager)"
      fi
      backup-notify "${hostName}: backup FAILED" high rotating_light "$logs"
    '';
  };
in
{
  options.yoyozbi.backup = with lib; {
    paths = mkOption {
      type = types.nonEmptyListOf types.str;
      description = "Absolute paths to back up.";
    };

    exclude = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Paths or globs under `paths` to leave out (duplicity selection syntax).";
    };

    environmentFile = mkOption {
      type = types.str;
      description = "EnvironmentFile with the target, credentials and ntfy settings (see the header of this file).";
    };

    preBackup = mkOption {
      type = types.lines;
      default = "";
      description = "Shell run before each backup, e.g. to dump a database into one of `paths`.";
    };

    startAt = mkOption {
      type = types.str;
      default = "*-*-* 03:00:00";
      description = "When to run (systemd.time calendar event).";
    };

    fullIfOlderThan = mkOption {
      type = types.str;
      # Not 7D: a daily run that starts a few seconds earlier than last week's
      # full would find it just under 7 days old and push the full to day 8.
      default = "6D12h";
      description = "Take a full backup once the last one is older than this (duplicity time format).";
    };

    keepFull = mkOption {
      type = types.ints.positive;
      default = 4;
      description = "Number of full backup chains (a full plus its incrementals) to keep.";
    };
  };

  config = {
    systemd.services.duplicity-backup = {
      description = "Back up with duplicity";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      startAt = cfg.startAt;
      onFailure = [ "duplicity-backup-failure-notify.service" ];

      # With a path missing its mount, the backup would record its contents as
      # deleted.
      unitConfig.RequiresMountsFor = cfg.paths;

      environment.HOME = archiveDir;

      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe backup;
        EnvironmentFile = cfg.environmentFile;
        StateDirectory = baseNameOf archiveDir;
        StateDirectoryMode = "0700";
        PrivateTmp = true;
        # A full backup can take hours on a slow uplink, but a hung upload
        # should still end in a failure notification eventually.
        TimeoutStartSec = "12h";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    # Catch up after the host was off at the scheduled time.
    systemd.timers.duplicity-backup.timerConfig.Persistent = true;

    systemd.services.duplicity-backup-failure-notify = {
      description = "Notify that the duplicity backup failed";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe failureNotify;
        EnvironmentFile = cfg.environmentFile;
      };
    };

    environment.systemPackages = [ pkgs.duplicity ];
  };
}
