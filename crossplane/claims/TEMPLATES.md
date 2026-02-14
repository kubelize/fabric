# Important: Template Configuration

## Template ID Mapping

The provider-proxmox-bpg composition requires **VM IDs** (integers) for templates, not names.

You need to update the `composition.yaml` with your actual template IDs:

```yaml
# In crossplane/package/composition.yaml
# Find this section and update it:
- type: FromCompositeFieldPath
  fromFieldPath: spec.image
  toFieldPath: spec.forProvider.clone.vmId
  transforms:
    - type: map
      map:
        nixos-23-11-template: "9000"  # ← Change to your actual template VM ID
        nixos-24-05-template: "9001"  # ← Add your templates here
```

## Finding Your Template VM IDs

### Method 1: Proxmox Web UI
1. Navigate to your template VM in the Proxmox web interface
2. Look at the URL or the VM name - the number in parentheses is the VM ID
3. Example: `nixos-template (9000)` means VM ID is `9000`

### Method 2: Proxmox CLI
```bash
# SSH into your Proxmox host
ssh root@proxmox-host

# List all VMs and templates
qm list

# Look for templates (marked with 'T' in the STATUS column)
# The first column is the VM ID
```

### Method 3: Proxmox API
```bash
# Query the API
curl -k -H "Authorization: PVEAPIToken=USER@REALM!TOKENID=SECRET" \
  https://proxmox:8006/api2/json/nodes/<node>/qemu | jq '.data[] | select(.template==1) | {vmid, name}'
```

## Example Template IDs

Common convention is to use high numbers for templates:

- `9000` - NixOS 23.11 template
- `9001` - NixOS 24.05 template  
- `9010` - Ubuntu 22.04 template
- `9020` - Debian 12 template

## Update Your Composition

After identifying your template IDs, update the composition:

```bash
# Edit the composition
vim crossplane/package/composition.yaml

# Find the template mapping section (around line 127)
# Update with your actual template IDs

# Re-apply if already installed
kubectl apply -f crossplane/package/composition.yaml
```

## Creating Templates

If you don't have templates yet, see [proxmox/template/README.md](../../proxmox/template/README.md) (TODO) for automated template creation with Packer, or create manually:

1. Create a VM in Proxmox
2. Install and configure base OS
3. Install cloud-init, qemu-agent
4. Clean up (clear machine-id, logs, etc.)
5. Convert to template: `qm template <vmid>`

## Using Template Names (Alternative)

If you prefer using template names instead of IDs, you could:

1. **Option A:** Use Crossplane Composition Functions to look up template IDs dynamically
2. **Option B:** Document the ID→name mapping in a ConfigMap
3. **Option C:** Keep using the map transform in the composition (current approach)

The map transform approach (current) is simplest and most explicit.
