# Plan: TOML-driven host configuration restructure

**Complexity**: Large (touches every file, but mechanical after the machinery exists)
**Goal**: A host is fully described by one `host.toml`. Day-to-day changes (add a package, enable a role, add a host) never require touching Nix code. The Nix machinery that makes this work is allowed to be dense and write-once.

---

## 1. Current state (analysis)

| Piece | Today | Pain point |
|---|---|---|
| Host list | Hardcoded attrset in `flake.nix:60-68` **and** repeated in `homeConfigurations` (`flake.nix:96-120`) | Two places to keep in sync; adding a host = editing the flake |
| Host modules | `nixos/<hostname>/default.nix` imports 5–10 `../_mixins/...` paths by hand | Every capability toggle is an import-path edit |
| Shared config | `nixos/_mixins/{desktop,hardware,k3s,services,users}` + `home-manager/_mixins/{console,desktop,dotfiles,services,users}` | Everything lands in `_mixins`, no notion of "role"; discovery is by grepping imports |
| Network/cluster data | `hosts.nix` (custom `networking.yoyozbi.hosts` options module, ~240 lines) | Host data lives in a third place, as Nix |
| Wiring | `lib/helpers.nix` `mkHost`/`mkHome` + magic `builtins.pathExists` imports in `nixos/default.nix` and `home-manager/default.nix` | Implicit conventions (`users/<u>/hosts/<h>.nix`) scattered across files |
| Home-only hosts | `wsl-nix`, `laptop-omarchy` exist only as `homeConfigurations` entries | Not visible in the host list at all |

Note on the reference: wimpysworld/nix-config is actually the *origin* of the `_mixins` pattern; what it does well is "hosts are data, helpers do the rest". This plan keeps that idea but replaces both the hardcoded attrset **and** `_mixins` with: **TOML per host + role modules**.

---

## 2. Target layout

```
flake.nix                      # ~40 lines, never changes when hosts change
lib/
  default.nix
  hosts.nix                    # THE machinery: readDir hosts/, fromTOML,
                               # validation, role resolution, mkHost/mkHome.
                               # Dense, write-once, allowed to be ugly.
hosts/
  laptop-nix/
    host.toml                  # identity, roles, packages, overlays, network
    hardware.nix               # boot/fs/luks/nvidia — cannot be TOML, stays Nix
  surface-nix/   { host.toml, hardware.nix, disks.nix }
  vm-nix/        { host.toml, hardware.nix }
  ocr1/          { host.toml, hardware.nix, disks.nix }
  tiny1/         { host.toml, hardware.nix, disks.nix }
  tiny2/         { host.toml, hardware.nix, disks.nix }
  rp/            { host.toml, hardware.nix }
  wsl-nix/       { host.toml }              # nixos = false → home-only
  laptop-omarchy/{ host.toml }              # nixos = false → home-only
nixos/
  core/default.nix             # today's nixos/default.nix baseline (nix settings, gc, sops, disko, root user)
  roles/
    desktop/default.nix        # graphics + dconf (today's _mixins/desktop/default.nix)
    desktop/hyprland.nix, kde.nix, gnome.nix, noctalia.nix, dms.nix, kdemobile.nix
    server/default.nix         # cachix + openssh + networkmanager (the trio every server imports)
    k3s-server/  k3s-agent/  ocr-cluster/   # from _mixins/k3s (secrets move with them)
    boot-systemd.nix, boot-grub.nix, boot-lanzaboote.nix   # from _mixins/hardware
    bluetooth.nix, docker.nix, virtualbox.nix, focusrite.nix,
    thunderbolt.nix, boxes.nix, firewall.nix, pipewire.nix,
    touchpad.nix, tpm.nix, netdata.nix, appimage.nix, ...   # from _mixins/services, flat
  users/
    yohan/default.nix, nix/default.nix, root/default.nix
home/
  core/default.nix             # today's home-manager/default.nix + console baseline
  roles/
    kubernetes.nix, ssh.nix, darktable.nix, ...             # from hm _mixins/services
  desktops/
    hyprland/, noctalia/, dms/, discord.nix, vscode.nix, ...
  users/
    yohan/
      default.nix, desktop.nix
      hosts/<hostname>.nix     # keep this convention, it works
```

Deleted at the end: `nixos/_mixins/`, `home-manager/_mixins/`, `hosts.nix`, `lib/helpers.nix` (absorbed into `lib/hosts.nix`), the two host attrsets in `flake.nix`.

---

## 3. The `host.toml` schema

```toml
# hosts/laptop-nix/host.toml
[host]
username      = "yohan"
platform      = "x86_64-linux"
state-version = "25.05"        # per-host, explicit (today it's one global)
desktop       = "hyprland"     # optional → pulls nixos/roles/desktop/<d> + home/desktops/<d>
nixos         = true           # false = home-only host (wsl-nix, laptop-omarchy)
build-home    = false          # true = embed home-manager in the NixOS build (vm-nix)

# Each role resolves to nixos/roles/<name>.nix or nixos/roles/<name>/default.nix
roles = [
  "boot-systemd", "bluetooth", "firewall", "docker",
  "thunderbolt", "boxes", "virtualbox", "focusrite",
]
home-roles = [ "kubernetes", "ssh" ]

# Plain packages by attr path — resolved against pkgs (dots traverse, so
# "unstable.discord" works thanks to the unstable overlay)
packages      = [ "htop", "ripgrep" ]
home-packages = [ "unstable.discord" ]

# Extra hardware/nixos-hardware modules by name (resolved from a small map in lib)
hardware = [ "dell-xps-15-9520-nvidia" ]

# Overlays beyond the always-on set (additions/modifications/unstable-packages)
overlays = [ ]

# Only servers need this — replaces hosts.nix entirely
[network]
internal-ip = "10.0.0.93"
external-ip = "144.24.253.246"
mac         = "02:00:17:00:a1:bb"

[network.dashboards.traefik]
enabled = true
url     = "traefik-ocr1.yohanzbinden.ch"

[network.dashboards.longhorn]
enabled = true
url     = "longhorn.yohanzbinden.ch"
```

Rules:
- **TOML holds data, `hardware.nix` holds expressions.** Filesystems, LUKS, nvidia
  config, kernel modules can't (and shouldn't) be TOML — each host keeps exactly one
  hand-written Nix file, auto-imported when present. `disks.nix` likewise.
- `builtins.fromTOML`/`readFile` on in-repo files is pure eval — no IFD, no impurity.

---

## 4. The machinery (`lib/hosts.nix`) — what it must do

1. **Discover**: `builtins.readDir ../hosts` → every dir with a `host.toml` is a host.
   Adding a host = `mkdir hosts/foo && $EDITOR hosts/foo/host.toml`. Nothing else.
2. **Validate loudly**: unknown role → eval error listing available roles (readDir on
   `nixos/roles/`); missing required keys → error naming the file and key. Good errors
   are what makes "unreadable machinery" livable.
3. **Resolve**:
   - `roles` → module paths; `desktop` → desktop role + home desktop dir
   - `packages` → `environment.systemPackages` via dotted-attr-path lookup in `pkgs`
   - `home-packages` → `home.packages`
   - `hardware` → entries from a small name→module map over `inputs.nixos-hardware.nixosModules`
   - `[network]` sections of **all** hosts aggregated → generates the
     `networking.yoyozbi.hosts` attrset so the existing k3s/ocr-cluster modules keep
     working with zero changes (the options module survives, only its *data* moves to TOML)
4. **Generate flake outputs**:
   - `nixosConfigurations` = every host with `nixos = true`
   - `homeConfigurations."<user>@<host>"` = every host (incl. `nixos = false` ones)
   - cachix-deploy `defaultPackage` spec = hosts with no `desktop`, grouped by platform
     (same behavior as today's `serverHosts` filter — agent names must not change)
5. `flake.nix` shrinks to: inputs + `import ./lib { … }` + output plumbing.

---

## 5. Migration phases

Each phase leaves the repo **fully building**. Verify with closure diffing (see §6).

### Phase 0 — Baseline snapshots (before touching anything)
- `nix build .#nixosConfigurations.<h>.config.system.build.toplevel -o /tmp/pre-<h>`
  for all 7 NixOS hosts (aarch64 ones eval-only if no builder: `nix eval --raw ...drvPath`)
- Same for the 5 home configs (`.activationPackage`)
- Commit nothing; these are the reference points.

### Phase 1 — Machinery, zero behavior change
- Write `lib/hosts.nix` (loader, validation, resolution) alongside the existing helpers.
- Create `hosts/` with all 9 `host.toml` files transcribing today's flake attrset +
  `hosts.nix` network data. Hardware files not moved yet.
- Add a temporary `checks.` output asserting the loader parses all 9 hosts.

### Phase 2 — Reorganize modules into roles (git mv, path fixes only)
- `git mv` every `_mixins` file to its `nixos/roles/…`, `nixos/users/…`, `home/…` home
  per the layout in §2. No content changes beyond relative-path fixes.
- **k3s secrets**: `nixos/_mixins/k3s/*.yml` moves too → update path patterns in
  `.sops.yaml` (keys unchanged, only paths — no `updatekeys` needed).
- Old `nixos/<host>/default.nix` files keep working during this phase by fixing their
  import paths (sed-able).

### Phase 3 — Cut hosts over to TOML, one at a time
Order: `vm-nix` (pilot — cheap to test, `build-home` exercises the embedded-HM path) →
`tiny1`/`tiny2` (simple servers) → `ocr1`, `rp` (k3s + network data) →
`laptop-nix`, `surface-nix` (desktop + hardware) → `wsl-nix`, `laptop-omarchy` (home-only).

Per host:
1. Split old `nixos/<host>/default.nix`: role imports → `roles = [...]` in TOML;
   everything else → `hosts/<host>/hardware.nix`.
2. Point the flake's generated config at the new path; delete `nixos/<host>/`.
3. Build and diff against the Phase 0 snapshot. Expected diff: **empty** (or only
   store-path noise from file moves).

### Phase 4 — Move network data, delete `hosts.nix`
- The options module from `hosts.nix` moves into `lib/` (or `nixos/core/`); its `config`
  section is replaced by the TOML aggregation from §4.3.
- Rebuild `ocr1`, `rp`, `tiny1/2` — the k3s modules read `networking.yoyozbi.*`
  unchanged, so closures must match.

### Phase 5 — Burn the scaffolding
- Delete `nixos/_mixins/`, `home-manager/_mixins/` (now empty), `hosts.nix`,
  `lib/helpers.nix`, host attrsets in `flake.nix`.
- Update `CLAUDE.md` (structure section + "how to add a host/role" recipe) and `README.md`.
- `nix fmt`, final full-matrix build, `nix flake check`.

---

## 6. Validation (every phase)

```bash
# Full eval of everything
nix flake check

# Per-host closure comparison against Phase 0 snapshot
nix build .#nixosConfigurations.vm-nix.config.system.build.toplevel -o /tmp/post-vm-nix
nix store diff-closures /tmp/pre-vm-nix /tmp/post-vm-nix   # want: empty / trivial

# Home configs
nix build .#homeConfigurations."yohan@laptop-nix".activationPackage

# Cachix-deploy spec still produces the same agent set
nix build .#defaultPackage.x86_64-linux   # compare agent names before/after

# Pilot host end-to-end
nix build .#nixosConfigurations.vm-nix.config.system.build.vm && run the VM
```

---

## 7. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Closure drift during migration (silent config loss) | Medium | Phase 0 snapshots + `nix store diff-closures` after every host cutover; one host per commit so `git bisect` works |
| TOML too weak for some current config (e.g. hyprland input's nixpkgs in laptop-nix) | High (known) | By design: anything expression-shaped stays in `hosts/<h>/hardware.nix`; TOML only selects |
| sops path breakage when k3s files move | Medium | `.sops.yaml` path-regex update in the same commit as the `git mv`; test with `sops -d` on one file |
| cachix-deploy agent names/spec change → CI deploy breaks | Low | Agent attr names derived from hostname exactly as today; compare `nix eval` of the spec before/after |
| `useGlobalPkgs = false` subtlety for `build-home` hosts lost in rewrite | Medium | Port the comment + behavior verbatim into `lib/hosts.nix`; vm-nix is the pilot precisely to test this path |
| aarch64 hosts (ocr1, rp) can't be built locally | Medium | Eval `drvPath` instead of building; laptop has `binfmt` aarch64 emulation if a real build is wanted |
| `stateVersion` mismatch surprises (global "25.05" vs nixpkgs 26.05) | Low | Per-host `state-version` in TOML transcribes today's value exactly — no behavior change, just made explicit |

---

## 8. What "day-to-day" looks like after

```bash
# Add a package to the laptop
$EDITOR hosts/laptop-nix/host.toml   # append to packages = [...]

# Give tiny2 docker
$EDITOR hosts/tiny2/host.toml        # roles += "docker"

# New machine
mkdir hosts/newbox && cp hosts/tiny1/host.toml hosts/newbox/  # edit, add hardware.nix
# → nixosConfigurations.newbox and yohan@newbox exist automatically
```

## Acceptance
- [ ] All 7 NixOS closures identical (or explained) vs Phase 0 snapshots
- [ ] All 5 home configs build
- [ ] cachix-deploy spec unchanged (same agents)
- [ ] `_mixins`, `hosts.nix`, flake host attrsets deleted
- [ ] `nix flake check` + `nix fmt` clean
- [ ] CLAUDE.md documents the TOML schema and add-a-host recipe
