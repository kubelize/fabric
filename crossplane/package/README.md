# Machine API Package

This directory contains the complete Crossplane package definition for the Machine API.

## Contents

- `crossplane.yaml` - Package metadata and dependencies
- `xrd.yaml` - XMachine CompositeResourceDefinition
- `composition.yaml` - Composition for provisioning VMs on Proxmox

## Package Structure

This is a standard Crossplane Configuration package that can be:
1. Used directly from this repo during development
2. Built and published to a package registry
3. Moved to a dedicated Crossplane packages repository

## Installation Options

### Option 1: Apply Directly (Development)

```bash
# Apply the package resources directly
kubectl apply -f crossplane/package/xrd.yaml
kubectl apply -f crossplane/package/composition.yaml
```

### Option 2: Build and Install as Package

```bash
# Build the package
cd crossplane/package
kubectl crossplane build configuration

# Push to registry
kubectl crossplane push configuration <registry>/fabric-machine-api:v0.1.0

# Install in cluster
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: fabric-machine-api
spec:
  package: <registry>/fabric-machine-api:v0.1.0
EOF
```

### Option 3: Install from Git (Development)

If you have the right tooling:

```bash
kubectl crossplane install configuration \
  --name fabric-machine-api \
  --source git \
  --git-ref main \
  --git-url https://github.com/kubelize/fabric
```

## Provider

This package uses **[provider-proxmox-bpg](https://marketplace.upbound.io/providers/valkiriaaquaticamendi/provider-proxmox-bpg/v1.3.0)** - a native Crossplane provider that wraps the [bpg/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox) Terraform provider.

**Why this provider:**
- Native Crossplane integration (no need for provider-terraform)
- Based on the mature and actively maintained bpg Proxmox provider
- Auto-syncs with upstream provider releases
- Full Crossplane v2.0+ compatibility
- 63 managed resources covering VMs, containers, storage, networking, etc.

### Provider Setup

1. **Install provider:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-proxmox-bpg
spec:
  package: xpkg.upbound.io/valkiriaaquaticamendi/provider-proxmox-bpg:v1.3.0
EOF
```

### 1. Update Provider References

Edit `composition.yaml` to match your Proxmox provider:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
spec:
  resources:
    - name: virtualmachine
      base:
        # Change this to match your actual provider
        apiVersion: compute.proxmox.io/v1alpha1
        kind: VirtualMachine
```

**Available Providers:**

- **Terraform**: `tf.upbound.io/v1beta1.Workspace` (see Terraform composition in file)
- **Native Proxmox**: `compute.proxmox.io/v1alpha1.VirtualMachine` (if available)
- **Custom**: Your own provider's API

### 2. Update Dependencies

Edit `crossplane.yaml` to declare your provider dependency:

```yaml
spec:
  dependsOn:
    - provider: xpkg.upbound.io/upbound/provider-terraform
      version: ">=v0.13.0"
```

### 3. Customize VM Classes

Edit the Composition patches to adjust sizing classes:

```yaml
# In composition.yaml
transforms:
  - type: map
    map:
      small: "2"    # 2 CPU
      medium: "8"   # Change to 6 CPU
      large: "16"   # Change to 12 CPU
```

### 4. Cloud-Init Integration

The trickiest part is integrating the cloud-init template from `../../bootstrap/cloud-init-template.yaml`.

**Method 1: Inline in Composition** (simple, but verbose)
- Paste the cloud-init template into the Composition
- Use string transforms to inject values

**Method 2: ConfigMap Reference** (cleaner)
```bash
# Create ConfigMap with cloud-init template
kubectl create configmap nixos-bootstrap-template \
  --from-file=user-data=bootstrap/cloud-init-template.yaml \
  --namespace crossplane-system
```

Then reference in Composition using function-go-templating or similar.

**Method 3: Proxmox Snippets**
- Store cloud-init as snippet file on Proxmox
- Reference in VM: `cicustom: "user=local:snippets/nixos-bootstrap.yaml"`

See [../../bootstrap/README.md](../../bootstrap/README.md) for full documentation.

## Provider Setup

### Terraform Provider (Recommended for Starting)

1. **Install provider:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-terraform
spec:
  package: xpkg.upbound.io/upbound/provider-terraform:v0.13.0
EOF
```

2. **Create credentials secret:**
```bash
kubectl create secret generic proxmox-creds \
  --namespace crossplane-system \
  --from-literal=credentials='{"pm_api_url":"https://proxmox:8006/api2/json","pm_api_token_id":"user@pve!token","pm_api_token_secret":"secret"}'
```

3. **Create ProviderConfig:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: tf.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: proxmox-creds
      key: credentials
EOF
```

### Native Proxmox Provider (When Available)

```bash
# Check marketplace for available providers
kubectl crossplane install provider <provider-name>

# Configure with Proxmox credentials
```

## Testing the Package

### 1. Validate Resources

```bash
# Validate XRD
kubectl apply --dry-run=server -f xrd.yaml

# Validate Composition
kubectl apply --dry-run=server -f composition.yaml
```

### 2. Install Package

```bash
# Apply directly for testing
kubectl apply -f xrd.yaml
kubectl apply -f composition.yaml

# Verify XRD is installed
kubectl get xrd xmachines.infra.kubelize.io
kubectl get compositeresourcedefinitions

# Verify Composition is installed
kubectl get composition
```

### 3. Create Test Machine

```bash
# Create namespace
kubectl create namespace infra-machines

# Apply a test claim
kubectl apply -f ../claims/examples/basic.yaml

# Watch it provision
kubectl get machines -n infra-machines -w

# Check details
kubectl describe machine test-vm -n infra-machines
```

### 4. Verify Composed Resources

```bash
# List all managed resources
kubectl get managed

# Check the specific VM resource (name depends on provider)
kubectl get virtualmachines
# or
kubectl get workspaces  # if using Terraform provider
```

## Debugging

### XRD Issues

```bash
# Check if XRD is installed
kubectl get xrd

# Check XRD status
kubectl describe xrd xmachines.infra.kubelize.io

# View XRD definition
kubectl get xrd xmachines.infra.kubelize.io -o yaml
```

### Composition Issues

```bash
# List Compositions
kubectl get composition

# Check Composition details
kubectl describe composition xmachine.infra.kubelize.io

# View Composition definition
kubectl get composition xmachine.infra.kubelize.io -o yaml
```

### Claim Issues

```bash
# Check claim status
kubectl get machine <name> -n infra-machines -o yaml

# Look for conditions
kubectl get machine <name> -n infra-machines -o jsonpath='{.status.conditions}'

# Check events
kubectl get events -n infra-machines --sort-by='.lastTimestamp'
```

### Crossplane Logs

```bash
# View Crossplane controller logs
kubectl logs -n crossplane-system -l app=crossplane -f

# View provider logs (Terraform provider example)
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-terraform -f
```

## Upgrading the Package

When making changes to the XRD or Composition:

1. **Test changes locally first:**
   ```bash
   kubectl apply -f xrd.yaml
   kubectl apply -f composition.yaml
   ```

2. **Version the package:**
   - Update version in `crossplane.yaml` annotations
   - Tag the Git repo: `git tag v0.2.0`

3. **Build and push:**
   ```bash
   kubectl crossplane build configuration
   kubectl crossplane push configuration <registry>/fabric-machine-api:v0.2.0
   ```

4. **Upgrade in cluster:**
   ```bash
   # If using Configuration package
   kubectl edit configuration fabric-machine-api
   # Update spec.package to new version
   ```

## Moving to Dedicated Repo

When ready to move this to your Crossplane packages repo:

```bash
# Copy the entire package directory
cp -r crossplane/package /path/to/crossplane-packages/fabric-machine-api/

# Update paths in documentation
# Update Git URLs in examples
# Add to your packages repo CI/CD pipeline
```

Your packages repo structure might look like:
```
crossplane-packages/
├── fabric-machine-api/
│   ├── crossplane.yaml
│   ├── xrd.yaml
│   └── composition.yaml
├── other-api/
└── ...
```

## API Reference

### Machine.spec Fields

See the XRD for complete schema. Key fields:

- `cpu.cores`: Number of CPU cores
- `memory.size`: Memory in MB
- `disk.size`: Disk size in GB (optional, defaults to 32GB)
- `hostname`: VM hostname
- `network`: Network configuration (DHCP or static)
- `proxmox`: Proxmox-specific settings
- `image`: NixOS template name
- `nix.flakeRef`: Git flake reference for configuration
- `bootstrap`: Admin user and SSH keys
- `tags`: Arbitrary metadata

### Example

```yaml
apiVersion: infra.kubelize.io/v1alpha1
kind: Machine
metadata:
  name: dns01
  namespace: infra-machines
spec:
  class: small
  hostname: dns01
  network:
    ip: 10.0.1.10
    cidr: 24
    gateway: 10.0.1.1
  proxmox:
    storage: local-zfs
    bridge: vmbr0
  image: nixos-23-11-template
  nix:
    flakeRef: git+https://github.com/org/fabric?ref=main#dns01
  bootstrap:
    adminUser: admin
    sshAuthorizedKeys:
      - ssh-ed25519 AAAAC3...
```

## Contributing

When modifying the API:

1. Update XRD schema if adding/changing fields
2. Update Composition patches to handle new fields
3. Update examples in `../claims/examples/`
4. Test thoroughly before committing
5. Update version in crossplane.yaml

## Further Reading

- [Crossplane Compositions](https://docs.crossplane.io/latest/concepts/compositions/)
- [Crossplane Packages](https://docs.crossplane.io/latest/concepts/packages/)
- [Provider Development](https://docs.crossplane.io/latest/contributing/provider-development-guide/)
