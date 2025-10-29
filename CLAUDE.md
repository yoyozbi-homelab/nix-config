# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal NixOS configuration repository that manages both servers and desktop systems using Nix flakes. The configuration includes multiple hosts (servers and desktops) with automated deployment via GitHub Actions and Cachix.

## Architecture

### Host Configuration Structure
- **NixOS hosts**: Managed via `nixosConfigurations` in `flake.nix`
- **Home Manager configs**: Separate home configurations for user environments
- **Modular design**: Uses mixins pattern for reusable configuration components

### Key Architecture Components

1. **Helper Library** (`lib/helpers.nix`):
   - `mkHome`: Generates home-manager configurations
   - `mkHost`: Generates NixOS host configurations
   - Supports parameters: hostname, username, desktop environment, platform

2. **Host Network Configuration** (`hosts.nix`):
   - Centralized network configuration for all hosts
   - Defines internal/external IPs, MACs, and service dashboards
   - Includes K3s cluster configuration with Traefik, Longhorn, ArgoCD, Portainer

3. **Mixins Pattern**:
   - `nixos/_mixins/`: Reusable NixOS modules (desktop, hardware, services, users)
   - `home-manager/_mixins/`: Reusable home-manager modules (console, desktop, dotfiles)

### Host Types
- **Desktop hosts**: `laptop-nix` (KDE), `surface-nix` (GNOME)
- **Server hosts**: `ocr1` (K3s master), `tiny1`/`tiny2` (K3s agents), `rp` (RPi4 K3s)

## Common Development Commands

### Building and Testing
```bash
# Build specific host configuration
nixos-rebuild build --flake .#hostname

# Build and switch (requires root)
sudo nixos-rebuild switch --flake .#hostname

# Build home-manager configuration
home-manager switch --flake .#username@hostname

# Format Nix code
nix fmt

# Update flake inputs
nix flake update
```

### Remote Deployment
```bash
# Deploy to remote host using nixos-rebuild
nixos-rebuild --target-host root@hostname --flake .#hostname switch

# Deploy using deploy-rs
nix run github:serokell/deploy-rs -- .#hostname
```

### Secret Management (SOPS)
```bash
# Edit encrypted secrets
nix-shell -p sops --run "sops secrets.yml"

# Update keys for existing secrets after adding new hosts
nix-shell -p sops --run "sops updatekeys nixos/_mixins/k3s/ocr-secrets.yml"

# Get age key from SSH host key
nix-shell -p ssh-to-age --run 'ssh-keyscan <hostname> | ssh-to-age'
```

### Server-Specific Commands
```bash
# Build SD card image for Raspberry Pi
nix run nixpkgs#nixos-generators -- -f sd-aarch64 --flake .#rp --system aarch64-linux -o ../pi.sd

# Reset K3s node (on server)
./nixos/_mixins/k3s/k3s-reset-node
```

## File Structure Conventions

- Host-specific configs: `nixos/hostname/` and `home-manager/_mixins/users/username/hosts/hostname.nix`
- Shared mixins: `nixos/_mixins/` and `home-manager/_mixins/`
- Custom packages: `pkgs/`
- Secrets: Encrypted with SOPS, keys defined in `.sops.yaml`

## Development Notes

- State version is centrally managed in `flake.nix` (currently "25.05")
- Uses unstable Nix package for latest features
- Cachix deployment configured for automated updates
- All unfree packages allowed in nixpkgs config
- Custom overlays defined in `overlays/`