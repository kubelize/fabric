# Machine Claims

This directory contains Machine resources that Crossplane will reconcile into actual VMs on Proxmox.

## Structure

- `examples/` - Template Machine claims for common use cases
- `*.yaml` - Active Machine claims (GitOps-managed)

## Creating a New Machine

1. Copy an example that matches your use case:
   ```bash
   cp examples/basic.yaml my-machine.yaml
   ```

2. Edit the spec:
   - Set `metadata.name` and `spec.hostname`
   - Configure networking (static IP or DHCP)
   - Update `spec.nix.flakeRef` to point to the correct host config
   - Add your SSH keys to `spec.bootstrap.sshAuthorizedKeys`

3. Create matching Nix config in `../../nix/hosts/<name>/`

4. Commit both files and let GitOps apply

## Resource Configuration

Configure CPU, memory, and disk explicitly in your Machine spec:

```yaml
spec:
  cpu:
    cores: 4        # 1-128 cores
    sockets: 1      # optional, defaults to 1
  memory:
    size: 8192      # Memory in MB
  disk:
    size: 100       # Disk size in GB (optional, defaults to 32GB)
```

Example configurations:
- **Lightweight**: 1 core, 1024MB (1GB), 20GB disk
- **Standard**: 2 cores, 4096MB (4GB), 50GB disk
- **Application**: 4 cores, 8192MB (8GB), 100GB disk

## Network Configuration

### Static IP
```yaml
network:
  ip: 10.0.1.10
  cidr: 24
  gateway: 10.0.1.1
  dns:
    - 10.0.1.10
    - 1.1.1.1
```

### DHCP
```yaml
network:
  dhcp: true
```

## FlakeRef Format

The `nix.flakeRef` should point to this repo and the specific host output:

```yaml
nix:
  flakeRef: git+https://github.com/kubelize/fabric?ref=main#hostname
```

For local testing:
```yaml
nix:
  flakeRef: git+file:///path/to/fabric#hostname
```

## Labels

Use labels for grouping and selection:

```yaml
labels:
  role: dns|docker-host|k8s-node|monitoring
  tier: core|compute|edge|dev
  environment: production|staging|development
```
