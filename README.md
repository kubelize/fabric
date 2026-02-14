# Fabric - GitOps Infrastructure

GitOps-managed NixOS machines on Proxmox with Crossplane.

## Architecture

- **Crossplane**: Provisions VMs on Proxmox using provider-terraform
- **This repo**: Source of truth for Machine claims and NixOS configurations
- **NixOS VMs**: Pull configuration from Fabric flake (future: automatic bootstrap)

## Repository Structure

```
.
├── crossplane/
│   ├── package/             # Crossplane package (XRD + Composition)
│   │   ├── xrd.yaml         # Machine API definition
│   │   ├── composition.yaml # Terraform-based Proxmox provisioning
│   │   └── crossplane.yaml  # Package metadata
│   ├── config/              # Provider configs and secrets
│   │   ├── providerconfig-terraform.yaml
│   │   └── proxmox-terraform-secret.yaml
│   └── claims/              # Machine CRs (what VMs to provision)
│       └── examples/
├── bootstrap/               # Cloud-init templates (future enhancement)
│   ├── README.md
│   └── cloud-init-template.yaml
├── docs/
│   ├── CREATE-TEMPLATE.md   # Guide for creating NixOS template
│   └── nixos-template-config.nix
├── nix/                     # NixOS configurations (coming soon)
└── TODO.md                  # Current status and roadmap
```

## Current Status

**Working:**
- Crossplane v2.0.0 with Pipeline mode compositions
- provider-terraform v0.15.0 deployed
- Machine XRD with explicit CPU/memory/disk fields
- Composition using Terraform Workspace with bpg/proxmox provider
- Secret management via environment variables

**In Progress:**
- Creating NixOS Proxmox template (see [docs/CREATE-TEMPLATE.md](docs/CREATE-TEMPLATE.md))
- Proxmox API token permissions (requires `VM.Clone` permission)

**Planned:**
- Cloud-init integration for automatic VM bootstrap
- NixOS flake configurations
- GitOps automation (ArgoCD/Flux)

See [TODO.md](TODO.md) for detailed roadmap.

## Getting Started

### Prerequisites

- Kubernetes cluster with Crossplane installed
- Proxmox VE cluster
- Proxmox API token with appropriate permissions

### 1. Install Crossplane Providers

```bash
# Install provider-terraform and functions
kubectl apply -f bootstrap/crossplane-providers.yaml

# Wait for providers to be healthy
kubectl get providers
```

### 2. Create NixOS Template

Follow the guide: **[docs/CREATE-TEMPLATE.md](docs/CREATE-TEMPLATE.md)**

This creates a NixOS template VM (ID 9000) with:
- QEMU guest agent
- Cloud-init support
- SSH access
- Nix flakes enabled

**Important:** Template must exist on each Proxmox node (for local storage) or use shared storage.

### 3. Configure Proxmox Credentials

```bash
# Edit the secret with your Proxmox credentials
nano crossplane/config/proxmox-terraform-secret.yaml

# Apply the secret
kubectl apply -f crossplane/config/proxmox-terraform-secret.yaml

# Apply ProviderConfig
kubectl apply -f crossplane/config/providerconfig-terraform.yaml
```

**Secret format:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: proxmox-terraform-creds
  namespace: crossplane-system
type: Opaque
stringData:
  api_url: "https://10.130.5.10:8006/api2/json"
  token_id: "root@pam!fabric"
  token_secret: "your-token-secret-here"
```

### 4. Grant Proxmox Permissions

```bash
# On Proxmox host, grant VM.Clone permission to your token
pveum aclmod / -token 'root@pam!fabric' -role PVEAdmin
```

### 5. Install Machine API

```bash
# Build and install the Crossplane package
make build
make install

# Or use ArgoCD/Flux to deploy crossplane/package/
```

### 6. Create Your First VM

```bash
# Copy the example claim
cp crossplane/claims/examples/basic.yaml crossplane/claims/my-vm.yaml

# Edit the claim
nano crossplane/claims/my-vm.yaml

# Apply
kubectl apply -f crossplane/claims/my-vm.yaml

# Watch for provisioning
kubectl get machines -n infra-machines -w
```

## How It Works

1. **Create a Machine claim** in `crossplane/claims/` with desired specs (CPU, memory, disk, etc.)
2. **Crossplane** picks up the claim and creates a Terraform Workspace resource
3. **provider-terraform** executes Terraform with the bpg/proxmox provider
4. **Proxmox** clones the template VM and provisions with specified resources
5. **VM boots** and is ready for configuration (manual or via cloud-init in future)

## Machine API

The Machine XRD provides a declarative API for VMs:

```yaml
apiVersion: fabric.kubelize.io/v1alpha1
kind: Machine
metadata:
  name: test-vm
  namespace: infra-machines
spec:
  cpu:
    cores: 2
  memory:
    size: 2048  # MB
  disk:
    size: 32    # GB
  proxmox:
    node: "pve"
    storage: "local-zfs"
    bridge: "vmbr0"
    templateId: 9000
```

## Provider Details

**Provider:** [provider-terraform v0.15.0](https://marketplace.upbound.io/providers/upbound/provider-terraform/v0.15.0)

**Terraform Provider:** [bpg/proxmox ~> 0.50](https://registry.terraform.io/providers/bpg/proxmox/latest)

**Why this approach?**
- Native provider-proxmox-bpg has critical bugs in v1.3.0
- Terraform provider approach is more stable and well-maintained
- Provides access to full Terraform ecosystem

## Development

```bash
# Build the Crossplane package
make build

# Install to cluster
make install

# Validate changes
kubectl get xrd
kubectl get compositions
```

## Troubleshooting

**VM creation fails with HTTP 403:**
- Grant proper permissions to your Proxmox API token (see step 4 above)

**Template not found:**
- Ensure template VM ID 9000 exists on the target Proxmox node
- For local storage, template must exist on each node

**Workspace stays in Creating:**
- Check provider-terraform pod logs: `kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-terraform`
- Check Workspace status: `kubectl describe workspace <name>`

See [TODO.md](TODO.md) for known issues and next steps.

## Future Enhancements

- **Cloud-init integration**: Automatic VM bootstrap from Git (templates in `bootstrap/`)
- **NixOS flake configs**: Declarative VM configurations in `nix/`
- **GitOps**: Full ArgoCD/Flux integration
- **Networking**: Advanced network configuration, VLANs, static IPs
- **Storage**: Multiple disks, custom sizing
- **Monitoring**: Prometheus integration

## Contributing

1. Follow the template creation guide
2. Test VM provisioning
3. Document any issues in TODO.md
4. Submit improvements via PR

## License

Apache 2.0
