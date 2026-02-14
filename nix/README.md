# Nix Configurations

This directory contains the NixOS flake and configurations for all managed machines.

## Structure

```
nix/
├── flake.nix           # Main flake with all host configs
├── flake.lock          # Locked dependency versions
├── hosts/              # Per-host configurations
│   ├── dns01/
│   │   └── configuration.nix
│   ├── docker01/
│   │   └── configuration.nix
│   └── test-vm/
│       └── configuration.nix
└── modules/            # Reusable modules
    ├── base.nix
    ├── networking-static.nix
    ├── docker-host.nix
    └── dns-unbound.nix
```

## Adding a New Host

1. Create host directory and configuration:
   ```bash
   mkdir -p hosts/my-host
   cp hosts/examples/basic/configuration.nix hosts/my-host/
   ```

2. Edit `hosts/my-host/configuration.nix` with host-specific settings

3. Add entry to `flake.nix`:
   ```nix
   nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
     system = "x86_64-linux";
     specialArgs = { inherit inputs; };
     modules = [
       ./hosts/my-host/configuration.nix
       ./modules/base.nix
       # Add other modules as needed
     ];
   };
   ```

4. Test locally:
   ```bash
   nix flake check
   nix build .#nixosConfigurations.my-host.config.system.build.toplevel
   ```

## VM Bootstrap Process

When a VM boots for the first time:

1. Crossplane injects cloud-init with flakeRef
2. VM runs `nixos-rebuild switch --flake <flakeRef>`
3. Configuration is applied locally
4. Optional: timer for periodic re-application

## Host Configuration Guidelines

Keep host configs minimal - most logic should be in modules:

```nix
{ config, pkgs, ... }:
{
  # Host-specific settings only
  networking.hostName = "dns01";
  networking.hostId = "12345678";  # For ZFS
  
  # Service-specific config
  services.unbound = {
    enable = true;
    # ...
  };
}
```

## Module Design

Modules should be:
- Reusable across hosts
- Well-documented with options
- Composable (one module = one responsibility)

Example module structure:
```nix
{ config, lib, pkgs, ... }:
with lib;
{
  options.fabric.docker-host = {
    enable = mkEnableOption "Docker host configuration";
  };

  config = mkIf config.fabric.docker-host.enable {
    # Docker host logic
  };
}
```

## Testing

### Local Testing
```bash
# Check flake
nix flake check

# Build specific host
nix build .#nixosConfigurations.dns01.config.system.build.toplevel

# Test in a VM
nixos-rebuild build-vm --flake .#dns01
```

### Updating Dependencies
```bash
# Update all inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs
```

## Rollback

NixOS generations are kept on each machine:

```bash
# List generations
nixos-rebuild list-generations

# Rollback to previous
nixos-rebuild switch --rollback

# Boot into specific generation
nixos-rebuild switch --switch-generation 42
```

## Secrets Management

Avoid storing secrets in Git. Use:

1. **MVP**: No secrets - start with public services
2. **Production**: Vault integration
   - VM authenticates to Vault
   - Secrets fetched at runtime
   - See `modules/vault-agent.nix` (when implemented)
