# Bootstrap Process

This directory contains templates and documentation for bootstrapping Fabric-managed VMs.

## Overview

When Crossplane provisions a VM, it injects a cloud-init configuration that:

1. Creates the admin user with SSH access
2. Sets the hostname
3. Writes the flake reference to `/etc/nix-flake-target`
4. Creates and enables a one-shot systemd service to pull and apply the Nix configuration
5. The VM converges to its desired state by pulling from Git

## Cloud-Init Template

The `cloud-init-template.yaml` contains placeholders that your Crossplane Composition should substitute:

| Placeholder | Description | Example |
|------------|-------------|---------|
| `${HOSTNAME}` | VM hostname | `dns01` |
| `${DOMAIN}` | Domain name | `homelab.local` |
| `${ADMIN_USER}` | Admin username | `admin` |
| `${SSH_AUTHORIZED_KEYS}` | SSH public keys (YAML list) | See below |
| `${FLAKE_REF}` | Git flake reference | `git+https://github.com/org/fabric#dns01` |
| `${NETWORK_INTERFACE}` | Network interface | `ens18` |
| `${STATIC_IP}` | Static IP address | `10.0.1.10` |
| `${CIDR}` | Network prefix length | `24` |
| `${GATEWAY}` | Default gateway | `10.0.1.1` |
| `${DNS_SERVERS}` | DNS servers (YAML list) | See below |

### SSH Keys Format

The `${SSH_AUTHORIZED_KEYS}` should be replaced with a YAML list:

```yaml
- ssh-ed25519 AAAAC3... user@host
- ssh-rsa AAAAB3... other@host
```

### DNS Servers Format

The `${DNS_SERVERS}` should be replaced with a YAML list:

```yaml
- 10.0.1.10
- 1.1.1.1
```

## Crossplane Composition Example

Your Composition should template the cloud-init data:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xmachine.infra.kubelize.io
spec:
  # ... other fields ...
  resources:
    - name: vm
      base:
        apiVersion: compute.proxmox.io/v1alpha1
        kind: VirtualMachine
        spec:
          # ... VM specs ...
          cloudInit:
            userData: |
              #cloud-config
              hostname: PLACEHOLDER
              # ... rest of templated cloud-init ...
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.hostname
          toFieldPath: spec.cloudInit.userData
          transforms:
            - type: string
              string:
                type: Format
                fmt: |
                  #cloud-config
                  hostname: %s
                  # ... full cloud-init template with dynamic values ...
```

## Alternative: Using a ConfigMap

Instead of inline templating in the Composition, you can:

1. Store the cloud-init template in a ConfigMap
2. Reference it in your Composition
3. Use Crossplane's patching to inject values

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nixos-bootstrap-template
  namespace: crossplane-system
data:
  user-data: |
    # Contents of cloud-init-template.yaml
```

## Bootstrap Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. User creates Machine claim with flakeRef                 │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Crossplane Composition templates cloud-init              │
│    - Injects hostname, SSH keys, flakeRef, network config   │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Proxmox provider creates VM from NixOS template          │
│    - Applies cloud-init on first boot                       │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. VM boots and cloud-init runs                             │
│    - Creates admin user                                     │
│    - Sets hostname                                          │
│    - Writes /etc/nix-flake-target                          │
│    - Enables nixos-bootstrap.service                        │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. nixos-bootstrap.service runs                             │
│    - Reads flakeRef from /etc/nix-flake-target             │
│    - Runs: nixos-rebuild switch --flake <ref>              │
│    - Marks bootstrap as complete                            │
│    - Disables itself                                        │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. NixOS configuration applied                              │
│    - VM now matches desired state from Git                  │
│    - GitOps agent can handle future updates (if enabled)    │
└─────────────────────────────────────────────────────────────┘
```

## Testing Bootstrap Locally

### Option 1: Test with a Local NixOS VM

```bash
# Build a VM from your flake
cd nix/
nixos-rebuild build-vm --flake .#test-vm

# Run the VM
./result/bin/run-test-vm-vm
```

### Option 2: Test cloud-init templating

```bash
# Install cloud-init utilities
nix-shell -p cloud-utils

# Validate cloud-init syntax
cloud-init schema --config-file bootstrap/cloud-init-template.yaml
```

### Option 3: Test bootstrap script manually

```bash
# SSH into an existing NixOS machine
ssh admin@test-vm

# Manually write flakeRef
echo "git+https://github.com/kubelize/fabric#test-vm" | sudo tee /etc/nix-flake-target

# Run bootstrap manually
sudo nixos-rebuild switch --flake "$(cat /etc/nix-flake-target)"
```

## Troubleshooting

### Check bootstrap service status
```bash
systemctl status nixos-bootstrap.service
journalctl -u nixos-bootstrap.service -f
```

### Check cloud-init logs
```bash
cat /var/log/cloud-init.log
cat /var/log/cloud-init-output.log
```

### Verify flake reference
```bash
cat /etc/nix-flake-target
```

### Test Git connectivity
```bash
git ls-remote $(cat /etc/nix-flake-target | cut -d'#' -f1)
```

### Re-run bootstrap manually
```bash
sudo systemctl restart nixos-bootstrap.service
```

## Security Considerations

1. **SSH Keys**: Stored in Machine claims - consider using Kubernetes Secrets
2. **Git Access**: VMs need network access to Git repo (public or with credentials)
3. **Bootstrap Script**: Runs as root - ensure cloud-init template is trusted
4. **Network**: VM needs internet access during bootstrap (can be restricted after)

## Proxmox Template Requirements

Your NixOS template VM should have:

1. ✅ cloud-init installed and enabled
2. ✅ QEMU guest agent installed
3. ✅ SSH server enabled
4. ✅ Network configured (will be overridden by cloud-init/Nix config)
5. ✅ Nix with flakes enabled
6. ✅ Git installed

### Creating the Template

```bash
# On Proxmox host
# 1. Create base NixOS VM (manual or with Packer)
# 2. Install cloud-init
qm set <vmid> --ciuser admin --sshkey ~/.ssh/authorized_keys
# 3. Convert to template
qm template <vmid>
```

See `proxmox/template/` directory for automated template creation (TODO).
