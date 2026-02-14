# Fabric - GitOps Infrastructure

GitOps-managed NixOS machines on Proxmox with Crossplane.

## Architecture

- **Crossplane**: Provisions VMs on Proxmox (XRD/Compositions in separate package repo)
- **This repo**: Source of truth for Machine claims and Nix configurations
- **NixOS VMs**: Self-manage by pulling flake configs from this repo

## Repository Structure

```
.
├── crossplane/
│   ├── package/             # Crossplane package (XRD + Composition)
│   ├── config/              # Provider configs and cluster resources
│   └── claims/              # Machine CRs (what VMs to provision)
├── nix/
│   ├── flake.nix           # Main flake definition
│   ├── flake.lock          # Locked dependencies
│   ├── hosts/              # Per-host configurations
│   │   ├── dns01/
│   │   └── docker01/
│   └── modules/            # Reusable Nix modules
│       ├── base.nix
│       ├── networking-static.nix
│       ├── docker-host.nix
│       └── dns-unbound.nix
├── bootstrap/               # VM bootstrap templates
└── plan.md                 # Architecture documentation
```

## How It Works

1. Create a `Machine` claim in `crossplane/claims/`
2. Create matching Nix config in `nix/hosts/<name>/`
3. Commit → GitOps controller applies
4. Crossplane provisions VM on Proxmox
5. VM boots and pulls its flake config from this repo
6. NixOS applies configuration locally

## Getting Started

### Ready to Deploy?

**👉 Start here: [READY.md](READY.md)** - Deployment readiness summary

Then follow:
1. **[CHECKLIST.md](CHECKLIST.md)** - Pre-deployment checklist
2. **[DEPLOY.md](DEPLOY.md)** - Detailed deployment guide
3. **[GETTING_STARTED.md](GETTING_STARTED.md)** - Complete setup instructions

### Quick Test Deployment

```bash
# 1. Validate everything is ready
./scripts/validate.sh

# 2. Deploy test VM
./scripts/deploy-test.sh

# 3. Monitor
kubectl get machines -n infra-machines -w
```

### Quick Setup

```bash
# 1. Run automated setup (installs Crossplane, provider-terraform, Machine API)
./scripts/setup.sh

# 2. Configure Proxmox credentials (see crossplane/config/README.md)
kubectl create secret generic proxmox-creds \
  --namespace crossplane-system \
  --from-literal=credentials='{"endpoint":"https://proxmox:8006","api_token":"root@pam!token=xxx","insecure":true}'

kubectl apply -f crossplane/config/providerconfig-proxmox.yaml

# 3. Create your first VM
make new-host HOST=myvm IP=10.0.1.50
# Edit generated files, commit, and apply
```

**Provider:** Uses [provider-terraform](https://marketplace.upbound.io/providers/upbound/provider-terraform/v0.15.0) with the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) Terraform provider to manage Proxmox VMs.

### Manual Setup

See [GETTING_STARTED.md](GETTING_STARTED.md) for comprehensive step-by-step instructions.

See [plan.md](plan.md) for detailed architecture and milestones.

### Prerequisites

- Crossplane installed with Proxmox provider
- NixOS template VM in Proxmox
- GitOps controller (Argo CD or Flux)

### Create Your First Machine

1. Add a Machine claim:
```bash
cp crossplane/claims/examples/basic.yaml crossplane/claims/my-vm.yaml
# Edit as needed
```

2. Add corresponding Nix config:
```bash
mkdir -p nix/hosts/my-vm
cp nix/hosts/examples/basic/configuration.nix nix/hosts/my-vm/
# Edit as needed
```

3. Commit and push - GitOps will handle the rest!
