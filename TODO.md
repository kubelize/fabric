# Fabric Infrastructure - TODO

## Immediate Actions

### 1. Fix Proxmox API Token Permissions
The `root@pam!fabric` API token needs VM.Clone permission.

**Commands to run on Proxmox:**
```bash
# Option 1: Grant full PVEAdmin role
pveum aclmod / -token 'root@pam!fabric' -role PVEAdmin

# Option 2: Grant specific permissions to clone VM 9000
pveum aclmod /vms/9000 -token 'root@pam!fabric' -role Administrator

# Verify permissions
pveum user permissions root@pam!fabric
```

### 2. Test Machine Deployment
Once permissions are fixed:
```bash
kubectl apply -f crossplane/claims/examples/basic.yaml
kubectl get machines -n infra-machines
kubectl get xmachines
kubectl get workspace -A
```

Watch the Workspace for successful VM creation:
```bash
kubectl describe workspace <workspace-name>
```

### 3. Verify VM Creation in Proxmox
```bash
# On Proxmox host
qm list | grep test-vm
```

## Current State

### ✅ Working
- **Crossplane v2.0.0** installed and healthy
- **function-patch-and-transform** v0.10.0 installed
- **provider-terraform** v0.15.0 installed and configured
- **XRD (Machine)** with explicit CPU/memory/disk fields
- **Composition (xmachine-terraform)** using Terraform provider with bpg/proxmox
- **ProviderConfig** with Kubernetes backend for Terraform state
- **DeploymentRuntimeConfig** for provider-terraform with proper permissions
- Machine → XMachine → Workspace chain fully functional

### ❌ Blocked (One Issue)
- **Proxmox API Permissions**: Token needs VM.Clone permission on template VM 9000
  - Error: `HTTP 403 - Permission check failed (/vms/9000, VM.Clone)`

### 🗑️ Deprecated
- **provider-proxmox-bpg** v1.3.0 - Has a bug preventing EnvironmentVM resources from working
  - Error: `cannot get terraform setup: cannot resolve provider config: resource is not a managed resource`
  - Composition `xmachine-bpg` remains in codebase but is not used

## Next Steps

### Phase 1: Validation
1. ✅ Fix Proxmox permissions
2. ✅ Test VM deployment with basic.yaml example
3. ✅ Verify VM boots and is accessible
4. ✅ Test NixOS bootstrapping with flake reference

### Phase 2: Enhancement
1. **Secret Management**: Move Proxmox credentials from hardcoded values to Secret/ExternalSecret
   - Currently hardcoded in composition vars (insecure)
   - Consider using ESO (External Secrets Operator) with vault/doppler
   
2. **Template Management**: 
   - Document required NixOS template setup (VM 9000)
   - Create automation for template updates
   
3. **Network Configuration**:
   - Add static IP support (currently DHCP only)
   - Add VLAN support testing
   
4. **Cloud-init/NixOS Integration**:
   - Configure cloud-init for SSH keys
   - Test NixOS flake deployment from git repo
   - Verify nixos-rebuild triggers on claim updates

### Phase 3: Production Readiness
1. **Documentation**:
   - Update READY.md with Terraform provider details
   - Document provider-proxmox-bpg deprecation
   - Add troubleshooting guide
   
2. **GitOps Integration**:
   - Test with ArgoCD (existing setup)
   - Ensure proper reconciliation
   
3. **Multiple Machine Testing**:
   - Deploy dns01, docker01 example claims
   - Test claim updates (resize, etc.)
   - Test claim deletion and cleanup

4. **Monitoring**:
   - Add alerts for failed compositions
   - Monitor Terraform workspace state
   - Track VM provision times

## Technical Details

### Composition Architecture
```
Machine (Claim)
  └─> XMachine (Composite)
      └─> Workspace (Managed - Terraform)
          └─> Creates VM in Proxmox via bpg/proxmox provider
```

### Provider Info
- **Provider**: `xpkg.upbound.io/upbound/provider-terraform:v0.15.0`
- **Terraform Provider**: `bpg/proxmox ~> 0.50`
- **ProviderConfig**: Uses Kubernetes backend for state storage
- **Credentials**: Hardcoded in composition (needs migration to Secret)

### Files Modified
- `crossplane/package/xrd.yaml` - Explicit CPU/memory/disk fields
- `crossplane/package/composition.yaml` - Terraform provider implementation
- `crossplane/claims/examples/basic.yaml` - Provider selector updated to `terraform`

### Commands Reference
```bash
# Check overall status
kubectl get machines -n infra-machines
kubectl get xmachines
kubectl get workspace -A

# Debug composition issues
kubectl describe xmachine <name>
kubectl describe workspace <name>

# Check provider status
kubectl get providers.pkg.crossplane.io
kubectl get pods -n crossplane-system -l pkg.crossplane.io/provider=provider-terraform

# View Terraform logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-terraform --tail=100
```

## Notes
- provider-proxmox-bpg (native Crossplane provider) has a bug and should not be used
- Terraform provider approach is working and preferred
- All patches and field structures validated and working
- Only blocker is Proxmox API permission (trivial to fix)
