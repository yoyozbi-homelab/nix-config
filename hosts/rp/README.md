# rp: backups and restore

`duplicity-backup.service` (role `backup`) runs every night at 03:00 and takes
a GPG-encrypted duplicity backup to the WebDAV server. It makes a full backup
once a week and incrementals on the other days, and it keeps the last 4
weekly chains. The target, credentials and passphrase come from Bitwarden
(`backup-*` secrets). Each run sends an ntfy notification, whether it
succeeds or fails.

What is in the backup (paths relative to `/`):

| Path | Content |
|------|---------|
| `mnt/data/paperless/media` | The documents: `documents/originals` (named by storage path), `documents/archive`, `documents/thumbnails` |
| `mnt/data/paperless/data` | Search index, classifier model |
| `mnt/data/paperless/consume` | Files waiting to be imported |
| `mnt/data/paperless/db-dump/paperless.sql` | `pg_dump` of the database, taken before each backup |

The raw Postgres directory is not backed up: the database is restored from
the dump.

## List and restore from the local copy

The WebDAV folder is synced locally, so only the passphrase (`backup-passphrase`)
is needed. The URL takes three slashes, because the path is absolute:

```bash
nix shell nixpkgs#duplicity
export PASSPHRASE='...'
export BACKUP_TARGET_URL='file:///home/yohan/kDrive/backup/paperless'

duplicity collection-status "$BACKUP_TARGET_URL"   # full/incremental dates
duplicity list-current-files "$BACKUP_TARGET_URL"  # files in the latest backup

duplicity restore --path-to-restore mnt/data/paperless/media/documents/originals \
  "$BACKUP_TARGET_URL" ./paperless-originals
```

- `--time 3D` (or `--time 2026-09-10`) selects an older backup.
- `--path-to-restore` has no leading slash, and the target must not exist yet.
- The synced copy must be complete: it needs the last full backup and every
  incremental after it, with no online-only placeholders.
  `collection-status` reports a broken chain.

## Restore paperless on rp

As root on rp, after deploying the configuration:

```bash
# 1. Pause the backups: repeated backups of an empty instance would
#    eventually prune the chains that hold the data.
systemctl stop duplicity-backup.timer

# 2. Download the backup (the WebDAV credentials are already on rp).
set -a; . /run/bitwarden-secrets/templates/backup.env; set +a
duplicity restore --archive-dir /var/lib/duplicity "$BACKUP_TARGET_URL" /mnt/data/restore
R=/mnt/data/restore/mnt/data/paperless

# 3. Put the files back (paperless runs as uid 1000).
systemctl stop arion-paperless
for d in data media consume db-dump; do
  rm -rf "/mnt/data/paperless/$d" && mv "$R/$d" /mnt/data/paperless/
done
chown -R 1000:1000 /mnt/data/paperless/{data,media,consume}

# 4. Replace the database with the dump.
systemctl start arion-paperless
until docker exec paperless-postgres pg_isready -U paperless; do sleep 2; done
docker stop paperless
docker exec paperless-postgres dropdb -U paperless paperless
docker exec paperless-postgres createdb -U paperless paperless
docker exec -i paperless-postgres psql -q -U paperless -d paperless \
  < /mnt/data/paperless/db-dump/paperless.sql
systemctl restart arion-paperless

# 5. Check, clean up, resume the backups.
docker exec paperless document_sanity_checker
rm -rf /mnt/data/restore
systemctl start duplicity-backup.timer
```
