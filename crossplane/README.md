# Crossplane Resources

This directory contains Machine claims and reference resources for Crossplane-managed VMs.

## Directory Structure

```
crossplane/
├── package/         # Crossplane package (XRD, Composition, metadata)
│   ├── crossplane.yaml  # Package definition
│   ├── xrd.yaml        # Machine API definition
│   └── composition.yaml # Proxmox VM provisioning
├── claims/          # Machine CRs - actual VM instances to provision
│   ├── examples/   # Example Machine claims
│   └── *.yaml      # Active claims (applied via GitOps)
└── config/          # Provider configs and other cluster resources
```

## Quick Start

### 1. Install the Machine API Package

The complete Crossplane package is in the `package/` directory:

```bash
# Option A: Apply directly (development/testing)
kubectl apply -f package/xrd.yaml
kubectl apply -f package/composition.yaml

# Option B: Build and install as package
cd package/
kubectl crossplane build configuration
kubectl crossplane push configuration <registry>/fabric-machine-api:v0.1.0

# Then install
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: fabric-machine-api
spec:
  package: <registry>/fabric-machine-api:v0.1.0
EOF

# See package/README.md for detailed setup instructions
```

### 2. Create a Machine

```bash
# Copy an example
cp claims/examples/basic.yaml claims/my-vm.yaml

# Edit the spec
vim claims/my-vm.yaml

# Don't forget to create the matching Nix config!
mkdir -p ../nix/hosts/my-vm
cp ../nix/hosts/examples/basic/configuration.nix ../nix/hosts/my-vm/

# Edit Nix config
vim ../nix/hosts/my-vm/configuration.nix

# Update flake.nix to include the new host
vim ../nix/flake.nix
```

### 3. Apply via GitOps

```bash
# Commit both the Machine claim and Nix config
git add claims/my-vm.yaml nix/hosts/my-vm/ nix/flake.nix
git commit -m "Add my-vm"
git push

# Your GitOps controller (Argo CD / Flux) will:
# 1. Apply the Machine claim
# 2. Crossplane provisions the VM
# 3. VM boots and pulls its Nix config
```

## Manual Testing (Without GitOps)

If you want to test without GitOps:

```bash
# Apply Machine claim directly
kubectl apply -f claims/my-vm.yaml

# Watch it get provisioned
kubectl get machines -n infra-machines -w

# Check the VM details
kubectl describe machine my-vm -n infra-machines
```

## Updating a Machine

### Changing VM Resources
To change CPU, RAM, or disk (requires VM recreate in most cases):
1. Edit the Machine claim
2. Crossplane will reconcile (behavior depends on provider)

### Changing Configuration
To change OS/service configuration:
1. Edit the Nix config in `../nix/hosts/<name>/`
2. Commit and push
3. VM will pull changes via GitOps agent (if enabled)
4. OR SSH in and run: `nixos-rebuild switch --flake <flakeRef>`

## Deleting a Machine

```bash
# Option 1: Delete the claim file and commit (GitOps)
git rm claims/my-vm.yaml
git commit -m "Delete my-vm"
git push

# Option 2: Delete directly
kubectl delete machine my-vm -n infra-machines

# The VM will be destroyed by Crossplane
# The Nix config remains in Git for potential rebuild
```

## Troubleshooting

### Machine stuck in Pending
```bash
kubectl describe machine <name> -n infra-machines
kubectl get events -n infra-machines --sort-by='.lastTimestamp'
```

Check:
- Is the XRD installed? `kubectl get xrd`
- Is the Composition installed? `kubectl get composition`
- Are there Crossplane errors? `kubectl logs -n crossplane-system -l app=crossplane`

### VM created but not converging
```bash
# SSH into the VM
ssh admin@<vm-ip>

# Check bootstrap service
sudo systemctl status nixos-bootstrap.service
sudo journalctl -u nixos-bootstrap.service -f

# Check cloud-init
cat /var/log/cloud-init.log
```

### VM has wrong configuration
```bash
# Check flake reference
ssh admin@<vm-ip> cat /etc/nix-flake-target

# Manually trigger rebuild
ssh admin@<vm-ip> sudo nixos-rebuild switch --flake "$(cat /etc/nix-flake-target)"
```

## Machine Claim Reference

See [claims/README.md](claims/README.md) for detailed documentation on:
- Machine spec fields
- VM sizing classes
- Network configuration
- FlakeRef format
- Labels and tags

## See Also

- [package/README.md](package/README.md) - Complete package setup and customization
- [../nix/README.md](../nix/README.md) - Nix configuration guide
- [../bootstrap/README.md](../bootstrap/README.md) - Bootstrap process details
- [claims/README.md](claims/README.md) - Machine claim documentation
